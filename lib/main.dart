import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'dart:io'; // 用於 CSV
import 'package:path_provider/path_provider.dart'; // 用於 CSV / 圖片
import 'package:scv_water_dashboard/firebase_options.dart';
import 'package:scv_water_dashboard/gemini_service.dart';
import 'package:share_plus/share_plus.dart'; // 用於分享
import 'package:http/http.dart' as http; // 用於 GPT API
import 'dart:convert'; // 用於 GPT API
import 'package:screenshot/screenshot.dart'; // 用於截圖
import 'package:flutter_dotenv/flutter_dotenv.dart';
// GPT Details
/*
API KEY: AIzaSyDRmIRdsu5PBzGmREHxDTaFT39g1WNWKy8
Quick Start: 
curl "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent" \
  -H 'Content-Type: application/json' \
  -H 'X-goog-api-key: AIzaSyDRmIRdsu5PBzGmREHxDTaFT39g1WNWKy8' \
  -X POST \
  -d '{
    "contents": [
      {
        "parts": [
          {
            "text": "Explain how AI works in a few words"
          }
        ]
      }
    ]
  }'
 */

// --- 您需要_Initialize Firebase---
// 1. 請先確保您已設定 Firebase 專案
// 2. 在 pubspec.yaml 加入:
//    flutter_riverpod: ^2.5.1
//    firebase_core: ^2.27.2
//    cloud_firestore: ^4.15.10
//    fl_chart: ^0.67.0         // 圖表
//    intl: ^0.19.0            // 日期格式化
//    path_provider: ^2.1.3     // 存取檔案系統
//    share_plus: ^9.0.0        // 分享檔案
//    http: ^1.2.1             // GPT API 呼叫
//    screenshot: ^2.5.0       // 圖表截圖
//
// 3. 您的 main.dart 應如下所示:
Future<void> main() async {
  // <-- 2. 將 main 改為 Future<void>
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: "key.env"); // <-- 3. 在 Firebase 之前載入 .env

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // 如果您使用 FlutterFire CLI
  );
  runApp(ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App 2 - 儀表板',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: WaterDashboardApp(),
    );
  }
}
// --- Firebase 結束 ---

// --- 資料模型 ---
class WaterLog {
  final String location;
  final double amountML;
  final DateTime timestamp;

  WaterLog({
    required this.location,
    required this.amountML,
    required this.timestamp,
  });

