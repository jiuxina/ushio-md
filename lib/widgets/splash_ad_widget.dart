import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/constants.dart';

/// 开屏广告倒计时组件
///
/// 全屏展示广告图片占位，右上角显示「跳过 N秒」倒计时按钮，
/// 倒计时结束或用户点击跳过时触发 [onDismiss] 回调。
class SplashAdWidget extends StatefulWidget {
  /// 倒计时结束或用户跳过时的回调
  final VoidCallback onDismiss;

  /// 倒计时秒数，默认 5 秒
  final int countdownSeconds;

  const SplashAdWidget({
    super.key,
    required this.onDismiss,
    this.countdownSeconds = 5,
  });

  @override
  State<SplashAdWidget> createState() => _SplashAdWidgetState();
}

class _SplashAdWidgetState extends State<SplashAdWidget> {
  late int _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.countdownSeconds;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _remaining--);
      if (_remaining <= 0) {
        timer.cancel();
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppConstants.primaryColor,
            AppConstants.primaryDark,
            Color(0xFF7C3AED),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Ad image placeholder
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.school_rounded, size: 80, color: Colors.white),
                const SizedBox(height: 16),
                Text(
                  AppConstants.appName,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppConstants.appDescription,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),

          // Skip button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: GestureDetector(
              onTap: () {
                _timer?.cancel();
                widget.onDismiss();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '跳过 ${_remaining}秒',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
