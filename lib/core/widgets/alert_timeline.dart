import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../../data/models/alert_model.dart';

class AlertTimeline extends StatelessWidget {
  final AlertModel alert;

  const AlertTimeline({super.key, required this.alert});

  @override
  Widget build(BuildContext context) {
    final events = _buildTimelineEvents();

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF3F3F3F), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline, color: AppTheme.infoColor, size: 20),
              SizedBox(width: 8),
              Text(
                'Alert Timeline',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFFFFFF),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          ...events.map((event) => _TimelineEvent(event: event)),
        ],
      ),
    );
  }

  List<_TimelineEventData> _buildTimelineEvents() {
    final events = <_TimelineEventData>[];

    // Raised
    events.add(
      _TimelineEventData(
        icon: Icons.notification_important,
        iconColor: AppTheme.criticalColor,
        title: 'Alert Raised',
        subtitle: 'System detected condition violation',
        timestamp: alert.raisedAt,
        isCompleted: true,
      ),
    );

    // Escalated
    if (alert.escalatedAt != null && alert.escalationLevel > 0) {
      events.add(
        _TimelineEventData(
          icon: Icons.trending_up,
          iconColor: AppTheme.warningColor,
          title: 'Escalated (Level ${alert.escalationLevel})',
          subtitle: 'Auto-escalated due to no acknowledgement',
          timestamp: alert.escalatedAt!,
          isCompleted: true,
        ),
      );
    }

    // Acknowledged
    if (alert.acknowledgedAt != null) {
      events.add(
        _TimelineEventData(
          icon: Icons.task_alt,
          iconColor: AppTheme.normalColor,
          title: 'Acknowledged',
          subtitle: alert.acknowledgedBy != null
              ? 'By: ${alert.acknowledgedBy}'
              : 'Operator acknowledged',
          timestamp: alert.acknowledgedAt!,
          isCompleted: true,
        ),
      );
    } else {
      events.add(
        _TimelineEventData(
          icon: Icons.radio_button_unchecked,
          iconColor: Color(0xFF616161),
          title: 'Pending Acknowledgement',
          subtitle: 'Awaiting operator action',
          timestamp: null,
          isCompleted: false,
        ),
      );
    }

    // Cleared
    if (alert.clearedAt != null) {
      events.add(
        _TimelineEventData(
          icon: Icons.check_circle,
          iconColor: AppTheme.normalColor,
          title: 'Cleared',
          subtitle: 'Condition returned to normal',
          timestamp: alert.clearedAt!,
          isCompleted: true,
        ),
      );
    } else if (alert.isActive) {
      events.add(
        _TimelineEventData(
          icon: Icons.radio_button_unchecked,
          iconColor: Color(0xFF616161),
          title: 'Awaiting Clearance',
          subtitle: 'Alert still active',
          timestamp: null,
          isCompleted: false,
        ),
      );
    }

    return events;
  }
}

class _TimelineEventData {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final DateTime? timestamp;
  final bool isCompleted;

  _TimelineEventData({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.timestamp,
    required this.isCompleted,
  });
}

class _TimelineEvent extends StatelessWidget {
  final _TimelineEventData event;

  const _TimelineEvent({required this.event});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon and line
          Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: event.iconColor.withOpacity(
                    event.isCompleted ? 0.15 : 0.08,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: event.iconColor.withOpacity(
                      event.isCompleted ? 0.4 : 0.2,
                    ),
                    width: 2,
                  ),
                ),
                child: Icon(event.icon, color: event.iconColor, size: 20),
              ),
              Expanded(
                child: Container(
                  width: 2,
                  margin: EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        event.iconColor.withOpacity(
                          event.isCompleted ? 0.3 : 0.1,
                        ),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: 16),

          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: event.isCompleted
                          ? Color(0xFFFFFFFF)
                          : Color(0xFF9E9E9E),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    event.subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: event.isCompleted
                          ? Color(0xFFB0B0B0)
                          : Color(0xFF757575),
                    ),
                  ),
                  if (event.timestamp != null) ...[
                    SizedBox(height: 6),
                    Text(
                      _formatTimestamp(event.timestamp!),
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF757575),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    String timeStr;
    if (diff.inDays > 0) {
      timeStr = '${diff.inDays}d ${diff.inHours % 24}h ago';
    } else if (diff.inHours > 0) {
      timeStr = '${diff.inHours}h ${diff.inMinutes % 60}m ago';
    } else if (diff.inMinutes > 0) {
      timeStr = '${diff.inMinutes}m ago';
    } else {
      timeStr = 'Just now';
    }

    return '${timestamp.toString().substring(0, 19)} ($timeStr)';
  }
}