  factory WaterLog.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return WaterLog(
      location: data['location'] ?? 'N/A',
      amountML: (data['amountML'] ?? 0.0).toDouble(),
      // 處理 Firestore Timestamp
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

// --- 狀態管理 (Riverpod) ---

// 儲存目前配對號碼的 Provider
final pairingCodeProvider = StateProvider<String>((ref) {
  // 產生一個 6 位數的隨機碼
  return (100000 + Random().nextInt(900000)).toString();
});

// 透過 StreamProvider 監聽 Firebase 資料
final waterLogStreamProvider = StreamProvider<List<WaterLog>>((ref) {
  final pairingCode = ref.watch(pairingCodeProvider);

  if (pairingCode.isEmpty) {
    return Stream.value([]); // 如果沒有配對碼，返回空串流
  }

  try {
    final stream = FirebaseFirestore.instance
        .collection('channels')
        .doc(pairingCode)
        .collection('logs')
        .orderBy('timestamp', descending: true) // 依時間排序
        .limit(200) // 限制筆數，避免效能問題
        .snapshots();

    // 將 Firestore 快照轉換為 WaterLog 列表
    return stream.map(
      (snapshot) =>
          snapshot.docs.map((doc) => WaterLog.fromFirestore(doc)).toList(),
    );
  } catch (e) {
    print("Firebase 監聽失敗: $e");
    return Stream.value([]);
  }
});

// --- 主畫面 ---
class WaterDashboardApp extends ConsumerWidget {
  const WaterDashboardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pairingCode = ref.watch(pairingCodeProvider);

    return DefaultTabController(
      length: 4, // 4個分頁
      child: Scaffold(
        appBar: AppBar(
          title: Text('App 2 - 用水儀表板'),
          backgroundColor: Colors.deepPurple,
          bottom: TabBar(
            tabs: [
              Tab(icon: Icon(Icons.dashboard), text: '儀表板'),
              Tab(icon: Icon(Icons.bar_chart), text: '歷史圖表'),
              Tab(icon: Icon(Icons.assistant), text: 'AI 助理'),
              Tab(icon: Icon(Icons.edit_note), text: '手動輸入'),
            ],
          ),
        ),
        body: Column(
          children: [
            // --- 配對碼顯示區 ---
            Container(
              color: Colors.deepPurple[50],
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '您的配對號碼:',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.deepPurple[800],
                        ),
                      ),
                      Text(
                        pairingCode,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.refresh,
                      color: Colors.deepPurple,
                      size: 30,
                    ),
                    onPressed: () {
                      // 產生新的配對碼
                      ref.read(pairingCodeProvider.notifier).state =
                          (100000 + Random().nextInt(900000)).toString();
                    },
                  ),
                ],
              ),
            ),
            // --- 分頁內容 ---
            Expanded(
              child: TabBarView(
                children: [
                  DashboardLogView(),
                  HistoryGraphView(),
                  AIAgentView(),
                  ManualEntryView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 分頁 1: 即時日誌 ---
class DashboardLogView extends ConsumerWidget {
  const DashboardLogView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsyncValue = ref.watch(waterLogStreamProvider);

    return logsAsyncValue.when(
      data: (logs) {
        if (logs.isEmpty) {
          return Center(child: Text('等待 App 1 傳送資料...'));
        }

        // 計算今日總用量
        final today = DateTime.now();
        final totalTodayL =
            logs
                .where(
                  (log) =>
                      log.timestamp.year == today.year &&
                      log.timestamp.month == today.month &&
                      log.timestamp.day == today.day,
                )
                .fold(0.0, (sum, log) => sum + log.amountML) /
            1000.0; // 換算成 L

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: Colors.deepPurple[50],
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Center(
                    child: Column(
                      children: [
                        Text(
                          '今日總用量 (L)',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.deepPurple[700],
                          ),
                        ),
                        Text(
                          totalTodayL.toStringAsFixed(2),
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Text(
                "即時紀錄",
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];
                  final formattedTime = DateFormat(
                    'HH:mm:ss',
                  ).format(log.timestamp);
                  final isKitchen = log.location == 'KITCHEN';

                  return ListTile(
                    leading: Icon(
                      isKitchen ? Icons.kitchen : Icons.shower,
                      color: isKitchen ? Colors.orange : Colors.blue,
                    ),
                    title: Text('${log.location} 用水'),
                    subtitle: Text('時間: $formattedTime'),
                    trailing: Text(
                      '${log.amountML.toStringAsFixed(0)} mL',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('發生錯誤: $err')),
    );
  }
}

// --- 分頁 2: 歷史圖表 ---
class HistoryGraphView extends ConsumerStatefulWidget {
  const HistoryGraphView({super.key});

  @override
  _HistoryGraphViewState createState() => _HistoryGraphViewState();
}

class _HistoryGraphViewState extends ConsumerState<HistoryGraphView> {
  // 用於截圖
  final ScreenshotController _screenshotController = ScreenshotController();

  // 將每秒的資料聚合成每小時
  Map<int, double> _aggregateDataByHour(List<WaterLog> logs) {
    final Map<int, double> hourlyTotals = {};
    final now = DateTime.now();

    // 只看今天的資料
    final todayLogs = logs.where(
      (log) =>
          log.timestamp.year == now.year &&
          log.timestamp.month == now.month &&
          log.timestamp.day == now.day,
    );

    for (final log in todayLogs) {
      final hour = log.timestamp.hour;
      final currentTotal = hourlyTotals[hour] ?? 0.0;
      hourlyTotals[hour] = currentTotal + log.amountML;
    }
    return hourlyTotals;
  }

  // 匯出 CSV
  Future<void> _exportCSV(List<WaterLog> logs) async {
    if (logs.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('沒有資料可匯出')));
      return;
    }

    List<List<dynamic>> rows = [];
    // 標題行
    rows.add(["Timestamp", "Location", "Amount (mL)"]);
    // 資料行
    for (var log in logs) {
      rows.add([log.timestamp.toIso8601String(), log.location, log.amountML]);
    }

    // 轉換為 CSV 字串 (簡易版)
    String csv = rows.map((row) => row.join(',')).join('\n');

    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/water_logs.csv';
      final file = File(path);
      await file.writeAsString(csv);

      // 使用 share_plus 分享檔案
      Share.shareXFiles([XFile(path)], text: '我的用水紀錄 CSV');
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('匯出失敗: $e')));
    }
  }

  // 匯出圖片
  Future<void> _exportImage() async {
    try {
      final image = await _screenshotController.capture();
      if (image == null) return;

      final directory = await getTemporaryDirectory();
      final imagePath = await File(
        '${directory.path}/water_chart.png',
      ).create();
      await imagePath.writeAsBytes(image);

      // 使用 share_plus 分享圖片
      Share.shareXFiles([XFile(imagePath.path)], text: '我的用水圖表');
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('匯出圖片失敗: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final logsAsyncValue = ref.watch(waterLogStreamProvider);

    return logsAsyncValue.when(
      data: (logs) {
        final hourlyData = _aggregateDataByHour(logs);

        // 準備 BarChart 資料
        final List<BarChartGroupData> barGroups = [];
        for (int i = 0; i < 24; i++) {
          // 0 點到 23 點
          barGroups.add(
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: (hourlyData[i] ?? 0.0) / 1000.0, // 換算成 L
                  color: Colors.deepPurpleAccent,
                  width: 10,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(
                '今日每小時用量 (L)',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              SizedBox(height: 24),
              // 這是我們要截圖的區域
              Screenshot(
                controller: _screenshotController,
                child: Container(
                  color: Colors.white, // 確保截圖背景是白色
                  height: 300,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: (hourlyData.values.isEmpty
                          ? 10.0
                          : (hourlyData.values.reduce(max) / 1000.0) *
                                1.2), // 最大 Y 軸
                      barGroups: barGroups,
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              // 每 3 小時顯示一個標籤
                              if (value % 3 == 0) {
                                return Text('${value.toInt()}:00');
                              }
                              return Text('');
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                          ),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(show: true, drawVerticalLine: false),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    icon: Icon(Icons.download),
                    label: Text('匯出 CSV'),
                    onPressed: () => _exportCSV(logs),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: Icon(Icons.image),
                    label: Text('匯出圖片'),
                    onPressed: _exportImage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('載入圖表失敗: $err')),
    );
  }
}

// --- 分頁 3: AI 助理 ---
class AIAgentView extends ConsumerStatefulWidget {
  const AIAgentView({super.key});

  @override
  _AIAgentViewState createState() => _AIAgentViewState();
}

class _AIAgentViewState extends ConsumerState<AIAgentView> {
  final TextEditingController _queryController = TextEditingController();
  String _apiResponse = "您可以詢問關於用水習慣的問題... \n(例如：我哪個時段用水最多？)";
  bool _isLoading = false;

  // 3. 建立 GeminiService 的實例
  late final GeminiService _geminiService;

  @override
  void initState() {
    super.initState();
    // 4. 初始化服務
    try {
      _geminiService = GeminiService();
    } catch (e) {
      _apiResponse = "AI 服務初始化失敗: $e \n(請檢查 .env 檔案)";
    }
  }

  // 5. *** 這是我們更新的 _askAgent() 函數 ***
  Future<void> _askAgent() async {
    if (_queryController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _apiResponse = "AI 助理分析中...";
    });

    // 1. 取得所有資料
    final logs = ref.read(waterLogStreamProvider).value ?? [];
    if (logs.isEmpty) {
      setState(() {
        _isLoading = false;
        _apiResponse = "目前沒有用水資料可供分析。";
      });
      return;
    }

    // 2. 格式化資料 (只取最近 100 筆，避免 prompt 過長)
    final dataSummary = logs
        .take(100)
        .map(
          (log) =>
              "${log.timestamp.toIso8601String()}, ${log.location}, ${log.amountML}mL",
        )
        .join('\n');

    final query = _queryController.text;
    _queryController.clear();

    // 3. 呼叫 *新的* GeminiService (替換掉 http.post)
    try {
      final String answer = await _geminiService.ask(query, dataSummary);

      setState(() {
        _apiResponse = answer; // 顯示 AI 的回答
      });
    } catch (e) {
      setState(() {
        _apiResponse = "AI 助理連線錯誤: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 6. Build 方法 (完全不需要改變)
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Expanded(
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SingleChildScrollView(
                child: Text(
                  _apiResponse,
                  style: TextStyle(fontSize: 16, height: 1.5),
                ),
              ),
            ),
          ),
          SizedBox(height: 16),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: LinearProgressIndicator(),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _queryController,
                  decoration: InputDecoration(
                    hintText: '詢問 AI 助理...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onSubmitted: (_) => _askAgent(),
                ),
              ),
              SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.send),
                onPressed: _isLoading ? null : _askAgent,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.all(12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
// --- 分頁 4: 手動輸入 ---

// (我們移除了 _scenarioData map，因為不再需要自動填入)

class ManualEntryView extends ConsumerStatefulWidget {
  const ManualEntryView({super.key});

  @override
  _ManualEntryViewState createState() => _ManualEntryViewState();
}

class _ManualEntryViewState extends ConsumerState<ManualEntryView> {
  bool _isLoading = false;

  // 為 6 個類別建立 TextEditingControllers
  late final TextEditingController _toiletController;
  late final TextEditingController _showerController;
  late final TextEditingController _kitchenController;
  late final TextEditingController _laundryController;
  late final TextEditingController _plantController;
  late final TextEditingController _otherController;

  @override
  void initState() {
    super.initState();
    // 初始化空白的 controllers
    _toiletController = TextEditingController();
    _showerController = TextEditingController();
    _kitchenController = TextEditingController();
    _laundryController = TextEditingController();
    _plantController = TextEditingController();
    _otherController = TextEditingController();

    // (我們移除了 _populateFields()，欄位會是空白的)
  }

  @override
  void dispose() {
    // 記得 dispose controllers
    _toiletController.dispose();
    _showerController.dispose();
    _kitchenController.dispose();
    _laundryController.dispose();
    _plantController.dispose();
    _otherController.dispose();
    super.dispose();
  }

  // (我們移除了 _populateFields() 方法)

  // 將這 6 筆數據作為單日總結傳送到 Firebase
  Future<void> _submitData() async {
    setState(() => _isLoading = true);

    final pairingCode = ref.read(pairingCodeProvider);
    final firestore = FirebaseFirestore.instance;
    final collectionPath = firestore
        .collection('channels')
        .doc(pairingCode)
        .collection('logs');

    // 獲取當前時間
    final now = Timestamp.now();

    // 準備一個 List 包含所有要寫入的數據
    final entries = [
      {
        "location": "MANUAL_TOILET",
        "amountML": (double.tryParse(_toiletController.text) ?? 0.0) * 1000.0,
      },
      {
        "location": "MANUAL_SHOWER",
        "amountML": (double.tryParse(_showerController.text) ?? 0.0) * 1000.0,
      },
      {
        "location": "MANUAL_KITCHEN",
        "amountML": (double.tryParse(_kitchenController.text) ?? 0.0) * 1000.0,
      },
      {
        "location": "MANUAL_LAUNDRY",
        "amountML": (double.tryParse(_laundryController.text) ?? 0.0) * 1000.0,
      },
      {
        "location": "MANUAL_PLANT",
        "amountML": (double.tryParse(_plantController.text) ?? 0.0) * 1000.0,
      },
      {
        "location": "MANUAL_OTHER",
        "amountML": (double.tryParse(_otherController.text) ?? 0.0) * 1000.0,
      },
    ];

    try {
      // 使用 Batch Write 一次性寫入所有數據
      final batch = firestore.batch();
      int entriesAdded = 0;

      for (var entry in entries) {
        final amount = entry["amountML"] as double;
        if (amount > 0) {
          final docRef = collectionPath.doc(); // 建立新文件
          batch.set(docRef, {
            "location": entry["location"],
            "amountML": amount,
            "timestamp": now,
          });
          entriesAdded++;
        }
      }

      if (entriesAdded == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('您沒有輸入任何數據。'), backgroundColor: Colors.orange),
        );
        setState(() => _isLoading = false);
        return;
      }

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('手動數據傳送成功！ ($entriesAdded 筆)'),
          backgroundColor: Colors.green,
        ),
      );

      // 傳送成功後清空欄位
      _toiletController.clear();
      _showerController.clear();
      _kitchenController.clear();
      _laundryController.clear();
      _plantController.clear();
      _otherController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('傳送失敗: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('手動輸入單日總用量 (L)', style: Theme.of(context).textTheme.titleLarge),
          SizedBox(height: 8),
          Text(
            '請在此輸入您一整天的各項總用量 (單位：公升)，然後按下「傳送數據」。\n這些數據將會被加到您的歷史紀錄中。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),

          // (我們移除了 DropdownButton)
          SizedBox(height: 24),
          _buildTextField(_toiletController, '馬桶 (Toilet)', Icons.wc),
          SizedBox(height: 12),
          _buildTextField(_showerController, '淋浴 (Shower)', Icons.shower),
          SizedBox(height: 12),
          _buildTextField(_kitchenController, '廚房 (Kitchen)', Icons.kitchen),
          SizedBox(height: 12),
          _buildTextField(
            _laundryController,
            '洗衣 (Laundry)',
            Icons.local_laundry_service,
          ),
          SizedBox(height: 12),
          _buildTextField(_plantController, '植物 (Plant)', Icons.local_florist),
          SizedBox(height: 12),
          _buildTextField(_otherController, '其他 (Other)', Icons.more_horiz),
          SizedBox(height: 24),
          ElevatedButton.icon(
            icon: Icon(Icons.send),
            label: Text(_isLoading ? '傳送中...' : '傳送數據到 Firebase'),
            onPressed: _isLoading ? null : _submitData,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16),
              textStyle: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  // 輔助 Widet，用於建立文字欄位
  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon,
  ) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: '0.0', // 提示用戶輸入
        prefixIcon: Icon(icon),
        suffixText: 'L',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      keyboardType: TextInputType.numberWithOptions(decimal: true),
    );
  }
}
