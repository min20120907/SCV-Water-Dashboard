import 'dart:convert';
import 'package:http/http.dart' as http;

/// Client for the SSH remote deployment service.
/// Deploys sensor drivers to Raspberry Pi via SSH.
class DeployService {
  final String baseUrl;
  static const _apiKey = 'scv-water-2026-secure-key';

  DeployService({this.baseUrl = 'http://localhost:8767'});

  /// Deploy a sensor driver to a Raspberry Pi via SSH.
  Future<DeployResult> deploy({
    required String deviceId,
    required String sensorDescription,
    required String protocol,
    required Map<String, dynamic> schema,
    required String piHost,
    int piPort = 22,
    String piUser = 'pi',
    required String piSshKey,
    required Map<String, dynamic> firebaseConfig,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/deploy'),
      headers: {'Content-Type': 'application/json', 'X-API-Key': _apiKey},
      body: jsonEncode({
        'device_id': deviceId,
        'sensor_description': sensorDescription,
        'protocol': protocol,
        'schema': schema,
        'pi_host': piHost,
        'pi_port': piPort,
        'pi_user': piUser,
        'pi_ssh_key': piSshKey,
        'firebase_config': firebaseConfig,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Deploy failed: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return DeployResult.fromJson(data);
  }

  /// Undeploy / unbind a sensor driver from a Raspberry Pi via SSH.
  Future<bool> undeploy({
    required String deviceId,
    required String piHost,
    int piPort = 22,
    String piUser = 'pi',
    String piSshKey = '',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/undeploy'),
      headers: {'Content-Type': 'application/json', 'X-API-Key': _apiKey},
      body: jsonEncode({
        'device_id': deviceId,
        'pi_host': piHost,
        'pi_port': piPort,
        'pi_user': piUser,
        'pi_ssh_key': piSshKey,
      }),
    );
    if (response.statusCode != 200) return false;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['success'] == true;
  }

  /// Scan local network for Raspberry Pi devices.
  Future<List<DiscoveredDevice>> scan() async {
    final response = await http.get(Uri.parse('$baseUrl/scan'), headers: {'X-API-Key': _apiKey});
    if (response.statusCode != 200) {
      throw Exception('Scan failed: ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['devices'] as List)
        .map((e) => DiscoveredDevice.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Health check
  Future<bool> isHealthy() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health'));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Render a Fritzing hardware installation diagram for a site.
  ///
  /// The diagram is generated server-side because it needs Fritzing, the LLM
  /// credentials and the SSH keys -- none of which belong on the phone. Call
  /// this after deployment, not before.
  Future<HardwareDiagram> generateHardwareDiagram({
    required String siteId,
    required String siteName,
    required List<Map<String, dynamic>> sensors,
    bool useLlm = true,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/hardware/diagram'),
      headers: {'Content-Type': 'application/json', 'X-API-Key': _apiKey},
      body: jsonEncode({
        'site_id': siteId,
        'site_name': siteName,
        'sensors': sensors,
        'use_llm': useLlm,
      }),
    );

    if (response.statusCode != 200) {
      String detail = response.body;
      try {
        final parsed = jsonDecode(response.body);
        if (parsed is Map && parsed['detail'] != null) {
          detail = parsed['detail'].toString();
        }
      } catch (_) {}
      throw Exception('硬體安裝圖生成失敗：$detail');
    }

    return HardwareDiagram.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// RESEARCH phase: datasheet web research -> LLM driver codegen -> on-Pi
  /// selftest gate. Slow (web + LLM + 3 selftest attempts; ~2-4 min).
  /// success=true only if the on-Pi selftest passes; no_device with scan
  /// evidence is an honest hardware result, not a pipeline failure.
  Future<ResearchResult> research({
    required String model,
    required String siteId,
    bool forceResearch = false,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/pipeline/research'),
          headers: {
            'Content-Type': 'application/json',
            'X-API-Key': _apiKey,
          },
          body: jsonEncode({
            'model': model,
            'site_id': siteId,
            'force_research': forceResearch,
          }),
        )
        .timeout(const Duration(minutes: 10));
    if (response.statusCode != 200) {
      throw Exception('Research failed: ${response.statusCode} ${response.body}');
    }
    return ResearchResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Inspect currently running sensors, USB devices, I2C, and GPIO status on Pi.
  Future<HardwareInspectResult> inspectHardware({
    String? host,
    int? port,
    String? user,
  }) async {
    final body = <String, dynamic>{};
    if (host != null) body['pi_host'] = host;
    if (port != null) body['pi_port'] = port;
    if (user != null) body['pi_user'] = user;

    final response = await http
        .post(
          Uri.parse('$baseUrl/hardware/inspect'),
          headers: {
            'Content-Type': 'application/json',
            'X-API-Key': _apiKey,
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('Hardware inspection failed: ${response.statusCode} ${response.body}');
    }
    final raw = jsonDecode(response.body);
    return HardwareInspectResult.fromJson(
      raw is Map ? raw : {},
    );
  }
}

class HardwareInspectResult {
  final bool success;
  final String host;
  final List<String> sensors;
  final List<String> usb;
  final List<String> i2c;
  final List<String> gpio;
  final String? error;

  const HardwareInspectResult({
    required this.success,
    required this.host,
    required this.sensors,
    required this.usb,
    required this.i2c,
    required this.gpio,
    this.error,
  });

  factory HardwareInspectResult.fromJson(Map raw) {
    final json = Map<String, dynamic>.from(raw);
    final sensorsList = (json['sensors'] as List? ?? [])
        .map((s) => s is Map ? "${s['name']} (PID: ${s['pid']})" : s.toString())
        .toList();
    final usbList =
        (json['usb'] as List? ?? []).map((e) => e.toString()).toList();
    final i2cMap = json['i2c'] is Map ? (json['i2c'] as Map) : {};
    final List<String> i2cList = [];
    i2cMap.forEach((k, v) {
      if (v is List && v.isNotEmpty) {
        i2cList.add('$k: ${v.join(', ')}');
      }
    });
    final gpioList =
        (json['gpio'] as List? ?? []).map((e) => e.toString()).toList();

    return HardwareInspectResult(
      success: json['success'] == true,
      host: json['host']?.toString() ?? '',
      sensors: sensorsList,
      usb: usbList,
      i2c: i2cList,
      gpio: gpioList,
      error: json['error']?.toString(),
    );
  }
}

class ResearchResult {
  final bool success;
  final bool verified;
  final String deviceId;
  final String mode; // catalog | research
  final String protocol;
  final List<String> fieldKeys;
  final List<String> sources;
  final String message;
  final String logsTail;

  const ResearchResult({
    required this.success,
    required this.verified,
    required this.deviceId,
    required this.mode,
    required this.protocol,
    required this.fieldKeys,
    required this.sources,
    required this.message,
    required this.logsTail,
  });

  factory ResearchResult.fromJson(Map<String, dynamic> json) {
    return ResearchResult(
      success: json['success'] == true,
      verified: json['verified'] == true,
      deviceId: json['device_id']?.toString() ?? '',
      mode: json['mode']?.toString() ?? '',
      protocol: json['protocol']?.toString() ?? '',
      fieldKeys: (json['fields'] as List? ?? [])
          .map((e) => (e as Map)['key']?.toString() ?? '')
          .toList(),
      sources: (json['sources'] as List? ?? [])
          .map((e) => (e as Map)['title']?.toString() ??
              (e['url'] as String?) ?? '')
          .toList(),
      message: json['message']?.toString() ?? '',
      logsTail: json['logs_tail']?.toString() ?? '',
    );
  }
}

/// One rendered wiring row (sensor pin -> Pi pin).
class WiringRow {
  final String sensor;
  final String sensorPin;
  final String piPin;
  final String function;

  const WiringRow({
    required this.sensor,
    required this.sensorPin,
    required this.piPin,
    required this.function,
  });

  factory WiringRow.fromJson(Map<String, dynamic> json) {
    return WiringRow(
      sensor: json['sensor']?.toString() ?? '',
      sensorPin: json['sensor_pin']?.toString() ?? '',
      piPin: json['pi_pin']?.toString() ?? '-',
      function: json['function']?.toString() ?? '',
    );
  }
}

class HardwareDiagram {
  /// PNG bytes of the Fritzing breadboard render.
  final List<int> pngBytes;
  final String svg;
  final String fzzPath;
  final List<WiringRow> wiringTable;
  final List<String> warnings;
  final String runId;

  const HardwareDiagram({
    required this.pngBytes,
    required this.svg,
    required this.fzzPath,
    required this.wiringTable,
    required this.warnings,
    required this.runId,
  });

  factory HardwareDiagram.fromJson(Map<String, dynamic> json) {
    final ir = (json['ir'] as Map?)?.cast<String, dynamic>() ?? {};
    final warns = (ir['warnings_from_code'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];
    return HardwareDiagram(
      pngBytes: base64Decode(json['png_base64'] as String),
      svg: json['svg']?.toString() ?? '',
      fzzPath: json['fzz']?.toString() ?? '',
      wiringTable: (json['wiring_table'] as List? ?? [])
          .map((e) => WiringRow.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      warnings: warns,
      runId: json['run_id']?.toString() ?? '',
    );
  }
}

class DiscoveredDevice {
  final String ip;
  final int port;
  final String name;
  final String method;
  final String? mac;

  DiscoveredDevice({
    required this.ip,
    required this.port,
    required this.name,
    required this.method,
    this.mac,
  });

  factory DiscoveredDevice.fromJson(Map<String, dynamic> json) {
    return DiscoveredDevice(
      ip: json['ip'] as String,
      port: json['port'] as int,
      name: json['name'] as String,
      method: json['method'] as String,
      mac: json['mac'] as String?,
    );
  }
}

class DeployResult {
  final bool success;
  final String deviceId;
  final String message;
  final List<String> logs;
  final String deployedAt;

  DeployResult({
    required this.success,
    required this.deviceId,
    required this.message,
    required this.logs,
    required this.deployedAt,
  });

  factory DeployResult.fromJson(Map<String, dynamic> json) {
    return DeployResult(
      success: json['success'] as bool,
      deviceId: json['device_id'] as String,
      message: json['message'] as String,
      logs: (json['logs'] as List).map((e) => e.toString()).toList(),
      deployedAt: json['deployed_at'] as String,
    );
  }
}
