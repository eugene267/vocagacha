import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'gemini_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MaterialApp(home: VocachaTest()));
}

class VocachaTest extends StatefulWidget {
  const VocachaTest({super.key});

  @override
  State<VocachaTest> createState() => _VocachaTestState();
}

class _VocachaTestState extends State<VocachaTest> {
  final GeminiService _gemini = GeminiService();
  bool _isLoading = false;

  void _onGachaPressed() async {
    setState(() => _isLoading = true);

    try {
      // S등급 단어를 하나 뽑아보자!
      final result = await _gemini.drawWordCard("S");
      print("🎉 가챠 성공: $result");
    } catch (e) {
      print("❌ 가챠 실패: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('보카차 AI 테스트')),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : ElevatedButton(
                onPressed: _onGachaPressed,
                child: const Text('S등급 단어 뽑기!'),
              ),
      ),
    );
  }
}
