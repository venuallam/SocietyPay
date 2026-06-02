import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/constants/app_constants.dart';
import '../../data/services/notification_service.dart';
import 'notification_history_screen.dart';

class SendNotificationScreen extends StatefulWidget {
  final String societyId;

  const SendNotificationScreen({
    super.key,
    required this.societyId,
  });

  @override
  State<SendNotificationScreen> createState() =>
      _SendNotificationScreenState();
}

class _SendNotificationScreenState
    extends State<SendNotificationScreen> {
  final _titleCtrl   = TextEditingController();
  final _messageCtrl = TextEditingController();

  _NotifType _type = _NotifType.reminder;
  bool   _sending  = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error   = null;
      _success = null;
    });

    try {
      final adminId =
          FirebaseAuth.instance.currentUser!.uid;

      if (_type == _NotifType.reminder) {
        final now    = DateTime.now();
        const months = [
          'JAN','FEB','MAR','APR','MAY','JUN',
          'JUL','AUG','SEP','OCT','NOV','DEC',
        ];
        final month =
            '${months[now.month - 1]}-${now.year}';

        final result = await notificationService
            .sendPaymentReminder(
          societyId: widget.societyId,
          month:     month,
          adminId:   adminId,
        );

        setState(() =>
        _success = '✅ ${result['message']}');

      } else {
        final title   = _titleCtrl.text.trim();
        final message = _messageCtrl.text.trim();

        if (title.isEmpty) {
          setState(() {
            _error   = 'Enter a title';
            _sending = false;
          });
          return;
        }
        if (message.isEmpty) {
          setState(() {
            _error   = 'Enter a message';
            _sending = false;
          });
          return;
        }

        final count = await notificationService
            .sendAnnouncement(
          societyId: widget.societyId,
          title:     title,
          message:   message,
          adminId:   adminId,
        );

        setState(() {
          _success =
          '✅ Announcement sent to '
              '$count members';
          _titleCtrl.clear();
          _messageCtrl.clear();
        });
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Notification'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [

            // ── Type selector ──────────────────────
            const Text('NOTIFICATION TYPE',
                style: AppText.label),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _TypeCard(
                icon:  '🔔',
                title: 'Payment Reminder',
                desc:
                'Send to all unpaid residents',
                selected:
                _type == _NotifType.reminder,
                onTap: () => setState(() =>
                _type = _NotifType.reminder),
              )),
              const SizedBox(width: 10),
              Expanded(child: _TypeCard(
                icon:  '📢',
                title: 'Announcement',
                desc:  'Send to all members',
                selected:
                _type == _NotifType.announcement,
                onTap: () => setState(() =>
                _type = _NotifType.announcement),
              )),
            ]),

            const SizedBox(height: 20),

            // ── Reminder info card ─────────────────
            if (_type == _NotifType.reminder)
              _InfoCard(
                icon:  '🔔',
                title: 'Payment Reminder',
                points: const [
                  'Sent to all unpaid residents',
                  'Includes flat number and amount',
                  'Stored as in-app notification',
                  'Only for current month',
                ],
                color:   AppColors.warning,
                bgColor: AppColors.warningLight,
              ),

            // ── Announcement form ──────────────────
            if (_type == _NotifType.announcement)
              Card(child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    const Text('TITLE',
                        style: AppText.label),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _titleCtrl,
                      decoration:
                      const InputDecoration(
                          hintText:
                          'e.g. Society Meeting',
                          prefixIcon: Icon(
                              Icons.title)),
                    ),
                    const SizedBox(height: 16),
                    const Text('MESSAGE',
                        style: AppText.label),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _messageCtrl,
                      maxLines: 4,
                      decoration:
                      const InputDecoration(
                        hintText:
                        'e.g. Society meeting '
                            'on 15th June at 6PM '
                            'in the community hall.',
                      ),
                    ),
                  ],
                ),
              )),

            const SizedBox(height: 16),

            // ── Delivery info ──────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius:
                  BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  const Text('📱 Delivery Info',
                      style: AppText.h4),
                  const SizedBox(height: 10),
                  _DeliveryRow(
                      icon:  '🔔',
                      label: 'In-app notification',
                      value: 'All members'),
                  _DeliveryRow(
                      icon:  '📲',
                      label: 'Push notification',
                      value:
                      'Android (if app installed)'),
                  _DeliveryRow(
                      icon:  '📋',
                      label: 'Saved in history',
                      value: 'Yes'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Error message ──────────────────────
            if (_error != null)
              Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: AppColors.dangerLight,
                      borderRadius:
                      BorderRadius.circular(10)),
                  child: Text(_error!,
                      style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 13))),

            // ── Success message ────────────────────
            if (_success != null)
              Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: AppColors.successLight,
                      borderRadius:
                      BorderRadius.circular(10)),
                  child: Text(_success!,
                      style: const TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                          fontSize: 13))),

            const SizedBox(height: 16),

            // ── Send button ────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _sending ? null : _send,
                child: _sending
                    ? const SizedBox(
                    width: 20, height: 20,
                    child:
                    CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white))
                    : Text(_type ==
                    _NotifType.reminder
                    ? '🔔 Send Payment Reminders'
                    : '📢 Send Announcement'),
              ),
            ),

            const SizedBox(height: 12),

            // ── History button ─────────────────────
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            NotificationHistoryScreen(
                              societyId:
                              widget.societyId,
                            ))),
                child: const Row(
                  mainAxisAlignment:
                  MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history),
                    SizedBox(width: 8),
                    Text(
                        'View Notification History'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ── Enums ─────────────────────────────────────────
enum _NotifType { reminder, announcement }

// ── Supporting Widgets ────────────────────────────
class _TypeCard extends StatelessWidget {
  final String icon, title, desc;
  final bool selected;
  final VoidCallback onTap;

  const _TypeCard({
    required this.icon,
    required this.title,
    required this.desc,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: selected
                  ? AppColors.accentLight
                  : Colors.white,
              borderRadius:
              BorderRadius.circular(12),
              border: Border.all(
                  color: selected
                      ? AppColors.accent
                      : AppColors.border,
                  width: selected ? 2 : 1)),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(icon,
                  style: const TextStyle(
                      fontSize: 28)),
              const SizedBox(height: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 3),
              Text(desc,
                  style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary)),
              if (selected) ...[
                const SizedBox(height: 8),
                const Icon(Icons.check_circle,
                    color: AppColors.accent,
                    size: 18),
              ],
            ],
          ),
        ),
      );
}

class _InfoCard extends StatelessWidget {
  final String icon, title;
  final List<String> points;
  final Color color, bgColor;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.points,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: color.withOpacity(0.3))),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(icon,
                  style: const TextStyle(
                      fontSize: 20)),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ]),
            const SizedBox(height: 10),
            ...points.map((p) => Padding(
              padding:
              const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Icon(Icons.check_circle,
                    color: color, size: 14),
                const SizedBox(width: 8),
                Text(p,
                    style: TextStyle(
                        fontSize: 12,
                        color: color)),
              ]),
            )),
          ],
        ),
      );
}

class _DeliveryRow extends StatelessWidget {
  final String icon, label, value;
  const _DeliveryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Text(icon,
          style: const TextStyle(fontSize: 14)),
      const SizedBox(width: 8),
      Text('$label: ',
          style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary)),
      Text(value,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary)),
    ]),
  );
}