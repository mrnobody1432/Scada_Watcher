import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsState {
  final bool vibrationEnabled;
  final bool soundEnabled;
  final String criticalSound;
  final String warningSound;
  final String infoSound;

  SettingsState({
    this.vibrationEnabled = true,
    this.soundEnabled = true,
    this.criticalSound = 'Industrial Siren',
    this.warningSound = 'Digital Beep',
    this.infoSound = 'Subtle Chime',
  });

  SettingsState copyWith({
    bool? vibrationEnabled,
    bool? soundEnabled,
    String? criticalSound,
    String? warningSound,
    String? infoSound,
  }) {
    return SettingsState(
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      criticalSound: criticalSound ?? this.criticalSound,
      warningSound: warningSound ?? this.warningSound,
      infoSound: infoSound ?? this.infoSound,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(SettingsState());

  void toggleVibration(bool enabled) {
    state = state.copyWith(vibrationEnabled: enabled);
  }

  void toggleSound(bool enabled) {
    state = state.copyWith(soundEnabled: enabled);
  }

  void setCriticalSound(String sound) {
    state = state.copyWith(criticalSound: sound);
  }

  void setWarningSound(String sound) {
    state = state.copyWith(warningSound: sound);
  }

  void setInfoSound(String sound) {
    state = state.copyWith(infoSound: sound);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});
