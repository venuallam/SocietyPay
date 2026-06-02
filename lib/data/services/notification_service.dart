import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  final _db  = FirebaseFirestore.instance;
  final _fcm = FirebaseMessaging.instance;

  // ── Initialize ──────────────────────────────────
  Future<void> initialize() async {
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final token = await _fcm.getToken();
    if (token != null) {
      _currentToken = token;
    }

    // Refresh token whenever FCM rotates it
    _fcm.onTokenRefresh.listen((t) {
      _currentToken = t;
    });

    // Foreground FCM message — badge updates automatically
    // via the Firestore stream; no extra action needed.
    FirebaseMessaging.onMessage.listen((_) {});
  }

  // ── Stream: notification tapped while app in background ─
  Stream<RemoteMessage> get onNotificationTap =>
      FirebaseMessaging.onMessageOpenedApp;

  // ── Check if app was launched by a notification tap ──────
  Future<RemoteMessage?> getInitialNotification() =>
      FirebaseMessaging.instance.getInitialMessage();

  String? _currentToken;
  String? get currentToken => _currentToken;

  // ── Save token for logged in user ───────────────
  Future<void> saveUserToken({
    required String userId,
    required String societyId,
  }) async {
    final token = await _fcm.getToken();
    if (token == null) return;
    _currentToken = token;

    await _db.collection('users').doc(userId)
        .update({
      'fcmToken':  token,
      'platform':  'android',
      'updatedAt': Timestamp.now(),
    });
  }

  // ── Send payment reminder ───────────────────────
  Future<Map<String, dynamic>>
  sendPaymentReminder({
    required String societyId,
    required String month,
    required String adminId,
  }) async {
    final billsSnap = await _db
        .collection('societies')
        .doc(societyId)
        .collection('bills')
        .where('month', isEqualTo: month)
        .where('status', isEqualTo: 'unpaid')
        .get();

    if (billsSnap.docs.isEmpty) {
      return {
        'sent':    0,
        'message': 'No unpaid bills for $month',
      };
    }

    final batch   = _db.batch();
    int sentCount = 0;

    for (final doc in billsSnap.docs) {
      final bill = doc.data();
      final uid  =
      bill['billingResponsibleId'] as String?;
      if (uid == null) continue;

      final userDoc = await _db
          .collection('users')
          .doc(uid)
          .get();
      final userData = userDoc.data();
      if (userData == null) continue;

      final name   =
          userData['name'] as String? ?? 'Resident';
      final flatNo =
          bill['flatNumber'] as String? ?? '';
      final amount =
      (bill['totalAmount'] as num? ?? 0)
          .toDouble();

      final notifRef = _db
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc();

      batch.set(notifRef, {
        'title': '🔔 Payment Reminder',
        'body':
        'Dear $name, your $month maintenance '
            'of ₹${amount.toStringAsFixed(0)} '
            'for $flatNo is pending.',
        'type':      'paymentReminder',
        'month':     month,
        'isRead':    false,
        'createdAt': Timestamp.now(),
      });

      sentCount++;
    }

    await batch.commit();

    await _saveNotificationHistory(
      societyId: societyId,
      title:     '🔔 Payment Reminder — $month',
      body:
      'Sent to $sentCount unpaid residents',
      type:      'paymentReminder',
      adminId:   adminId,
      sentTo:    sentCount,
    );

    return {
      'sent':    sentCount,
      'message':
      'Reminder sent to $sentCount residents',
    };
  }

  // ── Send announcement ───────────────────────────
  Future<int> sendAnnouncement({
    required String societyId,
    required String title,
    required String message,
    required String adminId,
  }) async {
    final usersSnap = await _db
        .collection('users')
        .where('societyId', isEqualTo: societyId)
        .get();

    final batch   = _db.batch();
    int sentCount = 0;

    for (final doc in usersSnap.docs) {
      final notifRef = _db
          .collection('users')
          .doc(doc.id)
          .collection('notifications')
          .doc();

      batch.set(notifRef, {
        'title':     '📢 $title',
        'body':      message,
        'type':      'announcement',
        'isRead':    false,
        'createdAt': Timestamp.now(),
      });
      sentCount++;
    }

    await batch.commit();

    await _saveNotificationHistory(
      societyId: societyId,
      title:     '📢 $title',
      body:      message,
      type:      'announcement',
      adminId:   adminId,
      sentTo:    sentCount,
    );

    return sentCount;
  }

  // ── Save notification history ───────────────────
  Future<void> _saveNotificationHistory({
    required String societyId,
    required String title,
    required String body,
    required String type,
    required String adminId,
    required int sentTo,
  }) async {
    await _db
        .collection('societies')
        .doc(societyId)
        .collection('notifications')
        .add({
      'title':     title,
      'body':      body,
      'type':      type,
      'sentBy':    adminId,
      'sentTo':    sentTo,
      'timestamp': Timestamp.now(),
    });
  }

  // ── Watch member notifications ──────────────────
  Stream<List<Map<String, dynamic>>>
  watchMyNotifications(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map((d) => {
      ...d.data(),
      'id': d.id,
    }).toList());
  }

  // ── Mark as read ────────────────────────────────
  Future<void> markAsRead({
    required String userId,
    required String notifId,
  }) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notifId)
        .update({'isRead': true});
  }

  // ── Mark all as read ────────────────────────────
  Future<void> markAllAsRead(
      String userId) async {
    final snap = await _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference,
          {'isRead': true});
    }
    await batch.commit();
  }

  // ── Watch unread count ──────────────────────────
  Stream<int> watchUnreadCount(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  // ── Watch notification history ──────────────────
  Stream<List<Map<String, dynamic>>>
  watchNotificationHistory(String societyId) {
    return _db
        .collection('societies')
        .doc(societyId)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map((d) => {
      ...d.data(),
      'id': d.id,
    }).toList());
  }
}

// ── Singleton ─────────────────────────────────────
final notificationService = NotificationService();