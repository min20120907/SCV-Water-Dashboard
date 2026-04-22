import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'gemini_service.dart';

class AddSitePage extends StatefulWidget {
  final String? initialName;
  final String? initialDescription;
  final String? initialPrompt;

  const AddSitePage({
    super.key,
    this.initialName,
    this.initialDescription,
    this.initialPrompt,
  });

  @override
  State<AddSitePage> createState() => _AddSitePageState();
}

class _AddSitePageState extends State<AddSitePage> {
  final _gemini = GeminiService();
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _promptController = TextEditingController();
  final _descController = TextEditingController();

  bool _generating = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialName != null) {
      _nameController.text = widget.initialName!;
      _idController.text = widget.initialName!.toLowerCase().replaceAll(' ', '_');
    }
    if (widget.initialDescription != null) {
      _descController.text = widget.initialDescription!;
    }
    if (widget.initialPrompt != null) {
      _promptController.text = widget.initialPrompt!;
    }
  }

  Future<void> _generateDescription() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _generating = true);
    try {
      final text = await _gemini.generateSiteDescription(
        siteName: name,
        prompt: _promptController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _descController.text = text);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _save() async {
    final id = _idController.text.trim();
    final name = _nameController.text.trim();
    if (id.isEmpty || name.isEmpty) return;

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('sites').doc(id).set({
        'id': id,
        'name': name,
        'description': _descController.text.trim(),
        'prompt': _promptController.text.trim(),
        'created_at': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('場域已新增')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('新增場域失敗: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _promptController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新增場域')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _idController,
            decoration: const InputDecoration(
              labelText: '場域 ID',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '場域名稱',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _promptController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: '場域描述提示詞（例如：客廳、有植栽、晚間用水較高）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _generating ? null : _generateDescription,
                icon: _generating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: const Text('GPT 產生場域敘述'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _descController,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: '場域敘述',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '儲存中...' : '儲存場域'),
          ),
        ],
      ),
    );
  }
}
