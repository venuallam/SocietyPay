import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/dashboard_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../../data/repositories/corpus_repository.dart';
import '../../data/repositories/billing_repository.dart';
import '../../data/repositories/society_repository.dart';
import '../../core/ads/banner_ad_widget.dart';
import '../../data/services/notification_service.dart';
import '../notifications/my_notifications_screen.dart';
import '../flats/member_requests_screen.dart';
import '../expenses/expense_list_screen.dart';
import '../expenses/expense_approvals_screen.dart';
import '../expenses/add_expense_screen.dart';
import '../payments/payment_tracking_screen.dart';
import '../../main.dart';
import '../corpus/corpus_screen.dart';
import '../../data/models/user_model.dart';
import '../corpus/corpus_screen.dart';
import '../contacts/contacts_screen.dart';
import '../notifications/send_notification_screen.dart';
import '../voting/voting_screen.dart';
import 'package:share_plus/share_plus.dart';
import '../reports/reports_screen.dart';
import '../flats/flats_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  final String societyId;
  final String societyName;
  final String inviteCode;

  const AdminDashboardScreen({
    super.key,
    required this.societyId,
    required this.societyName,
    required this.inviteCode,
  });

  @override
  State<AdminDashboardScreen> createState() =>
      _AdminDashboardState();
}

