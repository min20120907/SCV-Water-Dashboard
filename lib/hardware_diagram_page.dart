import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'deploy_service.dart';

/// Shows the Fritzing hardware installation diagram for one site.
///
/// Generated server-side (Fritzing + LLM live in the middle service), so this
/// page only renders what it gets back: the PNG, the wiring table and any
/// electrical warnings.
class HardwareDiagramPage extends StatefulWidget {
  final String siteId;
  final String siteName;
  final List<Map<String, dynamic>> sensors;
  final DeployService deployService;

  const HardwareDiagramPage({
    super.key,
    required this.siteId,
    required this.siteName,
    required this.sensors,
    required this.deployService,
  });

  @override
  State<HardwareDiagramPage> createState() => _HardwareDiagramPageState();
}

class _HardwareDiagramPageState extends State<HardwareDiagramPage> {
  HardwareDiagram? _diagram;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await widget.deployService.generateHardwareDiagram(
        siteId: widget.siteId,
        siteName: widget.siteName,
        sensors: widget.sensors,
      );
      if (!mounted) return;
      setState(() {
        _diagram = d;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.siteName} 硬體安裝圖'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _generate,
            icon: const Icon(Icons.refresh),
            tooltip: '重新生成',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Fritzing 正在繪製接線圖…'),
            SizedBox(height: 4),
            Text(
              '約需 5–15 秒',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _generate,
                icon: const Icon(Icons.refresh),
                label: const Text('重試'),
              ),
            ],
          ),
        ),
      );
    }

    final d = _diagram;
    if (d == null) return const SizedBox.shrink();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Fritzing breadboard render
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(8),
                child: Image.memory(
                  Uint8List.fromList(d.pngBytes),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stack) => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('接線圖載入失敗'),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Row(
                  children: [
                    const Icon(Icons.account_tree, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Fritzing 麵包板視圖 · run ${d.runId}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Electrical warnings first -- these are the ones that prevent damage
        if (d.warnings.isNotEmpty) ...[
          for (final w in d.warnings)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.warning_amber, color: Colors.amber),
                title: Text(w, style: const TextStyle(fontSize: 13)),
                dense: true,
              ),
            ),
          const SizedBox(height: 4),
        ],

        // Wiring table
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.table_rows, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '接線對照表（${d.wiringTable.length} 條）',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final r in d.wiringTable)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            r.sensor,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            r.sensorPin,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Icon(
                            Icons.arrow_right_alt,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            r.piPin,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1565C0),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Scope note: software install + cloud deploy happen over SSH, not here
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade100),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.blue),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '本頁只說明硬體接線。驅動程式安裝與雲端連線已由「SSH 自動部署」完成，'
                  '不需手動操作。',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
