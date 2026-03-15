import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CallTimerWidget extends StatefulWidget {
  const CallTimerWidget({super.key});

  @override
  State<CallTimerWidget> createState() => _CallTimerWidgetState();
}

class _CallTimerWidgetState extends State<CallTimerWidget> {
  late Timer _timer;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _seconds++);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String get _formatted {
    final m = _seconds ~/ 60;
    final s = _seconds % 60;
    return 'SeniorCare AI \u2014 $m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _formatted,
      style: AppTextStyles.seniorLabel.copyWith(fontWeight: FontWeight.w500),
    );
  }
}