class _AdminDashboardState
    extends State<AdminDashboardScreen> {
  final _repo        = DashboardRepository();
  final _corpusRepo  = CorpusRepository();
  DashboardStats? _stats;
  List<MonthlyCollection> _trend = [];
  bool _loading              = true;
  bool _prevMonthUnclosed    = false;
  late String _currentMonth;
  int _currentNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentMonth = _getMonth();
    _loadStats();
    // Persist FCM token so push delivery works
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      notificationService.saveUserToken(
        userId:    uid,
        societyId: widget.societyId,
      );
    }
    _setupNotificationTapHandlers();
    _loadAdminFlat();
  }

  void _setupNotificationTapHandlers() {
    // App was in background — admin tapped the notification
    notificationService.onNotificationTap.listen((_) {
      if (mounted) _openNotifications();
    });

    // App was terminated — admin tapped the notification
    notificationService.getInitialNotification().then((msg) {
      if (msg != null && mounted) _openNotifications();
    });
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => const MyNotificationsScreen()),
    );
  }

  String _getMonth() {
    final now    = DateTime.now();
    const months = [
      'JAN','FEB','MAR','APR','MAY','JUN',
      'JUL','AUG','SEP','OCT','NOV','DEC',
    ];
    return '${months[now.month - 1]}-${now.year}';
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _repo.getDashboardStats(
          societyId: widget.societyId,
          month:     _currentMonth,
        ),
        _corpusRepo.isPreviousMonthClosed(
            widget.societyId),
        _repo.getCollectionTrend(
            widget.societyId),
      ]);
      setState(() {
        _stats             = results[0] as DashboardStats;
        _prevMonthUnclosed = !(results[1] as bool);
        _trend = results[2] as List<MonthlyCollection>;
      });
    } catch (e) {
      debugPrint('Dashboard error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  // ── Remind every resident with outstanding dues ────
  Future<void> _remindDues() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(16)),
        title: const Text('Remind Defaulters'),
        content: const Text(
            'Send a dues reminder to every resident '
            'who has any unpaid or unconfirmed bill '
            '(across all months)?'),
        actions: [
          TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () =>
                  Navigator.pop(ctx, true),
              child: const Text('Send')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final n = await BillingRepository()
          .remindAllDefaulters(
        societyId: widget.societyId,
        adminId: FirebaseAuth
            .instance.currentUser!.uid,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(
            content: Text(n == 0
                ? '✅ No outstanding dues — '
                    'everyone is up to date!'
                : '🔔 Reminder sent to $n '
                    'resident(s) with dues'),
            backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.danger));
      }
    }
  }

  // ── Navigate and refresh dashboard on return ───────
  Future<void> _push(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    if (mounted) _loadStats();
  }

  Future<void> _logout() async {
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(20))),
      backgroundColor: Colors.white,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 20, 24,
            MediaQuery.of(ctx).padding.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius:
                  BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Container(
              width: 64, height: 64,
              decoration: const BoxDecoration(
                  color: AppColors.dangerLight,
                  shape: BoxShape.circle),
              child: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.danger,
                  size: 28),
            ),
            const SizedBox(height: 16),
            const Text('Logout?',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text(
                'You will be signed out and need '
                    'to log in again.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger),
                  child: const Text('Yes, Logout'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );

    if (confirm == true && mounted) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
              builder: (_) => const AuthWrapper()),
              (route) => false,
        );
      }
    }
  }

  String?               _adminFlatId;
  Map<String, dynamic>? _adminFlatDoc;
  String                _adminName = '';

  Future<void> _loadAdminFlat() async {
    final uid =
        FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final userDoc = await FirebaseFirestore
        .instance
        .collection('users')
        .doc(uid)
        .get();
    final data   = userDoc.data();
    final flatId = data?['flatId'] as String?;
    final name   = data?['name']   as String? ?? '';

    Map<String, dynamic>? flatDoc;
    if (flatId != null && flatId.isNotEmpty) {
      final snap = await FirebaseFirestore
          .instance
          .collection('societies')
          .doc(widget.societyId)
          .collection('flats')
          .doc(flatId)
          .get();
      flatDoc = snap.data();

      // Auto-repair: flat was linked before the fix
      // that sets ownerId/ownerName/status.
      // Update Firestore so Flats screen shows correctly.
      if (flatDoc != null) {
        final needsRepair =
            (flatDoc['ownerId'] == null ||
             flatDoc['status'] != 'occupied');
        if (needsRepair && uid != null) {
          final adminDisplayName =
              name.isNotEmpty ? name : 'Admin';
          await FirebaseFirestore.instance
              .collection('societies')
              .doc(widget.societyId)
              .collection('flats')
              .doc(flatId)
              .update({
            'status':               'occupied',
            'ownerId':              uid,
            'ownerName':            adminDisplayName,
            'billingResponsibleId': uid,
          });
          // Refresh flatDoc with repaired values
          flatDoc = {
            ...flatDoc,
            'status':               'occupied',
            'ownerId':              uid,
            'ownerName':            adminDisplayName,
            'billingResponsibleId': uid,
          };
        }
      }
    }

    if (mounted) {
      setState(() {
        _adminName    = name;
        _adminFlatId  = flatId ?? '';
        _adminFlatDoc = flatDoc;
      });
    }
  }

  void _onNavTap(int index) {
    if (index == 0 || index == 4) {
      setState(() => _currentNavIndex = index);
      return;
    }
    if (index == 1) {
      _push(ExpenseListScreen(
        societyId: widget.societyId,
        userRole:  UserRole.admin,
        userName:  'Admin',
      ));
    } else if (index == 2) {
      _push(PaymentTrackingScreen(
        societyId: widget.societyId,
      ));
    } else if (index == 3) {
      _push(ReportsScreen(
        societyId:   widget.societyId,
        societyName: widget.societyName,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _currentNavIndex == 4
          ? _AdminMyFlatTab(
              societyId:   widget.societyId,
              societyName: widget.societyName,
              inviteCode:  widget.inviteCode,
              adminName:   _adminName,
              adminFlatId: _adminFlatId,
              adminFlatDoc: _adminFlatDoc,
              onFlatLinked: (flatId) {
                setState(() =>
                _adminFlatId = flatId);
                _loadAdminFlat();
              },
              onLogout: _logout,
              // Refresh dashboard stats so Collected
              // updates after admin pays own bill.
              onBillPaid: _loadStats,
            )
          : RefreshIndicator(
        onRefresh: _loadStats,
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [

            // ── App Bar ─────────────────────────────
            SliverAppBar(
              expandedHeight: 220,
              pinned: true,
              automaticallyImplyLeading: false,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primaryDark,
                        AppColors.primary,
                      ],
                    ),
                  ),
                  // Content pushed to bottom —
                  // logout button lives in the toolbar
                  // (top), so no overlap possible.
                  padding: const EdgeInsets
                      .fromLTRB(20, 56, 20, 16),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    mainAxisAlignment:
                    MainAxisAlignment.end,
                    children: [
                      Text(
                        _greeting(),
                        style: TextStyle(
                            color: Colors.white
                                .withOpacity(0.65),
                            fontSize: 13),
                      ),
                      Text(
                        widget.societyName,
                        maxLines: 2,
                        overflow:
                        TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight:
                            FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      // Admin badge + month — same row,
                      // left side only, clear of logout
                      Row(children: [
                        Container(
                          padding:
                          const EdgeInsets
                              .symmetric(
                              horizontal: 8,
                              vertical: 3),
                          decoration: BoxDecoration(
                              color: Colors.white
                                  .withOpacity(0.15),
                              borderRadius:
                              BorderRadius
                                  .circular(20)),
                          child: const Text(
                              '👑 Admin',
                              style: TextStyle(
                                  color:
                                  Colors.white,
                                  fontSize: 11,
                                  fontWeight:
                                  FontWeight.w600)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding:
                          const EdgeInsets
                              .symmetric(
                              horizontal: 8,
                              vertical: 3),
                          decoration: BoxDecoration(
                              color: Colors.white
                                  .withOpacity(0.12),
                              borderRadius:
                              BorderRadius
                                  .circular(20)),
                          child: Text(
                              _currentMonth,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight:
                                  FontWeight.w600)),
                        ),
                      ]),
                      const SizedBox(height: 14),
                      // Invite code chip
                      GestureDetector(
                        onTap: () =>
                            _showInviteCode(context),
                        child: Container(
                          padding:
                          const EdgeInsets
                              .symmetric(
                              horizontal: 14,
                              vertical: 8),
                          decoration: BoxDecoration(
                              color: Colors.white
                                  .withOpacity(0.12),
                              borderRadius:
                              BorderRadius
                                  .circular(10),
                              border: Border.all(
                                  color: Colors.white
                                      .withOpacity(0.2))),
                          child: Row(children: [
                            const Icon(
                                Icons.share,
                                color: Colors.white,
                                size: 16),
                            const SizedBox(width: 8),
                            Text(
                                'Invite Code: '
                                    '${widget.inviteCode}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight:
                                    FontWeight.w700,
                                    letterSpacing: 2)),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Body ────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([

                  // ── Alert Banners ──────────────────
                  // Previous month unclosed warning
                  if (_prevMonthUnclosed)
                    GestureDetector(
                      onTap: () => _push(CorpusScreen(
                        societyId: widget.societyId,
                        userRole:  UserRole.admin,
                      )),
                      child: const _AlertBanner(
                        icon:    '📅',
                        message: 'Previous month not closed yet — '
                            'tap to open Corpus & run Month-End',
                        color:   AppColors.warning,
                        bgColor: AppColors.warningLight,
                      ),
                    ),

                  if (_stats != null) ...[
                    // Member requests alert
                    if (_stats!.pendingRequests > 0)
                      GestureDetector(
                        onTap: () => _push(
                            MemberRequestsScreen(
                                societyId:
                                widget.societyId,
                                adminId: FirebaseAuth
                                    .instance
                                    .currentUser!
                                    .uid)),
                        child: _AlertBanner(
                            icon: '👥',
                            message:
                            '${_stats!.pendingRequests}'
                                ' member request(s) '
                                'pending approval',
                            color: AppColors.warning,
                            bgColor:
                            AppColors.warningLight),
                      ),

                    // Expense approvals alert
                    if (_stats!.pendingExpenses > 0)
                      GestureDetector(
                        onTap: () => _push(
                            ExpenseApprovalsScreen(
                                societyId:
                                widget.societyId,
                                adminId: FirebaseAuth
                                    .instance
                                    .currentUser!
                                    .uid)),
                        child: _AlertBanner(
                            icon: '💸',
                            message:
                            '${_stats!.pendingExpenses}'
                                ' expense(s) pending '
                                'approval',
                            color: AppColors.accent,
                            bgColor:
                            AppColors.accentLight),
                      ),

                    // Payment reports awaiting confirmation
                    if (_stats!.reportedPayments > 0)
                      GestureDetector(
                        onTap: () => _push(
                            PaymentTrackingScreen(
                                societyId:
                                widget.societyId)),
                        child: _AlertBanner(
                            icon: '💰',
                            message:
                            '${_stats!.reportedPayments}'
                                ' payment(s) reported — '
                                'tap to verify & confirm',
                            color: AppColors.success,
                            bgColor:
                            AppColors.successLight),
                      ),
                  ],

                  const SizedBox(height: 8),

                  // ── Stats ──────────────────────────
                  if (_loading)
                    const Center(
                        child: Padding(
                            padding: EdgeInsets.all(32),
                            child:
                            CircularProgressIndicator(
                                color:
                                AppColors.primary)))
                  else if (_stats != null) ...[
                    // Amount cards row — ₹ collected vs pending
                    Row(children: [
                      Expanded(child: _AmountCard(
                        label:   'Collected',
                        amount:
                        _stats!.totalCollected,
                        color:   AppColors.success,
                        bgColor:
                        AppColors.successLight,
                        icon:    '💰',
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _AmountCard(
                        label:   'Pending',
                        amount:  _stats!.totalPending,
                        color:   AppColors.danger,
                        bgColor: AppColors.dangerLight,
                        icon:    '⏳',
                      )),
                    ]),

                    const SizedBox(height: 12),

                    // ── Donut chart — replaces the old
                    //    flat-stats row + collection progress.
                    //    Shows Paid / Unpaid / Vacant counts
                    //    AND the collection % in one place.
                    _PaymentDonutChart(
                        stats: _stats!),

                    const SizedBox(height: 12),

                    // Month summary card
                    _MonthSummaryCard(stats: _stats!),

                    const SizedBox(height: 12),

                    // Corpus card — tappable
                    GestureDetector(
                      onTap: () => _push(CorpusScreen(
                        societyId: widget.societyId,
                        userRole:  UserRole.admin,
                      )),
                      child: _CorpusCard(
                          balance:
                          _stats!.corpusBalance),
                    ),

                    const SizedBox(height: 12),

                    // ── 6-month collection trend ──────
                    if (_trend.isNotEmpty)
                      _CollectionTrendChart(
                          trend: _trend),

                    const SizedBox(height: 16),
                  ],

                  // ── Quick Actions Grid ─────────────
                  const Text('Quick Actions',
                      style: AppText.h4),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics:
                    const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    children: [
                      _QuickAction(
                        icon:  '💸',
                        label: 'Add\nExpense',
                        onTap: () => _push(
                            AddExpenseScreen(
                              societyId:
                              widget.societyId,
                              userId: FirebaseAuth
                                  .instance
                                  .currentUser!.uid,
                              userName:
                              _adminName.isNotEmpty
                                  ? _adminName
                                  : 'Admin',
                              userRole:
                              UserRole.admin,
                            )),
                      ),
                      _QuickAction(
                        icon:  '🏦',
                        label: 'Corpus\nFund',
                        onTap: () => _push(CorpusScreen(
                          societyId: widget.societyId,
                          userRole:  UserRole.admin,
                        )),
                      ),
                      _QuickAction(
                        icon:  '🏠',
                        label: 'Flats',
                        onTap: () => _push(FlatsScreen(
                          societyId: widget.societyId,
                        )),
                      ),
                      _QuickAction(
                        icon:  '👥',
                        label: 'Pending\nRequests',
                        badgeCount: _stats
                            ?.pendingRequests ?? 0,
                        onTap: () => _push(MemberRequestsScreen(
                          societyId: widget.societyId,
                          adminId:   FirebaseAuth
                              .instance
                              .currentUser!.uid,
                        )),
                      ),
                      _QuickAction(
                        icon:  '🔔',
                        label: 'Send\nReminder',
                        onTap: () => _push(SendNotificationScreen(
                          societyId: widget.societyId,
                        )),
                      ),
                      _QuickAction(
                        icon:  '🗳️',
                        label: 'Voting',
                        onTap: () => _push(VotingScreen(
                          societyId: widget.societyId,
                          userRole:  UserRole.admin,
                          userName:  'Admin',
                        )),
                      ),
                      _QuickAction(
                        icon:  '📞',
                        label: 'Contacts',
                        onTap: () => _push(ContactsScreen(
                          societyId: widget.societyId,
                          userRole:  UserRole.admin,
                          userName:  'Admin',
                        )),
                      ),
                      _QuickAction(
                        icon:  '🔔',
                        label: 'My\nNotices',
                        onTap: () => _push(
                            const MyNotificationsScreen()),
                      ),
                      _QuickAction(
                        icon:  '📢',
                        label: 'Remind\nDues',
                        onTap: _remindDues,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Center(
                      child: BannerAdWidget()),
                  const SizedBox(height: 80),
                ]),
              ),
            ),
          ],
        ),
      ),

      // ── Bottom Navigation ───────────────────────────
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentNavIndex,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        onTap: _onNavTap,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.receipt_outlined),
              activeIcon: Icon(Icons.receipt),
              label: 'Expenses'),
          BottomNavigationBarItem(
              icon: Icon(Icons.payment_outlined),
              activeIcon: Icon(Icons.payment),
              label: 'Payments'),
          BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart),
              label: 'Reports'),
          BottomNavigationBarItem(
              icon: Icon(Icons.home_work_outlined),
              activeIcon: Icon(Icons.home_work),
              label: 'My Flat'),
        ],
      ),
    );
  }

  void _showInviteCode(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text(
            'Society Invite Code',
            style: TextStyle(
                fontWeight: FontWeight.w800),
            textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Share this code with residents:',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius:
                  BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.accent)),
              child: Text(
                widget.inviteCode,
                style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: 8),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
                'This code is permanent.',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted)),
          ],
        ),
        actions: [
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Share.share(
                    'Join ${widget.societyName} on SocietyPay!\n'
                    'Use invite code: ${widget.inviteCode}\n'
                    'Download the app and enter this code to join.',
                    subject: 'SocietyPay Invite Code',
                  );
                },
                icon: const Icon(Icons.share, size: 16),
                label: const Text('Share'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close')),
            ),
          ]),
        ],
      ),
    );
  }
}

