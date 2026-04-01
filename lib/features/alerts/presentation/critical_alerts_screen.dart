import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/alert_card.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/audio_service.dart';
import '../providers/alert_providers.dart';
import 'alert_details_screen.dart';

class CriticalAlertsScreen extends ConsumerWidget {
  const CriticalAlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(criticalAlertsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final audioService = ref.read(audioServiceProvider);

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverAppBar(
            expandedHeight: 140.0,
            pinned: true,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: isDark ? Colors.white : Colors.black87),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
              title: Text(
                'Critical Alerts',
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
                          AppTheme.criticalColor.withOpacity(isDark ? 0.2 : 0.15),
                          Theme.of(context).scaffoldBackgroundColor,
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: -10,
                    bottom: -10,
                    child: Icon(
                      Icons.error_outline_rounded,
                      size: 140,
                      color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.04),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          alertsAsync.when(
            data: (alerts) {
              if (alerts.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 64, color: AppTheme.normalColor.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text(
                          'No Critical Alarms',
                          style: TextStyle(
                            fontSize: 18, 
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white54 : Colors.black45
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              
              return SliverPadding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final alert = alerts[index];
                      return AlertCard(
                        alert: alert,
                        onTap: () {
                          audioService.playAlertSound(alert.severity);
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (context, anim, sec) => AlertDetailsScreen(alertId: alert.id),
                              transitionsBuilder: (context, anim, sec, child) {
                                return SlideTransition(
                                  position: anim.drive(Tween(begin: const Offset(1, 0), end: Offset.zero).chain(CurveTween(curve: Curves.easeOutCubic))),
                                  child: child,
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                    childCount: alerts.length,
                  ),
                ),
              );
            },
            loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
            error: (err, _) => SliverFillRemaining(child: Center(child: Text('Error: $err'))),
          ),
        ],
      ),
    );
  }
}
