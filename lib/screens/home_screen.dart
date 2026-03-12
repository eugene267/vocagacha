import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/db_service.dart';
import '../widgets/gacha_animation_screen.dart';

class HomeScreen extends StatefulWidget {
  final String uid;
  final DbService dbService;
  final int tokens;
  final VoidCallback onLoadingStart;
  final VoidCallback onLoadingEnd;
  final bool isLoading;

  const HomeScreen({
    super.key,
    required this.uid,
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
      final result = await widget.dbService.performGacha(widget.uid);

      if (!mounted) return;

      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("🎊 모든 단어를 수집하셨습니다! 더 이상 뽑을 단어가 없어요.")),
        );
      } else {
        HapticFeedback.heavyImpact();
        _showResultAnimation(result.word, result.mean, result.grade);
      }
    } catch (e) {
      // 에러 처리는 DbService 로깅에 의존하거나 별도 알림
    } finally {
      widget.onLoadingEnd();
    }
  }

  void _showResultAnimation(String word, String mean, String grade) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false, // 팝업처럼 배경이 보이게
        barrierDismissible: true,
        transitionDuration: Duration.zero, // GachaAnimationScreen 내부에서 애니메이션 처리
        pageBuilder: (context, _, _) =>
            GachaAnimationScreen(word: word, mean: mean, grade: grade),
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
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
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
