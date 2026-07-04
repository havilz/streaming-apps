import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:streaming_mobile/core/core.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;
  late final Animation<double> _letterSpacingAnimation;
  late final Animation<double> _glowAnimation;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _audioPlayed = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _scaleAnimation = Tween<double>(begin: 0.3, end: 1.1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    _letterSpacingAnimation = Tween<double>(begin: 24.0, end: 3.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.8, curve: Curves.easeOutExpo),
      ),
    );

    _glowAnimation = Tween<double>(begin: 0.0, end: 30.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeInOut),
      ),
    );

    _playIntroSoundAndAnimate();
  }

  Future<void> _playIntroSoundAndAnimate() async {
    try {
      if (!_audioPlayed) {
        _audioPlayed = true;
        await _audioPlayer.play(AssetSource('sounds/Netflix intro - QuickSounds.com.mp3'));
      }
    } catch (e) {
      debugPrint("Failed to play splash sound: $e");
    }

    _controller.forward();

    // After 3.5 seconds total, transition to Home screen
    Timer(const Duration(milliseconds: 3500), () {
      if (mounted) {
        context.go('/');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(
                opacity: _opacityAnimation.value,
                child: Text(
                  'Sv',
                  style: AppTypography.logo.copyWith(
                    color: AppColors.primary,
                    fontSize: 100,
                    fontWeight: FontWeight.w900,
                    letterSpacing: _letterSpacingAnimation.value,
                    shadows: [
                      Shadow(
                        color: AppColors.primary.withValues(alpha: 0.6),
                        blurRadius: _glowAnimation.value,
                        offset: Offset.zero,
                      ),
                      Shadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: _glowAnimation.value * 2,
                        offset: Offset.zero,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
