import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// What the rider hears and feels when scanning: a short beep for a good scan
/// (like the station's web scanner), a double buzz for a refused one.
class ScanFeedback {
  ScanFeedback._();

  static final AudioPlayer _player = AudioPlayer(playerId: 'scan-beep')
    ..setReleaseMode(ReleaseMode.stop);

  static Future<void> success() async {
    HapticFeedback.lightImpact();
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/beep.wav'), volume: 1.0);
    } catch (_) {
      SystemSound.play(SystemSoundType.click); // no audio: at least a click
    }
  }

  static Future<void> error() async {
    try {
      if (await Vibration.hasVibrator()) {
        await Vibration.vibrate(pattern: const [0, 180, 90, 260]);
        return;
      }
    } catch (_) {
      // fall through to the haptic below
    }
    HapticFeedback.heavyImpact();
  }
}
