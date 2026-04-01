import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/alert_card.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/providers/network_provider.dart';
import '../../../data/models/alert_model.dart';
import '../providers/alert_providers.dart';
import '../providers/search_provider.dart';
import 'alert_details_screen.dart';

class ActiveAlertsScreen extends ConsumerStatefulWidget {
  const ActiveAlertsScreen({super.key});

  @override
  ConsumerState<ActiveAlertsScreen> createState() => _ActiveAlertsScreenState();
}

class _ActiveAlertsScreenState extends ConsumerState<ActiveAlertsScreen>
    with AutomaticKeepAliveClientMixin {
  String? _selectedSeverity;
  bool? _filterAcknowledged;
  bool _isRefreshing = false;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final alertsAsync = ref.watch(activeAlertsProvider);
    final audioService = ref.read(audioServiceProvider);
    final isOffline = ref.watch(isOfflineProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _isRefreshing = true);
          ref.invalidate(activeAlertsProvider);
          await Future.delayed(const Duration(milliseconds: 600));
          setState(() => _isRefreshing = false);
        },
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverAppBar(
              expandedHeight: 140.0,
              floating: true,
              pinned: true,
              surfaceTintColor: Colors.transparent,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Active Alerts',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                        letterSpacing: -0.8,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (isOffline) ...[
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.cloud_off_rounded,
                        size: 16,
                        color: AppTheme.warningColor,
                      ),
                    ],
                  ],
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
                            AppTheme.criticalColor.withOpacity(isDark ? 0.15 : 0.12),
                            isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight,
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      right: -10,
                      bottom: -10,
                      child: Icon(
                        Icons.notifications_active_outlined,
                        size: 140,
                        color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.04),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.search_rounded, color: isDark ? Colors.white70 : Colors.black54),
                  onPressed: () => _showSearchDialog(context, alertsAsync.value ?? []),
                ),
                _buildFilterMenu(isDark),
                _buildStatusMenu(isDark),
                const SizedBox(width: 8),
              ],
            ),

            // Body Content
            alertsAsync.when(
              data: (alerts) =>
                  _buildAlertsSliverList(context, alerts, audioService, isDark),
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stack) =>
                  SliverFillRemaining(child: _buildErrorState(error)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterMenu(bool isDark) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.filter_list_rounded, color: isDark ? Colors.white70 : Colors.black54),
      tooltip: 'Filter by Severity',
      onSelected: (value) {
        setState(() {
          _selectedSeverity = value == 'all' ? null : value;
        });
      },
      itemBuilder: (context) => [
        _buildPopupItem('all', 'All Severities', Icons.list_alt, isDark ? Colors.white : Colors.black87),
        const PopupMenuDivider(),
        _buildPopupItem(
          'critical',
          'Critical Only',
          Icons.error_outline,
          AppTheme.criticalColor,
        ),
        _buildPopupItem(
          'warning',
          'Warning Only',
          Icons.warning_amber_rounded,
          AppTheme.warningColor,
        ),
        _buildPopupItem(
          'info',
          'Info Only',
          Icons.info_outline,
          AppTheme.infoColor,
        ),
      ],
    );
  }

  Widget _buildStatusMenu(bool isDark) {
    return PopupMenuButton<bool?>(
      icon: Icon(Icons.check_circle_outline, color: isDark ? Colors.white70 : Colors.black54),
      tooltip: 'Filter by Status',
      onSelected: (value) {
        setState(() {
          _filterAcknowledged = value;
        });
      },
      itemBuilder: (context) => [
        _buildPopupItem(null, 'All Alerts', Icons.all_inclusive, isDark ? Colors.white : Colors.black87),
        const PopupMenuDivider(),
        _buildPopupItem(
          false,
          'Unacknowledged',
          Icons.notification_important_outlined,
          AppTheme.warningColor,
        ),
        _buildPopupItem(
          true,
          'Acknowledged',
          Icons.check_circle_outline,
          AppTheme.normalColor,
        ),
      ],
    );
  }

  PopupMenuItem<T> _buildPopupItem<T>(
    T value,
    String text,
    IconData icon,
    Color color,
  ) {
    return PopupMenuItem<T>(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildAlertsSliverList(
    BuildContext context,
    List<AlertModel> alerts,
    AudioService audioService,
    bool isDark,
  ) {
    var filteredAlerts = alerts;

    if (_selectedSeverity != null) {
      filteredAlerts = filteredAlerts
          .where(
            (a) => a.severity.toLowerCase() == _selectedSeverity!.toLowerCase(),
          )
          .toList();
    }

    if (_filterAcknowledged != null) {
      filteredAlerts = filteredAlerts
          .where((a) => a.isAcknowledged == _filterAcknowledged)
          .toList();
    }

    final sortedAlerts = List<AlertModel>.from(filteredAlerts)
      ..sort((a, b) => b.sortPriority.compareTo(a.sortPriority));

    if (sortedAlerts.isEmpty) {
      return SliverFillRemaining(child: _buildEmptyState(isDark));
    }

    return SliverList(
      delegate: SliverChildListDelegate([
        if (_selectedSeverity != null || _filterAcknowledged != null)
          _buildFilterBanner(alerts.length, sortedAlerts.length, isDark),

        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: ListView.builder(
            key: ValueKey(sortedAlerts.length),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 8, bottom: 100),
            itemCount: sortedAlerts.length,
            itemBuilder: (context, index) {
              final alert = sortedAlerts[index];
              return AlertCard(
                alert: alert,
                onTap: () => _navigateToDetails(context, alert, audioService),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _buildFilterBanner(int totalCount, int filteredCount, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.filter_alt_outlined,
            size: 18,
            color: AppTheme.infoColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Filtered: $filteredCount of $totalCount alerts',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          InkWell(
            onTap: () {
              setState(() {
                _selectedSeverity = null;
                _filterAcknowledged = null;
              });
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.infoColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'CLEAR',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.infoColor,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.normalColor.withOpacity(0.1),
            ),
            child: const Icon(
              Icons.task_alt_rounded,
              size: 64,
              color: AppTheme.normalColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'All Clear',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black87,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedSeverity != null || _filterAcknowledged != null
                ? 'No alerts match your current filters.'
                : 'System operating within normal parameters.',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white54 : Colors.black45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 64,
              color: AppTheme.criticalColor,
            ),
            const SizedBox(height: 24),
            const Text(
              'Connection Error',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to load alerts. Running in offline mode.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.white54),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () {
                ref.invalidate(activeAlertsProvider);
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('RETRY'),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToDetails(
    BuildContext context,
    AlertModel alert,
    AudioService audioService,
  ) {
    audioService.playAlertSound(alert.severity);

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            AlertDetailsScreen(alertId: alert.id),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    ).then((_) {
      if (mounted) {
        ref.invalidate(activeAlertsProvider);
      }
    });
  }

  Future<void> _showSearchDialog(
    BuildContext context,
    List<AlertModel> alerts,
  ) async {
    final result = await showSearch(
      context: context,
      delegate: AlertSearchDelegate(alerts),
    );

    if (result != null && mounted) {
      _navigateToDetails(context, result, ref.read(audioServiceProvider));
    }
  }
}