// ── Supporting Widgets ────────────────────────────────────────────────────────
class _AlertBanner extends StatelessWidget {
  final String icon, message;
  final Color color, bgColor;

  const _AlertBanner({
    required this.icon,
    required this.message,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(
        horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: color.withOpacity(0.3))),
    child: Row(children: [
      Text(icon,
          style: const TextStyle(fontSize: 16)),
      const SizedBox(width: 8),
      Expanded(child: Text(message,
          style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600))),
      Icon(Icons.chevron_right,
          color: color, size: 18),
    ]),
  );
}

class _StatCard extends StatelessWidget {
  final String icon, label, value, sub;
  final bool accent;
  final Color? badgeColor;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    this.accent     = false,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
        color: accent
            ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: accent
                ? Colors.transparent
                : AppColors.border)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon,
            style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 6),
        Text(value,
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: accent
                    ? Colors.white
                    : AppColors.textPrimary)),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: accent
                    ? Colors.white.withOpacity(0.7)
                    : AppColors.textMuted)),
      ],
    ),
  );
}

class _AmountCard extends StatelessWidget {
  final String label, icon;
  final double amount;
  final Color color, bgColor;

  const _AmountCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.bgColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon,
            style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 6),
        Text(
            '₹${NumberFormat('#,##0').format(amount)}',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color)),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: color.withOpacity(0.7),
                fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

class _CorpusCard extends StatelessWidget {
  final double balance;
  const _CorpusCard({required this.balance});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border)),
    child: Row(children: [
      Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
            color: AppColors.accentLight,
            borderRadius: BorderRadius.circular(12)),
        child: const Center(child: Text('🏦',
            style: TextStyle(fontSize: 24))),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Text('Corpus Fund',
              style: AppText.bodyBold),
          Text(
              balance < 0 ? 'Deficit!' : 'Healthy',
              style: TextStyle(
                  fontSize: 11,
                  color: balance < 0
                      ? AppColors.danger
                      : AppColors.success)),
        ],
      )),
      Text(
          '₹${NumberFormat('#,##0').format(balance)}',
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: balance < 0
                  ? AppColors.danger
                  : AppColors.textPrimary)),
    ]),
  );
}

