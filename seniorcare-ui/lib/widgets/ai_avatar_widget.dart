import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AIAvatarWidget extends StatefulWidget {
  final double size;
  final bool pulsing;

  const AIAvatarWidget({
    super.key,
    required this.size,
    this.pulsing = false,
  });

  @override
  State<AIAvatarWidget> createState() => _AIAvatarWidgetState();
}

class _AIAvatarWidgetState extends State<AIAvatarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 12).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.pulsing) _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, child) => Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.aiActionBg,
          border: Border.all(color: AppColors.brandPrimary, width: 2),
          boxShadow: widget.pulsing
              ? [
                  BoxShadow(
                    color: AppColors.brandPrimary.withValues(alpha: 0.4),
                    blurRadius: _animation.value,
                    spreadRadius: _animation.value / 2,
                  )
                ]
              : [],
        ),
        child: Center(
          child: Text(
            'AI',
            style: TextStyle(
              color: AppColors.brandPrimary,
              fontWeight: FontWeight.bold,
              fontSize: widget.size * 0.25,
            ),
          ),
        ),
      ),
    );
  }
}
