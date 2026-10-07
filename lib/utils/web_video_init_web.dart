import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:video_player_web/video_player_web.dart';

void ensureWebVideoInitialized() {
  try {
    if (VideoPlayerPlatform.instance is! VideoPlayerPlugin) {
      VideoPlayerPlatform.instance = VideoPlayerPlugin();
      // ignore: avoid_print
      print('SPLASH_INIT: Successfully registered VideoPlayerPlugin for Web');
    }
  } catch (e) {
    // ignore: avoid_print
    print('SPLASH_INIT: Failed to register VideoPlayerPlugin: $e');
  }
}