class _CollectionProgress extends StatelessWidget {
  final DashboardStats stats;
  const _CollectionProgress({required this.stats});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment:
          MainAxisAlignment.spaceBetween,
          children: [
            const Text('Collection Progress',
                style: AppText.h4),
            Text(
                '${stats.collectionPercentage.toStringAsFixed(0)}%',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary)),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value:
            stats.collectionPercentage / 100,
            minHeight: 10,
            backgroundColor: AppColors.border,
            valueColor:
            const AlwaysStoppedAnimation(
                AppColors.success),
          ),
        ),
        const SizedBox(height: 8),
        Text(
            '${stats.paidFlats} of '
                '${stats.totalFlats - stats.vacantFlats}'
                ' occupied flats paid',
            style: AppText.small),
      ],
    ),
  );
}

class _MonthSummaryCard extends StatelessWidget {
  final DashboardStats stats;
  const _MonthSummaryCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final net        = stats.monthlyNet;
    final isPositive = net >= 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
            children: [
              const Text('This Month',
                  style: AppText.h4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: isPositive
                        ? AppColors.successLight
                        : AppColors.dangerLight,
                    borderRadius:
                    BorderRadius.circular(20)),
                child: Text(
                    '${isPositive ? '+' : ''}₹${NumberFormat('#,##0').format(net)}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isPositive
                            ? AppColors.success
                            : AppColors.danger)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Row: Accumulation | Expenses
          Row(children: [
            // Month accumulation
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius:
                    BorderRadius.circular(10)),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    const Text('📥',
                        style: TextStyle(
                            fontSize: 18)),
                    const SizedBox(height: 6),
                    Text(
                        '₹${NumberFormat('#,##0').format(stats.totalCollected)}',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.success)),
                    const SizedBox(height: 2),
                    const Text(
                        'Accumulation',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Approved expenses
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: AppColors.warningLight,
                    borderRadius:
                    BorderRadius.circular(10)),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    const Text('💸',
                        style: TextStyle(
                            fontSize: 18)),
                    const SizedBox(height: 6),
                    Text(
                        '₹${NumberFormat('#,##0').format(stats.monthlyApprovedExpenses)}',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.warning)),
                    const SizedBox(height: 2),
                    const Text(
                        'Approved Expenses',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.warning)),
                  ],
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final String icon, label;
  final VoidCallback onTap;
  final int badgeCount;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.border)),
          child: Stack(children: [
            Center(
              child: Column(
                mainAxisAlignment:
                MainAxisAlignment.center,
                children: [
                  Text(icon,
                      style: const TextStyle(
                          fontSize: 26)),
                  const SizedBox(height: 6),
                  Padding(
                    padding:
                    const EdgeInsets.symmetric(
                        horizontal: 4),
                    child: Text(label,
                        textAlign:
                        TextAlign.center,
                        maxLines: 2,
                        style: const TextStyle(
                            fontSize: 10,
                            color: AppColors
                                .textSecondary,
                            fontWeight:
                            FontWeight.w600)),
                  ),
                ],
              ),
            ),
            // Count badge
            if (badgeCount > 0)
              Positioned(
                top: 6, right: 6,
                child: Container(
                  constraints:
                  const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18),
                  padding:
                  const EdgeInsets.symmetric(
                      horizontal: 4),
                  decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius:
                      BorderRadius.circular(9),
                      border: Border.all(
                          color: Colors.white,
                          width: 1.5)),
                  child: Center(
                    child: Text(
                        badgeCount > 99
                            ? '99+'
                            : '$badgeCount',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight:
                            FontWeight.w800)),
                  ),
                ),
              ),
          ]),
        ),
      );
}

// ── Admin My Flat Tab ─────────────────────────────────────────────────────────
class _AdminMyFlatTab extends StatefulWidget {
  final String societyId;
  final String societyName;
  final String inviteCode;
  final String adminName;
  final String? adminFlatId;
  final Map<String, dynamic>? adminFlatDoc;
  final ValueChanged<String> onFlatLinked;
  final VoidCallback onLogout;
  final VoidCallback onBillPaid;

  const _AdminMyFlatTab({
    required this.societyId,
    required this.societyName,
    required this.inviteCode,
    required this.adminName,
    required this.adminFlatId,
    required this.adminFlatDoc,
    required this.onFlatLinked,
    required this.onLogout,
    required this.onBillPaid,
  });

  @override
  State<_AdminMyFlatTab> createState() =>
      _AdminMyFlatTabState();
}

