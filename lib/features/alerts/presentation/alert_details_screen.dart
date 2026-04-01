import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import '../../../core/theme/app_theme.dart';
import '../../alerts/providers/alert_providers.dart';
import '../../../data/models/alert_model.dart';

class AlertDetailsScreen extends ConsumerWidget {
  final String alertId;

  const AlertDetailsScreen({super.key, required this.alertId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertAsync = ref.watch(alertByIdProvider(alertId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return alertAsync.when(
      data: (alert) {
        if (alert == null) {
          return _buildErrorScaffold(context, 'Alert no longer active', isDark);
        }
        return _buildDetailsScaffold(context, ref, alert, isDark);
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => _buildErrorScaffold(context, 'Error: $error', isDark),
    );
  }

  Widget _buildDetailsScaffold(BuildContext context, WidgetRef ref, AlertModel alert, bool isDark) {
    final isCritical = alert.severity.toLowerCase() == 'critical';
    final themeColor = isCritical ? AppTheme.criticalColor : AppTheme.warningColor;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context, alert, themeColor, isDark),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusChip(alert),
                  const SizedBox(height: 24),
                  
                  _buildMetricsSection(context, alert, themeColor, isDark),
                  const SizedBox(height: 24),

                  _buildDescriptionSection(context, alert, isDark),
                  const SizedBox(height: 32),
                  
                  _buildSectionHeader('DIAGNOSTIC DETAILS', isDark),
                  const SizedBox(height: 12),
                  _buildDiagnosticGrid(context, alert, isDark),
                  const SizedBox(height: 32),
                  
                  _buildSectionHeader('EVENT TIMELINE', isDark),
                  const SizedBox(height: 12),
                  _buildTimeline(context, alert, isDark),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: !alert.isAcknowledged
          ? FloatingActionButton.extended(
              onPressed: () => _showAcknowledgeDialog(context, ref, alert),
              label: const Text(
                'ACKNOWLEDGE ALARM',
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              icon: const Icon(Icons.check_circle_outline),
              backgroundColor: AppTheme.infoColor,
              elevation: 4,
            )
          : null,
    );
  }

  Widget _buildSliverAppBar(BuildContext context, AlertModel alert, Color themeColor, bool isDark) {
    return SliverAppBar(
      expandedHeight: 180.0,
      pinned: true,
      stretch: true,
      backgroundColor: Theme.of(context).cardColor,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new, 
          size: 20,
          color: isDark ? Colors.white : Colors.black87,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              alert.name,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              alert.tagName,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white.withOpacity(0.6) : Colors.black45,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (alert.severity.toLowerCase() == 'critical')
              Positioned.fill(
                child: Opacity(
                  opacity: 0.05,
                  child: Lottie.network(
                    'https://assets9.lottiefiles.com/packages/lf20_pk5puaqq.json',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    themeColor.withOpacity(isDark ? 0.3 : 0.1),
                    Theme.of(context).scaffoldBackgroundColor,
                  ],
                ),
              ),
            ),
            Positioned(
              right: -20,
              top: -20,
              child: Icon(
                AppTheme.getSeverityIcon(alert.severity),
                size: 150,
                color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsSection(BuildContext context, AlertModel alert, Color themeColor, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? themeColor.withOpacity(0.2) : const Color(0xFFE0E4E9), 
          width: 1.5
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildValueIndicator('TRIGGER VALUE', '${alert.currentValue}', themeColor, true, isDark),
              Container(
                height: 50,
                width: 1,
                color: isDark ? Colors.white10 : Colors.black12,
              ),
              _buildValueIndicator('THRESHOLD', '${alert.threshold}', isDark ? Colors.white38 : Colors.black38, false, isDark),
            ],
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: alert.threshold != 0 ? (alert.currentValue / alert.threshold).clamp(0.0, 1.0) : 0,
              backgroundColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
              color: themeColor,
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Deviation: ${((alert.currentValue - alert.threshold).abs()).toStringAsFixed(2)} units',
                style: TextStyle(
                  fontSize: 11, 
                  color: isDark ? Colors.white38 : Colors.black45,
                  fontWeight: FontWeight.w600
                ),
              ),
              Text(
                'Condition: ${alert.condition}',
                style: TextStyle(fontSize: 11, color: themeColor, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection(BuildContext context, AlertModel alert, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151515) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE0E4E9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: AppTheme.infoColor),
              SizedBox(width: 8),
              Text(
                'ALARM CONTEXT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.infoColor,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            alert.description,
            style: TextStyle(
              fontSize: 15,
              color: isDark ? Colors.white70 : Colors.black87,
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(AlertModel alert) {
    final isAck = alert.isAcknowledged;
    final color = isAck ? AppTheme.normalColor : AppTheme.criticalColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAck ? Icons.check_circle : Icons.warning_amber_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            isAck ? 'ACKNOWLEDGED' : 'ACTIVE / UNACK',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: isDark ? Colors.white24 : Colors.black38,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildDiagnosticGrid(BuildContext context, AlertModel alert, bool isDark) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: [
        _buildInfoTile(context, 'EQUIPMENT', alert.equipment ?? 'N/A', Icons.precision_manufacturing_outlined, isDark),
        _buildInfoTile(context, 'LOCATION', alert.location ?? 'N/A', Icons.location_on_outlined, isDark),
        _buildInfoTile(context, 'SOURCE', alert.source, Icons.hub_outlined, isDark),
        _buildInfoTile(context, 'SOURCE TAG', alert.tagName, Icons.tag_outlined, isDark),
        _buildInfoTile(context, 'LATENCY', 'REAL-TIME', Icons.timer_outlined, isDark, color: AppTheme.infoColor),
        _buildInfoTile(context, 'ESCALATIONS', '${alert.escalationCount}', Icons.trending_up_rounded, isDark,
            color: alert.escalationCount > 0 ? AppTheme.criticalColor : null),
      ],
    );
  }

  Widget _buildInfoTile(BuildContext context, String label, String value, IconData icon, bool isDark, {Color? color}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE0E4E9)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (color ?? (isDark ? Colors.white : Colors.black)).withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color ?? (isDark ? Colors.white38 : Colors.black38)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: TextStyle(fontSize: 8, color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValueIndicator(String label, String value, Color color, bool highlight, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label, 
          style: TextStyle(
            fontSize: 10, 
            color: isDark ? Colors.white38 : Colors.black38, 
            letterSpacing: 1, 
            fontWeight: FontWeight.w900
          )
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: highlight ? 32 : 24, 
            fontWeight: FontWeight.w900, 
            color: color,
            letterSpacing: -1,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeline(BuildContext context, AlertModel alert, bool isDark) {
    final dateFormat = DateFormat('HH:mm:ss (MMM dd)');
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151515) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF252525) : const Color(0xFFE0E4E9)),
      ),
      child: Column(
        children: [
          _buildTimelineItem(
            'ALARM RAISED',
            dateFormat.format(alert.raisedAt),
            'Trigger condition detected: ${alert.condition}',
            Icons.notification_important_outlined,
            AppTheme.criticalColor,
            alert.isAcknowledged,
            isDark,
          ),
          if (alert.isAcknowledged && alert.acknowledgedAt != null)
            _buildTimelineItem(
              'ACKNOWLEDGED',
              dateFormat.format(alert.acknowledgedAt!),
              'Verified by: ${alert.acknowledgedBy ?? "System"}\nComment: ${alert.acknowledgedComment ?? "Acknowledged via mobile"}',
              Icons.verified_user_outlined,
              AppTheme.infoColor,
              alert.clearedAt != null,
              isDark,
            ),
          if (alert.clearedAt != null)
            _buildTimelineItem(
              'AUTO-RESOLVED',
              dateFormat.format(alert.clearedAt!),
              'Process values returned to normal range.',
              Icons.task_alt_outlined,
              AppTheme.normalColor,
              false,
              isDark,
            ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(String title, String time, String details, IconData icon, Color color, bool hasNext, bool isDark) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withOpacity(0.5), width: 1.5),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              if (hasNext)
                Expanded(
                  child: Container(
                    width: 1.5,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [color.withOpacity(0.5), isDark ? Colors.white10 : Colors.black12],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title, 
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5)
                      ),
                      Text(
                        time, 
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.w700)
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    details, 
                    style: TextStyle(
                      fontSize: 12, 
                      color: isDark ? Colors.white60 : Colors.black54, 
                      height: 1.6, 
                      fontWeight: FontWeight.w500
                    )
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScaffold(BuildContext context, String message, bool isDark) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Text(
          message,
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _showAcknowledgeDialog(BuildContext context, WidgetRef ref, AlertModel alert) {
    final commentController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Acknowledge Alarm'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter comments or action taken:'),
            const SizedBox(height: 16),
            TextField(
              controller: commentController,
              decoration: const InputDecoration(
                hintText: 'e.g., Investigating motor heat',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              final repository = ref.read(alertRepositoryProvider);
              await repository.acknowledgeAlert(
                alert.id,
                'User-App',
                comment: commentController.text,
              );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('CONFIRM'),
          ),
        ],
      ),
    );
  }
}
