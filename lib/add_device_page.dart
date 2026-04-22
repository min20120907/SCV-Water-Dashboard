import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:scv_water_dashboard/gemini_service.dart';

class AddDevicePage extends StatefulWidget {
  const AddDevicePage({super.key});

  @override
  State<AddDevicePage> createState() => _AddDevicePageState();
}

class _AddDevicePageState extends State<AddDevicePage> {
  final _geminiService = GeminiService();
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
  String? _schemaJson;
  Map<String, dynamic>? _parsedSchema;

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
                      '連線設定（實體感測器）',
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
            const SizedBox(height: 20),
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
