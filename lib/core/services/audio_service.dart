import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';

enum AlertSound { critical, warning, info, none }

class AudioService {
  final Ref _ref;

  AudioService(this._ref);

  Future<void> playAlertSound(String severity) async {
    final settings = _ref.read(settingsProvider);
    
    if (!settings.soundEnabled) return;

    switch (severity.toLowerCase()) {
      case 'critical':
        await _playSequence(settings.criticalSound);
        break;
      case 'warning':
        await _playSequence(settings.warningSound);
        break;
      case 'info':
        await _playSequence(settings.infoSound);
        break;
    }

    if (settings.vibrationEnabled) {
      await _vibrate(severity);
    }
  }

  Future<void> _playSequence(String soundName) async {
    // Since we don't have actual assets, we simulate different sound patterns using Haptics
    // In a real app, this would use a plugin like audioplayers
    switch (soundName) {
      case 'Industrial Siren':
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 150));
        await HapticFeedback.heavyImpact();
        break;
      case 'Digital Beep':
        await HapticFeedback.mediumImpact();
        break;
      case 'Subtle Chime':
        await HapticFeedback.lightImpact();
        break;
      case 'Electronic Pulse':
        await HapticFeedback.selectionClick();
        break;
      case 'Mechanical Alarm':
        await HapticFeedback.vibrate();
        break;
      default:
        await HapticFeedback.mediumImpact();
    }
  }

  Future<void> _vibrate(String severity) async {
    switch (severity.toLowerCase()) {
      case 'critical':
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 200));
        await HapticFeedback.heavyImpact();
        break;
      case 'warning':
        await HapticFeedback.mediumImpact();
        break;
      case 'info':
        await HapticFeedback.selectionClick();
        break;
    }
  }

  Future<void> testSound(String soundName) async {
    await _playSequence(soundName);
    await HapticFeedback.lightImpact();
  }
}

final audioServiceProvider = Provider<AudioService>((ref) {
  return AudioService(ref);
});
