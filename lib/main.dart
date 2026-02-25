import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore 추가
import 'firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    const MaterialApp(home: VocachaTest(), debugShowCheckedModeBanner: false),
  );
}

class VocachaTest extends StatefulWidget {
  const VocachaTest({super.key});

  @override
  State<VocachaTest> createState() => _VocachaTestState();
}

class _VocachaTestState extends State<VocachaTest> {
  final String _testUid = "test_user_01"; // 테스트용 고정 UID
  int _tokens = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  // 1. 유저 초기화 및 토큰 실시간 리스너
  Future<void> _initializeUser() async {
    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_testUid);
    final doc = await userRef.get();

    if (!doc.exists) {
      // 신규 유저일 경우 10토큰 지급
      await userRef.set({'tokens': 10});
    }

    // 토큰 변화 실시간 감시
    userRef.snapshots().listen((snapshot) {
      if (snapshot.exists && mounted) {
        setState(() {
          _tokens = snapshot.data()?['tokens'] ?? 0;
        });
      }
    });
  }

  // 2. 가챠 핵심 엔진 (랜덤 추출 + 트랜잭션)
  void _onGachaPressed() async {
    if (_tokens <= 0) return;

    setState(() => _isLoading = true);

    try {
      final firestore = FirebaseFirestore.instance;

      // (1) 전체 단어 목록 가져오기
      final allWordsSnapshot = await firestore.collection('all_words').get();
      if (allWordsSnapshot.docs.isEmpty) throw "DB에 단어가 없습니다.";

      // (2) 클라이언트 측 랜덤 선택
      final randomDoc = (allWordsSnapshot.docs..shuffle()).first;
      final wordData = randomDoc.data();

      // (3) 트랜잭션: 토큰 차감 및 인벤토리 저장
      await firestore.runTransaction((transaction) async {
        final userRef = firestore.collection('users').doc(_testUid);
        final userSnap = await transaction.get(userRef);

        int currentTokens = userSnap.get('tokens');
        if (currentTokens > 0) {
          // 토큰 1개 차감
          transaction.update(userRef, {'tokens': currentTokens - 1});

          // 유저 인벤토리에 추가
          final inventoryRef = userRef.collection('inventory').doc();
          transaction.set(inventoryRef, {
            'word': wordData['word'],
            'mean': wordData['mean'],
            'grade': wordData['grade'],
            'isMemorized': false,
            'pickedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      // (4) 결과 팝업 띄우기
      if (mounted) {
        _showResultDialog(
          wordData['word'],
          wordData['mean'],
          wordData['grade'],
        );
      }
    } catch (e) {
      print("❌ 가챠 실패: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 3. 결과 알림창
  void _showResultDialog(String word, String mean, String grade) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("🎉 $grade 등급 획득!"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              word,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            Text(mean, style: const TextStyle(fontSize: 18)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("확인"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('보카차(Vocacha)'),
        backgroundColor: Colors.amber,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("보유 토큰", style: TextStyle(fontSize: 16)),
            Text(
              "$_tokens",
              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 20,
                      ),
                      backgroundColor: Colors.amber,
                    ),
                    onPressed: _tokens > 0 ? _onGachaPressed : null,
                    child: const Text(
                      '가챠 돌리기 (1코인)',
                      style: TextStyle(fontSize: 20, color: Colors.black),
                    ),
                  ),
            if (_tokens == 0 && !_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: Text("토큰이 부족합니다!", style: TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }
}
