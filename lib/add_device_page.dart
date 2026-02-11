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

  bool _isAnalyzing = false;
  String? _schemaJson;
  Map<String, dynamic>? _parsedSchema;

  Future<void> _analyze() async {
    if (_manualController.text.isEmpty) return;
    setState(() => _isAnalyzing = true);

    try {
      final jsonStr = await _geminiService.identifySensorSchema(
        _manualController.text,
      );
      final schemaMap = jsonDecode(jsonStr) as Map<String, dynamic>;

      if (!mounted) return;
      setState(() {
        _schemaJson = const JsonEncoder.withIndent('  ').convert(schemaMap);
        _parsedSchema = schemaMap;
        if (_idController.text.isEmpty && schemaMap['type_id'] != null) {
          _idController.text = "${schemaMap['type_id']}_001";
        }
      });
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
            'place': _placeController.text.trim(),
            'purpose': _purposeController.text.trim(),
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
  }

  @override
  void dispose() {
    _manualController.dispose();
    _idController.dispose();
    _placeController.dispose();
    _purposeController.dispose();
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
              color: Colors.blue.shade50,
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
                color: Colors.black12,
                child: Text(
                  _schemaJson!,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
                ),
              ),
            ],
            const SizedBox(height: 20),
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
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _parsedSchema == null ? null : _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
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
