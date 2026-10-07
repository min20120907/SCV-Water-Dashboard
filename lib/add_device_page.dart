import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:scv_water_dashboard/gemini_service.dart';
import 'package:scv_water_dashboard/deploy_service.dart';

class AddDevicePage extends StatefulWidget {
  const AddDevicePage({super.key});

  @override
  State<AddDevicePage> createState() => _AddDevicePageState();
}

class _AddDevicePageState extends State<AddDevicePage> {
  final _geminiService = GeminiService();
  final _deployService = DeployService();
  final _manualController = TextEditingController();
  final _idController = TextEditingController();
  final _placeController = TextEditingController();
  final _purposeController = TextEditingController();
  final _endpointController = TextEditingController();
  final _topicController = TextEditingController();
  final _bleServiceController = TextEditingController();
  final _zigbeeIeeeController = TextEditingController();
  String? _selectedSiteId;
  String? _selectedSiteName;
  String _protocol = 'emulator';

  bool _isAnalyzing = false;
  bool _isGeneratingGuide = false;
  bool _isDeploying = false;
  bool _isScanning = false;
  String? _schemaJson;
  Map<String, dynamic>? _parsedSchema;

  // Discovered Pi devices
  List<DiscoveredDevice> _discoveredDevices = [];
  DiscoveredDevice? _selectedDevice;

  Map<String, dynamic> _buildEmulatorFallbackSchema() {
    return {
      "type_id": "SCV_EMULATOR",
      "fields": [
        {
          "key": "kitchen_flow",
          "label": "Kitchen Flow",
          "unit": "mL/s",
          "data_type": "double",
          "min_threshold": null,
          "max_threshold": 1000,
        },
        {
          "key": "shower_flow",
          "label": "Shower Flow",
          "unit": "mL/s",
          "data_type": "double",
          "min_threshold": null,
          "max_threshold": 1000,
        },
        {
          "key": "bathtub_flow",
          "label": "Bathtub Flow",
          "unit": "mL/s",
          "data_type": "double",
          "min_threshold": null,
          "max_threshold": 1000,
        },
        {
          "key": "toilet_flow",
          "label": "Toilet Flow",
          "unit": "mL/s",
          "data_type": "double",
          "min_threshold": null,
          "max_threshold": 1000,
        },
      ],
    };
  }

  void _applySchema(Map<String, dynamic> schemaMap) {
    _schemaJson = const JsonEncoder.withIndent('  ').convert(schemaMap);
    _parsedSchema = schemaMap;
    if (_idController.text.isEmpty && schemaMap['type_id'] != null) {
      _idController.text = "${schemaMap['type_id']}_001";
    }
  }

