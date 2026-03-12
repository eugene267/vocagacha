import 'package:flutter/material.dart';

class GachaAnimationScreen extends StatefulWidget {
  final String word;
  final String mean;
  final String grade;

  const GachaAnimationScreen({
    super.key,
    required this.word,
    required this.mean,
    required this.grade,
  });

  @override
  State<GachaAnimationScreen> createState() => _GachaAnimationScreenState();
}

class _GachaAnimationScreenState extends State<GachaAnimationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // SSS grade gets a slightly longer, more dramatic intro
    final duration = widget.grade == 'SSS'
        ? const Duration(milliseconds: 1500)
        : const Duration(milliseconds: 1000);

    _controller = AnimationController(vsync: this, duration: duration);

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getGradeColor() {
    switch (widget.grade) {
      case 'SSS':
        return Colors.redAccent.shade400;
      case 'S':
        return Colors.orangeAccent.shade400;
      case 'A':
        return Colors.purpleAccent.shade400;
      case 'B':
      default:
        return Colors.blueGrey;
    }
  }

  List<BoxShadow> _getGradeShadow() {
    final color = _getGradeColor();
    switch (widget.grade) {
      case 'SSS':
        return [
          BoxShadow(
            color: color.withOpacity(0.8),
            blurRadius: 40,
            spreadRadius: 10,
          ),
          BoxShadow(
            color: Colors.yellowAccent.withOpacity(0.5),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ];
      case 'S':
        return [
          BoxShadow(
            color: color.withOpacity(0.6),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ];
      case 'A':
        return [
          BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ];
      case 'B':
      default:
        return [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(), // Tap anywhere to dismiss
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 50,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: _getGradeShadow(),
                      border: widget.grade == 'SSS' || widget.grade == 'S'
                          ? Border.all(color: _getGradeColor(), width: 3)
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.grade,
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: _getGradeColor(),
                            shadows: [
                              Shadow(
                                color: _getGradeColor().withOpacity(0.5),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          widget.word,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.mean,
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.grey.shade700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 30),
                        Text(
                          "화면을 터치해서 닫기",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
