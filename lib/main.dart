import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'add_device_page.dart';
import 'add_site_page.dart';
import 'firebase_options.dart';
import 'gemini_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: "assets/key.env");
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProviderScope(child: WaterDashboardApp()));
}

class WaterDashboardApp extends StatelessWidget {
  const WaterDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SCV Water Dashboard',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const WaterDashboardApp();
  }
}

double _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}

bool _isDeviceAbnormal(
  Map<String, dynamic> schema,
  Map<String, dynamic> latestData,
) {
  final fields = (schema['fields'] as List<dynamic>? ?? []).whereType<Map>();
  for (final f in fields) {
    final key = f['key']?.toString();
    if (key == null || key.isEmpty) continue;
    final max = _toDouble(f['max_threshold']);
    if (max <= 0) continue;
    final value = _toDouble(latestData[key]);
    if (value > max) return true;
  }
  return false;
}

double _deviceTotalFlow(
  Map<String, dynamic> schema,
  Map<String, dynamic> latestData,
) {
  double sum = 0;
  final fields = (schema['fields'] as List<dynamic>? ?? []).whereType<Map>();
  for (final f in fields) {
    final key = f['key']?.toString();
    if (key == null || key.isEmpty) continue;
    sum += _toDouble(latestData[key]);
  }
  return sum;
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _tabIndex = 0;
  bool _autoTriggerEnabled = false;
  int _autoTriggerSeconds = 15;

  void _openAddDevice() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddDevicePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const DevicesDashboardTab(),
      const SiteManagementTab(),
      const ConnectivityTab(),
      PostAnalysisTab(
        autoTriggerEnabled: _autoTriggerEnabled,
        autoTriggerSeconds: _autoTriggerSeconds,
      ),
      AutoTriggerSettingsTab(
        enabled: _autoTriggerEnabled,
        seconds: _autoTriggerSeconds,
        onEnabledChanged: (value) => setState(() => _autoTriggerEnabled = value),
        onSecondsChanged: (value) => setState(() => _autoTriggerSeconds = value),
      ),
      const ManualInputTab(),
    ];

    final titles = [
      'SCV 智慧水資源監控',
      '場域管理',
      '連線設定',
      '場域 Post-AI',
      'Auto Trigger 設定',
      '手動輸入',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_tabIndex]),
        backgroundColor: Colors.deepPurple.shade100,
        actions: [
          if (_tabIndex == 0)
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add_business_outlined),
                  tooltip: "新增場域",
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddSitePage()),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: "新增裝置 (AI)",
                  onPressed: _openAddDevice,
                ),
              ],
            ),
          if (_tabIndex == 1)
            IconButton(
              icon: const Icon(Icons.add_business_outlined),
              tooltip: "新增場域",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddSitePage()),
                );
              },
            ),
        ],
      ),
      body: pages[_tabIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (idx) => setState(() => _tabIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: '儀表板'),
          NavigationDestination(icon: Icon(Icons.domain), label: '場域'),
          NavigationDestination(icon: Icon(Icons.cable), label: '連線'),
          NavigationDestination(icon: Icon(Icons.psychology), label: '場域AI'),
          NavigationDestination(icon: Icon(Icons.tune), label: 'Auto'),
          NavigationDestination(icon: Icon(Icons.edit_note), label: '手動'),
        ],
      ),
    );
  }
}

class DevicesDashboardTab extends StatefulWidget {
  const DevicesDashboardTab({super.key});

  @override
  State<DevicesDashboardTab> createState() => _DevicesDashboardTabState();
}

class _DevicesDashboardTabState extends State<DevicesDashboardTab> {
  String _sortBy = 'abnormal';

  Future<void> _deleteDevice(String sensorDocId, String deviceId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('刪除裝置'),
        content: Text('確定刪除裝置 $deviceId？\n（僅刪除 sensors 文件）'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await FirebaseFirestore.instance.collection('sensors').doc(sensorDocId).delete();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已刪除裝置 $deviceId')),
    );
  }

  Future<void> _clearDeviceSite(String sensorDocId) async {
    await FirebaseFirestore.instance.collection('sensors').doc(sensorDocId).set({
      'site_id': null,
      'site_name': null,
    }, SetOptions(merge: true));
  }

