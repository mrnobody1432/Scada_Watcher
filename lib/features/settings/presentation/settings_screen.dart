import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/audio_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 140.0,
            floating: true,
            pinned: true,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Text(
                'Settings',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                  letterSpacing: -0.8,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.infoColor.withOpacity(isDark ? 0.15 : 0.05),
                          Theme.of(context).scaffoldBackgroundColor,
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: -20,
                    bottom: -20,
                    child: Icon(
                      Icons.settings_outlined,
                      size: 160,
                      color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _SectionHeader(title: 'APPEARANCE', isDark: isDark),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.black.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ThemeOption(
                            label: 'Light',
                            icon: Icons.light_mode_outlined,
                            isSelected: ref.watch(themeModeProvider) == ThemeMode.light,
                            onTap: () => ref.read(themeModeProvider.notifier).state = ThemeMode.light,
                            isDark: isDark,
                          ),
                        ),
                        Expanded(
                          child: _ThemeOption(
                            label: 'Dark',
                            icon: Icons.dark_mode_outlined,
                            isSelected: ref.watch(themeModeProvider) == ThemeMode.dark,
                            onTap: () => ref.read(themeModeProvider.notifier).state = ThemeMode.dark,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _SectionHeader(title: 'USER INFORMATION', isDark: isDark),
                _SettingsTile(
                  icon: Icons.person_outline,
                  title: 'User',
                  subtitle: 'Mobile Operator',
                  isDark: isDark,
                ),
                _SettingsTile(
                  icon: Icons.badge_outlined,
                  title: 'Role',
                  subtitle: 'View & Acknowledge',
                  isDark: isDark,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Divider(color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE0E4E9)),
                ),
                _SectionHeader(title: 'NOTIFICATIONS', isDark: isDark),
                SwitchListTile(
                  secondary: Icon(Icons.notifications_none, color: isDark ? Colors.white70 : Colors.black54),
                  title: Text('Push Notifications', style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
                  subtitle: Text('Receive alerts on device', style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 13, fontWeight: FontWeight.w500)),
                  value: true,
                  activeColor: AppTheme.infoColor,
                  onChanged: (val) {},
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                SwitchListTile(
                  secondary: Icon(Icons.vibration, color: isDark ? Colors.white70 : Colors.black54),
                  title: Text('Vibration', style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
                  subtitle: Text('Vibrate on critical alerts', style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 13, fontWeight: FontWeight.w500)),
                  value: settings.vibrationEnabled,
                  activeColor: AppTheme.infoColor,
                  onChanged: (val) => settingsNotifier.toggleVibration(val),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                SwitchListTile(
                  secondary: Icon(Icons.volume_up_outlined, color: isDark ? Colors.white70 : Colors.black54),
                  title: Text('Sound', style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
                  subtitle: Text('Alert sound on notifications', style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 13, fontWeight: FontWeight.w500)),
                  value: settings.soundEnabled,
                  activeColor: AppTheme.infoColor,
                  onChanged: (val) => settingsNotifier.toggleSound(val),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                if (settings.soundEnabled) ...[
                  _SettingsTile(
                    icon: Icons.error_outline,
                    title: 'Critical Alert Sound',
                    subtitle: settings.criticalSound,
                    isDark: isDark,
                    onTap: () => _showSoundPicker(context, ref, 'Critical', settings.criticalSound, (s) => settingsNotifier.setCriticalSound(s)),
                  ),
                  _SettingsTile(
                    icon: Icons.warning_amber_rounded,
                    title: 'Warning Alert Sound',
                    subtitle: settings.warningSound,
                    isDark: isDark,
                    onTap: () => _showSoundPicker(context, ref, 'Warning', settings.warningSound, (s) => settingsNotifier.setWarningSound(s)),
                  ),
                  _SettingsTile(
                    icon: Icons.info_outline,
                    title: 'Info Alert Sound',
                    subtitle: settings.infoSound,
                    isDark: isDark,
                    onTap: () => _showSoundPicker(context, ref, 'Info', settings.infoSound, (s) => settingsNotifier.setInfoSound(s)),
                  ),
                ],
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Divider(color: Colors.transparent),
                ),
                _SectionHeader(title: 'BACKEND CONFIGURATION', isDark: isDark),
                _SettingsTile(
                  icon: Icons.cloud_outlined,
                  title: 'Firebase Project',
                  subtitle: 'scada-alarm-system',
                  isDark: isDark,
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.normalColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.normalColor.withOpacity(0.3)),
                    ),
                    child: const Text(
                      'CONNECTED',
                      style: TextStyle(
                        color: AppTheme.normalColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                _SettingsTile(
                  icon: Icons.storage_outlined,
                  title: 'Firestore Collections',
                  subtitle: 'alerts_active, alerts_history',
                  isDark: isDark,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Divider(color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE0E4E9)),
                ),
                _SectionHeader(title: 'ABOUT', isDark: isDark),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF151515) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? const Color(0xFF252525) : const Color(0xFFE0E4E9)),
                      boxShadow: [
                        if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          'SCADA Alarm Client',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Industrial alarm monitoring system\nRead-only mobile client for operators',
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.black45,
                            fontSize: 13,
                            height: 1.6,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.normalColor.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.security_outlined,
                                size: 18,
                                color: AppTheme.normalColor,
                              ),
                              SizedBox(width: 10),
                              Text(
                                'View & Acknowledge Only',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.normalColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _showSoundPicker(BuildContext context, WidgetRef ref, String type, String current, Function(String) onSelect) {
    final sounds = ['Industrial Siren', 'Digital Beep', 'Subtle Chime', 'Electronic Pulse', 'Mechanical Alarm'];
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text('Select $type Sound', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...sounds.map((sound) => ListTile(
              title: Text(sound, style: TextStyle(fontWeight: sound == current ? FontWeight.bold : FontWeight.normal)),
              trailing: sound == current ? const Icon(Icons.check_circle, color: AppTheme.infoColor) : null,
              onTap: () {
                onSelect(sound);
                ref.read(audioServiceProvider).testSound(sound);
                Navigator.pop(context);
              },
            )),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final selectedColor = isSelected ? AppTheme.infoColor : Colors.transparent;
    final contentColor = isSelected 
        ? Colors.white 
        : (isDark ? Colors.white54 : Colors.black45);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selectedColor,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: AppTheme.infoColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Column(
              children: [
                Icon(icon, color: contentColor, size: 20),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: contentColor,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool isDark;

  const _SectionHeader({required this.title, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.infoColor,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final bool isDark;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: isDark ? Colors.white70 : Colors.black54, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: isDark ? Colors.white54 : Colors.black45,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right, size: 20) : null),
    );
  }
}

