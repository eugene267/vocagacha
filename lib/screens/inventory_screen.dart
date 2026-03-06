import 'package:flutter/material.dart';
import '../models/word_model.dart';
import '../services/db_service.dart';
import '../gemini_service.dart';

class InventoryScreen extends StatelessWidget {
  final String testUid;
  final DbService dbService;
  final GeminiService _geminiService = GeminiService();

  InventoryScreen({super.key, required this.testUid, required this.dbService});

  void _claimReward(BuildContext context, String docId) async {
    final success = await dbService.claimReward(testUid, docId);
    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("🎉 암기 완료! 보상으로 1코인을 얻었습니다.")),
      );
    }
  }

  void _startRandomMemorization(BuildContext context) async {
    final word = await dbService.getRandomUnmemorizedWord(testUid);
    if (!context.mounted) return;

    if (word == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("외울 단어가 없거나 이미 모두 암기했습니다.")));
      return;
    }

    final meanController = TextEditingController();
    final exampleController = TextEditingController();
    bool isChecking = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text("단어 암기: ${word.word}"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "단어의 뜻과 예문을 입력해주세요.",
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: meanController,
                    decoration: const InputDecoration(
                      labelText: "뜻",
                      hintText: "예: 사과",
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: exampleController,
                    decoration: const InputDecoration(
                      labelText: "예문",
                      hintText: "단어를 사용한 문장 입력",
                    ),
                  ),
                  if (isChecking) ...[
                    const SizedBox(height: 16),
                    const CircularProgressIndicator(),
                    const SizedBox(height: 8),
                    const Text("Gemini가 채점 중..."),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isChecking ? null : () => Navigator.pop(context),
                  child: const Text("취소"),
                ),
                ElevatedButton(
                  onPressed: isChecking
                      ? null
                      : () async {
                          if (meanController.text.trim().isEmpty ||
                              exampleController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("뜻과 예문을 모두 입력해주세요."),
                              ),
                            );
                            return;
                          }

                          setState(() => isChecking = true);

                          try {
                            final result = await _geminiService
                                .validateMemorization(
                                  word.word,
                                  word.mean,
                                  meanController.text.trim(),
                                  exampleController.text.trim(),
                                );

                            if (!context.mounted) return;

                            if (result['isValid'] == true) {
                              Navigator.pop(context);
                              _claimReward(context, word.id);
                            } else {
                              setState(() => isChecking = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("오답입니다: ${result['reason']}"),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } catch (e) {
                            if (!context.mounted) return;
                            setState(() => isChecking = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("오류가 발생했습니다: $e")),
                            );
                          }
                        },
                  child: const Text("제출"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: () => _startRandomMemorization(context),
            icon: const Icon(Icons.psychology),
            label: const Text("랜덤 단어 암기하기"),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<WordResult>>(
            stream: dbService.getInventoryStream(testUid),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final words = snapshot.data!;
              if (words.isEmpty) {
                return const Center(child: Text("아직 뽑은 단어가 없습니다.\n가챠를 돌려보세요!"));
              }

              return ListView.builder(
                itemCount: words.length,
                itemBuilder: (context, index) {
                  final wordData = words[index];
                  return ListTile(
                    leading: CircleAvatar(child: Text(wordData.grade)),
                    title: Text(
                      wordData.word,
                      style: TextStyle(
                        decoration: wordData.isMemorized
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    subtitle: Text(wordData.mean),
                    trailing: wordData.isMemorized
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const Icon(Icons.lock_outline, color: Colors.grey),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