class _AdminMyFlatTabState
    extends State<_AdminMyFlatTab> {
  bool _linking    = false;
  bool _billLoading = false;
  String? _linkError;
  Map<String, dynamic>? _billData;

  @override
  void initState() {
    super.initState();
    if (_hasFlat) _loadBill();
  }

  @override
  void didUpdateWidget(_AdminMyFlatTab old) {
    super.didUpdateWidget(old);
    // Reload bill if flat was just linked
    if (old.adminFlatId != widget.adminFlatId
        && _hasFlat) {
      _loadBill();
    }
  }

  Future<void> _loadBill() async {
    final uid =
        FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !_hasFlat) return;

    setState(() => _billLoading = true);
    try {
      final month = _currentMonthStr();
      final snap = await FirebaseFirestore
          .instance
          .collection('societies')
          .doc(widget.societyId)
          .collection('bills')
          .where('billingResponsibleId',
          isEqualTo: uid)
          .where('month', isEqualTo: month)
          .limit(1)
          .get();

      setState(() {
        _billData = snap.docs.isNotEmpty
            ? {
          ...snap.docs.first.data(),
          'id': snap.docs.first.id,
        }
            : null;
      });
    } catch (_) {} finally {
      if (mounted) {
        setState(() => _billLoading = false);
      }
    }
  }

  // Admin marks their OWN bill paid (self-confirm)
  Future<void> _markOwnBillPaid() async {
    final uid =
        FirebaseAuth.instance.currentUser?.uid;
    final billId = _billData?['id'] as String?;
    if (uid == null || billId == null) return;

    setState(() => _billLoading = true);
    try {
      await BillingRepository().markAsPaid(
        societyId: widget.societyId,
        billId:    billId,
        adminId:   uid,
      );
      await _loadBill();
      // Refresh dashboard so Collected updates
      widget.onBillPaid();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(
            content: Text(
                '✅ Your bill marked as paid'),
            backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.danger));
      }
    } finally {
      if (mounted) {
        setState(() => _billLoading = false);
      }
    }
  }

  // ── Transfer admin role to another member ─────────
  Future<void> _transferAdmin() async {
    final uid =
        FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final repo = SocietyRepository();
    final candidates =
        await repo.getTransferCandidates(
            widget.societyId);

    if (!mounted) return;

    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(
          content: Text(
              'No eligible members yet. '
              'Members must join and be approved '
              'first.')));
      return;
    }

    // Pick the new admin
    final selected =
    await showModalBottomSheet<
        Map<String, dynamic>>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, ctrl) => Column(children: [
          Container(
            margin:
            const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius:
                BorderRadius.circular(2)),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
                'Choose New Admin',
                style: AppText.h4),
          ),
          Expanded(
            child: ListView.separated(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(
                  16, 0, 16, 24),
              itemCount: candidates.length,
              separatorBuilder: (_, __) =>
              const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final c = candidates[i];
                final name = c['name']
                as String? ?? 'Member';
                final role = c['role']
                as String? ?? 'owner';
                return GestureDetector(
                  onTap: () =>
                      Navigator.pop(ctx, c),
                  child: Container(
                    padding:
                    const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                        BorderRadius.circular(
                            12),
                        border: Border.all(
                            color: AppColors
                                .border)),
                    child: Row(children: [
                      Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                            color: AppColors
                                .accentLight,
                            shape:
                            BoxShape.circle),
                        child: Center(
                          child: Text(
                            name.isNotEmpty
                                ? name[0]
                                .toUpperCase()
                                : '?',
                            style: const TextStyle(
                                fontWeight:
                                FontWeight.w800,
                                color: AppColors
                                    .primary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                        children: [
                          Text(name,
                              style: AppText
                                  .bodyBold),
                          Text(role,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors
                                      .textMuted)),
                        ],
                      )),
                      const Icon(
                          Icons.chevron_right,
                          color: AppColors
                              .textMuted),
                    ]),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );

    if (selected == null || !mounted) return;

    final newName =
        selected['name'] as String? ?? 'Member';

    // Confirm
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(16)),
        title: const Text(
            '⚠️ Transfer Admin Role',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17)),
        content: Text(
            'Make $newName the new admin?\n\n'
            'You will become a regular resident '
            'and lose admin access immediately. '
            'This cannot be undone by you '
            'afterwards.'),
        actions: [
          TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () =>
                  Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor:
                  AppColors.danger),
              child: const Text(
                  'Yes, Transfer')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await repo.transferAdmin(
        societyId:  widget.societyId,
        newAdminId: selected['id'] as String,
        oldAdminId: uid,
      );
      if (mounted) {
        // Re-route — current user is now a resident
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
              builder: (_) =>
              const AuthWrapper()),
              (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.danger));
      }
    }
  }

  String _currentMonthStr() {
    final now = DateTime.now();
    const months = [
      'JAN','FEB','MAR','APR','MAY','JUN',
      'JUL','AUG','SEP','OCT','NOV','DEC',
    ];
    return '${months[now.month - 1]}-${now.year}';
  }

  // True when flatId is non-null and non-empty
  bool get _hasFlat =>
      widget.adminFlatId != null &&
          widget.adminFlatId!.isNotEmpty;

  Widget _buildLinkedFlatCard(
      BuildContext context) {
    final flatDoc    = widget.adminFlatDoc;
    final flatNumber = flatDoc?['flatNumber']
        as String? ?? widget.adminFlatId ?? '—';
    final flatType   =
        flatDoc?['flatTypeName'] as String? ?? '';
    final uid =
        FirebaseAuth.instance.currentUser?.uid;

    final isPaid =
        (_billData?['status'] as String?)
            == 'paid';
    final amount =
        (_billData?['totalAmount'] as num?)
            ?.toDouble() ?? 0;
    final month  =
        _billData?['month'] as String?
            ?? _currentMonthStr();
    final hasBill = _billData != null;

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        // ── Flat info card ─────────────────
        Container(
          margin: const EdgeInsets.symmetric(
              horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
              BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.border)),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius:
                  BorderRadius.circular(12)),
              child: const Icon(Icons.home,
                  color: Colors.white,
                  size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(flatNumber,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight:
                        FontWeight.w800,
                        color:
                        AppColors.textPrimary)),
                if (flatType.isNotEmpty)
                  Text(flatType,
                      style: const TextStyle(
                          fontSize: 12,
                          color:
                          AppColors.textMuted)),
              ],
            )),
          ]),
        ),

        const SizedBox(height: 10),

        // ── Bill card ─────────────────────
        Container(
          margin: const EdgeInsets.symmetric(
              horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: isPaid
                  ? AppColors.successLight
                  : AppColors.dangerLight,
              borderRadius:
              BorderRadius.circular(14),
              border: Border.all(
                  color: isPaid
                      ? AppColors.success
                      .withOpacity(0.4)
                      : AppColors.danger
                      .withOpacity(0.3))),
          child: _billLoading
              ? const Center(child: Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2)))
              : hasBill
              ? Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(month,
                          style: const TextStyle(
                              fontSize: 11,
                              color:
                              AppColors.textMuted,
                              fontWeight:
                              FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text(
                        '₹${amount.toStringAsFixed(0)}',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight:
                            FontWeight.w800,
                            color: isPaid
                                ? AppColors.success
                                : AppColors.danger),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                  const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4),
                  decoration: BoxDecoration(
                      color: isPaid
                          ? AppColors.success
                          : AppColors.danger,
                      borderRadius:
                      BorderRadius.circular(
                          20)),
                  child: Text(
                    isPaid ? '✓ Paid' : 'Unpaid',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight:
                        FontWeight.w700),
                  ),
                ),
              ]),
              if (!isPaid && uid != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _billLoading
                        ? null
                        : _markOwnBillPaid,
                    icon: const Icon(
                        Icons.check_circle_outline,
                        size: 18),
                    label: const Text(
                        'Mark as Paid'),
                    style:
                    ElevatedButton.styleFrom(
                        backgroundColor:
                        AppColors.success),
                  ),
                ),
              ],
            ],
          )
              : Row(children: [
            const Text('📋 ',
                style: TextStyle(fontSize: 16)),
            Text(
              'No bill for $month yet.',
              style: const TextStyle(
                  fontSize: 13,
                  color:
                  AppColors.textSecondary),
            ),
          ]),
        ),
      ],
    );
  }

  Future<void> _pickFlat() async {
    final snap = await FirebaseFirestore
        .instance
        .collection('societies')
        .doc(widget.societyId)
        .collection('flats')
        .orderBy('flatNumber')
        .get();

    if (!mounted) return;

    final selected =
    await showModalBottomSheet<
        Map<String, dynamic>>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, ctrl) => Column(
          children: [
            Container(
              margin:
              const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius:
                  BorderRadius.circular(2)),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select Your Flat',
                style: AppText.h4,
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: ctrl,
                padding:
                const EdgeInsets.fromLTRB(
                    16, 0, 16, 24),
                separatorBuilder: (_, __) =>
                const SizedBox(height: 8),
                itemCount: snap.docs.length,
                itemBuilder: (_, i) {
                  final doc = snap.docs[i];
                  final d = doc.data();
                  final flatNo =
                      d['flatNumber']
                      as String? ??
                          doc.id;
                  final type =
                      d['flatTypeName']
                      as String? ?? '';
                  return GestureDetector(
                    onTap: () =>
                        Navigator.pop(ctx, {
                          'id': doc.id,
                          ...d,
                        }),
                    child: Container(
                      padding:
                      const EdgeInsets
                          .all(14),
                      decoration:
                      BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                          BorderRadius
                              .circular(12),
                          border: Border.all(
                              color:
                              AppColors
                                  .border)),
                      child: Row(children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration:
                          BoxDecoration(
                              color: AppColors
                                  .accentLight,
                              borderRadius:
                              BorderRadius
                                  .circular(
                                  10)),
                          child: const Center(
                            child: Icon(
                                Icons
                                    .home_outlined,
                                color: AppColors
                                    .primary),
                          ),
                        ),
                        const SizedBox(
                            width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                          children: [
                            Text(flatNo,
                                style:
                                AppText
                                    .bodyBold),
                            if (type.isNotEmpty)
                              Text(type,
                                  style:
                                  const TextStyle(
                                      fontSize:
                                      12,
                                      color: AppColors
                                          .textMuted)),
                          ],
                        )),
                        const Icon(
                            Icons
                                .chevron_right,
                            color: AppColors
                                .textMuted),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (selected == null) return;

    setState(() {
      _linking  = true;
      _linkError = null;
    });
    try {
      final uid =
          FirebaseAuth.instance.currentUser!.uid;
      final flatId = selected['id'] as String;

      // Link flat to admin user
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'flatId': flatId});

      // Mark flat as occupied with admin as owner
      // so Flats screen shows admin as resident
      await FirebaseFirestore.instance
          .collection('societies')
          .doc(widget.societyId)
          .collection('flats')
          .doc(flatId)
          .update({
        'status':               'occupied',
        'ownerId':              uid,
        'ownerName':            widget.adminName
            .isNotEmpty
            ? widget.adminName
            : 'Admin',
        'billingResponsibleId': uid,
      });

      widget.onFlatLinked(flatId);
    } catch (e) {
      setState(() =>
      _linkError = e.toString());
    } finally {
      if (mounted) {
        setState(() => _linking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = FirebaseAuth.instance
        .currentUser?.phoneNumber ?? '';
    // Prefer stored name; fall back to phone
    final displayName = widget.adminName
        .isNotEmpty
        ? widget.adminName
        : phone;
    final initial = widget.adminName.isNotEmpty
        ? widget.adminName[0].toUpperCase()
        : widget.societyName.isNotEmpty
            ? widget.societyName[0].toUpperCase()
            : 'A';

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // ── Header ──────────────────────────
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primaryDark,
                AppColors.primary,
              ],
            ),
          ),
          padding: EdgeInsets.fromLTRB(
              24,
              MediaQuery.of(context)
                  .padding.top + 32,
              24, 32),
          child: Column(children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: Colors.white
                    .withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white
                        .withOpacity(0.4),
                    width: 2),
              ),
              child: Center(child: Text(
                initial,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight:
                    FontWeight.w800),
              )),
            ),
            const SizedBox(height: 14),
            // Admin's name (primary)
            Text(
              displayName.isNotEmpty
                  ? displayName
                  : 'Admin',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            // Society name (secondary)
            Text(
              widget.societyName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: Colors.white
                      .withOpacity(0.75),
                  fontSize: 13),
            ),
            const SizedBox(height: 8),
            Container(
              padding:
              const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.white
                      .withOpacity(0.15),
                  borderRadius:
                  BorderRadius.circular(
                      20)),
              child: const Text('👑 Admin',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight:
                      FontWeight.w600)),
            ),
          ]),
        ),

        const SizedBox(height: 20),

        // ── My Flat section ──────────────────
        const Padding(
          padding: EdgeInsets.symmetric(
              horizontal: 16),
          child: Text('My Flat',
              style: AppText.h4),
        ),
        const SizedBox(height: 10),

        if (widget.adminFlatId == null)
          // Still loading
          const Center(
              child: Padding(
                padding:
                EdgeInsets.all(16),
                child:
                CircularProgressIndicator(
                    color:
                    AppColors.primary),
              ))
        else if (_hasFlat)
          // Flat linked — show open button
          _buildLinkedFlatCard(context)
        else ...[
          // No flat linked yet
          Container(
            margin:
            const EdgeInsets.symmetric(
                horizontal: 16),
            padding:
            const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                BorderRadius.circular(14),
                border: Border.all(
                    color:
                    AppColors.border)),
            child: Column(children: [
              const Text('🏠',
                  style: TextStyle(
                      fontSize: 40)),
              const SizedBox(height: 10),
              const Text(
                'You haven\'t linked '
                    'your flat yet',
                textAlign:
                TextAlign.center,
                style: TextStyle(
                    fontWeight:
                    FontWeight.w700,
                    color:
                    AppColors
                        .textPrimary),
              ),
              const SizedBox(height: 4),
              const Text(
                'Link your flat to view '
                    'bills and use the '
                    'resident experience.',
                textAlign:
                TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    color:
                    AppColors
                        .textSecondary),
              ),
              const SizedBox(height: 14),
              if (_linkError != null)
                Padding(
                  padding:
                  const EdgeInsets
                      .only(bottom: 8),
                  child: Text(
                      _linkError!,
                      style:
                      const TextStyle(
                          color: AppColors
                              .danger,
                          fontSize: 12)),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _linking
                      ? null
                      : _pickFlat,
                  child: _linking
                      ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                      CircularProgressIndicator(
                          strokeWidth: 2,
                          color:
                          Colors.white))
                      : const Text(
                      '🔗 Link My Flat'),
                ),
              ),
            ]),
          ),
        ],

        const SizedBox(height: 20),

        // ── Account section ──────────────────
        const Padding(
          padding: EdgeInsets.symmetric(
              horizontal: 16),
          child: Text('Account',
              style: AppText.h4),
        ),
        const SizedBox(height: 10),

        _ProfileTile(
          icon: Icons.person_outline,
          label: 'Name',
          value: widget.adminName.isNotEmpty
              ? widget.adminName : '—',
        ),
        _ProfileTile(
          icon: Icons.phone_outlined,
          label: 'Phone',
          value: phone,
        ),
        _ProfileTile(
          icon: Icons.apartment_outlined,
          label: 'Society',
          value: widget.societyName,
        ),
        _ProfileTile(
          icon: Icons.vpn_key_outlined,
          label: 'Invite Code',
          value: widget.inviteCode,
          isCode: true,
        ),

        const SizedBox(height: 20),

        // ── Transfer admin role ──────────────
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 24),
          child: OutlinedButton.icon(
            onPressed: _transferAdmin,
            icon: const Icon(
                Icons.swap_horiz,
                color: AppColors.primary),
            label: const Text(
                'Transfer Admin Role',
                style: TextStyle(
                    color: AppColors.primary,
                    fontWeight:
                    FontWeight.w700)),
            style: OutlinedButton.styleFrom(
              minimumSize:
              const Size(double.infinity, 50),
              side: const BorderSide(
                  color: AppColors.primary),
              shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(12)),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ── Logout ───────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 24),
          child: OutlinedButton.icon(
            onPressed: widget.onLogout,
            icon: const Icon(
                Icons.logout,
                color: AppColors.danger),
            label: const Text('Logout',
                style: TextStyle(
                    color: AppColors.danger,
                    fontWeight:
                    FontWeight.w700)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(
                  double.infinity, 52),
              side: const BorderSide(
                  color: AppColors.danger),
              shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ── Shared Profile Tile ───────────────────────────────────────────────────────
class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isCode;

  const _ProfileTile({
    required this.icon,
    required this.label,
    required this.value,
    this.isCode = false,
  });

  @override
  Widget build(BuildContext context) =>
      Container(
        margin: const EdgeInsets.fromLTRB(
            16, 0, 16, 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
          BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.border),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
                color: AppColors.accentLight,
                borderRadius:
                BorderRadius.circular(10)),
            child: Icon(icon,
                color: AppColors.primary,
                size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11,
                        color:
                        AppColors.textMuted,
                        fontWeight:
                        FontWeight.w500)),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? '—' : value,
                  style: TextStyle(
                      fontSize: isCode ? 16 : 14,
                      fontWeight:
                      FontWeight.w700,
                      color:
                      AppColors.textPrimary,
                      letterSpacing:
                      isCode ? 3 : 0),
                ),
              ],
            ),
          ),
        ]),
      );
}

