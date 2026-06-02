import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../data/services/notification_service.dart';

class NotificationHistoryScreen
    extends StatelessWidget {
  final String societyId;

  const NotificationHistoryScreen({
    super.key,
    required this.societyId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification History'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _HistoryList(societyId: societyId),
    );
  }
}

class _HistoryList extends StatelessWidget {
  final String societyId;
  const _HistoryList({required this.societyId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: notificationService
          .watchNotificationHistory(societyId),
      builder: (context,
          AsyncSnapshot<List<Map<String, dynamic>>>
          snap) {

        if (snap.connectionState ==
            ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary));
        }

        final notifs = snap.data ?? [];

        if (notifs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment:
              MainAxisAlignment.center,
              children: [
                Text('📬',
                    style: TextStyle(
                        fontSize: 52)),
                SizedBox(height: 16),
                Text(
                    'No notifications sent yet',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                SizedBox(height: 8),
                Text(
                    'Notifications you send will '
                        'appear here.',
                    style: TextStyle(
                        color:
                        AppColors.textSecondary)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: notifs.length,
          separatorBuilder: (_, __) =>
          const SizedBox(height: 10),
          itemBuilder: (ctx, i) =>
              _HistoryTile(notif: notifs[i]),
        );
      },
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final Map<String, dynamic> notif;
  const _HistoryTile({required this.notif});

  String _typeIcon(String type) =>
      switch (type) {
        'paymentReminder' => '🔔',
        'announcement'    => '📢',
        _                 => '📬',
      };

  Color _typeColor(String type) =>
      switch (type) {
        'paymentReminder' => AppColors.warning,
        'announcement'    => AppColors.accent,
        _                 => AppColors.primary,
      };

  Color _typeBg(String type) =>
      switch (type) {
        'paymentReminder' => AppColors.warningLight,
        'announcement'    => AppColors.accentLight,
        _                 => AppColors.bgLight,
      };

  @override
  Widget build(BuildContext context) {
    final type  =
        notif['type'] as String? ?? '';
    final ts    = notif['timestamp'];
    final date  = ts != null
        ? DateFormat('d MMM yyyy, h:mm a')
        .format((ts as dynamic).toDate())
        : '';
    final sentTo =
        notif['sentTo'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: AppColors.border)),
      child: Row(children: [
        // Icon
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
              color: _typeBg(type),
              borderRadius:
              BorderRadius.circular(12)),
          child: Center(child: Text(
              _typeIcon(type),
              style: const TextStyle(
                  fontSize: 22))),
        ),
        const SizedBox(width: 12),

        // Details
        Expanded(child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
                notif['title'] as String? ?? '',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text(
                notif['body'] as String? ?? '',
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Row(children: [
              Container(
                  padding:
                  const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: _typeBg(type),
                      borderRadius:
                      BorderRadius.circular(20)),
                  child: Text(
                      '$sentTo recipients',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: _typeColor(type)))),
              const SizedBox(width: 6),
              Text(date,
                  style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted)),
            ]),
          ],
        )),

        // Sent badge
        Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius:
                BorderRadius.circular(20)),
            child: const Text('SENT',
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success))),
      ]),
    );
  }
}