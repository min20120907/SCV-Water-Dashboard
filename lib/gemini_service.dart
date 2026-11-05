// lib/gemini_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// SCV Water AI 助理與感測器分析服務。
/// 改接本機 FastMTP (:8088 Qwen3.8-27B Uncensored MTP)，免除外部配額與連線限制。
class GeminiService {
  static const String _endpoint = 'http://127.0.0.1:8088/v1/chat/completions';
  static const String _model = 'qwen3.8-27b-fastmtp';

  static const String _knowledgeBase = '''
你是一個專業的「家庭節水顧問 App 助手」。
你的核心目標是：
1. 監控用戶的即時和歷史用水量。
2. 分析使用模式以識別浪費和低效率。
3. 你的回答必須使用「繁體中文」。

你的分析必須基於以下 "知識庫" (來自一份台灣四口之家的文件)。
這是所有 9 種情境的「平均每日用量 (L/天)」：
1. 基準 (Baseline): 總計 1114.4 (馬桶: 263.9, 淋浴: 232.0, 廚房: 209.3, 洗衣: 185.6, 植物: 61.4, 其他: 162.4)
2. 夏天 (Summer - Hot & Dry): 馬桶: 262.9, 淋浴: 278.4, 廚房: 203.9, 洗衣: 186.3, 植物: 116.4, 其他: 175.0
3. 季風 (Monsoon - Humid): 總計 1086.9 (馬桶: 254.3, 淋浴: 229.0, 廚房: 197.1, 洗衣: 232.4, 植物: 21.6, 其他: 152.4)
4. 乾旱限制 (Drought restrictions): 總計 980.4 (馬桶: 249.4, 淋浴: 211.0, 廚房: 191.0, 洗衣: 172.0, 植物: 6.3, 其他: 150.7)
5. 假期客人 (Holiday guests): 總計 1384.4 (馬桶: 295.0, 淋浴: 293.7, 廚房: 280.0, 洗衣: 272.3, 植物: 51.4, 其他: 192.0)
6. 寒冬 (Cold winter): 馬桶: 252.7, 淋浴: 148.9, 廚房: 191.6, 洗衣: 173.3, 植物: 51.1, 其他: 150.0
7. 假期 - 全家外出 (Vacation): 總計 467.9 (馬桶: 108.9, 淋浴: 99.7, 廚房: 91.1, 洗衣: 83.4, 植物: 30.3, 其他: 54.4)
8. 節日烹飪 (Festival cooking CNY): 總計 1305.9 (馬桶: 255.7, 淋浴: 241.3, 廚房: 363.4, 洗衣: 187.3, 植物: 52.1, 其他: 206.0)
9. 理想目標 (Water-efficiency push): 總計 801.7 (馬桶: 197.0, 淋浴: 165.0, 廚房: 152.1, 洗衣: 139.6, 植物: 25.0, 其他: 123.0)
''';

  GeminiService();

