import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiService {
  final String _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  late final GenerativeModel _model;

  GeminiService() {
    if (_apiKey.isEmpty) {
      throw Exception("GEMINI_API_KEY is not set in .env file");
    }
    _model = GenerativeModel(
      model: 'gemini-3-flash-preview',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(responseMimeType: 'application/json'),
    );
  }

  Future<Map<String, dynamic>> validateMemorization(
    String word,
    String expectedMean,
    String userMean,
    String userExample,
  ) async {
    final prompt =
        """
      너는 영단어 학습을 도와주는 엄격한 영어 선생님이야.
      학생이 제시된 영단어의 뜻과 그 단어를 사용한 예문을 제출했어.
      이 제출 답안이 올바른지 평가해줘.

      [단어 정보]
      - 영단어: $word
      - DB에 저장된 뜻: $expectedMean

      [학생 제출 답안]
      - 제출한 뜻: $userMean
      - 제출한 예문: $userExample

      평가 기준:
      1. '제출한 뜻'이 'DB에 저장된 뜻'과 의미상 일치하거나, 해당 영단어의 실제 뜻으로 인정할 수 있는지 평가해.
      2. '제출한 예문'이 문법적으로 올바른지, 그리고 해당 영단어('$word')가 올바른 의미와 품사로 자연스럽게 사용되었는지 평가해. (단어의 형태 변화는 허용됨)

      응답은 반드시 아래의 JSON 형식으로만 해줘. 다른 설명은 하지마.
      {
        "isValid": true 또는 false,
        "reason": "평가 결과에 대한 짧은 피드백 (한국어, 1~2문장)"
      }
    """;

    final response = await _model.generateContent([Content.text(prompt)]);

    try {
      return jsonDecode(response.text!);
    } catch (e) {
      return {"isValid": false, "reason": "AI 응답을 처리하는데 실패했습니다. 다시 시도해주세요."};
    }
  }
}
