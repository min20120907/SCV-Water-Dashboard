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
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'add_device_page.dart';
import 'add_site_page.dart';
import 'firebase_options.dart';
import 'gemini_service.dart';

const _scvPrimary = Color(0xFF2F7BFF);
const _scvPrimarySoft = Color(0xFFEAF2FF);
const _scvBg = Color(0xFFF6F8FC);
const _scvSurface = Colors.white;
const _scvText = Color(0xFF1F2937);
const _scvMutedText = Color(0xFF6B7280);
const _scvBorder = Color(0xFFDCE4F2);
const _scvDanger = Color(0xFFE05858);

ThemeData _buildScvTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: _scvPrimary,
        brightness: Brightness.light,
      ).copyWith(
        primary: _scvPrimary,
        secondary: const Color(0xFF5EA2FF),
        surface: _scvSurface,
        error: _scvDanger,
      );

  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: _scvBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: _scvText,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: _scvText,
      ),
    ),
    cardTheme: CardThemeData(
      color: _scvSurface,
      margin: const EdgeInsets.all(0),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _scvBorder),
      ),
    ),
    dividerTheme: const DividerThemeData(color: _scvBorder),
    textTheme: const TextTheme(
      titleLarge: TextStyle(
        color: _scvText,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
      titleMedium: TextStyle(color: _scvText, fontWeight: FontWeight.w600),
      bodyMedium: TextStyle(color: _scvText, height: 1.35),
      bodySmall: TextStyle(color: _scvMutedText),
      labelLarge: TextStyle(color: _scvText, fontWeight: FontWeight.w600),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: _scvPrimary,
      textColor: _scvText,
      subtitleTextStyle: TextStyle(color: _scvMutedText),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: _scvSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: _scvPrimarySoft,
      height: 72,
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(color: _scvText, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(color: _scvMutedText),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _scvBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _scvBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _scvPrimary, width: 1.4),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _scvPrimary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _scvPrimary,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _scvText,
        side: const BorderSide(color: _scvBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: _scvPrimarySoft,
      side: const BorderSide(color: _scvBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      labelStyle: const TextStyle(color: _scvText),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: _scvText,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: "assets/key.env");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: WaterDashboardApp()));
}