  Future<String> _callModel({
    required String systemPrompt,
    required String userPrompt,
    double temperature = 0.2,
    int maxTokens = 1024,
  }) async {
    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': _model,
        'messages': [
          if (systemPrompt.isNotEmpty) {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
        'temperature': temperature,
        'max_tokens': maxTokens,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('LLM :8088 error: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) return '';
    var text = (choices.first['message']?['content'] as String?)?.trim() ?? '';

    // 去除 <think> 標籤與 markdown 程式碼區塊
    text = text.replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '').trim();
    final jsonMarker = String.fromCharCodes([96, 96, 96, 106, 115, 111, 110]);
    final codeMarker = String.fromCharCodes([96, 96, 96]);
    if (text.startsWith(jsonMarker)) {
      text = text.substring(jsonMarker.length);
      if (text.endsWith(codeMarker)) text = text.substring(0, text.length - codeMarker.length);
    } else if (text.startsWith(codeMarker)) {
      text = text.substring(codeMarker.length);
      if (text.endsWith(codeMarker)) text = text.substring(0, text.length - codeMarker.length);
    }
    return text.trim();
  }

  Future<String> getOptimizationTips(String dataContext) async {
    try {
      const prompt = '''
請根據提供的用水數據，給出 2-3 條「具體、專業且可執行」的節水優化建議。
需求：
1. 必須針對數據中顯示的異常（如：某項流量過高）給出建議。
2. 建議格式請包含：【標題】與【詳細說明】。
3. 如果數據正常，則給出預防性的維護建議。
4. 使用繁體中文。
''';
      return await ask(prompt, dataContext);
    } catch (e) {
      return "暫時無法產生優化建議：$e";
    }
  }

  Future<Map<String, String>> suggestIcon(String fieldKey) async {
    try {
      final prompt = '''
針對感測器欄位名稱 "$fieldKey"，請回傳一個最適合的圖示資訊。
回傳格式必須為 JSON，包含以下欄位：
1. "emoji": 一個單一 Emoji 圖示。
2. "icon_name": 一個適合的 FontAwesome 圖示名稱（例如: "faucet", "shower", "bath", "toilet", "droplet"）。
3. "description": 該欄位的簡短中文說明（2-4 字）。

範例：
{"emoji": "🚿", "icon_name": "shower", "description": "浴室淋浴"}
請只回傳純 JSON，不要任何解釋或多餘文字。
''';
      final text = await _callModel(
        systemPrompt: 'You are a UI icon expert. Return pure JSON only.',
        userPrompt: prompt,
        temperature: 0.1,
        maxTokens: 256,
      );
      final Map<String, dynamic> data = jsonDecode(text);
      return data.map((key, value) => MapEntry(key, value.toString()));
    } catch (_) {
      return {
        'emoji': '💧',
        'icon_name': 'droplet',
        'description': fieldKey,
      };
    }
  }

  Future<String> ask(String query, String dataContext) async {
    try {
      final userText = '''
這是我的問題:
"$query"

這是我近期的原始用水數據 (格式: Timestamp, Location, Amount (mL)):
$dataContext
''';
      final text = await _callModel(
        systemPrompt: _knowledgeBase,
        userPrompt: userText,
        temperature: 0.5,
        maxTokens: 1024,
      );
      return text.isNotEmpty ? text : "AI 沒有返回文字回應，請重試。";
    } catch (e) {
      debugPrint("FastMTP API Error: $e");
      return "AI 助理連線失敗: $e";
    }
  }

  Future<String> identifySensorSchema(String manualText) async {
    try {
      const sysPrompt = '''
You are an IoT Sensor Expert. Convert the user's sensor description or manual into a JSON Schema.
Output MUST be a valid JSON object only with this structure:
{
  "type_id": "DEVICE_TYPE_NAME",
  "fields": [
    {
      "key": "internal_variable_name",
      "label": "Human Readable Label",
      "unit": "Unit (e.g. mL/s, mg/L)",
      "data_type": "double or int",
      "min_threshold": null,
      "max_threshold": null
    }
  ]
}
If the user mentions 'SCV Emulator', always include keys: 'kitchen_flow', 'shower_flow', 'bathtub_flow', 'toilet_flow'.
Return ONLY valid JSON. No conversational text.
''';
      final text = await _callModel(
        systemPrompt: sysPrompt,
        userPrompt: 'Sensor Description:\n$manualText',
        temperature: 0.1,
        maxTokens: 512,
      );
      return text.isNotEmpty ? text : "{}";
    } catch (e) {
      final errorText = e.toString();
      debugPrint("Schema Generation Error: $errorText");
      return '{"error": "$errorText"}';
    }
  }

  Future<Map<String, dynamic>> generateHardwareGuide({
    required String sensorDescription,
    required String protocol,
    required Map<String, dynamic>? schema,
  }) async {
    try {
      final fields = schema?['fields'] as List<dynamic>? ?? [];
      final fieldSummary = fields
          .map((f) {
            final key = f['key']?.toString() ?? '';
            final label = f['label']?.toString() ?? '';
            final unit = f['unit']?.toString() ?? '';
            return '- $label ($key): $unit';
          })
          .join('\n');

      final userPrompt = '''
你是一位 IoT 硬體安裝工程師。請根據以下感測器規格，產生一份「繁體中文」的樹莓派安裝指南。

感測器描述：
$sensorDescription

通訊協定：$protocol

感測器欄位：
${fieldSummary.isEmpty ? '（無特定欄位）' : fieldSummary}

請以 JSON 格式回傳，結構如下：
{
  "title": "硬體安裝指南",
  "difficulty": "簡單|中等|困難",
  "estimated_time": "約 30 分鐘",
  "sections": [
    {
      "icon": "hardware",      "title": "所需硬體",
      "items": ["項目 1", "項目 2"]
    },
    {
      "icon": "wiring",
      "title": "接線方式",
      "items": ["步驟 1", "步驟 2"]
    }
  ],
  "tips": ["注意事項 1", "注意事項 2"]
}

重要：
1. 只需要「所需硬體」和「接線方式」兩個章節
2. 每個 section 的 items 要簡潔（每項 1-2 句話）
3. 不要使用 Markdown 格式，不要畫 ASCII 圖
4. 請只回傳純 JSON
''';

      final text = await _callModel(
        systemPrompt: 'You are an IoT hardware engineer. Output valid JSON only.',
        userPrompt: userPrompt,
        temperature: 0.2,
        maxTokens: 1024,
      );

      final data = jsonDecode(text) as Map<String, dynamic>;
      return data;
    } catch (e) {
      debugPrint('Hardware Guide Error: $e');
      return {
        'title': '硬體安裝指南',
        'difficulty': '中等',
        'estimated_time': '約 30 分鐘',
        'sections': [
          {
            'icon': 'hardware',
            'title': '所需硬體',
            'items': ['樹莓派 4B / Zero', '感測器模組', '杜邦線'],
          },
          {
            'icon': 'wiring',
            'title': '接線方式',
            'items': ['請依感測器腳位 (VCC/GND/GPIO) 對照連接'],
          },
        ],
        'tips': ['請確認接線正確後再通電'],
      };
    }
  }

  Future<String> generateSiteDescription({
    required String siteName,
    required String prompt,
  }) async {
    try {
      final userPrompt = '''
請用繁體中文，為以下場域產生 2-4 句精簡敘述，內容包含場域用途、常見用水情境、建議監控重點。

場域名稱: $siteName
使用者補充: $prompt
''';
      final text = await _callModel(
        systemPrompt: 'You are an environmental IoT consultant. Output Traditional Chinese only.',
        userPrompt: userPrompt,
        temperature: 0.4,
        maxTokens: 256,
      );
      return text.isNotEmpty
          ? text
          : '此場域主要用於日常活動，建議優先監控主要用水設備的尖峰時段與異常流量。';
    } catch (e) {
      debugPrint("Site Description Error: $e");
      return '此場域主要用於日常活動，建議優先監控主要用水設備的尖峰時段與異常流量。';
    }
  }
}
