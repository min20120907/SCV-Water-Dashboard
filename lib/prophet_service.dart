import 'dart:convert';
import 'package:http/http.dart' as http;

/// Client for the Prophet prediction service.
/// Replaces Gemini-based curve prediction with proper time-series forecasting.
class ProphetService {
  final String baseUrl;

  ProphetService({this.baseUrl = 'http://localhost:8766'});

  /// Fetch historical readings from Firestore and get Prophet forecast.
  /// 
  /// [readings] — list of {"timestamp": epoch_ms, "value": double}
  /// [horizonHours] — how many hours ahead to predict (default 24)
  /// [intervalMinutes] — aggregation bucket size (default 60)
  Future<ProphetForecast> predict({
    required String deviceId,
    required List<Map<String, dynamic>> readings,
    int horizonHours = 24,
    int intervalMinutes = 60,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/predict'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'device_id': deviceId,
        'readings': readings,
        'horizon_hours': horizonHours,
        'interval_minutes': intervalMinutes,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Prophet predict failed: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return ProphetForecast.fromJson(data);
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
}

/// Response from the Prophet service.
class ProphetForecast {
  final String deviceId;
  final List<ForecastPoint> forecast;
  final ModelInfo modelInfo;

  ProphetForecast({
    required this.deviceId,
    required this.forecast,
    required this.modelInfo,
  });

  factory ProphetForecast.fromJson(Map<String, dynamic> json) {
    return ProphetForecast(
      deviceId: json['device_id'] as String,
      forecast: (json['forecast'] as List)
          .map((e) => ForecastPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      modelInfo: ModelInfo.fromJson(json['model_info'] as Map<String, dynamic>),
    );
  }
}

class ForecastPoint {
  final int timestamp; // epoch ms
  final double yhat;
  final double yhatLower;
  final double yhatUpper;

  ForecastPoint({
    required this.timestamp,
    required this.yhat,
    required this.yhatLower,
    required this.yhatUpper,
  });

  factory ForecastPoint.fromJson(Map<String, dynamic> json) {
    return ForecastPoint(
      timestamp: json['timestamp'] as int,
      yhat: (json['yhat'] as num).toDouble(),
      yhatLower: (json['yhat_lower'] as num).toDouble(),
      yhatUpper: (json['yhat_upper'] as num).toDouble(),
    );
  }
}

class ModelInfo {
  final int trainingPoints;
  final int intervalMinutes;
  final int horizonHours;
  final int lastTrainingTs;

  ModelInfo({
    required this.trainingPoints,
    required this.intervalMinutes,
    required this.horizonHours,
    required this.lastTrainingTs,
  });

  factory ModelInfo.fromJson(Map<String, dynamic> json) {
    return ModelInfo(
      trainingPoints: json['training_points'] as int,
      intervalMinutes: json['interval_minutes'] as int,
      horizonHours: json['horizon_hours'] as int,
      lastTrainingTs: json['last_training_ts'] as int,
    );
  }
}