  Future<void> _changeDeviceSite(
    String sensorDocId,
    String currentSiteId,
  ) async {
    final sites = await FirebaseFirestore.instance
        .collection('sites')
        .orderBy('created_at', descending: true)
        .get();
    if (!mounted) return;
    String? selected = currentSiteId.isEmpty ? null : currentSiteId;
    final chosen = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) => AlertDialog(
            title: const Text('更改場域'),
            content: DropdownButtonFormField<String>(
              initialValue: selected,
              items: sites.docs.map((doc) {
                final data = doc.data();
                final id = data['id']?.toString() ?? doc.id;
                final name = data['name']?.toString() ?? id;
                return DropdownMenuItem<String>(
                  value: id,
                  child: Text('$name ($id)'),
                );
              }).toList(),
              onChanged: (v) => setLocal(() => selected = v),
              decoration: const InputDecoration(
                labelText: '選擇場域',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, selected),
                child: const Text('儲存'),
              ),
            ],
          ),
        );
      },
    );
    if (chosen == null) return;
    final siteData = sites.docs
        .map((d) => d.data())
        .cast<Map<String, dynamic>>()
        .firstWhere(
          (d) => (d['id']?.toString() ?? '') == chosen,
          orElse: () => <String, dynamic>{},
        );
    await FirebaseFirestore.instance.collection('sensors').doc(sensorDocId).set({
      'site_id': chosen,
      'site_name': siteData['name']?.toString(),
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sensors')
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("錯誤: ${snapshot.error}"));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("目前沒有裝置，請按右上角 [+] 新增"));
        }

        final devices = snapshot.data!.docs;
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collectionGroup('stream')
              .orderBy('timestamp', descending: true)
              .limit(1200)
              .snapshots(),
          builder: (context, readingSnap) {
            final latestByDevice = <String, Map<String, dynamic>>{};
            for (final d in readingSnap.data?.docs ?? const []) {
              final deviceId = d.reference.parent.parent?.id;
              if (deviceId == null) continue;
              latestByDevice.putIfAbsent(
                deviceId,
                () => d.data() as Map<String, dynamic>,
              );
            }

            final enriched = devices.map((doc) {
              final deviceData = doc.data() as Map<String, dynamic>;
              final id = deviceData['id']?.toString() ?? '';
              final schema =
                  (deviceData['schema'] as Map?)?.cast<String, dynamic>() ??
                  <String, dynamic>{};
              final latest = latestByDevice[id] ?? <String, dynamic>{};
              final abnormal = _isDeviceAbnormal(schema, latest);
              final total = _deviceTotalFlow(schema, latest);
              return {
                'docId': doc.id,
                'raw': deviceData,
                'latest': latest,
                'abnormal': abnormal,
                'total': total,
              };
            }).toList();

            if (_sortBy == 'place_asc') {
              enriched.sort((a, b) => ((a['raw'] as Map<String, dynamic>)['place']
                      ?.toString() ??
                  '').compareTo(
                ((b['raw'] as Map<String, dynamic>)['place']?.toString() ?? ''),
              ));
            } else if (_sortBy == 'site_asc') {
              enriched.sort((a, b) => ((a['raw'] as Map<String, dynamic>)['site_name']
                      ?.toString() ??
                  '').compareTo(
                ((b['raw'] as Map<String, dynamic>)['site_name']?.toString() ?? ''),
              ));
            } else {
              enriched.sort((a, b) {
                final abnormalCmp =
                    ((b['abnormal'] as bool) ? 1 : 0) -
                    ((a['abnormal'] as bool) ? 1 : 0);
                if (abnormalCmp != 0) return abnormalCmp;
                return (b['total'] as double).compareTo(a['total'] as double);
              });
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: DropdownButtonFormField<String>(
                    initialValue: _sortBy,
                    items: const [
                      DropdownMenuItem(
                        value: 'abnormal',
                        child: Text('排序：異常優先'),
                      ),
                      DropdownMenuItem(value: 'place_asc', child: Text('排序：位置 A-Z')),
                      DropdownMenuItem(value: 'site_asc', child: Text('排序：場域 A-Z')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _sortBy = v);
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: enriched.length,
                    itemBuilder: (context, index) {
                      final docId = enriched[index]['docId'] as String;
                      final raw = enriched[index]['raw'] as Map<String, dynamic>;
                      final latest =
                          enriched[index]['latest'] as Map<String, dynamic>;
                      final abnormal = enriched[index]['abnormal'] as bool;
                      final deviceId = raw['id']?.toString() ?? docId;
                      final currentSiteId = raw['site_id']?.toString() ?? '';
                      return SensorCard(
                        deviceId: deviceId,
                        siteName: raw['site_name']?.toString(),
                        place: raw['place'] ?? '未命名區域',
                        schema: raw['schema'] ?? {},
                        connectionProfile:
                            (raw['connection_profile'] as Map?)
                                ?.cast<String, dynamic>(),
                        latestData: latest,
                        isAbnormal: abnormal,
                        onChangeSite: () => _changeDeviceSite(docId, currentSiteId),
                        onClearSite: () => _clearDeviceSite(docId),
                        onDeleteDevice: () => _deleteDevice(docId, deviceId),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class PostAnalysisTab extends StatefulWidget {
  final bool autoTriggerEnabled;
  final int autoTriggerSeconds;

  const PostAnalysisTab({
    super.key,
    required this.autoTriggerEnabled,
    required this.autoTriggerSeconds,
  });

  @override
  State<PostAnalysisTab> createState() => _PostAnalysisTabState();
}

class _PostAnalysisTabState extends State<PostAnalysisTab> {
  final _gemini = GeminiService();
  String? _selectedSiteId;
  String? _selectedSiteName;
  final _questionController = TextEditingController(
    text: '請分析這個場域目前是否有異常用水，並給出節水建議。',
  );
  Timer? _autoTimer;
  String _result = '尚未分析';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _syncAutoTimer();
  }

  @override
  void didUpdateWidget(covariant PostAnalysisTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autoTriggerEnabled != widget.autoTriggerEnabled ||
        oldWidget.autoTriggerSeconds != widget.autoTriggerSeconds) {
      _syncAutoTimer();
    }
  }

  void _syncAutoTimer() {
    _autoTimer?.cancel();
    if (!widget.autoTriggerEnabled) return;
    _autoTimer = Timer.periodic(
      Duration(seconds: widget.autoTriggerSeconds),
      (_) => _runAnalysis(autoTriggered: true),
    );
  }

  Future<void> _runAnalysis({bool autoTriggered = false}) async {
    final siteId = _selectedSiteId;
    if (siteId == null || siteId.isEmpty) {
      if (!autoTriggered && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('請先選擇場域')));
      }
      return;
    }

    setState(() => _loading = true);
    try {
      final sensorQuery = await FirebaseFirestore.instance
          .collection('sensors')
          .where('site_id', isEqualTo: siteId)
          .get();

      if (sensorQuery.docs.isEmpty) {
        setState(() => _result = '此場域目前沒有裝置可分析。');
        return;
      }

      final summaryLines = <String>[];
      for (final sensorDoc in sensorQuery.docs) {
        final sensor = sensorDoc.data();
        final deviceId = sensor['id']?.toString() ?? sensorDoc.id;
        final place = sensor['place']?.toString() ?? '未命名區域';
        final query = await FirebaseFirestore.instance
            .collection('readings')
            .doc(deviceId)
            .collection('stream')
            .orderBy('timestamp', descending: true)
            .limit(8)
            .get();
        if (query.docs.isEmpty) {
          summaryLines.add('[$place/$deviceId] no_data');
          continue;
        }
        for (final doc in query.docs) {
          final data = doc.data();
          final ts = data['timestamp'];
          final map = Map<String, dynamic>.from(data)..remove('timestamp');
          summaryLines.add('[$place/$deviceId] ${ts ?? 'no_ts'} ${jsonEncode(map)}');
        }
      }

      if (summaryLines.isEmpty) {
        setState(() => _result = '此場域裝置尚無資料可分析。');
        return;
      }

      final summary = summaryLines.join('\n');
      final prefixedQuestion =
          '場域：${_selectedSiteName ?? siteId}\n${_questionController.text.trim()}';
      final answer = await _gemini.ask(prefixedQuestion, summary);
      setState(() => _result = answer);
    } catch (e) {
      setState(() => _result = '分析失敗: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _questionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('sites')
                .orderBy('created_at', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const LinearProgressIndicator();
              }
              final docs = snapshot.data!.docs;
              final items = docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final id = data['id']?.toString() ?? doc.id;
                final name = data['name']?.toString() ?? id;
                return DropdownMenuItem<String>(
                  value: id,
                  child: Text('$name ($id)'),
                );
              }).toList();
              final valid = items.any((i) => i.value == _selectedSiteId)
                  ? _selectedSiteId
                  : null;

              return DropdownButtonFormField<String>(
                key: ValueKey(valid),
                initialValue: valid,
                items: items,
                onChanged: (value) {
                  String? siteName;
                  for (final d in docs) {
                    final data = d.data() as Map<String, dynamic>;
                    if ((data['id']?.toString() ?? d.id) == value) {
                      siteName = data['name']?.toString();
                      break;
                    }
                  }
                  setState(() {
                    _selectedSiteId = value;
                    _selectedSiteName = siteName;
                  });
                },
                decoration: const InputDecoration(
                  labelText: '選擇要分析的場域',
                  border: OutlineInputBorder(),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _questionController,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '問題',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _loading ? null : () => _runAnalysis(),
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.analytics),
                label: const Text('分析'),
              ),
              const SizedBox(width: 12),
              if (widget.autoTriggerEnabled)
                Text('Auto 每 ${widget.autoTriggerSeconds}s', style: const TextStyle(color: Colors.deepPurple)),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.share),
                      label: const Text('分享'),
                      onPressed: () {
                        SharePlus.instance.share(
                          ShareParams(text: _result, subject: 'SCV 場域AI 分析結果'),
                        );
                      },
                    ),
                  ],
                ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Markdown(
                      data: _result,
                      selectable: true,
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AutoTriggerSettingsTab extends StatelessWidget {
  final bool enabled;
  final int seconds;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<int> onSecondsChanged;

  const AutoTriggerSettingsTab({
    super.key,
    required this.enabled,
    required this.seconds,
    required this.onEnabledChanged,
    required this.onSecondsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          title: const Text('啟用 Auto Trigger'),
          subtitle: const Text('自動觸發 Post-analysis GPT'),
          value: enabled,
          onChanged: onEnabledChanged,
        ),
        const SizedBox(height: 8),
        Text('觸發間隔: $seconds 秒'),
        Slider(
          value: seconds.toDouble(),
          min: 5,
          max: 120,
          divisions: 23,
          label: '$seconds s',
          onChanged: enabled ? (v) => onSecondsChanged(v.round()) : null,
        ),
        const SizedBox(height: 16),
        const Text(
          '說明：啟用後，場域 Post-AI 分頁會依設定秒數自動讀取最近資料並送給 GPT。',
        ),
      ],
    );
  }
}