class WaterDashboardApp extends StatelessWidget {
  const WaterDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SCV Water Dashboard',
      theme: _buildScvTheme(),
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

int _toEpochMillis(dynamic value) {
  if (value is Timestamp) return value.millisecondsSinceEpoch;
  if (value is DateTime) return value.millisecondsSinceEpoch;
  if (value is num) return value.toInt();
  return 0;
}

String _formatNowLabel(DateTime now) {
  const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
  final y = now.year.toString().padLeft(4, '0');
  final m = now.month.toString().padLeft(2, '0');
  final d = now.day.toString().padLeft(2, '0');
  final hh = now.hour.toString().padLeft(2, '0');
  final mm = now.minute.toString().padLeft(2, '0');
  return '星期${weekdays[now.weekday - 1]}，$y/$m/$d $hh:$mm';
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
  int _profileSubTab = 0;

  void _openAddDevice() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddDevicePage()),
    );
  }

  void _showDemoGuide() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _DemoGuideDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const DashboardV2Page(),
      const SiteManagementTab(),
      PostAnalysisTab(
        autoTriggerEnabled: _autoTriggerEnabled,
        autoTriggerSeconds: _autoTriggerSeconds,
      ),
      const _AddActionsTab(),
      _ProfileHubTab(
        subTab: _profileSubTab,
        onTabChanged: (idx) => setState(() => _profileSubTab = idx),
        autoTriggerEnabled: _autoTriggerEnabled,
        autoTriggerSeconds: _autoTriggerSeconds,
        onEnabledChanged: (value) =>
            setState(() => _autoTriggerEnabled = value),
        onSecondsChanged: (value) =>
            setState(() => _autoTriggerSeconds = value),
      ),
    ];
    final titles = [
      'DASHBOARD',
      'Choose Template',
      'Alert & Optimize',
      'Add',
      'Profile',
    ];
    final showDefaultAppBar = _tabIndex != 0;

    return Scaffold(
      appBar: showDefaultAppBar
          ? AppBar(
              title: Text(titles[_tabIndex]),
              actions: [
                IconButton(
                  icon: const Icon(Icons.help_outline),
                  onPressed: _showDemoGuide,
                ),
                if (_tabIndex == 1)
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add_business_outlined),
                        tooltip: "Add Site",
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AddSitePage(),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        tooltip: "Add Sensor",
                        onPressed: _openAddDevice,
                      ),
                    ],
                  ),
              ],
            )
          : PreferredSize(
              preferredSize: const Size.fromHeight(74),
              child: _DashboardTopBar(
                onNotificationTap: () {
                  setState(() => _tabIndex = 2);
                },
                onHelpTap: _showDemoGuide,
              ),
            ),
      body: pages[_tabIndex],
      bottomNavigationBar: Container(
        height: 78,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0x1A000000), width: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 10,
              offset: Offset(0, -1),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _BottomTabIcon(
                icon: Icons.home_filled,
                active: _tabIndex == 0,
                onTap: () => setState(() => _tabIndex = 0),
              ),
              _BottomTabIcon(
                icon: Icons.dashboard_outlined,
                active: _tabIndex == 1,
                onTap: () => setState(() => _tabIndex = 1),
              ),
              _BottomTabIcon(
                icon: Icons.add_circle_outline,
                active: _tabIndex == 3,
                onTap: () => setState(() => _tabIndex = 3),
                big: true,
              ),
              _BottomTabIcon(
                icon: Icons.notifications_none,
                active: _tabIndex == 2,
                onTap: () => setState(() => _tabIndex = 2),
              ),
              _BottomTabIcon(
                icon: Icons.person_outline,
                active: _tabIndex == 4,
                onTap: () => setState(() => _tabIndex = 4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomTabIcon extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final bool big;

  const _BottomTabIcon({
    required this.icon,
    required this.active,
    required this.onTap,
    this.big = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: SizedBox(
        width: 72,
        height: 44,
        child: Center(
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? _scvPrimarySoft : Colors.transparent,
            ),
            padding: const EdgeInsets.all(6),
            child: Icon(
              icon,
              size: big ? 27 : 24,
              color: active ? const Color(0xFF000000) : const Color(0xFF1E1E1E),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardTopBar extends StatelessWidget {
  final VoidCallback onNotificationTap;
  final VoidCallback onHelpTap;

  const _DashboardTopBar({
    required this.onNotificationTap,
    required this.onHelpTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        height: 74,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        decoration: const BoxDecoration(color: Colors.white),
        child: Row(
          children: [
            Container(
              width: 53,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _scvPrimarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.water_drop, color: _scvPrimary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const _LiveNowLabel(),
                  const Text(
                    'DASHBOARD',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 27,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF000000),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.help_outline, color: Color(0xFF1E1E1E)),
              onPressed: onHelpTap,
              tooltip: 'Demo Guide',
            ),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onNotificationTap,
              child: Stack(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(
                      Icons.notifications_none,
                      color: Color(0xFF1E1E1E),
                      size: 26,
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF2D6EFF),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _scvBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class AppSearchBar extends StatelessWidget {
  final String hintText;
  final ValueChanged<String>? onChanged;

  const AppSearchBar({super.key, required this.hintText, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search, color: _scvMutedText),
      ),
    );
  }
}

class DashboardV2Page extends StatelessWidget {
  const DashboardV2Page({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(15, 10, 15, 16),
      children: [
        const _IndustryPills(),
        const SizedBox(height: 12),
        const SizedBox(height: 300, child: _DashboardChartFromFirestore()),
        const SizedBox(height: 20),
        Text(
          'Sensor Monitoring - Individual',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontSize: 16),
        ),
        const SizedBox(height: 10),
        const _MiniSensorMonitoringList(),
      ],
    );
  }
}

class _LiveNowLabel extends StatefulWidget {
  const _LiveNowLabel();

  @override
  State<_LiveNowLabel> createState() => _LiveNowLabelState();
}

class _LiveNowLabelState extends State<_LiveNowLabel> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _formatNowLabel(_now),
      style: const TextStyle(
        fontFamily: 'Encode Sans Semi Expanded',
        fontSize: 12,
        color: Color(0xFF323232),
      ),
    );
  }
}

class _MiniSensorMonitoringList extends StatelessWidget {
  const _MiniSensorMonitoringList();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sensors')
          .limit(6)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const AppCard(child: Text('目前沒有感測器資料'));

        return ListView.separated(
          itemCount: docs.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final sensorDoc = docs[index];
            final data = sensorDoc.data() as Map<String, dynamic>;
            final deviceId = data['id']?.toString() ?? sensorDoc.id;
            final schema = (data['schema'] as Map?)?.cast<String, dynamic>() ?? {};
            final place = data['place']?.toString() ?? '未命名區域';

            return DashboardGaugeCard(
              deviceId: deviceId,
              place: place,
              schema: schema,
            );
          },
        );
      },
    );
  }
}

class DashboardGaugeCard extends StatefulWidget {
  final String deviceId;
  final String place;
  final Map<String, dynamic> schema;

  const DashboardGaugeCard({
    super.key,
    required this.deviceId,
    required this.place,
    required this.schema,
  });

  @override
  State<DashboardGaugeCard> createState() => _DashboardGaugeCardState();
}

class _DashboardGaugeCardState extends State<DashboardGaugeCard> {
  final GeminiService _gemini = GeminiService();
  static final Map<String, Map<String, String>> _iconInfoCache = {};
  Map<String, dynamic> _latestData = {};
  
  StreamSubscription<QuerySnapshot>? _subscription;
  Timer? _uiUpdateTimer;
  Map<String, dynamic> _pendingData = {};

  @override
  void initState() {
    super.initState();
    _loadIconInfo();
    
    // Subscribe to real-time updates
    _subscription = FirebaseFirestore.instance
        .collection('readings')
        .doc(widget.deviceId)
        .collection('stream')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snap) {
      if (snap.docs.isNotEmpty) {
        _pendingData = snap.docs.first.data() as Map<String, dynamic>;
      }
    });

    // Throttle UI updates to every 2 seconds
    _uiUpdateTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted && _pendingData.isNotEmpty) {
        setState(() {
          _latestData = _pendingData;
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _uiUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadIconInfo() async {
    final fields = (widget.schema['fields'] as List? ?? []).whereType<Map>();
    for (final f in fields) {
      final key = f['key']?.toString() ?? '';
      if (!_iconInfoCache.containsKey(key)) {
        final info = await _gemini.suggestIcon(f['label'] ?? key);
        if (mounted) {
          setState(() => _iconInfoCache[key] = info);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final latest = _latestData;

    final fields = (widget.schema['fields'] as List? ?? []).whereType<Map>();
    final totalVal = _deviceTotalFlow(widget.schema, latest);

    return AppCard(
      padding: const EdgeInsets.all(20),
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
                    widget.place,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  Text(widget.deviceId, style: const TextStyle(fontSize: 10, color: _scvMutedText)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _scvPrimary,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: _scvPrimary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4)),
                  ],
                ),
                child: Text(
                  "${totalVal.toStringAsFixed(1)} mL/s",
                  style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: fields.map((f) {
              final key = f['key']?.toString() ?? '';
              final info = _iconInfoCache[key] ?? {};
              final emoji = info['emoji'] ?? '💧';
              final val = _toDouble(latest[key]);
              final max = _toDouble(f['max_threshold']);
              final percent = (val / (max > 0 ? max : 100)).clamp(0.0, 1.0);
              final isDanger = percent > 0.8;

              return Container(
                width: 72, // Just enough for 60 + 6*2 padding
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                decoration: BoxDecoration(
                  color: isDanger ? const Color(0xFFFFF2F2) : const Color(0xFFF7F9FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDanger ? _scvDanger.withValues(alpha: 0.4) : _scvBorder),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 60, 
                      height: 60,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: percent,
                            strokeWidth: 6,
                            strokeCap: StrokeCap.round,
                            backgroundColor: Colors.white,
                            valueColor: AlwaysStoppedAnimation(isDanger ? _scvDanger : _scvPrimary),
                          ),
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  val.toStringAsFixed(0),
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: isDanger ? _scvDanger : const Color(0xFF1A1A1A),
                                    letterSpacing: -1,
                                    height: 1.0,
                                  ),
                                ),
                                Text(emoji, style: const TextStyle(fontSize: 10)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      info['description'] ?? f['label'] ?? key,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isDanger ? _scvDanger : _scvText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _IndustryPills extends StatefulWidget {
  const _IndustryPills();

  @override
  State<_IndustryPills> createState() => _IndustryPillsState();
}

class _IndustryPillsState extends State<_IndustryPills> {
  String _selected = 'Textile';

  @override
  Widget build(BuildContext context) {
    final options = const ['Textile', 'Agriculture', 'Manufacture'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...List.generate(options.length, (index) {
            final label = options[index];
            final selected = label == _selected;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () => setState(() => _selected = label),
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFFFBF9D) : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE6E6E6)),
                  ),
                  child: Center(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xE6000000),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              side: const BorderSide(color: Color(0xFFE6E6E6)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              foregroundColor: const Color(0xFF1A1A1A),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TemplateSelectionPage(),
                ),
              );
            },
            icon: const Icon(Icons.tune, size: 16),
            label: const Text(
              'Add Template',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardChartFromFirestore extends StatefulWidget {
  const _DashboardChartFromFirestore();

  @override
  State<_DashboardChartFromFirestore> createState() =>
      _DashboardChartFromFirestoreState();
}

class _DashboardChartFromFirestoreState
    extends State<_DashboardChartFromFirestore> {
  final GeminiService _gemini = GeminiService();
  bool _optimizing = false;
  List<double>? _aiSuggestedSeries;
  String _selectedInterval = '1m';
  
  StreamSubscription<QuerySnapshot>? _subscription;
  QuerySnapshot? _latestSnapshot;
  Timer? _uiUpdateTimer;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subscription = FirebaseFirestore.instance
        .collectionGroup('stream')
        .limit(240)
        .snapshots()
        .listen((snap) {
      _latestSnapshot = snap;
      _error = null;
    }, onError: (e) {
      _error = e.toString();
    });

    _uiUpdateTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted && _latestSnapshot != null) {
        setState(() {}); // Trigger rebuild every 2s
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _uiUpdateTimer?.cancel();
    super.dispose();
  }

  int _getBucket(int epochMillis, String interval) {
    final dt = DateTime.fromMillisecondsSinceEpoch(epochMillis);
    switch (interval) {
      case '1s':
        return DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second).millisecondsSinceEpoch;
      case '1h':
        return DateTime(dt.year, dt.month, dt.day, dt.hour).millisecondsSinceEpoch;
      case '1d':
        return DateTime(dt.year, dt.month, dt.day).millisecondsSinceEpoch;
      case '1m':
      default:
        return DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute).millisecondsSinceEpoch;
    }
  }

  List<double>? _extractNumberList(String text) {
    try {
      final direct = jsonDecode(text);
      if (direct is List) {
        return direct.map((e) => _toDouble(e)).toList();
      }
      if (direct is Map && direct['curve'] is List) {
        return (direct['curve'] as List).map((e) => _toDouble(e)).toList();
      }
    } catch (_) {}

    final listMatch = RegExp(r'\[[\s\S]*\]').firstMatch(text);
    if (listMatch == null) return null;
    try {
      final parsed = jsonDecode(listMatch.group(0)!);
      if (parsed is List) {
        return parsed.map((e) => _toDouble(e)).toList();
      }
    } catch (_) {}
    return null;
  }

  List<FlSpot> _buildRecommendedSpots(List<FlSpot> current) {
    final ai = _aiSuggestedSeries;
    if (ai == null || ai.isEmpty) return const [];
    
    final lastX = current.isNotEmpty ? current.last.x : 0.0;
    
    return List.generate(ai.length, (i) {
      return FlSpot(lastX + i + 1, ai[i]);
    });
  }

  Future<void> _generateSuggestedCurve(List<FlSpot> current) async {
    if (_optimizing) return;
    setState(() => _optimizing = true);
    try {
      final values = current.isEmpty ? '0' : current.map((e) => e.y.toStringAsFixed(2)).join(', ');
      final prompt =
          '''
請根據這段用水曲線和當前時間，預測未來的水量變化。
需求：
1) 回傳 JSON 陣列，內容僅數字（單位為 mL/s）
2) 長度為 24 小時（每小時 1 點）
3) 考慮時間趨勢和季節性波動
4) 如果沒有過去資料或資料不足，請以合理的常規用水量或 0 預測
5) 只回傳 JSON，不要其他文字

當前時間：${DateTime.now()}
時間間隔：1 小時

請預測未來 24 小時的用水趨勢。

目前曲線：
[$values]
''';

      final response = await _gemini.ask(prompt, '圖表即時總用水序列，單位為 L。');
      final parsed = _extractNumberList(response);
      if (parsed == null || parsed.isEmpty) {
        throw Exception('AI 回傳格式無法解析');
      }
      setState(() {
        final list = parsed.map((v) => v < 0 ? 0.0 : v.toDouble()).toList();
        while (list.length < 24) {
          list.add(0.0);
        }
        _aiSuggestedSeries = list;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已生成未來 24 小時用水預測')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('生成失敗：$e')));
    } finally {
      if (mounted) setState(() => _optimizing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return AppCard(
        child: Text(
          '圖表資料讀取失敗：$_error',
          style: const TextStyle(color: _scvDanger),
        ),
      );
    }
    if (_latestSnapshot == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final snapshot = _latestSnapshot!;
    // 在記憶體中進行排序以避免索引需求
    final docs = [...snapshot.docs];
    docs.sort((a, b) {
      final aa = (a.data() as Map<String, dynamic>)['timestamp'];
      final bb = (b.data() as Map<String, dynamic>)['timestamp'];
      return _toEpochMillis(aa).compareTo(_toEpochMillis(bb));
    });
        final Map<int, List<double>> bucketFlows = {};
        for (int i = 0; i < docs.length; i++) {
          final data = docs[i].data() as Map<String, dynamic>;
          final ts = data['timestamp'];
          if (ts == null) continue;
          final millis = _toEpochMillis(ts);
          if (millis == 0) continue;

          final current =
              _toDouble(data['kitchen_flow']) +
              _toDouble(data['shower_flow']) +
              _toDouble(data['bathtub_flow']) +
              _toDouble(data['toilet_flow']);

          final bucket = _getBucket(millis, _selectedInterval);
          bucketFlows.putIfAbsent(bucket, () => []).add(current);
        }

        final sortedBuckets = bucketFlows.keys.toList()..sort();
        final spotsCurrent = <FlSpot>[];
        for (int i = 0; i < sortedBuckets.length; i++) {
          final flows = bucketFlows[sortedBuckets[i]]!;
          final avgFlow = flows.reduce((a, b) => a + b) / flows.length;
          spotsCurrent.add(FlSpot(i.toDouble(), avgFlow));
        }
        final spotsRecommended = _buildRecommendedSpots(spotsCurrent);
        
        // Ensure the recommended spots connect smoothly from the current spots
        final allRecommendedSpots = <FlSpot>[];
        if (spotsCurrent.isNotEmpty && spotsRecommended.isNotEmpty) {
          allRecommendedSpots.add(spotsCurrent.last);
        }
        allRecommendedSpots.addAll(spotsRecommended);

        final maxY =
            [
              ...spotsCurrent.map((e) => e.y),
              ...spotsRecommended.map((e) => e.y),
            ].fold<double>(50.0, math.max) *
            1.15;
            
        final maxX = (spotsCurrent.length - 1 + spotsRecommended.length).toDouble();

        return AppCard(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Water Usage History',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  Row(
                    children: ['1s', '1m', '1h', '1d'].map((val) {
                      final isSelected = _selectedInterval == val;
                      final label = val == '1s' ? '秒' : val == '1m' ? '分' : val == '1h' ? '時' : '天';
                      return InkWell(
                        onTap: () => setState(() {
                          _selectedInterval = val;
                          _aiSuggestedSeries = null; // 清除預測因為刻度改變
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          margin: const EdgeInsets.only(left: 4),
                          decoration: BoxDecoration(
                            color: isSelected ? _scvPrimarySoft : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isSelected ? _scvPrimary : _scvBorder),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected ? _scvPrimary : _scvMutedText,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: maxY < 50 ? 50 : maxY,
                    minX: 0,
                    maxX: maxX < 1 ? 1 : maxX,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => const FlLine(
                        color: Color(0x80E6E6E6),
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                    ),
                    titlesData: const FlTitlesData(
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spotsCurrent,
                        isCurved: true,
                        barWidth: 3,
                        color: const Color(0xFF2D6EFF),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x262D6EFF), Color(0x002D6EFF)],
                          ),
                        ),
                        dotData: const FlDotData(show: false),
                      ),
                      if (allRecommendedSpots.isNotEmpty)
                        LineChartBarData(
                          spots: allRecommendedSpots,
                          isCurved: true,
                          barWidth: 3,
                          color: const Color(0xFF7E7E7E),
                          dashArray: [6, 4],
                          dotData: const FlDotData(show: false),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _optimizing
                      ? null
                      : () => _generateSuggestedCurve(spotsCurrent),
                  icon: _optimizing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome, size: 16),
                  label: Text(_optimizing ? '生成中...' : '現在優化'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _scvPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
  }
}

class TemplateSelectionPage extends StatefulWidget {
  const TemplateSelectionPage({super.key});

  @override
  State<TemplateSelectionPage> createState() => _TemplateSelectionPageState();
}

class _TemplateSelectionPageState extends State<TemplateSelectionPage> {
  String _keyword = '';
  
  final List<Map<String, dynamic>> _categories = [
    {
      'title': 'Industrial & Manufacturing',
      'icon': Icons.factory_outlined,
      'color': Colors.blueGrey,
      'items': [
        {
          'name': 'Textile Dyeing Plant', 
          'desc': 'High-volume water usage for dyeing and finishing.', 
          'prompt': '自動化染整線、包含冷卻水塔與廢水回收系統、需監控 pH 值與濁度。',
          'icon': Icons.opacity
        },
        {
          'name': 'Beverage Bottling Line', 
          'desc': 'Precision monitoring for CIP and ingredient water.', 
          'prompt': '食品級生產線、包含 CIP (原地清洗) 系統、需嚴格監控沖洗水量與廢水比。',
          'icon': Icons.local_drink
        },
        {
          'name': 'Semiconductor Fab', 
          'desc': 'Ultra-pure water (UPW) system monitoring.', 
          'prompt': '高科技廠房、超純水系統、包含多階過濾與回收、需監控漏水敏感度極高。',
          'icon': Icons.memory
        },
      ]
    },
    {
      'title': 'Commercial & Infrastructure',
      'icon': Icons.business_outlined,
      'color': Colors.orange,
      'items': [
        {
          'name': 'Data Center Cooling', 
          'desc': 'WUE (Water Usage Effectiveness) tracking.', 
          'prompt': '資料中心機房、主要為冷卻主機用水、需計算 PUE/WUE、監控蒸發與排放比。',
          'icon': Icons.dns
        },
        {
          'name': 'Hospital Medical Center', 
          'desc': 'Critical water supply for sterilization and HVAC.', 
          'prompt': '大型醫療機構、包含手術室消毒與中央空調用水、需 24/7 穩定供水監測。',
          'icon': Icons.local_hospital
        },
        {
          'name': 'Shopping Mall Complex', 
          'desc': 'High-traffic restroom and AHU monitoring.', 
          'prompt': '大型商場、主要用水為公廁與空調箱、尖峰時段流量波動大、需監控漏損。',
          'icon': Icons.storefront
        },
      ]
    },
    {
      'title': 'Smart Agriculture',
      'icon': Icons.agriculture_outlined,
      'color': Colors.green,
      'items': [
        {
          'name': 'Hydroponic Vertical Farm', 
          'desc': 'Recirculating nutrient solution monitoring.', 
          'prompt': '室內垂直農場、水耕養液循環系統、需精確監控蒸散量與自動補水頻率。',
          'icon': Icons.wb_sunny
        },
        {
          'name': 'Vineyard Drip Irrigation', 
          'desc': 'Evapotranspiration-based smart irrigation.', 
          'prompt': '戶外葡萄園、滴灌系統、結合氣象數據、監控分區供水壓力與土壤濕度回饋。',
          'icon': Icons.grass
        },
      ]
    },
    {
      'title': 'Residential & Hospitality',
      'icon': Icons.home_work_outlined,
      'color': Colors.blue,
      'items': [
        {
          'name': 'Luxury Smart Villa', 
          'desc': 'Multi-zone indoor and outdoor management.', 
          'prompt': '私人別墅、包含景觀泳池、智慧草坪灌溉與室內生活用水、需分區統計。',
          'icon': Icons.villa
        },
        {
          'name': 'Eco-Friendly Resort', 
          'desc': 'Greywater harvesting and reuse system.', 
          'prompt': '綠色渡假村、包含雨水回收系統與中水處理、需監控回收水使用比例。',
          'icon': Icons.holiday_village
        },
      ]
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose a Template')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: AppSearchBar(
              hintText: 'Search templates...',
              onChanged: (v) => setState(() => _keyword = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (context, idx) {
                final cat = _categories[idx];
                final items = cat['items'] as List<Map<String, dynamic>>;
                final filteredItems = items.where((i) => 
                  i['name'].toString().toLowerCase().contains(_keyword.toLowerCase()) ||
                  i['desc'].toString().toLowerCase().contains(_keyword.toLowerCase())
                ).toList();

                if (filteredItems.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Icon(cat['icon'] as IconData, color: cat['color'] as Color, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            cat['title'] as String,
                            style: TextStyle(
                              fontSize: 14, 
                              fontWeight: FontWeight.bold, 
                              color: cat['color'] as Color
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...filteredItems.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddSitePage(
                                initialName: item['name'] as String,
                                initialDescription: item['desc'] as String,
                                initialPrompt: item['prompt'] as String,
                              ),
                            ),
                          );
                        },
                        child: AppCard(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: (cat['color'] as Color).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(item['icon'] as IconData, color: cat['color'] as Color),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['name'] as String,
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                    Text(
                                      item['desc'] as String,
                                      style: TextStyle(color: _scvMutedText, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.add_circle_outline, color: _scvPrimary, size: 20),
                            ],
                          ),
                        ),
                      ),
                    )),
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class OptimizePage extends StatefulWidget {
  const OptimizePage({super.key});

  @override
  State<OptimizePage> createState() => _OptimizePageState();
}

class _OptimizePageState extends State<OptimizePage> {
  final GeminiService _gemini = GeminiService();
  String _aiSuggestions = '正在分析數據並產生建議...';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchAiAdvice();
  }

  Future<void> _fetchAiAdvice() async {
    try {
      // 獲取最近的數據作為上下文
      final snap = await FirebaseFirestore.instance
          .collectionGroup('stream')
          .limit(20)
          .get();
      
      String contextData = '無數據';
      if (snap.docs.isNotEmpty) {
        // 在記憶體中手動排序
        final sortedDocs = [...snap.docs];
        sortedDocs.sort((a, b) {
          final aa = (a.data() as Map<String, dynamic>)['timestamp'];
          final bb = (b.data() as Map<String, dynamic>)['timestamp'];
          return _toEpochMillis(bb).compareTo(_toEpochMillis(aa));
        });

        contextData = sortedDocs.map((d) {
          final data = Map<String, dynamic>.from(d.data() as Map<String, dynamic>);
          // 處理 Timestamp 無法 JSON 序列化的問題
          data.forEach((key, value) {
            if (value is Timestamp) {
              data[key] = value.toDate().toIso8601String();
            }
          });
          return "${data['timestamp'] ?? ''}: ${jsonEncode(data)}";
        }).join('\n');
      }

      final advice = await _gemini.getOptimizationTips(contextData);
      if (mounted) {
        setState(() {
          _aiSuggestions = advice;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiSuggestions = '建議產生失敗：$e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Learn to Optimize')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 220, child: _DashboardChartFromFirestore()),
          const SizedBox(height: 20),
          AppCard(
            child: Row(
              children: const [
                Icon(Icons.tips_and_updates_outlined, color: Colors.orangeAccent),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '基於您目前的用水模式，AI 為您量身打造了以下優化目標。',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: _scvPrimary, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'AI 智慧優化建議',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const Spacer(),
                    if (_loading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const Divider(height: 24),
                _loading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: Text('AI 正在深度思考中...')),
                      )
                    : Markdown(
                        data: _aiSuggestions,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                      ),
                const SizedBox(height: 8),
                if (!_loading)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() => _loading = true);
                        _fetchAiAdvice();
                      },
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('重新分析'),
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

class SensorManagementPage extends StatefulWidget {
  const SensorManagementPage({super.key});

  @override
  State<SensorManagementPage> createState() => _SensorManagementPageState();
}

class _SensorManagementPageState extends State<SensorManagementPage> {
  final _nameController = TextEditingController();
  final _modelController = TextEditingController();
  final _roomController = TextEditingController();
  final _keywordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _modelController.dispose();
    _roomController.dispose();
    _keywordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Your Sensor')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _modelController,
                  decoration: const InputDecoration(labelText: 'Model'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _roomController,
                  decoration: const InputDecoration(labelText: 'Room ID'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _keywordController,
                  decoration: const InputDecoration(labelText: 'Keyword'),
                ),
                const SizedBox(height: 10),
                const DropdownMenu(
                  dropdownMenuEntries: [
                    DropdownMenuEntry(value: 'wifi', label: 'Network: Wi-Fi'),
                    DropdownMenuEntry(value: 'mqtt', label: 'Network: MQTT'),
                    DropdownMenuEntry(value: 'ble', label: 'Network: BLE'),
                    DropdownMenuEntry(
                      value: 'zigbee',
                      label: 'Network: Zigbee',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.auto_awesome, color: _scvPrimary),
                  title: Text('AI Onboarding Status'),
                  subtitle: Text('Ready'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const AppCard(child: _SensorListsFromFirestore()),
        ],
      ),
    );
  }
}

class _SensorListsFromFirestore extends StatelessWidget {
  const _SensorListsFromFirestore();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sensors')
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final byRoom = <String, List<Map<String, dynamic>>>{};
        for (final d in docs) {
          final data = d.data() as Map<String, dynamic>;
          final room = data['place']?.toString().trim();
          final key = (room == null || room.isEmpty) ? 'Unassigned' : room;
          byRoom.putIfAbsent(key, () => []).add(data);
        }
        if (byRoom.isEmpty) {
          return const Text('No sensor data');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sensor Lists',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...byRoom.entries.map((entry) {
              return ExpansionTile(
                title: Text(entry.key),
                children: entry.value.map((sensor) {
                  final id = sensor['id']?.toString() ?? '-';
                  final typeId =
                      (sensor['schema'] as Map?)?['type_id']?.toString() ?? '-';
                  return ListTile(
                    title: Text('$id  $typeId'),
                    subtitle: Text(
                      (sensor['purpose']?.toString().isNotEmpty ?? false)
                          ? sensor['purpose'].toString()
                          : 'No tags',
                    ),
                  );
                }).toList(),
              );
            }),
          ],
        );
      },
    );
  }
}

class _AddActionsTab extends StatelessWidget {
  const _AddActionsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppCard(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.add_business_outlined),
                title: const Text('Add Site'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddSitePage()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.sensors_outlined),
                title: const Text('Add Sensor'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddDevicePage()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.library_books_outlined),
                title: const Text('Choose Template'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TemplateSelectionPage(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.psychology_outlined),
                title: const Text('Learn to Optimize'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const OptimizePage()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.list_alt_outlined),
                title: const Text('Sensor Lists'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SensorManagementPage(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileHubTab extends StatelessWidget {
  final int subTab;
  final ValueChanged<int> onTabChanged;
  final bool autoTriggerEnabled;
  final int autoTriggerSeconds;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<int> onSecondsChanged;

  const _ProfileHubTab({
    required this.subTab,
    required this.onTabChanged,
    required this.autoTriggerEnabled,
    required this.autoTriggerSeconds,
    required this.onEnabledChanged,
    required this.onSecondsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final pages = [
      const ConnectivityTab(),
      AutoTriggerSettingsTab(
        enabled: autoTriggerEnabled,
        seconds: autoTriggerSeconds,
        onEnabledChanged: onEnabledChanged,
        onSecondsChanged: onSecondsChanged,
      ),
      const ManualInputTab(),
    ];
    return Column(
      children: [
        const SizedBox(height: 8),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _ProfilePill(
                label: 'Connectivity',
                active: subTab == 0,
                onTap: () => onTabChanged(0),
              ),
              _ProfilePill(
                label: 'Auto',
                active: subTab == 1,
                onTap: () => onTabChanged(1),
              ),
              _ProfilePill(
                label: 'Manual',
                active: subTab == 2,
                onTap: () => onTabChanged(2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: pages[subTab]),
      ],
    );
  }
}

class _ProfilePill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ProfilePill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFFFBF9D) : Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE6E6E6)),
          ),
          child: Text(label),
        ),
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
    await FirebaseFirestore.instance
        .collection('sensors')
        .doc(sensorDocId)
        .delete();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已刪除裝置 $deviceId')));
  }

  Future<void> _clearDeviceSite(String sensorDocId) async {
    await FirebaseFirestore.instance.collection('sensors').doc(sensorDocId).set(
      {'site_id': null, 'site_name': null},
      SetOptions(merge: true),
    );
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
    await FirebaseFirestore.instance.collection('sensors').doc(sensorDocId).set(
      {'site_id': chosen, 'site_name': siteData['name']?.toString()},
      SetOptions(merge: true),
    );
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
              .limit(1200)
              .snapshots(),
          builder: (context, readingSnap) {
            if (readingSnap.hasError) return Center(child: Text("讀取失敗: ${readingSnap.error}"));
            final docs = readingSnap.data?.docs ?? [];
            // 在記憶體中手動排序，避免索引報報錯
            final sortedDocs = [...docs];
            sortedDocs.sort((a, b) {
              final aa = (a.data() as Map<String, dynamic>)['timestamp'];
              final bb = (b.data() as Map<String, dynamic>)['timestamp'];
              return _toEpochMillis(bb).compareTo(_toEpochMillis(aa));
            });

            final latestByDevice = <String, Map<String, dynamic>>{};
            for (final d in sortedDocs) {
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
              enriched.sort(
                (a, b) =>
                    ((a['raw'] as Map<String, dynamic>)['place']?.toString() ??
                            '')
                        .compareTo(
                          ((b['raw'] as Map<String, dynamic>)['place']
                                  ?.toString() ??
                              ''),
                        ),
              );
            } else if (_sortBy == 'site_asc') {
              enriched.sort(
                (a, b) =>
                    ((a['raw'] as Map<String, dynamic>)['site_name']
                                ?.toString() ??
                            '')
                        .compareTo(
                          ((b['raw'] as Map<String, dynamic>)['site_name']
                                  ?.toString() ??
                              ''),
                        ),
              );
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
                      DropdownMenuItem(
                        value: 'place_asc',
                        child: Text('排序：位置 A-Z'),
                      ),
                      DropdownMenuItem(
                        value: 'site_asc',
                        child: Text('排序：場域 A-Z'),
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
                    itemCount: enriched.length,
                    itemBuilder: (context, index) {
                      final docId = enriched[index]['docId'] as String;
                      final raw =
                          enriched[index]['raw'] as Map<String, dynamic>;
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
                        connectionProfile: (raw['connection_profile'] as Map?)
                            ?.cast<String, dynamic>(),
                        latestData: latest,
                        isAbnormal: abnormal,
                        onChangeSite: () =>
                            _changeDeviceSite(docId, currentSiteId),
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
        // 優先讀取 place，若無則讀取 id，再無則使用 docId
        final deviceId = sensor['id']?.toString() ?? sensorDoc.id;
        final place = (sensor['place']?.toString().isNotEmpty == true) 
            ? sensor['place'] 
            : (sensor['name']?.toString().isNotEmpty == true ? sensor['name'] : ' 區域 $deviceId');
        
        final query = await FirebaseFirestore.instance
            .collection('readings')
            .doc(deviceId)
            .collection('stream')
            .limit(10) // 增加讀取筆數
            .get();

        if (query.docs.isEmpty) {
          summaryLines.add('[$place (ID: $deviceId)] 目前無即時感測數據');
          continue;
        }

        // 手動排序以確保穩定性
        final sortedDocs = [...query.docs];
        sortedDocs.sort((a, b) {
          final aa = a.data()['timestamp'];
          final bb = b.data()['timestamp'];
          return _toEpochMillis(aa).compareTo(_toEpochMillis(bb));
        });

        for (final doc in sortedDocs.take(5)) {
          final data = doc.data();
          final ts = data['timestamp'];
          final map = Map<String, dynamic>.from(data)..remove('timestamp');
          summaryLines.add(
            '位置: $place, 裝置ID: $deviceId, 時間: ${ts ?? '未知'}, 數據: ${jsonEncode(map)}',
          );
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
                Text(
                  'Auto 每 ${widget.autoTriggerSeconds}s',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
                      color: _scvSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _scvBorder),
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
        const Text('說明：啟用後，場域 Post-AI 分頁會依設定秒數自動讀取最近資料並送給 GPT。'),
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
        if (_selectedDeviceId == null || _selectedDeviceId!.isEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('請先選擇裝置', style: const TextStyle(color: _scvMutedText)),
          )
        else
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('sensors')
                .where('id', isEqualTo: _selectedDeviceId)
                .limit(1)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              final data =
                  snapshot.data!.docs.first.data() as Map<String, dynamic>? ??
                  {};
              final schema = data['schema'] as Map<String, dynamic>? ?? {};
              final schemaFields = (schema['fields'] as List<dynamic>? ?? [])
                  .whereType<Map>()
                  .map(
                    (f) => {
                      'key': (f['key'] ?? '').toString(),
                      'label': (f['label'] ?? f['key'] ?? '').toString(),
                      'unit': (f['unit'] ?? '').toString(),
                    },
                  )
                  .where((f) => (f['key'] as String).isNotEmpty)
                  .toList();

              if (schemaFields.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    '此裝置無 schema 欄位，無法手動輸入',
                    style: TextStyle(color: Colors.orangeAccent),
                  ),
                );
              }

              return _ManualInputForm(
                deviceId: _selectedDeviceId!,
                fields: schemaFields,
              );
            },
          ),
      ],
    );
  }
}

class _ManualInputForm extends StatefulWidget {
  final String deviceId;
  final List<Map<String, dynamic>> fields;

  const _ManualInputForm({required this.deviceId, required this.fields});

  @override
  State<_ManualInputForm> createState() => _ManualInputFormState();
}

class _ManualInputFormState extends State<_ManualInputForm> {
  late Map<String, TextEditingController> _controllers;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final f in widget.fields)
        (f['key'] as String): TextEditingController(text: '0'),
    };
  }

  @override
  void didUpdateWidget(covariant _ManualInputForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_fieldKeys(oldWidget.fields) != _fieldKeys(widget.fields)) {
      for (final c in _controllers.values) {
        c.dispose();
      }
      _controllers = {
        for (final f in widget.fields)
          (f['key'] as String): TextEditingController(text: '0'),
      };
    }
  }

  Set<String> _fieldKeys(List<Map<String, dynamic>> fields) {
    return fields.map((f) => f['key'] as String).toSet();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final data = <String, num>{};
      for (final f in widget.fields) {
        final key = f['key'] as String;
        final c = _controllers[key];
        if (c != null) {
          data[key] = double.tryParse(c.text) ?? 0.0;
        }
      }

      await FirebaseFirestore.instance
          .collection('readings')
          .doc(widget.deviceId)
          .collection('stream')
          .add({...data, 'timestamp': FieldValue.serverTimestamp()});

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('手動資料已送出')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('送出失敗: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...widget.fields.map((f) {
          final key = f['key'] as String;
          final label = f['label'] as String;
          final unit = f['unit'] as String;
          final hint = unit.isNotEmpty ? '$label ($unit)' : label;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextField(
              controller: _controllers[key],
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: hint,
                border: const OutlineInputBorder(),
              ),
            ),
          );
        }),
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
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
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
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        "ID: $deviceId",
                        style: TextStyle(fontSize: 12, color: _scvMutedText),
                      ),
                      if (siteName != null && siteName!.isNotEmpty)
                        Text(
                          "場域: $siteName",
                          style: TextStyle(fontSize: 12, color: _scvMutedText),
                        ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Icon(
                        Icons.water_drop,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      if (connectionProfile != null)
                        Text(
                          (connectionProfile!['protocol'] ?? '-').toString(),
                          style: TextStyle(fontSize: 11, color: _scvMutedText),
                        ),
                      if (isAbnormal)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Chip(
                            label: Text(
                              '異常',
                              style: TextStyle(color: Colors.white),
                            ),
                            backgroundColor: _scvDanger,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      PopupMenuButton<String>(
                        tooltip: '裝置操作',
                        onSelected: (value) async {
                          if (value == 'change_site' && onChangeSite != null) {
                            await onChangeSite!.call();
                          } else if (value == 'clear_site' &&
                              onClearSite != null) {
                            await onClearSite!.call();
                          } else if (value == 'delete' &&
                              onDeleteDevice != null) {
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
                          PopupMenuItem(value: 'delete', child: Text('刪除裝置')),
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
                style: TextStyle(color: _scvMutedText, fontSize: 12),
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
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Text("數據異常");
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text(
            "等待數據連接...",
            style: TextStyle(color: _scvMutedText, fontStyle: FontStyle.italic),
          );
        }
        // 在記憶體中手動排序
        final readingDocs = snapshot.data?.docs ?? [];
        final sortedDocs = [...readingDocs];
        sortedDocs.sort((a, b) {
          final aa = (a.data() as Map<String, dynamic>)['timestamp'];
          final bb = (b.data() as Map<String, dynamic>)['timestamp'];
          return _toEpochMillis(bb).compareTo(_toEpochMillis(aa));
        });
        
        final latest = sortedDocs.first.data() as Map<String, dynamic>;
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
                  Text(label, style: const TextStyle(color: _scvText)),
                  Text(
                    "${value.toStringAsFixed(1)} $unit",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: percent > 0.8 ? _scvDanger : _scvPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percent,
                  backgroundColor: _scvBorder,
                  valueColor: AlwaysStoppedAnimation(
                    percent > 0.8 ? _scvDanger : _scvPrimary,
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
              .map((id) => DropdownMenuItem(value: id, child: Text(id)))
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

  Future<void> _deleteSite(
    String siteDocId,
    String siteId,
    String siteName,
  ) async {
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已刪除場域 $siteName')));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('sites').snapshots(),
      builder: (context, siteSnap) {
        if (siteSnap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('場域資料讀取失敗：${siteSnap.error}'),
            ),
          );
        }
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
            if (sensorSnap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('感測器資料讀取失敗：${sensorSnap.error}'),
                ),
              );
            }
            final sensorDocs = sensorSnap.data?.docs ?? const [];
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collectionGroup('stream')
                  .limit(1200)
                  .snapshots(),
              builder: (context, readingSnap) {
                if (readingSnap.hasError) return Center(child: Text("讀取失敗: ${readingSnap.error}"));
                final readingDocs = readingSnap.data?.docs ?? [];
                // 在記憶體中手動排序，避免索引報錯
                final sortedReadingDocs = [...readingDocs];
                sortedReadingDocs.sort((a, b) {
                  final aa = (a.data() as Map<String, dynamic>)['timestamp'];
                  final bb = (b.data() as Map<String, dynamic>)['timestamp'];
                  return _toEpochMillis(bb).compareTo(_toEpochMillis(aa));
                });

                final readingError = readingSnap.hasError
                    ? readingSnap.error
                    : null;
                final latestByDevice = <String, Map<String, dynamic>>{};
                for (final d in sortedReadingDocs) {
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
                  rows.sort(
                    (a, b) =>
                        (a['name'] as String).compareTo(b['name'] as String),
                  );
                } else if (_sortBy == 'devices_desc') {
                  rows.sort(
                    (a, b) => (b['deviceCount'] as int).compareTo(
                      a['deviceCount'] as int,
                    ),
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
                    if (readingError != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF6F6),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFFD9D9)),
                          ),
                          child: Text(
                            '即時讀值載入失敗，已改顯示場域基本資料：$readingError',
                            style: const TextStyle(
                              fontSize: 12,
                              color: _scvDanger,
                            ),
                          ),
                        ),
                      ),
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
                                abnormal > 0
                                    ? Icons.warning_amber
                                    : Icons.domain,
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
  int _updateSeconds = 30; // 預設每 30 秒更新

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
  void dispose() {
    super.dispose();
  }

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
      appBar: AppBar(title: Text('${widget.place} (${widget.deviceId})')),
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
          final snapshotDocs = snapshot.data!.docs.reversed.toList();
          final isTruncated = snapshot.data!.docs.length >= queryLimit;
          final renderDocs = _downsampleDocs(snapshotDocs, maxRenderPoints);
          final isDownsampled = renderDocs.length < snapshotDocs.length;

          final colorPool = <Color>[
            _scvPrimary,
            const Color(0xFF6FE6B8),
            const Color(0xFF4CA7FF),
            const Color(0xFFFFB86B),
            const Color(0xFFC58BFF),
            _scvDanger,
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
                spots.add(FlSpot(i.toDouble(), val.toDouble()));
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
            for (final doc in snapshotDocs) {
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
                  // 更新間隔設定
                  ChoiceChip(
                    label: Text('${_updateSeconds} 秒更新'),
                    selected: _updateSeconds == 30,
                    onSelected: (_) => setState(() => _updateSeconds = 30),
                  ),
                  ChoiceChip(
                    label: Text('30 秒更新'),
                    selected: _updateSeconds == 60,
                    onSelected: (_) => setState(() => _updateSeconds = 60),
                  ),
                  ChoiceChip(
                    label: Text('1 分鐘更新'),
                    selected: _updateSeconds == 120,
                    onSelected: (_) => setState(() => _updateSeconds = 120),
                  ),
                  // 清空選擇
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _windowHours = 1),
                    icon: const Icon(Icons.undo),
                    label: const Text('重置'),
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
                        _selectedKeys = commonKeys.isEmpty
                            ? fieldKeys
                            : commonKeys;
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
                  style: const TextStyle(
                    color: Color(0xFFFFC472),
                    fontSize: 12,
                  ),
                ),
              ],
              if (isDownsampled) ...[
                const SizedBox(height: 4),
                Text(
                  '為了避免卡頓，圖表已自動降採樣顯示（${renderDocs.length}/${snapshotDocs.length} 點）。',
                  style: const TextStyle(
                    color: Color(0xFFFFC472),
                    fontSize: 12,
                  ),
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
                                    ? math.max(1, snapshotDocs.length / 4)
                                    : (_windowHours == 24
                                          ? math.max(1, snapshotDocs.length / 6)
                                          : math.max(1, snapshotDocs.length / 7)),
                                getTitlesWidget: (value, meta) {
                                  final idx = value.round();
                                  if (idx < 0 || idx >= renderDocs.length) {
                                    return const SizedBox.shrink();
                                  }
                                  final data =
                                      renderDocs[idx].data()
                                          as Map<String, dynamic>;
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
                                    child: Text(
                                      label,
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: true,
                            getDrawingHorizontalLine: (value) =>
                                const FlLine(color: _scvBorder, strokeWidth: 1),
                            getDrawingVerticalLine: (value) =>
                                const FlLine(color: _scvBorder, strokeWidth: 1),
                          ),
                          borderData: FlBorderData(
                            show: true,
                            border: Border.all(color: _scvBorder),
                          ),
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
          final siteSensorDocs = snapshot.data!.docs;
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collectionGroup('stream')
                .limit(1200)
                .snapshots(),
            builder: (context, readingSnap) {
              if (readingSnap.hasError) return Center(child: Text("讀取失敗: ${readingSnap.error}"));
              final readingDocs = readingSnap.data?.docs ?? [];
              // 在記憶體中手動排序，避免索引報錯
              final sortedDocs = [...readingDocs];
              sortedDocs.sort((a, b) {
                final aa = (a.data() as Map<String, dynamic>)['timestamp'];
                final bb = (b.data() as Map<String, dynamic>)['timestamp'];
                return _toEpochMillis(bb).compareTo(_toEpochMillis(aa));
              });

              final latestByDevice = <String, Map<String, dynamic>>{};
              for (final d in sortedDocs) {
                final deviceId = d.reference.parent.parent?.id;
                if (deviceId == null) continue;
                latestByDevice.putIfAbsent(
                  deviceId,
                  () => d.data() as Map<String, dynamic>,
                );
              }

              final rows = siteSensorDocs.map((doc) {
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
              final abnormalCount = rows
                  .where((e) => e['abnormal'] as bool)
                  .length;
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
                                      ? _scvPrimary
                                      : const Color(0xFFFFC472),
                                ),
                                label: Text('即時健康 $healthText'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                            value: healthyRate.clamp(0, 1),
                            minHeight: 8,
                            backgroundColor: Colors.white12,
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
              .limit(120)
              .snapshots(),
          builder: (context, snapshot) {
            // 在記憶體中手動排序
            final readingDocs = snapshot.data?.docs ?? [];
            final sortedDocs = [...readingDocs];
            sortedDocs.sort((a, b) {
              final aa = (a.data() as Map<String, dynamic>)['timestamp'];
              final bb = (b.data() as Map<String, dynamic>)['timestamp'];
              return _toEpochMillis(bb).compareTo(_toEpochMillis(aa));
            });

            final snapshotDocs = sortedDocs.reversed.toList();
            final targetKey = fields.isNotEmpty ? fields.first : 'kitchen_flow';
            final spots = <FlSpot>[];
            for (int i = 0; i < snapshotDocs.length; i++) {
              final data = snapshotDocs[i].data() as Map<String, dynamic>;
              final value = data[targetKey];
              if (value is num) {
                spots.add(FlSpot(i.toDouble(), value.toDouble()));
              }
            }

            final latest = snapshotDocs.isNotEmpty
                ? (snapshotDocs.last.data() as Map<String, dynamic>)[targetKey]
                : null;
            final latestText = latest is num
                ? latest.toStringAsFixed(1)
                : 'N/A';
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
                              backgroundColor: _scvDanger,
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
                                color: _scvPrimary,
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
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              getDrawingHorizontalLine: (value) => const FlLine(
                                color: _scvBorder,
                                strokeWidth: 1,
                              ),
                            ),
                            borderData: FlBorderData(
                              show: true,
                              border: Border.all(color: _scvBorder),
                            ),
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

class _DemoGuideDialog extends StatefulWidget {
  const _DemoGuideDialog();

  @override
  State<_DemoGuideDialog> createState() => _DemoGuideDialogState();
}

class _DemoGuideDialogState extends State<_DemoGuideDialog> {
  int _step = 0;
  final List<Map<String, String>> _steps = [
    {
      'title': 'Welcome to SCV Water!',
      'content': 'This app helps you monitor water usage and optimize efficiency in real-time.',
      'image': '🌊',
    },
    {
      'title': 'Real-time Dashboard',
      'content': 'View live data from all your sensors. Colors turn red when usage exceeds thresholds.',
      'image': '📊',
    },
    {
      'title': 'Smart Optimization',
      'content': 'Use the AI-powered optimization tab to get suggestions on saving water and costs.',
      'image': '💡',
    },
    {
      'title': 'Device Management',
      'content': 'Easily add new sensors or sites to your network from the management tabs.',
      'image': '🔧',
    },
    {
      'title': 'Stay Notified',
      'content': 'Receive alerts when abnormal water flow is detected so you can act quickly.',
      'image': '🔔',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final stepData = _steps[_step];
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              stepData['image']!,
              style: const TextStyle(fontSize: 60),
            ),
            const SizedBox(height: 16),
            Text(
              stepData['title']!,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              stepData['content']!,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_step > 0)
                  TextButton(
                    onPressed: () => setState(() => _step--),
                    child: const Text('Back'),
                  )
                else
                  const SizedBox(width: 60),
                Row(
                  children: List.generate(
                    _steps.length,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _step == index ? _scvPrimary : Colors.grey.shade300,
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    if (_step < _steps.length - 1) {
                      setState(() => _step++);
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  child: Text(_step == _steps.length - 1 ? 'Finish' : 'Next'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
