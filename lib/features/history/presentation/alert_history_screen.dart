import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/alert_card.dart';
import '../../../data/models/alert_model.dart';
import '../../../data/repositories/alert_repository.dart';
import '../../alerts/presentation/alert_details_screen.dart';
import '../../alerts/providers/alert_providers.dart';

class AlertHistoryScreen extends ConsumerStatefulWidget {
  const AlertHistoryScreen({super.key});

  @override
  ConsumerState<AlertHistoryScreen> createState() => _AlertHistoryScreenState();
}

class _AlertHistoryScreenState extends ConsumerState<AlertHistoryScreen> {
  final ScrollController _scrollController = ScrollController();
  List<AlertModel> _alerts = [];
  bool _isLoading = false;
  bool _hasMore = true;
  String? _selectedSeverity;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      if (!_isLoading && _hasMore) {
        _loadAlerts();
      }
    }
  }

  Future<void> _loadAlerts({bool refresh = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (refresh) {
        _alerts = [];
        _hasMore = true;
      }
    });

    try {
      final repository = ref.read(alertRepositoryProvider);
      final newAlerts = await repository.getAlertHistory(
        startDate: _dateRange?.start,
        endDate: _dateRange?.end,
        severity: _selectedSeverity,
        limit: 50,
      );

      setState(() {
        if (refresh) {
          _alerts = newAlerts;
        } else {
          _alerts.addAll(newAlerts);
        }
        _hasMore = newAlerts.length >= 50;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading history: $e'),
            backgroundColor: AppTheme.criticalColor,
          ),
        );
      }
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: isDark ? AppTheme.darkTheme : AppTheme.lightTheme,
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateRange = picked;
      });
      _loadAlerts(refresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _loadAlerts(refresh: true),
        child: CustomScrollView(
          controller: _scrollController,
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
                title: Text(
                  'Alert History',
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
                            AppTheme.normalColor.withOpacity(isDark ? 0.15 : 0.12),
                            isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight,
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      right: -10,
                      bottom: -10,
                      child: Icon(
                        Icons.history_rounded,
                        size: 140,
                        color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.04),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    Icons.date_range_rounded,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  tooltip: 'Date Range',
                  onPressed: _selectDateRange,
                ),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.filter_list_rounded,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  tooltip: 'Filter Severity',
                  onSelected: (value) {
                    setState(() {
                      _selectedSeverity = value == 'all' ? null : value;
                    });
                    _loadAlerts(refresh: true);
                  },
                  itemBuilder: (context) => [
                    _buildPopupItem('all', 'All Severities', Icons.list_alt, isDark ? Colors.white : Colors.black87),
                    const PopupMenuDivider(),
                    _buildPopupItem('critical', 'Critical', Icons.error_outline, AppTheme.criticalColor),
                    _buildPopupItem('warning', 'Warning', Icons.warning_amber_rounded, AppTheme.warningColor),
                    _buildPopupItem('info', 'Info', Icons.info_outline, AppTheme.infoColor),
                  ],
                ),
                const SizedBox(width: 8),
              ],
            ),

            if (_selectedSeverity != null || _dateRange != null)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
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
                          'Filters: ${_selectedSeverity?.toUpperCase() ?? "ALL"}'
                          '${_dateRange != null ? " • Date Range Active" : ""}',
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
                            _dateRange = null;
                          });
                          _loadAlerts(refresh: true);
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
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
                ),
              ),

            if (_alerts.isEmpty && !_isLoading)
              SliverFillRemaining(
                child: _buildEmptyState(isDark),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    if (index == _alerts.length) {
                      return const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final alert = _alerts[index];
                    return AlertCard(
                      alert: alert,
                      onTap: () {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    AlertDetailsScreen(alertId: alert.id),
                            transitionsBuilder:
                                (
                                  context,
                                  animation,
                                  secondaryAnimation,
                                  child,
                                ) {
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
                        );
                      },
                    );
                  }, childCount: _alerts.length + (_hasMore ? 1 : 0)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<T> _buildPopupItem<T>(T value, String text, IconData icon, Color color) {
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

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? const Color(0xFF2D2D2D).withOpacity(0.5) : Colors.black.withOpacity(0.03),
            ),
            child: Icon(
              Icons.history_rounded,
              size: 64,
              color: isDark ? const Color(0xFF757575) : Colors.black26,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No History Available',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black87,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters or date range.',
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
}