// ── Payment Status Donut Chart ────────────────────────────────────────────────
class _PaymentDonutChart extends StatefulWidget {
  final DashboardStats stats;
  const _PaymentDonutChart({required this.stats});

  @override
  State<_PaymentDonutChart> createState() =>
      _PaymentDonutChartState();
}

class _PaymentDonutChartState
    extends State<_PaymentDonutChart> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final stats   = widget.stats;
    final paid    = stats.paidFlats.toDouble();
    final unpaid  = stats.unpaidFlats.toDouble();
    final vacant  = stats.vacantFlats.toDouble();
    final total   = paid + unpaid + vacant;

    if (total == 0) return const SizedBox.shrink();

    final sections = [
      PieChartSectionData(
        value:        paid,
        color:        AppColors.success,
        title:        paid > 0
            ? '${stats.paidFlats}' : '',
        titleStyle:   const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 14),
        radius:       _touched == 0 ? 68 : 58,
        badgeWidget: _touched == 0
            ? _badge('Paid') : null,
        badgePositionPercentageOffset: 1.3,
      ),
      PieChartSectionData(
        value:       unpaid,
        color:       AppColors.danger,
        title:       unpaid > 0
            ? '${stats.unpaidFlats}' : '',
        titleStyle:  const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 14),
        radius:      _touched == 1 ? 68 : 58,
        badgeWidget: _touched == 1
            ? _badge('Unpaid') : null,
        badgePositionPercentageOffset: 1.3,
      ),
      PieChartSectionData(
        value:       vacant,
        color:       AppColors.border,
        title:       vacant > 0
            ? '${stats.vacantFlats}' : '',
        titleStyle:  const TextStyle(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w800,
            fontSize: 14),
        radius:      _touched == 2 ? 68 : 58,
        badgeWidget: _touched == 2
            ? _badge('Vacant') : null,
        badgePositionPercentageOffset: 1.3,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: AppColors.border)),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Text('Payment Status',
              style: AppText.h4),
          const SizedBox(height: 4),
          Text(stats.month,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted)),
          const SizedBox(height: 16),
          Row(children: [
            // Donut
            SizedBox(
              width: 150, height: 150,
              child: PieChart(PieChartData(
                sections:      sections,
                centerSpaceRadius: 38,
                sectionsSpace:  3,
                pieTouchData: PieTouchData(
                  touchCallback: (ev, res) {
                    setState(() {
                      _touched = (ev
                          is FlTapUpEvent ||
                          res == null ||
                          res.touchedSection ==
                              null)
                          ? -1
                          : res.touchedSection!
                          .touchedSectionIndex;
                    });
                  },
                ),
              )),
            ),
            const SizedBox(width: 20),
            // Legend
            Expanded(child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                _LegendItem(
                    color: AppColors.success,
                    label: 'Paid',
                    value: '${stats.paidFlats} flats'),
                const SizedBox(height: 10),
                _LegendItem(
                    color: AppColors.danger,
                    label: 'Unpaid',
                    value:
                    '${stats.unpaidFlats} flats'),
                const SizedBox(height: 10),
                _LegendItem(
                    color: AppColors.border,
                    label: 'Vacant',
                    value:
                    '${stats.vacantFlats} flats'),
                const SizedBox(height: 12),
                Container(
                  padding:
                  const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5),
                  decoration: BoxDecoration(
                    color: stats
                        .collectionPercentage >= 80
                        ? AppColors.successLight
                        : AppColors.warningLight,
                    borderRadius:
                    BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${stats.collectionPercentage
                        .toStringAsFixed(0)}% collected',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: stats
                            .collectionPercentage >= 80
                            ? AppColors.success
                            : AppColors.warning),
                  ),
                ),
              ],
            )),
          ]),
        ],
      ),
    );
  }

  Widget _badge(String label) => Container(
    padding: const EdgeInsets.symmetric(
        horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius:
        BorderRadius.circular(8)),
    child: Text(label,
        style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700)),
  );
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label, value;
  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) =>
      Row(children: [
        Container(
            width: 12, height: 12,
            decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted)),
            Text(value,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color:
                    AppColors.textPrimary)),
          ],
        )),
      ]);
}

