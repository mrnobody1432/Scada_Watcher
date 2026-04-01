import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/summary_card.dart';
import '../../alerts/providers/alert_providers.dart';
import '../../alerts/presentation/critical_alerts_screen.dart';
import '../../alerts/presentation/warning_alerts_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final criticalCount = ref.watch(activeCriticalCountProvider);
    final warningCount = ref.watch(activeWarningCountProvider);
    final acknowledgedCount = ref.watch(acknowledgedCountProvider);
    final clearedCount = ref.watch(clearedLast24hCountProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(activeCriticalCountProvider);
          ref.invalidate(activeWarningCountProvider);
          ref.invalidate(acknowledgedCountProvider);
          ref.invalidate(clearedLast24hCountProvider);
          await Future.delayed(const Duration(milliseconds: 600));
        },
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverAppBar(
              expandedHeight: 140,
              floating: true,
              pinned: true,
              surfaceTintColor: Colors.transparent,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                title: Text(
                  'SCADA Monitor',
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
                            AppTheme.infoColor.withOpacity(isDark ? 0.15 : 0.12),
                            isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight,
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      right: -10,
                      bottom: -10,
                      child: Icon(
                        Icons.dashboard_outlined,
                        size: 140,
                        color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.04),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: IconButton(
                    icon: Icon(
                      Icons.refresh_rounded, 
                      color: isDark ? Colors.white70 : Colors.black54
                    ),
                    onPressed: () {
                      ref.invalidate(activeCriticalCountProvider);
                      ref.invalidate(activeWarningCountProvider);
                      ref.invalidate(acknowledgedCountProvider);
                      ref.invalidate(clearedLast24hCountProvider);
                    },
                  ),
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Row(
                    children: [
                      const Icon(
                        Icons.analytics_outlined,
                        size: 16,
                        color: AppTheme.infoColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'SYSTEM OVERVIEW',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.infoColor,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.3, // Made smaller (was 1.1)
                    children: [
                      SummaryCard(
                        title: 'Critical Alerts',
                        subtitle: 'Tap to view',
                        value: criticalCount.when(
                          data: (count) => count.toString(),
                          loading: () => '-',
                          error: (_, __) => '!',
                        ),
                        icon: Icons.error_outline,
                        color: AppTheme.criticalColor,
                        onTap: () {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (context, anim, sec) => const CriticalAlertsScreen(),
                              transitionsBuilder: (context, anim, sec, child) {
                                return FadeTransition(opacity: anim, child: child);
                              },
                            ),
                          );
                        },
                      ),
                      SummaryCard(
                        title: 'Warnings',
                        subtitle: 'Tap to view',
                        value: warningCount.when(
                          data: (count) => count.toString(),
                          loading: () => '-',
                          error: (_, __) => '!',
                        ),
                        icon: Icons.warning_amber_rounded,
                        color: AppTheme.warningColor,
                        onTap: () {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (context, anim, sec) => const WarningAlertsScreen(),
                              transitionsBuilder: (context, anim, sec, child) {
                                return FadeTransition(opacity: anim, child: child);
                              },
                            ),
                          );
                        },
                      ),
                      SummaryCard(
                        title: 'Acknowledged',
                        subtitle: 'Investigating',
                        value: acknowledgedCount.when(
                          data: (count) => count.toString(),
                          loading: () => '-',
                          error: (_, __) => '!',
                        ),
                        icon: Icons.check_circle_outline,
                        color: AppTheme.infoColor,
                      ),
                      SummaryCard(
                        title: 'Resolved',
                        subtitle: 'Past 24h',
                        value: clearedCount.when(
                          data: (count) => count.toString(),
                          loading: () => '-',
                          error: (_, __) => '!',
                        ),
                        icon: Icons.task_alt,
                        color: AppTheme.normalColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 100),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