class ManualInputTab extends StatefulWidget {
  const ManualInputTab({super.key});

  @override
  State<ManualInputTab> createState() => _ManualInputTabState();
}

class _ManualInputTabState extends State<ManualInputTab> {
  String? _selectedDeviceId;
  final _kController = TextEditingController();
  final _sController = TextEditingController();
  final _bController = TextEditingController();
  final _tController = TextEditingController();
  bool _saving = false;

  Future<void> _submit() async {
    final id = _selectedDeviceId;
    if (id == null || id.isEmpty) return;

    final data = {
      'kitchen_flow': double.tryParse(_kController.text) ?? 0.0,
      'shower_flow': double.tryParse(_sController.text) ?? 0.0,
      'bathtub_flow': double.tryParse(_bController.text) ?? 0.0,
      'toilet_flow': double.tryParse(_tController.text) ?? 0.0,
    };

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('readings')
          .doc(id)
          .collection('stream')
          .add({
            ...data,
            'timestamp': FieldValue.serverTimestamp(),
          });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('手動資料已送出')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('送出失敗: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _numField(TextEditingController c, String label) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  @override
  void dispose() {
    _kController.dispose();
    _sController.dispose();
    _bController.dispose();
    _tController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DeviceSelectorField(
          selectedId: _selectedDeviceId,
          label: '選擇要寫入的裝置',
          onChanged: (value) => setState(() => _selectedDeviceId = value),
        ),
        const SizedBox(height: 10),
        _numField(_kController, 'kitchen_flow (mL/s)'),
        const SizedBox(height: 10),
        _numField(_sController, 'shower_flow (mL/s)'),
        const SizedBox(height: 10),
        _numField(_bController, 'bathtub_flow (mL/s)'),
        const SizedBox(height: 10),
        _numField(_tController, 'toilet_flow (mL/s)'),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _saving ? null : _submit,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send),
          label: const Text('送出手動資料'),
        ),
      ],
    );
  }
}