// ── 6-Month Collection Bar Chart ──────────────────────────────────────────────
class _CollectionTrendChart extends StatelessWidget {
  final List<MonthlyCollection> trend;
  const _CollectionTrendChart({required this.trend});

  @override
  Widget build(BuildContext context) {
    // Max value for Y-axis scale
    final maxVal = trend.fold(0.0,
            (m, t) => t.billed > m ? t.billed : m);
    final yMax   = maxVal > 0
        ? (maxVal * 1.25).ceilToDouble()
        : 10000.0;

    final barGroups =
        trend.asMap().entries.map((e) {
          final i = e.key;
          final t = e.value;
          return BarChartGroupData(
            x: i,
            barRods: [
              // Billed (light, background)
              BarChartRodData(
                toY:   t.billed,
                color: AppColors.accentLight,
                width: 18,
                borderRadius:
                BorderRadius.circular(4),
              ),
              // Collected (solid, foreground)
              BarChartRodData(
                toY:   t.collected,
                color: AppColors.primary,
                width: 18,
                borderRadius:
                BorderRadius.circular(4),
              ),
            ],
            barsSpace: -18,
          );
        }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: AppColors.border)),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Expanded(
              child: Text('Collection Trend',
                  style: AppText.h4),
            ),
            // Legend
            Row(children: [
              Container(width: 10, height: 10,
                  decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius:
                      BorderRadius.circular(2))),
              const SizedBox(width: 4),
              const Text('Collected',
                  style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted)),
              const SizedBox(width: 10),
              Container(width: 10, height: 10,
                  decoration: BoxDecoration(
                      color: AppColors.accentLight,
                      borderRadius:
                      BorderRadius.circular(2))),
              const SizedBox(width: 4),
              const Text('Billed',
                  style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted)),
            ]),
          ]),
          const Text('Last 6 months',
              style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted)),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: BarChart(BarChartData(
              maxY:       yMax,
              barGroups:  barGroups,
              gridData:   FlGridData(
                drawVerticalLine: false,
                horizontalInterval: yMax / 4,
                getDrawingHorizontalLine: (_) =>
                    FlLine(
                        color: AppColors.border,
                        strokeWidth: 1),
              ),
              borderData:  FlBorderData(show: false),
              titlesData:  FlTitlesData(
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(
                        showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(
                        showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    interval: yMax / 4,
                    getTitlesWidget: (v, _) {
                      if (v == 0) {
                        return const Text('');
                      }
                      final k = v >= 1000
                          ? '${(v / 1000).toStringAsFixed(0)}k'
                          : v.toStringAsFixed(0);
                      return Text('₹$k',
                          style: const TextStyle(
                              fontSize: 9,
                              color:
                              AppColors.textMuted));
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) =>
                        Padding(
                          padding:
                          const EdgeInsets.only(
                              top: 6),
                          child: Text(
                            trend[v.toInt()].label,
                            style: const TextStyle(
                                fontSize: 10,
                                color: AppColors
                                    .textMuted,
                                fontWeight:
                                FontWeight.w600),
                          ),
                        ),
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData:
                BarTouchTooltipData(
                  getTooltipItem: (group, gI,
                      rod, rI) {
                    if (rI != 1) return null;
                    final t = trend[group.x];
                    return BarTooltipItem(
                      '${t.label}\n'
                          '₹${NumberFormat('#,##0').format(t.collected)} collected',
                      const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight:
                          FontWeight.w700),
                    );
                  },
                ),
              ),
            )),
          ),
        ],
      ),
    );
  }
}