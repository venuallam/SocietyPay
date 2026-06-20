import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../data/services/notification_service.dart';
import '../../core/ads/banner_ad_widget.dart';

class MyNotificationsScreen extends StatelessWidget {
  const MyNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid =
        FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
          body: Center(
              child: Text('Not logged in')));
    }

    return Scaffold(
      bottomNavigationBar: const BannerAdWidget(),
      appBar: AppBar(
        title: const Text('My Notifications'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
              onPressed: () =>
                  notificationService
                      .markAllAsRead(uid),
              child: const Text(
                  'Mark all read',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12))),
        ],
      ),
      body: _MyNotifList(uid: uid),
    );
  }
}

class _MyNotifList extends StatelessWidget {
  final String uid;
  const _MyNotifList({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: notificationService
          .watchMyNotifications(uid),
      builder: (BuildContext context, AsyncSnapshot<List<Map<String, dynamic>>> snap) {
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
                Text('🔔',
                    style: TextStyle(
                        fontSize: 52)),
                SizedBox(height: 16),
                Text('No notifications yet',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color:
                        AppColors.textPrimary)),
                SizedBox(height: 8),
                Text(
                    'Society notifications will '
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
          const SizedBox(height: 8),
          itemBuilder: (ctx, i) {
            final notif  = notifs[i];
            final id     =
                notif['id'] as String? ?? '';
            final isRead =
                notif['isRead'] as bool? ?? false;
            final type   =
                notif['type'] as String? ?? '';
            final ts     = notif['createdAt'];
            final date   = ts != null
                ? DateFormat('d MMM, h:mm a')
                .format(
                (ts as dynamic).toDate())
                : '';

            return GestureDetector(
              onTap: () {
                if (!isRead) {
                  notificationService.markAsRead(
                    userId:  uid,
                    notifId: id,
                  );
                }
              },
              child: Container(
                padding:
                const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: isRead
                        ? Colors.white
                        : AppColors.accentLight,
                    borderRadius:
                    BorderRadius.circular(12),
                    border: Border.all(
                        color: isRead
                            ? AppColors.border
                            : AppColors.accent
                            .withOpacity(0.3))),
                child: Row(children: [
                  if (!isRead)
                    Container(
                        width: 8, height: 8,
                        margin:
                        const EdgeInsets
                            .only(right: 10),
                        decoration:
                        const BoxDecoration(
                            color: AppColors.accent,
                            shape:
                            BoxShape.circle)),
                  Text(
                      switch (type) {
                        'paymentReminder' => '🔔',
                        'announcement'   => '📢',
                        _                => '📬',
                      },
                      style: const TextStyle(
                          fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                          notif['title']
                          as String? ?? '',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: isRead
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                              color: AppColors
                                  .textPrimary),
                          maxLines: 1,
                          overflow:
                          TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(
                          notif['body']
                          as String? ?? '',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors
                                  .textSecondary),
                          maxLines: 3,
                          overflow:
                          TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Text(date,
                          style: const TextStyle(
                              fontSize: 10,
                              color:
                              AppColors.textMuted)),
                    ],
                  )),
                ]),
              ),
            );
          },
        );
      },
    );
  }
}