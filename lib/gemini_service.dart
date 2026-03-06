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

  Future<Map<String, dynamic>> drawWordCard(String grade) async {
    // 제미나이에게 내릴 정교한 명령서 (프롬프트)
    final prompt =
        """
      너는 영어 교육 전문가이자 가챠 게임 설계자야.
      영어 단어 등급 [$grade]에 맞는 단어 1개를 추천해줘.
      
      등급 기준:
      - B: 중학생 수준의 기초 단어
      - A: 고등학생 수준의 필수 단어
      - S: 토익/학술 수준의 어려운 단어
      - SSS: 원어민도 어려워하는 매우 희귀한 전문 단어

      응답은 반드시 아래의 JSON 형식으로만 해줘. 다른 설명은 하지마.
      {
        "word": "단어",
        "mean": "뜻",
        "grade": "$grade",
        "example": "해당 단어가 사용된 짧은 영어 예문"
      }

      제약 조건:
      - 단어는 전부 소문자로 해줘.
    """;

    final response = await _model.generateContent([Content.text(prompt)]);

    try {
      return jsonDecode(response.text!);
    } catch (e) {
      throw Exception("AI가 이상한 데이터를 보냈어요: ${response.text}");
    }
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
