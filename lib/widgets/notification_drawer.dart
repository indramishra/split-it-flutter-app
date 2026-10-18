import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/splitwise_provider.dart';
import '../models/notification_model.dart';
import '../theme/app_theme.dart';

class NotificationDrawer extends StatefulWidget {
  const NotificationDrawer({super.key});

  @override
  State<NotificationDrawer> createState() => _NotificationDrawerState();
}

class _NotificationDrawerState extends State<NotificationDrawer> {
  bool _filterOnlyMe = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SplitwiseProvider>();
    final currentUserId = provider.currentUser.id;

    final allNotifications = provider.notifications;
    final filteredNotifications = _filterOnlyMe
        ? allNotifications.where((n) => n.recipientUserId == currentUserId).toList()
        : allNotifications;

    return Drawer(
      width: MediaQuery.of(context).size.width > 450
          ? 400
          : MediaQuery.of(context).size.width * 0.88,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.tealLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.mail_outline, color: AppTheme.tealDark),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Group Mail & Notifications',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.charcoal,
                      ),
                    ),
                  ),
                  if (allNotifications.isNotEmpty)
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        foregroundColor: AppTheme.teal,
                      ),
                      onPressed: () {
                        provider.markAllNotificationsAsRead();
                      },
                      child: const Text('Mark all read', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Filter Selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('All Group Dispatches'),
                    selected: !_filterOnlyMe,
                    selectedColor: AppTheme.tealLight,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: !_filterOnlyMe ? FontWeight.w700 : FontWeight.w500,
                      color: !_filterOnlyMe ? AppTheme.tealDark : AppTheme.textDark,
                    ),
                    onSelected: (val) => setState(() => _filterOnlyMe = false),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Only Mine'),
                    selected: _filterOnlyMe,
                    selectedColor: AppTheme.tealLight,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: _filterOnlyMe ? FontWeight.w700 : FontWeight.w500,
                      color: _filterOnlyMe ? AppTheme.tealDark : AppTheme.textDark,
                    ),
                    onSelected: (val) => setState(() => _filterOnlyMe = true),
                  ),
                ],
              ),
            ),

            // Notification Count Info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    '${filteredNotifications.length} notifications dispatched',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  const Spacer(),
                  const Tooltip(
                    message:
                        'Dispatches simulated transactional emails to each member whenever an activity happens in any group.',
                    child: Icon(Icons.info_outline, size: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // Notification List
            Expanded(
              child: filteredNotifications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.mark_email_read_outlined,
                              size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text(
                            'No notifications yet',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Group activities will dispatch mail here.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredNotifications.length,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      itemBuilder: (ctx, idx) {
                        final notif = filteredNotifications[idx];
                        return _buildNotificationCard(context, provider, notif);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    SplitwiseProvider provider,
    AppNotification notif,
  ) {
    final dateFormat = DateFormat('MMM d, h:mm a');
    final isForMe = notif.recipientUserId == provider.currentUser.id;

    IconData icon;
    Color iconColor;
    if (notif.type == 'payment_settled') {
      icon = Icons.payments_outlined;
      iconColor = AppTheme.positiveGreen;
    } else if (notif.type == 'group_created') {
      icon = Icons.group_add_outlined;
      iconColor = Colors.purple;
    } else {
      icon = Icons.receipt_long_outlined;
      iconColor = AppTheme.teal;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: notif.isRead ? Colors.white : const Color(0xFFF0FDF8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: notif.isRead ? Colors.grey.shade200 : AppTheme.teal.withValues(alpha: 0.3),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          provider.markNotificationAsRead(notif.id);
          _showEmailPreviewDialog(context, notif);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header line: Recipient & Time
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isForMe ? AppTheme.tealLight : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.mail_outline,
                          size: 11,
                          color: isForMe ? AppTheme.tealDark : Colors.grey.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isForMe ? 'To: You' : 'To: ${notif.recipientName}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isForMe ? AppTheme.tealDark : Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (notif.groupName != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        notif.groupName!,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    dateFormat.format(notif.timestamp),
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Title and Body
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: iconColor, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notif.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.w800,
                            color: AppTheme.charcoal,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          notif.body,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!notif.isRead)
                    Container(
                      margin: const EdgeInsets.only(top: 6, left: 6),
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.teal,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEmailPreviewDialog(BuildContext context, AppNotification notif) {
    final dateFormat = DateFormat('EEE, MMM d, yyyy • h:mm a');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.teal,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.email, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Transactional Email Preview',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Email metadata headers
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderRow('From', 'Splitwise Notifications <notify@splitwise.clone>'),
                      const SizedBox(height: 4),
                      _buildHeaderRow('To', '${notif.recipientName} <${notif.recipientEmail}>'),
                      const SizedBox(height: 4),
                      _buildHeaderRow('Subject', notif.title),
                      const SizedBox(height: 4),
                      _buildHeaderRow('Date', dateFormat.format(notif.timestamp)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Simulated Email Body Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppTheme.teal,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.call_split, color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Splitwise',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: AppTheme.charcoal,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Text(
                        'Hi ${notif.recipientName},',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        notif.body,
                        style: const TextStyle(fontSize: 14, height: 1.4, color: AppTheme.textDark),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.teal,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'View in Splitwise',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.teal,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 55,
          child: Text(
            '$label:',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 11, color: AppTheme.charcoal, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
