// lib/gemini_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

/// 這是我們的客製化 AI Bot 服務。
/// 它在啟動時會載入 "知識庫" (systemInstruction)。
class GeminiService {
  late final GenerativeModel _model;
  late final GenerativeModel _schemaModel;
  final String _apiKey;

  GeminiService() : _apiKey = dotenv.env['GEMINI_API_KEY']!.trim() {
    // 1. 從 .env 讀取 API 金鑰
    final apiKey = _apiKey;

    // 2. 這是您的「完整版知識庫」
    // (來自您 PDF 的 9 個情境)
    final systemInstruction = Content.system("""
      你是一個專業的「家庭節水顧問 App 助手」。
      你的核心目標是：
      1. 監控用戶的即時和歷史用水量。
      2. 分析使用模式以識別浪費和低效率。
      3. 你的回答必須使用「繁體中文」。

      你的分析必須基於以下 "知識庫" (來自一份台灣四口之家的文件)。
      這是所有 9 種情境的「平均每日用量 (L/天)」：

      1. 基準 (Baseline):
         - 總計: 1114.4
         - 馬桶: 263.9, 淋浴: 232.0, 廚房: 209.3, 洗衣: 185.6, 植物: 61.4, 其他: 162.4

      2. 夏天 (Summer - Hot & Dry):
         - 馬桶: 262.9, 淋浴: 278.4, 廚房: 203.9, 洗衣: 186.3, 植物: 116.4, 其他: 175.0

      3. 季風 (Monsoon - Humid):
         - 總計: 1086.9
         - 馬桶: 254.3, 淋浴: 229.0, 廚房: 197.1, 洗衣: 232.4, 植物: 21.6, 其他: 152.4

      4. 乾旱限制 (Drought restrictions):
         - 總計: 980.4
         - 馬桶: 249.4, 淋浴: 211.0, 廚房: 191.0, 洗衣: 172.0, 植物: 6.3, 其他: 150.7

      5. 假期客人 (Holiday guests):
         - 總計: 1384.4
         - 馬桶: 295.0, 淋浴: 293.7, 廚房: 280.0, 洗衣: 272.3, 植物: 51.4, 其他: 192.0

      6. 寒冬 (Cold winter):
         - 馬桶: 252.7, 淋浴: 148.9, 廚房: 191.6, 洗衣: 173.3, 植物: 51.1, 其他: 150.0

      7. 假期 - 全家外出 (Vacation):
         - 總計: 467.9
         - 馬桶: 108.9, 淋浴: 99.7, 廚房: 91.1, 洗衣: 83.4, 植物: 30.3, 其他: 54.4

      8. 節日烹飪 (Festival cooking CNY):
         - 總計: 1305.9
         - 馬桶: 255.7, 淋浴: 241.3, 廚房: 363.4, 洗衣: 187.3, 植物: 52.1, 其他: 206.0

      9. 理想目標 (Water-efficiency push):
         - 總計: 801.7
         - 馬桶: 197.0, 淋浴: 165.0, 廚房: 152.1, 洗衣: 139.6, 植物: 25.0, 其他: 123.0

      你的任務是擔任一個 Q&A 助理。
      用戶會提供他們的「問題」和他們的「原始用水數據」。
      你必須使用你的 "知識庫" (上述 9 種情境) 來分析他們的 "原始用水數據"，並回答他們的 "問題"。
      例如，如果用戶的用量接近 1300L，你應該將其與「假期客人」 或「節日烹飪」 進行比較，而不僅僅是「基準」。
      """);

    // 3. 建立 Gemini Bot (模型)
    _model = GenerativeModel(
      // 主要問答改用 1.5-pro，避開新專案可能的 2.x 配額限制
      model: 'gemini-1.5-pro',
      apiKey: apiKey,
      generationConfig: GenerationConfig(temperature: 0.5),

      // *** 這裡是修正的地方 ***
      safetySettings: [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
      ],

      systemInstruction: systemInstruction, // <-- 注入您的「完整版知識庫」
    );

    // 4. 規格解析專用模型 (JSON 模式)
    _schemaModel = GenerativeModel(
      // Schema 解析用 1.5-flash，成本低且通常可用性更穩定
      model: 'gemini-1.5-flash',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(responseMimeType: 'application/json'),
      systemInstruction: Content.system("""
        You are an IoT Sensor Expert. Convert the user's sensor description or manual into a JSON Schema.
        Output MUST be a valid JSON object with this structure:
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
      """),
    );
  }

  /// 呼叫 Gemini AI 來分析數據並回答問題
  Future<String> ask(String query, String dataContext) async {
    try {
      // 建立聊天 session
      final chat = _model.startChat();

      // 將問題和數據一起發送給 AI
      final response = await chat.sendMessage(
        Content.text("""
        這是我的問題:
        "$query"

        這是我近期的原始用水數據 (格式: Timestamp, Location, Amount (mL)):
        $dataContext
        """),
      );

      // 返回 AI 的文字回答
      final text = response.text;
      if (text == null) {
        return "AI 沒有返回文字回應，請重試。";
      }
      return text;
    } catch (e) {
      // 處理 API 錯誤
      debugPrint("Gemini API Error: $e");
      return "AI 助理連線失敗: $e";
    }
  }

  Future<String> identifySensorSchema(String manualText) async {
    try {
      final response = await _schemaModel.generateContent([
        Content.text("Sensor Description:\n$manualText"),
      ]);
      return response.text ?? "{}";
    } catch (e) {
      debugPrint("Schema Generation Error: $e");
      return '{"error": "$e"}';
    }
  }
}