class SensorCard extends StatelessWidget {
  final String deviceId;
  final String? siteName;
  final Map<String, dynamic> schema;
  final Map<String, dynamic>? connectionProfile;
  final Map<String, dynamic>? latestData;
  final bool isAbnormal;
  final Future<void> Function()? onChangeSite;
  final Future<void> Function()? onClearSite;
  final Future<void> Function()? onDeleteDevice;
  final String place;

  const SensorCard({
    super.key,
    required this.deviceId,
    this.siteName,
    required this.schema,
    this.connectionProfile,
    this.latestData,
    this.isAbnormal = false,
    this.onChangeSite,
    this.onClearSite,
    this.onDeleteDevice,
    required this.place,
  });

  @override
  Widget build(BuildContext context) {
    final List<dynamic> fields = schema['fields'] ?? [];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DeviceHistoryPage(
                deviceId: deviceId,
                place: place,
                schema: schema,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      "ID: $deviceId",
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    if (siteName != null && siteName!.isNotEmpty)
                      Text(
                        "場域: $siteName",
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Icon(Icons.water_drop, color: Colors.blueAccent),
                    if (connectionProfile != null)
                      Text(
                        (connectionProfile!['protocol'] ?? '-').toString(),
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    if (isAbnormal)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Chip(
                          label: Text('異常', style: TextStyle(color: Colors.white)),
                          backgroundColor: Colors.red,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    PopupMenuButton<String>(
                      tooltip: '裝置操作',
                      onSelected: (value) async {
                        if (value == 'change_site' && onChangeSite != null) {
                          await onChangeSite!.call();
                        } else if (value == 'clear_site' && onClearSite != null) {
                          await onClearSite!.call();
                        } else if (value == 'delete' && onDeleteDevice != null) {
                          await onDeleteDevice!.call();
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'change_site',
                          child: Text('更改場域'),
                        ),
                        PopupMenuItem(
                          value: 'clear_site',
                          child: Text('移出場域'),
                        ),
                        PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('刪除裝置'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            _DeviceLatestView(
              deviceId: deviceId,
              fields: fields,
              latestData: latestData,
            ),
              const SizedBox(height: 8),
              Text(
                '點擊查看分時圖表與欄位',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceLatestView extends StatelessWidget {
  final String deviceId;
  final List<dynamic> fields;
  final Map<String, dynamic>? latestData;

  const _DeviceLatestView({
    required this.deviceId,
    required this.fields,
    this.latestData,
  });

  @override
  Widget build(BuildContext context) {
    if (latestData != null && latestData!.isNotEmpty) {
      return _buildContent(latestData!);
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('readings')
          .doc(deviceId)
          .collection('stream')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Text("數據異常");
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text(
            "等待數據連接...",
            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
          );
        }
        final latest = snapshot.data!.docs.first.data() as Map<String, dynamic>;
        return _buildContent(latest);
      },
    );
  }

  Widget _buildContent(Map<String, dynamic> latest) {
    return Column(
      children: fields.map((field) {
        final key = field['key'];
        final label = field['label'] ?? key;
        final unit = field['unit'] ?? '';
        final value = _toDouble(latest[key]);
        final maxVal = _toDouble(field['max_threshold']);
        final safeMax = maxVal > 0 ? maxVal : 1000;
        final percent = (value / safeMax).clamp(0.0, 1.0);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label, style: TextStyle(color: Colors.grey[800])),
                  Text(
                    "${value.toStringAsFixed(1)} $unit",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: percent > 0.8 ? Colors.red : Colors.blue[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percent,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation(
                    percent > 0.8 ? Colors.redAccent : Colors.blueAccent,
                  ),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class ConnectivityTab extends StatelessWidget {
  const ConnectivityTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sensors')
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('尚未有裝置可設定連線'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final docId = docs[index].id;
            final id = data['id']?.toString() ?? docId;
            final place = data['place']?.toString() ?? '未命名區域';
            final cp =
                (data['connection_profile'] as Map?)?.cast<String, dynamic>() ??
                <String, dynamic>{};
            final protocol = cp['protocol']?.toString() ?? 'emulator';
            final status = cp['status']?.toString() ?? 'pending';
            final endpoint = cp['endpoint']?.toString() ?? '';
            final topic = cp['topic']?.toString() ?? '';
            final meta = <String>[
              if (endpoint.isNotEmpty) 'endpoint: $endpoint',
              if (topic.isNotEmpty) 'topic: $topic',
            ].join(' | ');
            return Card(
              child: ListTile(
                leading: const Icon(Icons.cable),
                title: Text('$place ($id)'),
                subtitle: Text(
                  'protocol: $protocol | status: $status${meta.isNotEmpty ? '\n$meta' : ''}',
                ),
                isThreeLine: meta.isNotEmpty,
                trailing: IconButton(
                  icon: const Icon(Icons.check_circle_outline),
                  tooltip: '標記為 online',
                  onPressed: () async {
                    await FirebaseFirestore.instance
                        .collection('sensors')
                        .doc(docId)
                        .set({
                          'connection_profile': {
                            ...cp,
                            'status': 'online',
                            'updated_at': FieldValue.serverTimestamp(),
                          },
                        }, SetOptions(merge: true));
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class DeviceSelectorField extends StatelessWidget {
  final String? selectedId;
  final String label;
  final ValueChanged<String?> onChanged;

  const DeviceSelectorField({
    super.key,
    required this.selectedId,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sensors')
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const LinearProgressIndicator();
        }
        final docs = snapshot.data!.docs;
        final options = docs
            .map((d) => (d.data() as Map<String, dynamic>)['id']?.toString())
            .whereType<String>()
            .toList();
        final value = options.contains(selectedId) ? selectedId : null;

        return DropdownButtonFormField<String>(
          key: ValueKey(value),
          initialValue: value,
          items: options
              .map(
                (id) => DropdownMenuItem(
                  value: id,
                  child: Text(id),
                ),
              )
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        );
      },
    );
  }
}

class SiteManagementTab extends StatefulWidget {
  const SiteManagementTab({super.key});

  @override
  State<SiteManagementTab> createState() => _SiteManagementTabState();
}

class _SiteManagementTabState extends State<SiteManagementTab> {
  String _sortBy = 'abnormal';

  Future<void> _deleteSite(String siteDocId, String siteId, String siteName) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('刪除場域'),
        content: Text('確定刪除場域 $siteName ($siteId)？\n會一併清空所屬裝置的場域欄位。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final sensors = await FirebaseFirestore.instance
        .collection('sensors')
        .where('site_id', isEqualTo: siteId)
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in sensors.docs) {
      batch.set(doc.reference, {
        'site_id': null,
        'site_name': null,
      }, SetOptions(merge: true));
    }
    batch.delete(FirebaseFirestore.instance.collection('sites').doc(siteDocId));
    await batch.commit();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已刪除場域 $siteName')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sites')
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, siteSnap) {
        if (!siteSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final siteDocs = siteSnap.data!.docs;
        if (siteDocs.isEmpty) {
          return const Center(child: Text('目前沒有場域，請按右上角新增'));
        }
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('sensors').snapshots(),
          builder: (context, sensorSnap) {
            final sensorDocs = sensorSnap.data?.docs ?? const [];
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collectionGroup('stream')
                  .orderBy('timestamp', descending: true)
                  .limit(1200)
                  .snapshots(),
              builder: (context, readingSnap) {
                final latestByDevice = <String, Map<String, dynamic>>{};
                for (final d in readingSnap.data?.docs ?? const []) {
                  final deviceId = d.reference.parent.parent?.id;
                  if (deviceId == null) continue;
                  latestByDevice.putIfAbsent(
                    deviceId,
                    () => d.data() as Map<String, dynamic>,
                  );
                }

                final rows = siteDocs.map((doc) {
                  final site = doc.data() as Map<String, dynamic>;
                  final siteId = site['id']?.toString() ?? doc.id;
                  final siteName = site['name']?.toString() ?? siteId;
                  final description = site['description']?.toString() ?? '';
                  final related = sensorDocs.where((s) {
                    final data = s.data() as Map<String, dynamic>;
                    return data['site_id']?.toString() == siteId;
                  }).toList();

                  int abnormalCount = 0;
                  double totalFlow = 0;
                  for (final s in related) {
                    final sensor = s.data() as Map<String, dynamic>;
                    final id = sensor['id']?.toString() ?? '';
                    final schema =
                        (sensor['schema'] as Map?)?.cast<String, dynamic>() ??
                        <String, dynamic>{};
                    final latest = latestByDevice[id] ?? <String, dynamic>{};
                    if (_isDeviceAbnormal(schema, latest)) abnormalCount++;
                    totalFlow += _deviceTotalFlow(schema, latest);
                  }

                  return {
                    'docId': doc.id,
                    'id': siteId,
                    'name': siteName,
                    'description': description,
                    'deviceCount': related.length,
                    'abnormalCount': abnormalCount,
                    'totalFlow': totalFlow,
                  };
                }).toList();

                if (_sortBy == 'name_asc') {
                  rows.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
                } else if (_sortBy == 'devices_desc') {
                  rows.sort(
                    (a, b) => (b['deviceCount'] as int).compareTo(a['deviceCount'] as int),
                  );
                } else {
                  rows.sort((a, b) {
                    final ab = (b['abnormalCount'] as int).compareTo(
                      a['abnormalCount'] as int,
                    );
                    if (ab != 0) return ab;
                    return (b['totalFlow'] as double).compareTo(
                      a['totalFlow'] as double,
                    );
                  });
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: DropdownButtonFormField<String>(
                        initialValue: _sortBy,
                        items: const [
                          DropdownMenuItem(
                            value: 'abnormal',
                            child: Text('排序：異常優先'),
                          ),
                          DropdownMenuItem(
                            value: 'name_asc',
                            child: Text('排序：名稱 A-Z'),
                          ),
                          DropdownMenuItem(
                            value: 'devices_desc',
                            child: Text('排序：裝置數量多到少'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _sortBy = v);
                        },
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: rows.length,
                        itemBuilder: (context, index) {
                          final row = rows[index];
                          final docId = row['docId'] as String;
                          final id = row['id'] as String;
                          final name = row['name'] as String;
                          final description = row['description'] as String;
                          final deviceCount = row['deviceCount'] as int;
                          final abnormal = row['abnormalCount'] as int;
                          final totalFlow = row['totalFlow'] as double;
                          return Card(
                            child: ListTile(
                              leading: Icon(
                                abnormal > 0 ? Icons.warning_amber : Icons.domain,
                                color: abnormal > 0 ? Colors.red : null,
                              ),
                              title: Text(name),
                              subtitle: Text(
                                'ID: $id\n裝置: $deviceCount  異常: $abnormal  總流量: ${totalFlow.toStringAsFixed(1)} mL/s\n$description',
                              ),
                              isThreeLine: true,
                              trailing: PopupMenuButton<String>(
                                onSelected: (v) async {
                                  if (v == 'delete') {
                                    await _deleteSite(docId, id, name);
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('刪除場域'),
                                  ),
                                ],
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SiteDetailPage(
                                      siteId: id,
                                      siteName: name,
                                      description: description,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class DeviceHistoryPage extends StatefulWidget {
  final String deviceId;
  final Map<String, dynamic> schema;
  final String place;

  const DeviceHistoryPage({
    super.key,
    required this.deviceId,
    required this.schema,
    required this.place,
  });

  @override
  State<DeviceHistoryPage> createState() => _DeviceHistoryPageState();
}

class _DeviceHistoryPageState extends State<DeviceHistoryPage> {
  late Set<String> _selectedKeys;
  int _windowHours = 1;

  String _readableHistoryError(Object error) {
    if (error is TimeoutException) {
      return '讀取逾時：資料量較大或網路較慢，請先切 1 小時再試。';
    }
    final text = error.toString();
    if (text.contains('failed-precondition') || text.contains('index')) {
      return 'Firestore 索引尚未建立，請建立 readings/{device_id}/stream 的 timestamp 查詢索引後重試。';
    }
    if (text.contains('permission-denied')) {
      return '沒有讀取權限，請確認 Firestore Rules。';
    }
    return '讀取資料失敗：$text';
  }

  List<QueryDocumentSnapshot> _downsampleDocs(
    List<QueryDocumentSnapshot> docs,
    int maxPoints,
  ) {
    if (docs.length <= maxPoints) return docs;
    final step = (docs.length / maxPoints).ceil();
    final sampled = <QueryDocumentSnapshot>[];
    for (int i = 0; i < docs.length; i += step) {
      sampled.add(docs[i]);
    }
    if (sampled.isNotEmpty && sampled.last.id != docs.last.id) {
      sampled.add(docs.last);
    }
    return sampled;
  }

  @override
  void initState() {
    super.initState();
    final fields = (widget.schema['fields'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((f) => f['key']?.toString() ?? '')
        .where((k) => k.isNotEmpty)
        .toSet();
    _selectedKeys = fields;
  }

  @override
  Widget build(BuildContext context) {
    final fields = (widget.schema['fields'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map(
          (f) => {
            'key': (f['key'] ?? '').toString(),
            'label': (f['label'] ?? f['key'] ?? '').toString(),
          },
        )
        .where((f) => (f['key'] as String).isNotEmpty)
        .toList();
    final cutoffTs = Timestamp.fromDate(
      DateTime.now().subtract(Duration(hours: _windowHours)),
    );
    // Keep query size bounded to avoid loading stalls on Flutter Web.
    final queryLimit = _windowHours == 1
        ? 1800
        : (_windowHours == 24 ? 3600 : 7200);
    final maxRenderPoints = _windowHours == 1
        ? 600
        : (_windowHours == 24 ? 900 : 1200);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.place} (${widget.deviceId})'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('readings')
            .doc(widget.deviceId)
            .collection('stream')
            .where('timestamp', isGreaterThanOrEqualTo: cutoffTs)
            .orderBy('timestamp', descending: true)
            .limit(queryLimit)
            .snapshots()
            .timeout(const Duration(seconds: 12)),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _readableHistoryError(snapshot.error!),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs.reversed.toList();
          final isTruncated = snapshot.data!.docs.length >= queryLimit;
          final renderDocs = _downsampleDocs(docs, maxRenderPoints);
          final isDownsampled = renderDocs.length < docs.length;

          final colorPool = <Color>[
            Colors.blue,
            Colors.orange,
            Colors.green,
            Colors.red,
            Colors.purple,
            Colors.teal,
          ];

          final lines = <LineChartBarData>[];
          int colorIdx = 0;
          for (final key in _selectedKeys) {
            final spots = <FlSpot>[];
            for (int i = 0; i < renderDocs.length; i++) {
              final doc = renderDocs[i];
              final data = doc.data() as Map<String, dynamic>;
              final val = data[key];
              if (val is num && val.toDouble().isFinite) {
                spots.add(
                  FlSpot(
                    i.toDouble(),
                    val.toDouble(),
                  ),
                );
              }
            }
            if (spots.isNotEmpty) {
              lines.add(
                LineChartBarData(
                  spots: spots,
                  // Use straight lines to avoid spline overshoot artifacts.
                  isCurved: false,
                  barWidth: 2,
                  color: colorPool[colorIdx % colorPool.length],
                  dotData: const FlDotData(show: false),
                ),
              );
              colorIdx++;
            }
          }
          final maxX = lines
              .expand((line) => line.spots.map((s) => s.x))
              .fold<double>(0, math.max);
          final maxY = lines
              .expand((line) => line.spots.map((s) => s.y))
              .fold<double>(0, math.max);
          final selectedValues = <double>[];
          for (final key in _selectedKeys) {
            for (final doc in docs) {
              final data = doc.data() as Map<String, dynamic>;
              final val = data[key];
              if (val is num) selectedValues.add(val.toDouble());
            }
          }
          final avg = selectedValues.isEmpty
              ? 0.0
              : selectedValues.reduce((a, b) => a + b) / selectedValues.length;
          final peak = selectedValues.isEmpty
              ? 0.0
              : selectedValues.reduce(math.max);
          final minVal = selectedValues.isEmpty
              ? 0.0
              : selectedValues.reduce(math.min);
          const commonDefaults = {
            'kitchen_flow',
            'shower_flow',
            'bathtub_flow',
            'toilet_flow',
          };
          final fieldKeys = fields
              .map((f) => f['key'] as String)
              .where((k) => k.isNotEmpty)
              .toSet();
          final commonKeys = fieldKeys.where(commonDefaults.contains).toSet();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('1 小時'),
                    selected: _windowHours == 1,
                    onSelected: (_) => setState(() => _windowHours = 1),
                  ),
                  ChoiceChip(
                    label: const Text('24 小時'),
                    selected: _windowHours == 24,
                    onSelected: (_) => setState(() => _windowHours = 24),
                  ),
                  ChoiceChip(
                    label: const Text('7 天'),
                    selected: _windowHours == 168,
                    onSelected: (_) => setState(() => _windowHours = 168),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _selectedKeys = fieldKeys),
                    icon: const Icon(Icons.done_all),
                    label: const Text('全選'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _selectedKeys.clear()),
                    icon: const Icon(Icons.clear_all),
                    label: const Text('清空'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      setState(() {
                        _selectedKeys = commonKeys.isEmpty ? fieldKeys : commonKeys;
                      });
                    },
                    icon: const Icon(Icons.auto_graph),
                    label: const Text('常用欄位'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: fields.map((field) {
                  final key = field['key'] as String;
                  final label = field['label'] as String;
                  return FilterChip(
                    label: Text(label),
                    selected: _selectedKeys.contains(key),
                    onSelected: (checked) {
                      setState(() {
                        if (checked) {
                          _selectedKeys.add(key);
                        } else {
                          _selectedKeys.remove(key);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Text('平均: ${avg.toStringAsFixed(2)}'),
                      Text('峰值: ${peak.toStringAsFixed(2)}'),
                      Text('最小: ${minVal.toStringAsFixed(2)}'),
                      Text('樣本: ${selectedValues.length}'),
                    ],
                  ),
                ),
              ),
              if (isTruncated) ...[
                const SizedBox(height: 8),
                Text(
                  '資料量過大，已顯示最近 $queryLimit 筆（建議搭配 1 小時或後續啟用降採樣）。',
                  style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
                ),
              ],
              if (isDownsampled) ...[
                const SizedBox(height: 4),
                Text(
                  '為了避免卡頓，圖表已自動降採樣顯示（${renderDocs.length}/${docs.length} 點）。',
                  style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
                ),
              ],
              const SizedBox(height: 8),
              SizedBox(
                height: 320,
                child: lines.isEmpty
                    ? const Center(child: Text('此時間段暫無資料'))
                    : LineChart(
                        LineChartData(
                          lineBarsData: lines,
                          minX: 0,
                          maxX: maxX <= 0 ? 1 : maxX,
                          minY: 0,
                          maxY: maxY <= 0 ? 10 : maxY * 1.2,
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: _windowHours == 1
                                    ? math.max(1, docs.length / 4)
                                    : (_windowHours == 24
                                          ? math.max(1, docs.length / 6)
                                          : math.max(1, docs.length / 7)),
                                getTitlesWidget: (value, meta) {
                                  final idx = value.round();
                                  if (idx < 0 || idx >= renderDocs.length) {
                                    return const SizedBox.shrink();
                                  }
                                  final data =
                                      renderDocs[idx].data() as Map<String, dynamic>;
                                  final ts = data['timestamp'];
                                  if (ts is! Timestamp) {
                                    return const SizedBox.shrink();
                                  }
                                  final dt = ts.toDate();
                                  final label = _windowHours == 168
                                      ? '${dt.month}/${dt.day}'
                                      : '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(label, style: const TextStyle(fontSize: 10)),
                                  );
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: true),
                          gridData: const FlGridData(show: true),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class SiteDetailPage extends StatelessWidget {
  final String siteId;
  final String siteName;
  final String description;

  const SiteDetailPage({
    super.key,
    required this.siteId,
    required this.siteName,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('場域：$siteName')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('sensors')
            .where('site_id', isEqualTo: siteId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collectionGroup('stream')
                .orderBy('timestamp', descending: true)
                .limit(1200)
                .snapshots(),
            builder: (context, readingSnap) {
              final latestByDevice = <String, Map<String, dynamic>>{};
              for (final d in readingSnap.data?.docs ?? const []) {
                final deviceId = d.reference.parent.parent?.id;
                if (deviceId == null) continue;
                latestByDevice.putIfAbsent(
                  deviceId,
                  () => d.data() as Map<String, dynamic>,
                );
              }

              final rows = docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final id = data['id']?.toString() ?? '-';
                final schema =
                    (data['schema'] as Map?)?.cast<String, dynamic>() ??
                    <String, dynamic>{};
                final latest = latestByDevice[id] ?? <String, dynamic>{};
                final abnormal = _isDeviceAbnormal(schema, latest);
                final totalFlow = _deviceTotalFlow(schema, latest);
                return {
                  'id': id,
                  'place': data['place']?.toString() ?? '未命名區域',
                  'schema': schema,
                  'abnormal': abnormal,
                  'flow': totalFlow,
                };
              }).toList();

              rows.sort((a, b) {
                final ab =
                    ((b['abnormal'] as bool) ? 1 : 0) -
                    ((a['abnormal'] as bool) ? 1 : 0);
                if (ab != 0) return ab;
                return (b['flow'] as double).compareTo(a['flow'] as double);
              });

              final deviceCount = rows.length;
              final abnormalCount = rows.where((e) => e['abnormal'] as bool).length;
              final totalFlow = rows.fold<double>(
                0,
                (acc, e) => acc + (e['flow'] as double),
              );
              final healthyRate = deviceCount == 0
                  ? 1.0
                  : (deviceCount - abnormalCount) / deviceCount;
              final healthText = healthyRate >= 0.8
                  ? '健康'
                  : (healthyRate >= 0.5 ? '注意' : '警示');

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            siteName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text('ID: $siteId'),
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(description),
                          ],
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              Chip(
                                label: Text(
                                  '總流量 ${totalFlow.toStringAsFixed(1)} mL/s',
                                ),
                              ),
                              Chip(label: Text('異常裝置 $abnormalCount')),
                              Chip(
                                avatar: Icon(
                                  healthyRate >= 0.8
                                      ? Icons.health_and_safety
                                      : Icons.warning_amber,
                                  size: 18,
                                  color: healthyRate >= 0.8
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                                label: Text('即時健康 $healthText'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                            value: healthyRate.clamp(0, 1),
                            minHeight: 8,
                            backgroundColor: Colors.grey.shade200,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (rows.isEmpty)
                    const Text('此場域目前沒有裝置。')
                  else
                    ...rows.map((row) {
                      return SiteDeviceMiniCard(
                        deviceId: row['id'] as String,
                        place: row['place'] as String,
                        schema: row['schema'] as Map<String, dynamic>,
                        isAbnormal: row['abnormal'] as bool,
                      );
                    }),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class SiteDeviceMiniCard extends StatelessWidget {
  final String deviceId;
  final String place;
  final Map<String, dynamic> schema;
  final bool isAbnormal;

  const SiteDeviceMiniCard({
    super.key,
    required this.deviceId,
    required this.place,
    required this.schema,
    this.isAbnormal = false,
  });

  @override
  Widget build(BuildContext context) {
    final fields = (schema['fields'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((f) => f['key']?.toString() ?? '')
        .where((k) => k.isNotEmpty)
        .toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('readings')
              .doc(deviceId)
              .collection('stream')
              .orderBy('timestamp', descending: true)
              .limit(120)
              .snapshots(),
          builder: (context, snapshot) {
            final docs = (snapshot.data?.docs ?? []).reversed.toList();
            final targetKey = fields.isNotEmpty ? fields.first : 'kitchen_flow';
            final spots = <FlSpot>[];
            for (int i = 0; i < docs.length; i++) {
              final data = docs[i].data() as Map<String, dynamic>;
              final value = data[targetKey];
              if (value is num) {
                spots.add(FlSpot(i.toDouble(), value.toDouble()));
              }
            }

            final latest = docs.isNotEmpty
                ? (docs.last.data() as Map<String, dynamic>)[targetKey]
                : null;
            final latestText =
                latest is num ? latest.toStringAsFixed(1) : 'N/A';
            final maxY = spots.isEmpty
                ? 10.0
                : spots.map((s) => s.y).fold<double>(0, math.max) * 1.2;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          '$place ($deviceId)',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (isAbnormal)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Chip(
                              label: Text(
                                '異常',
                                style: TextStyle(color: Colors.white),
                              ),
                              backgroundColor: Colors.red,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                      ],
                    ),
                    Text('$targetKey: $latestText'),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 120,
                  child: spots.isEmpty
                      ? const Center(child: Text('暫無資料'))
                      : LineChart(
                          LineChartData(
                            minX: 0,
                            maxX: (spots.length - 1).toDouble().clamp(1, 9999),
                            minY: 0,
                            maxY: maxY <= 0 ? 10 : maxY,
                            lineBarsData: [
                              LineChartBarData(
                                spots: spots,
                                // Keep mini chart stable without curve overshoot.
                                isCurved: false,
                                barWidth: 2,
                                color: Colors.deepPurple,
                                dotData: const FlDotData(show: false),
                              ),
                            ],
                            titlesData: const FlTitlesData(
                              topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                            ),
                            gridData: const FlGridData(show: true),
                            borderData: FlBorderData(show: true),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
