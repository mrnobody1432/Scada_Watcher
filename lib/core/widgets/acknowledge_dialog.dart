import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../../data/models/alert_model.dart';

class AcknowledgeDialog extends StatefulWidget {
  final AlertModel alert;
  final Function(String? comment) onConfirm;

  const AcknowledgeDialog({
    super.key,
    required this.alert,
    required this.onConfirm,
  });

  @override
  State<AcknowledgeDialog> createState() => _AcknowledgeDialogState();
}

class _AcknowledgeDialogState extends State<AcknowledgeDialog> {
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.cardDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Color(0xFF3F3F3F), width: 1),
      ),
      child: Container(
        constraints: BoxConstraints(maxWidth: 500),
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.warningColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.task_alt,
                    color: AppTheme.warningColor,
                    size: 28,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Acknowledge Alert',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFFFFFF),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Confirm operator acknowledgement',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Color(0xFF9E9E9E),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),

            // Alert Info
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariantDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xFF3F3F3F), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        AppTheme.getSeverityIcon(widget.alert.severity),
                        color: AppTheme.getSeverityColor(widget.alert.severity),
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.alert.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFFFFFFF),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  _buildInfoRow('Source', widget.alert.source),
                  SizedBox(height: 6),
                  _buildInfoRow('Tag', widget.alert.tagName),
                  SizedBox(height: 6),
                  _buildInfoRow(
                    'Raised',
                    widget.alert.timeSinceRaised + ' ago',
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),

            // Optional Comment
            Text(
              'Comment (Optional)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFFB0B0B0),
              ),
            ),
            SizedBox(height: 8),
            TextField(
              controller: _commentController,
              maxLines: 3,
              maxLength: 200,
              enabled: !_isSubmitting,
              style: TextStyle(color: Color(0xFFFFFFFF)),
              decoration: InputDecoration(
                hintText: 'Add acknowledgement notes (optional)',
                hintStyle: TextStyle(color: Color(0xFF757575)),
                filled: true,
                fillColor: AppTheme.surfaceVariantDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Color(0xFF3F3F3F)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Color(0xFF3F3F3F)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.infoColor, width: 2),
                ),
                contentPadding: EdgeInsets.all(12),
              ),
            ),
            SizedBox(height: 24),

            // Warning Notice
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.warningColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppTheme.warningColor,
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Acknowledgement does NOT clear the alert. Alert remains active until automatically cleared by SCADA system.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFB0B0B0),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Color(0xFFFFFFFF),
                    side: BorderSide(color: Color(0xFF616161), width: 1),
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                  child: Text('Cancel'),
                ),
                SizedBox(width: 12),
                FilledButton(
                  onPressed: _isSubmitting ? null : _handleAcknowledge,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.normalColor,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  ),
                  child: _isSubmitting
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Text('Acknowledge'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF9E9E9E),
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFFFFFFFF),
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Future<void> _handleAcknowledge() async {
    setState(() => _isSubmitting = true);

    try {
      final comment = _commentController.text.trim();
      await widget.onConfirm(comment.isEmpty ? null : comment);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to acknowledge: $e'),
            backgroundColor: AppTheme.criticalColor,
          ),
        );
      }
    }
  }
}
