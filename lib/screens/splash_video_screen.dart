// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System (Jalsah)
// File: lib/screens/splash_video_screen.dart
// Screen: Fullscreen Splash Video Screen with Skip Action & Web Autoplay Support
// Master Reference: Rule 20 (Frontend), Jalsah Branding
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../services/api_client.dart';
import '../theme/app_colors.dart';
import 'dashboard_screen.dart';
import 'onboarding_screen.dart';
import 'temp_login_screen.dart';

class SplashVideoScreen extends StatefulWidget {
  final Widget? nextScreenOverride;
  final VideoPlayerController? controllerOverride;
  final Duration skipButtonDelay;

  const SplashVideoScreen({
    super.key,
    this.nextScreenOverride,
    this.controllerOverride,
    this.skipButtonDelay = const Duration(seconds: 2),
  });

  @override
  State<SplashVideoScreen> createState() => _SplashVideoScreenState();
}

class _SplashVideoScreenState extends State<SplashVideoScreen> {
  VideoPlayerController? _controller;
  Timer? _skipTimer;
  Timer? _fallbackTimer;
  bool _canSkip = false;
  bool _hasNavigated = false;
  bool _hasInitError = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    _startSkipTimer();
  }

  void _startSkipTimer() {
    _skipTimer = Timer(widget.skipButtonDelay, () {
      if (mounted && !_hasNavigated) {
        setState(() {
          _canSkip = true;
        });
      }
    });
  }

  Future<void> _initializeVideo() async {
    try {
      if (widget.controllerOverride != null) {
        _controller = widget.controllerOverride!;
      } else {
        _controller = VideoPlayerController.asset('assets/video/intro.mp4');
      }

      await _controller!.initialize();
      if (!mounted) return;

      _controller!.setLooping(false);
      _controller!.addListener(_videoListener);

      // On Web browsers, unmuted autoplay without user interaction is blocked.
      // Setting volume to 0.0 allows automatic playback on web and mobile browsers.
      try {
        await _controller!.setVolume(0.0);
      } catch (_) {}

      setState(() {});

      try {
        await _controller!.play();
      } catch (playErr) {
        debugPrint('Autoplay prevented by browser: $playErr');
      }
    } catch (e) {
      debugPrint('Splash video initialization failed: $e');
      if (mounted) {
        setState(() {
          _hasInitError = true;
          _canSkip = true;
        });
      }
      // Fallback timer to prevent getting stuck in environments where video playback is unsupported
      _fallbackTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && !_hasNavigated) {
          _navigateToNextScreen();
        }
      });
    }
  }

  void _videoListener() {
    if (!mounted || _hasNavigated) return;
    final value = _controller?.value;
    if (value != null && value.isInitialized) {
      if (value.position >= value.duration && value.duration > Duration.zero) {
        _navigateToNextScreen();
      }
    }
  }

  Future<void> _navigateToNextScreen() async {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;

    _skipTimer?.cancel();
    _fallbackTimer?.cancel();

    try {
      _controller?.removeListener(_videoListener);
      await _controller?.pause();
    } catch (_) {}

    if (widget.nextScreenOverride != null) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => widget.nextScreenOverride!),
      );
      return;
    }

    // Determine destination according to startup sequence
    bool hasSeenOnboarding = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
    } catch (e) {
      debugPrint('Error reading onboarding pref: $e');
    }

    if (!mounted) return;

    if (!hasSeenOnboarding) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
      return;
    }

    // Check saved authentication token
    String? savedToken;
    try {
      savedToken = await ApiClient.loadSavedToken();
    } catch (e) {
      debugPrint('Error loading saved token: $e');
    }

    final bool hasValidToken =
        (savedToken != null && savedToken.isNotEmpty) || ApiClient.isAuthenticated;

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            hasValidToken ? const DashboardScreen() : const TempLoginScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _skipTimer?.cancel();
    _fallbackTimer?.cancel();
    try {
      _controller?.removeListener(_videoListener);
      _controller?.dispose();
    } catch (_) {}
    super.dispose();
  }

  Widget _buildVideoContent() {
    if (_controller != null &&
        _controller!.value.isInitialized &&
        !_hasInitError) {
      final size = _controller!.value.size;
      final bool isPlaying = _controller!.value.isPlaying;

      return GestureDetector(
        onTap: () {
          if (!_controller!.value.isPlaying) {
            _controller!.play();
          }
          // Unmute on direct user tap
          try {
            _controller!.setVolume(1.0);
          } catch (_) {}
          setState(() {});
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: size.width > 0 ? size.width : 1280,
                  height: size.height > 0 ? size.height : 720,
                  child: VideoPlayer(_controller!),
                ),
              ),
            ),
            // Play overlay if browser required user gesture
            if (!isPlaying && !_hasNavigated)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  size: 48,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      );
    }

    // Fallback UI if video is loading or unsupported
    return Container(
      color: const Color(0xFF0F0E1E),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.heroGradientStart.withValues(alpha: 0.5),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/icon/logo.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.wifi_tethering_rounded,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Jalsah | جلسة',
              style: GoogleFonts.cairo(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkipButton() {
    return AnimatedOpacity(
      opacity: _canSkip ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: IgnorePointer(
        ignoring: !_canSkip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _navigateToNextScreen,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'تخطي',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            _buildVideoContent(),
            SafeArea(
              child: Align(
                alignment: AlignmentDirectional.topEnd,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: _buildSkipButton(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
