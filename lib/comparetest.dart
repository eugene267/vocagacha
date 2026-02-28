import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final String _testUid = "test_user_01";
  int _tokens = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_testUid);
    final doc = await userRef.get();
    if (!doc.exists) {
      await userRef.set({'tokens': 10});
    }
    userRef.snapshots().listen((snapshot) {
      if (snapshot.exists && mounted) {
        setState(() => _tokens = snapshot.data()?['tokens'] ?? 0);
      }
    });
  }

  // --- 가챠 로직 ---
  void _onGachaPressed() async {
    if (_tokens <= 0) return;
    setState(() => _isLoading = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final allWordsSnapshot = await firestore.collection('all_words').get();
      if (allWordsSnapshot.docs.isEmpty) throw "DB에 단어가 없습니다.";

      final randomDoc = (allWordsSnapshot.docs..shuffle()).first;
      final wordData = randomDoc.data();

      await firestore.runTransaction((transaction) async {
        final userRef = firestore.collection('users').doc(_testUid);
        final userSnap = await transaction.get(userRef);
        int currentTokens = userSnap.get('tokens');

        if (currentTokens > 0) {
          transaction.update(userRef, {'tokens': currentTokens - 1});
          final inventoryRef = userRef.collection('inventory').doc();
          transaction.set(inventoryRef, {
            ...wordData,
            'isMemorized': false,
            'pickedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      _showResultDialog(wordData['word'], wordData['mean'], wordData['grade']);
    } catch (e) {
      print("❌ 가챠 실패: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 암기 완료 보상 로직 ---
  Future<void> _claimReward(String docId) async {
    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(_testUid);
    final wordRef = userRef.collection('inventory').doc(docId);

    await firestore.runTransaction((transaction) async {
      final userSnap = await transaction.get(userRef);
      final wordSnap = await transaction.get(wordRef);
      bool isMemorized = wordSnap.get('isMemorized') ?? false;
      int currentTokens = userSnap.get('tokens');

      if (isMemorized) return; // 이미 받은 경우 제외

      // 1. 단어 상태를 '암기 완료'로 변경
      transaction.update(wordRef, {'isMemorized': true});
      // 2. 보상으로 토큰 1개 지급
      transaction.update(userRef, {'tokens': currentTokens + 1});
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("🎉 암기 완료! 보상으로 1코인을 얻었습니다.")),
      );
    }
  }

  void _showResultDialog(String word, String mean, String grade) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("🎉 $grade 등급 획득!"),
        content: Text("$word: $mean"),
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Vocacha'),
          backgroundColor: Colors.amber,
          bottom: const TabBar(
            tabs: [
              Tab(text: "가챠", icon: Icon(Icons.casino)),
              Tab(text: "인벤토리", icon: Icon(Icons.inventory)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // 1번 탭: 가챠 화면
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("보유 토큰", style: TextStyle(fontSize: 16)),
                  Text(
                    "$_tokens",
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 40),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _tokens > 0 ? _onGachaPressed : null,
                          child: const Text('가챠 돌리기 (1코인)'),
                        ),
                ],
              ),
            ),
            // 2번 탭: 인벤토리 리스트
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(_testUid)
                  .collection('inventory')
                  .orderBy('pickedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final bool isMemorized = data['isMemorized'] ?? false;
                    return ListTile(
                      leading: CircleAvatar(child: Text(data['grade'])),
                      title: Text(
                        data['word'],
                        style: TextStyle(
                          decoration: isMemorized
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      subtitle: Text(data['mean']),
                      trailing: isMemorized
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : ElevatedButton(
                              onPressed: () => _claimReward(docs[index].id),
                              child: const Text("암기!"),
                            ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