  Future<void> _analyze() async {
    if (_manualController.text.isEmpty) return;
    setState(() => _isAnalyzing = true);

    try {
      final jsonStr = await _geminiService.identifySensorSchema(
        _manualController.text,
      );
      final schemaMap = jsonDecode(jsonStr) as Map<String, dynamic>;
      final hasError =
          schemaMap.containsKey('error') && schemaMap['error'] != null;
      final looksLikeEmulator = _manualController.text.toLowerCase().contains(
        'emulator',
      );
      final useFallback = hasError && looksLikeEmulator;
      final nextSchema = useFallback
          ? _buildEmulatorFallbackSchema()
          : schemaMap;

      if (!mounted) return;
      setState(() {
        _applySchema(nextSchema);
      });
      if (useFallback) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("AI 配額受限，已自動套用 Emulator 本地範本。")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("解析失敗: $e")));
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  Future<void> _save() async {
    if (_idController.text.isEmpty || _parsedSchema == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('sensors')
          .doc(_idController.text.trim())
          .set({
            'id': _idController.text.trim(),
            'site_id': _selectedSiteId,
            'site_name': _selectedSiteName,
            'place': _placeController.text.trim(),
            'purpose': _purposeController.text.trim(),
            'connection_profile': {
              'protocol': _protocol,
              'endpoint': _endpointController.text.trim(),
              'topic': _topicController.text.trim(),
              'ble_service_uuid': _bleServiceController.text.trim(),
              'zigbee_ieee': _zigbeeIeeeController.text.trim(),
              'status': 'pending',
              'updated_at': FieldValue.serverTimestamp(),
            },
            'schema': _parsedSchema,
            'created_at': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("裝置已新增！")));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("儲存錯誤: $e")));
    }
  }

  IconData _guideIcon(String icon) {
    switch (icon) {
      case 'hardware': return Icons.developer_board;
      case 'wiring': return Icons.cable;
      case 'software': return Icons.terminal;
      case 'test': return Icons.science;
      case 'cloud': return Icons.cloud;
      default: return Icons.build;
    }
  }

  /// 根據感測器數量和 protocol 自動產生接線圖
  Widget _buildWiringDiagram(String protocol, int sensorCount) {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: CustomPaint(
        painter: _WiringDiagramPainter(protocol: protocol, sensorCount: sensorCount),
      ),
    );
  }

  Color _difficultyColor(String difficulty) {
    switch (difficulty) {
      case '簡單': return Colors.green;
      case '困難': return Colors.red;
      default: return Colors.orange;
    }
  }

  Future<void> _showHardwareGuide() async {
    if (_parsedSchema == null) return;
    setState(() => _isGeneratingGuide = true);

    try {
      final guide = await _geminiService.generateHardwareGuide(
        sensorDescription: _manualController.text,
        protocol: _protocol,
        schema: _parsedSchema,
      );

      if (!mounted) return;
      setState(() => _isGeneratingGuide = false);

      final title = guide['title'] as String? ?? '硬體安裝指南';
      final difficulty = guide['difficulty'] as String? ?? '中等';
      final estimatedTime = guide['estimated_time'] as String? ?? '';
      final sections = guide['sections'] as List<dynamic>? ?? [];
      final tips = guide['tips'] as List<dynamic>? ?? [];

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Chip(
                        label: Text(difficulty),
                        backgroundColor: _difficultyColor(difficulty).withValues(alpha: 0.15),
                        labelStyle: TextStyle(color: _difficultyColor(difficulty), fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      if (estimatedTime.isNotEmpty)
                        Chip(
                          label: Text(estimatedTime),
                          backgroundColor: Colors.grey.withValues(alpha: 0.1),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...sections.map((section) {
                    final icon = section['icon'] as String? ?? 'build';
                    final sectionTitle = section['title'] as String? ?? '';
                    final items = section['items'] as List<dynamic>? ?? [];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(_guideIcon(icon), size: 20, color: Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 8),
                                Text(sectionTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (sectionTitle == '接線方式') ...[
                              _buildWiringDiagram(_protocol, items.length),
                              const SizedBox(height: 8),
                            ],
                            ...items.map((item) => Padding(
                              padding: const EdgeInsets.only(left: 4, bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('• ', style: TextStyle(fontSize: 14)),
                                  Expanded(child: Text(item.toString(), style: const TextStyle(fontSize: 14))),
                                ],
                              ),
                            )),
                          ],
                        ),
                      ),
                    );
                  }),
                  if (tips.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.lightbulb_outline, size: 18, color: Colors.amber),
                              SizedBox(width: 6),
                              Text('注意事項', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ...tips.map((tip) => Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('• ', style: TextStyle(fontSize: 13)),
                                Expanded(child: Text(tip.toString(), style: const TextStyle(fontSize: 13))),
                              ],
                            ),
                          )),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('關閉'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGeneratingGuide = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('產生失敗：$e')),
      );
    }
  }

  Future<void> _scanNetwork() async {
    setState(() => _isScanning = true);
    try {
      final devices = await _deployService.scan();
      if (!mounted) return;
      setState(() {
        _discoveredDevices = devices;
        _isScanning = false;
      });
      if (devices.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未找到樹莓派，請確認已開機並連網')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('找到 ${devices.length} 個裝置')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isScanning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('掃描失敗：$e')),
      );
    }
  }

  Future<void> _deployToPi() async {
    if (_parsedSchema == null) return;
    if (_selectedDevice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先掃描並選擇樹莓派')),
      );
      return;
    }
    setState(() => _isDeploying = true);

    try {
      final result = await _deployService.deploy(
        deviceId: _idController.text.trim(),
        sensorDescription: _manualController.text,
        protocol: _protocol,
        schema: _parsedSchema!,
        piHost: _selectedDevice!.ip,
        piPort: _selectedDevice!.port,
        piUser: 'pi',
        piSshKey: '',  // auto-discovered
        firebaseConfig: const {},  // auto-loaded by deploy service
      );

      if (!mounted) return;
      setState(() => _isDeploying = false);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(result.success ? '部署成功' : '部署失敗'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(result.message),
                if (result.logs.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('部署日誌：', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  ...result.logs.map((log) => Text(
                        log,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                      )),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('關閉'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeploying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('部署失敗：$e')),
      );
    }
  }

  void _loadEmulatorTemplate() {
    _manualController.text =
        "SCV Water Emulator V1. Includes Kitchen Sink, Shower, Bathtub, and Toilet sensors. Units in mL/s.";
    _placeController.text = "Demo Room";
    _purposeController.text = "Simulation";
    _protocol = 'emulator';
    _topicController.text = 'readings/stream';
  }

  @override
  void dispose() {
    _manualController.dispose();
    _idController.dispose();
    _placeController.dispose();
    _purposeController.dispose();
    _endpointController.dispose();
    _topicController.dispose();
    _bleServiceController.dispose();
    _zigbeeIeeeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("新增裝置 (AI Onboarding)")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "步驟 1: 裝置規格 (貼上說明書)",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextField(controller: _manualController, maxLines: 3),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isAnalyzing ? null : _analyze,
                          icon: _isAnalyzing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.auto_awesome),
                          label: const Text("AI 解析"),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: _loadEmulatorTemplate,
                          child: const Text("載入模擬器範本"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (_schemaJson != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Text(
                  _schemaJson!,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
                ),
              ),
            ],
            const SizedBox(height: 20),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('sites')
                  .orderBy('created_at', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? [];
                final items = docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return DropdownMenuItem<String>(
                    value: data['id']?.toString(),
                    child: Text(
                      '${data['name'] ?? data['id']} (${data['id'] ?? '-'})',
                    ),
                  );
                }).toList();

                final validValue =
                    items.any((item) => item.value == _selectedSiteId)
                    ? _selectedSiteId
                    : null;

                return DropdownButtonFormField<String>(
                  key: ValueKey(validValue),
                  initialValue: validValue,
                  items: items,
                  onChanged: (value) {
                    Map<String, dynamic>? selectedData;
                    for (final d in docs) {
                      final data = d.data() as Map<String, dynamic>;
                      if (data['id']?.toString() == value) {
                        selectedData = data;
                        break;
                      }
                    }
                    setState(() {
                      _selectedSiteId = value;
                      if (value == null || selectedData == null) {
                        _selectedSiteName = null;
                      } else {
                        _selectedSiteName = selectedData['name']?.toString();
                      }
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: '所屬場域（可選）',
                    border: OutlineInputBorder(),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _idController,
              decoration: const InputDecoration(
                labelText: "裝置 ID (配對碼)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _placeController,
              decoration: const InputDecoration(
                labelText: "安裝位置",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _purposeController,
              decoration: const InputDecoration(
                labelText: "用途",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '感測器通訊協定',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _protocol,
                      items: const [
                        DropdownMenuItem(
                          value: 'emulator',
                          child: Text('Emulator'),
                        ),
                        DropdownMenuItem(value: 'ip', child: Text('IP/HTTP')),
                        DropdownMenuItem(value: 'mqtt', child: Text('MQTT')),
                        DropdownMenuItem(
                          value: 'ble',
                          child: Text('Bluetooth LE'),
                        ),
                        DropdownMenuItem(
                          value: 'zigbee',
                          child: Text('Zigbee'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _protocol = v);
                      },
                      decoration: const InputDecoration(
                        labelText: '通訊協定',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_protocol == 'ip' || _protocol == 'mqtt')
                      TextField(
                        controller: _endpointController,
                        decoration: const InputDecoration(
                          labelText: 'Endpoint / Broker',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    if (_protocol == 'ip' || _protocol == 'mqtt')
                      const SizedBox(height: 10),
                    if (_protocol == 'mqtt')
                      TextField(
                        controller: _topicController,
                        decoration: const InputDecoration(
                          labelText: 'Topic',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    if (_protocol == 'ble') ...[
                      TextField(
                        controller: _bleServiceController,
                        decoration: const InputDecoration(
                          labelText: 'BLE Service UUID',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    if (_protocol == 'zigbee') ...[
                      TextField(
                        controller: _zigbeeIeeeController,
                        decoration: const InputDecoration(
                          labelText: 'Zigbee IEEE Address',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '樹莓派 SSH 自動部署',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isScanning ? null : _scanNetwork,
                        icon: _isScanning
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.wifi_find),
                        label: Text(_isScanning ? '掃描中...' : '掃描區域網路'),
                      ),
                    ),
                    if (_discoveredDevices.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ..._discoveredDevices.map((device) {
                        final isSelected = _selectedDevice?.ip == device.ip;
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            Icons.developer_board,
                            color: isSelected ? Colors.green : Colors.grey,
                          ),
                          title: Text(device.name),
                          subtitle: Text(
                            device.mac != null
                                ? '${device.mac}  ·  ${device.ip}:${device.port}'
                                : '${device.ip}:${device.port}',
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle, color: Colors.green)
                              : null,
                          selected: isSelected,
                          onTap: () {
                            setState(() {
                              _selectedDevice = device;
                              _endpointController.text = device.ip;
                            });
                          },
                        );
                      }),
                    ],
                    const SizedBox(height: 10),
                    // No SSH user / password fields. The deploy service holds a
                    // per-site key and connects as the fixed `pi` user; asking
                    // the operator for credentials here produced a value that
                    // was written to Firestore but never read by the deploy
                    // path (which auto-discovers the key on the server).
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.vpn_key_outlined,
                            size: 18,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '不需要帳密',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue.shade900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '金鑰由伺服器持有，自動以 pi 帳號連線',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_parsedSchema == null || _isGeneratingGuide) ? null : _showHardwareGuide,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                icon: _isGeneratingGuide
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.build),
                label: Text(_isGeneratingGuide ? '產生中...' : '產生硬體指南'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_parsedSchema == null || _isDeploying) ? null : _deployToPi,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                icon: _isDeploying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cloud_upload),
                label: Text(_isDeploying ? '部署中...' : 'SSH 自動部署到樹莓派'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _parsedSchema == null ? null : _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                child: const Text("確認新增"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 自動 render 樹莓派接線圖
class _WiringDiagramPainter extends CustomPainter {
  final String protocol;
  final int sensorCount;

  _WiringDiagramPainter({required this.protocol, required this.sensorCount});

  @override
  void paint(Canvas canvas, Size size) {
    final piPaint = Paint()
      ..color = const Color(0xFF2E7D32)
      ..style = PaintingStyle.fill;
    final pinPaint = Paint()
      ..color = const Color(0xFF424242)
      ..style = PaintingStyle.fill;
    final wireRed = Paint()
      ..color = Colors.red
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final wireBlack = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final wireYellow = Paint()
      ..color = Colors.amber.shade700
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final sensorPaint = Paint()
      ..color = const Color(0xFF1565C0)
      ..style = PaintingStyle.fill;
    final textStyle = const TextStyle(color: Colors.black87, fontSize: 10);

    // 樹莓派方塊（左側）
    final piRect = Rect.fromLTWH(20, 40, 80, 120);
    canvas.drawRRect(
      RRect.fromRectAndRadius(piRect, const Radius.circular(8)),
      piPaint,
    );
    _drawText(canvas, '樹莓派', Offset(piRect.center.dx - 18, piRect.center.dy - 6), textStyle);
    _drawText(canvas, 'GPIO', Offset(piRect.center.dx - 14, piRect.center.dy + 8), textStyle);

    // GPIO 腳位（右側邊緣）
    final gpioPins = [17, 27, 22, 23, 24, 25, 5, 6];
    final pinStartY = 55.0;
    final pinSpacing = 14.0;
    for (int i = 0; i < gpioPins.length && i < 8; i++) {
      final y = pinStartY + i * pinSpacing;
      canvas.drawCircle(Offset(piRect.right - 4, y), 3, pinPaint);
      _drawText(canvas, 'GPIO${gpioPins[i]}', Offset(piRect.right + 4, y - 5), textStyle);
    }

    // 感測器方塊（右側）
    final sensorWidth = 70.0;
    final sensorHeight = 28.0;
    final sensorSpacing = 8.0;
    final totalSensorHeight = sensorCount * sensorHeight + (sensorCount - 1) * sensorSpacing;
    final sensorStartY = (size.height - totalSensorHeight) / 2;

    for (int i = 0; i < sensorCount; i++) {
      final sy = sensorStartY + i * (sensorHeight + sensorSpacing);
      final sensorRect = Rect.fromLTWH(size.width - sensorWidth - 20, sy, sensorWidth, sensorHeight);
      canvas.drawRRect(
        RRect.fromRectAndRadius(sensorRect, const Radius.circular(6)),
        sensorPaint,
      );
      _drawText(canvas, '感測器 ${i + 1}', Offset(sensorRect.center.dx - 22, sensorRect.center.dy - 5), textStyle);

      // 每條感測器三條線：紅（VCC）、黑（GND）、黃（Signal）
      final pinY = pinStartY + i * pinSpacing;
      final sensorLeft = sensorRect.left;
      final sensorY = sensorRect.center.dy;

      // 紅線：5V
      canvas.drawLine(Offset(piRect.right - 4, pinStartY), Offset(sensorLeft, sensorY - 6), wireRed);
      // 黑線：GND
      canvas.drawLine(Offset(piRect.right - 4, pinStartY + 4), Offset(sensorLeft, sensorY), wireBlack);
      // 黃線：Signal
      canvas.drawLine(Offset(piRect.right - 4, pinY), Offset(sensorLeft, sensorY + 6), wireYellow);
    }

    // 圖例
    final legendY = size.height - 24;
    _drawLegend(canvas, 20, legendY, '5V', Colors.red);
    _drawLegend(canvas, 70, legendY, 'GND', Colors.black);
    _drawLegend(canvas, 120, legendY, 'Signal', Colors.amber.shade700);
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  void _drawLegend(Canvas canvas, double x, double y, String label, Color color) {
    canvas.drawLine(Offset(x, y + 4), Offset(x + 16, y + 4), Paint()..color = color..strokeWidth = 2);
    _drawText(canvas, label, Offset(x + 20, y), const TextStyle(fontSize: 10, color: Colors.black54));
  }

  @override
  bool shouldRepaint(covariant _WiringDiagramPainter oldDelegate) =>
      protocol != oldDelegate.protocol || sensorCount != oldDelegate.sensorCount;
}
