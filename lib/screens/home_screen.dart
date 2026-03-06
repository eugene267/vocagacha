import 'package:flutter/material.dart';
import '../services/db_service.dart';

class HomeScreen extends StatefulWidget {
  final String testUid;
  final DbService dbService;
  final int tokens;
  final VoidCallback onLoadingStart;
  final VoidCallback onLoadingEnd;
  final bool isLoading;

  const HomeScreen({
    super.key,
    required this.testUid,
    required this.dbService,
    required this.tokens,
    required this.onLoadingStart,
    required this.onLoadingEnd,
    required this.isLoading,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  void _onGachaPressed() async {
    if (widget.tokens <= 0) return;
    widget.onLoadingStart();

    try {
      final result = await widget.dbService.performGacha(widget.testUid);
      
      if (!mounted) return;

      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("🎊 모든 단어를 수집하셨습니다! 더 이상 뽑을 단어가 없어요."),
          ),
        );
      } else {
        _showResultDialog(result.word, result.mean, result.grade);
      }
    } catch (e) {
      // 에러 처리는 DbService 로깅에 의존하거나 별도 알림
    } finally {
      widget.onLoadingEnd();
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("보유 토큰", style: TextStyle(fontSize: 16)),
          Text(
            "${widget.tokens}",
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 40),
          widget.isLoading
              ? const CircularProgressIndicator()
              : ElevatedButton(
                  onPressed: widget.tokens > 0 ? _onGachaPressed : null,
                  child: const Text('가챠 돌리기 (1코인)'),
                ),
        ],
      ),
    );
  }
}
