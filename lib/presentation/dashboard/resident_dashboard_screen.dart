import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../main.dart';
import '../../data/models/user_model.dart';
import '../../data/services/notification_service.dart';
import '../corpus/corpus_screen.dart';
import '../contacts/contacts_screen.dart';
import '../expenses/expense_list_screen.dart';
import '../expenses/add_expense_screen.dart';
import '../../core/ads/banner_ad_widget.dart';
import '../payments/resident_bills_screen.dart';
import '../notifications/my_notifications_screen.dart';
import '../voting/voting_screen.dart';

class ResidentDashboardScreen extends StatefulWidget {
  final String userId;
  final String societyId;
  final String flatId;
  final String name;
  // When true, admin is viewing their own flat —
  // show a back-to-admin button.
  final bool isAdminView;

  const ResidentDashboardScreen({
    super.key,
    required this.userId,
    required this.societyId,
    required this.flatId,
    required this.name,
    this.isAdminView = false,
  });

  @override
  State<ResidentDashboardScreen> createState() =>
      _ResidentDashboardState();
}

class _ResidentDashboardState
    extends State<ResidentDashboardScreen> {
  Map<String, dynamic>? _flatData;
  Map<String, dynamic>? _societyData;
  Map<String, dynamic>? _billData;
  Map<String, dynamic>? _corpusData;
  double _monthApprovedExpenses  = 0;
  double _totalOutstanding       = 0;
  int    _outstandingCount       = 0;
  bool _loading = true;
  late String _currentMonth;
  int _currentNavIndex = 0;

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
                      backgroundColor:
                      AppColors.danger),
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

  @override
  void initState() {
    super.initState();
    _currentMonth = _getMonth();
    _loadData();
    // Persist FCM token so push delivery works
    notificationService.saveUserToken(
      userId:    widget.userId,
      societyId: widget.societyId,
    );
    _setupNotificationTapHandlers();
  }

  void _setupNotificationTapHandlers() {
    // App was in background — user tapped the notification
    notificationService.onNotificationTap.listen((_) {
      if (mounted) _openNotifications();
    });

    // App was terminated — user tapped the notification
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

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        // Flat data
        FirebaseFirestore.instance
            .collection('societies')
            .doc(widget.societyId)
            .collection('flats')
            .doc(widget.flatId)
            .get(),

        // Society data
        FirebaseFirestore.instance
            .collection('societies')
            .doc(widget.societyId)
            .get(),

        // All my bills (single-field filter, rules-safe).
        // Current-month bill + total outstanding are
        // derived from this client-side.
        FirebaseFirestore.instance
            .collection('societies')
            .doc(widget.societyId)
            .collection('bills')
            .where('billingResponsibleId',
            isEqualTo: widget.userId)
            .get(),

        // Corpus balance
        FirebaseFirestore.instance
            .collection('corpus')
            .doc(widget.societyId)
            .get(),

        // Society-wide approved expenses this month
        // (members are allowed to see society spending)
        FirebaseFirestore.instance
            .collection('societies')
            .doc(widget.societyId)
            .collection('expenses')
            .where('month', isEqualTo: _currentMonth)
            .where('status', isEqualTo: 'approved')
            .get(),
      ]);

      final flatSnap       = results[0] as DocumentSnapshot;
      final societySnap    = results[1] as DocumentSnapshot;
      final billsSnap      = results[2] as QuerySnapshot;
      final corpusSnap     = results[3] as DocumentSnapshot;
      final approvedExpSnap= results[4] as QuerySnapshot;

      final approvedExp = approvedExpSnap.docs.fold(0.0,
          (s, d) => s +
              ((d.data() as Map)['amount'] as num)
                  .toDouble());

      // Derive current-month bill + total outstanding
      Map<String, dynamic>? currentBill;
      double outstanding = 0;
      int    outstandingCount = 0;
      for (final d in billsSnap.docs) {
        final b = d.data() as Map<String, dynamic>;
        if (b['month'] == _currentMonth) {
          currentBill = b;
        }
        final st = b['status'];
        if (st != 'paid') {
          outstanding +=
              (b['totalAmount'] as num? ?? 0)
                  .toDouble();
          outstandingCount += 1;
        }
      }

      setState(() {
        _flatData    = flatSnap.data()
        as Map<String, dynamic>?;
        _societyData = societySnap.data()
        as Map<String, dynamic>?;
        _billData    = currentBill;
        _corpusData             = corpusSnap.data()
        as Map<String, dynamic>?;
        _monthApprovedExpenses  = approvedExp;
        _totalOutstanding       = outstanding;
        _outstandingCount       = outstandingCount;
      });
    } catch (e) {
      debugPrint('Resident dashboard error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  String _fmt(double v) =>
      NumberFormat('#,##0').format(v);

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _currentNavIndex == 4
          ? _ResidentProfileTab(
              name:    widget.name,
              flatId:  widget.flatId,
              flatData: _flatData,
              societyData: _societyData,
              onLogout: _logout,
            )
          : RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [

            // ── App Bar ─────────────────────────────
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              automaticallyImplyLeading: false,
              // Admin-as-resident: show back button
              leading: widget.isAdminView
                  ? IconButton(
                      icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white),
                      tooltip: 'Back to Admin',
                      onPressed: () =>
                          Navigator.pop(context),
                    )
                  : null,
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
                  padding:
                  const EdgeInsets.fromLTRB(
                      20, 56, 20, 16),
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
                        widget.name,
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
                      // Resident badge + month — left
                      // side only, clear of any actions
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
                          child: Text(
                              '🏠 Resident',
                              style: TextStyle(
                                  color: Colors
                                      .white
                                      .withOpacity(
                                      0.9),
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
                      // Society + Flat info
                      Container(
                        padding:
                        const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8),
                        decoration: BoxDecoration(
                            color: Colors.white
                                .withOpacity(0.12),
                            borderRadius:
                            BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.white
                                    .withOpacity(0.2))),
                        child: Row(children: [
                          const Icon(
                              Icons.apartment,
                              color: Colors.white,
                              size: 16),
                          const SizedBox(width: 8),
                          Text(
                              _societyData?['name']
                                  ?? 'My Society',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight:
                                  FontWeight.w600)),
                          const Spacer(),
                          const Icon(
                              Icons
                                  .door_front_door_outlined,
                              color: Colors.white,
                              size: 16),
                          const SizedBox(width: 6),
                          Text(
                              _flatData?['flatNumber']
                                  ?? '',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight:
                                  FontWeight.w700)),
                        ]),
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

                  // Admin-as-resident banner
                  if (widget.isAdminView)
                    Container(
                      margin: const EdgeInsets
                          .only(bottom: 12),
                      padding:
                      const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10),
                      decoration: BoxDecoration(
                          color: AppColors
                              .warningLight,
                          borderRadius:
                          BorderRadius
                              .circular(10),
                          border: Border.all(
                              color: AppColors
                                  .warning)),
                      child: const Row(children: [
                        Text('👑 ',
                            style: TextStyle(
                                fontSize: 16)),
                        Expanded(
                          child: Text(
                            'Viewing as resident '
                                '— your flat\'s '
                                'bills and details',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight:
                                FontWeight.w600,
                                color: AppColors
                                    .warning),
                          ),
                        ),
                      ]),
                    ),

                  if (_loading)
                    const Center(
                        child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(
                                color: AppColors.primary)))
                  else ...[

                    // ── Outstanding dues banner ──────
                    // Shows total arrears carried across
                    // all months, if any.
                    if (_outstandingCount > 0) ...[
                      GestureDetector(
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    ResidentBillsScreen(
                                      societyId:
                                      widget.societyId,
                                      userId:
                                      widget.userId,
                                      name: widget.name,
                                    ))),
                        child: Container(
                          width: double.infinity,
                          padding:
                          const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                              color: AppColors
                                  .dangerLight,
                              borderRadius:
                              BorderRadius.circular(
                                  12),
                              border: Border.all(
                                  color: AppColors
                                      .danger
                                      .withOpacity(
                                      0.3))),
                          child: Row(children: [
                            const Text('⚠️ ',
                                style: TextStyle(
                                    fontSize: 18)),
                            Expanded(child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                              children: [
                                Text(
                                  'Outstanding dues: '
                                  '₹${_fmt(_totalOutstanding)}',
                                  style:
                                  const TextStyle(
                                      fontSize: 14,
                                      fontWeight:
                                      FontWeight
                                          .w800,
                                      color: AppColors
                                          .danger),
                                ),
                                Text(
                                  'Across $_outstandingCount '
                                  'bill(s) · tap to pay',
                                  style:
                                  const TextStyle(
                                      fontSize: 11,
                                      color: AppColors
                                          .danger),
                                ),
                              ],
                            )),
                            const Icon(
                                Icons.chevron_right,
                                color: AppColors
                                    .danger),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // ── Current Bill Card ────────────
                    _BillCard(
                      billData:   _billData,
                      month:      _currentMonth,
                    ),

                    const SizedBox(height: 14),

                    // ── Corpus Balance ───────────────
                    // Corpus balance — tappable
                    if (_corpusData != null)
                      GestureDetector(
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => CorpusScreen(
                                  societyId: widget.societyId,
                                  userRole:  UserRole.owner,
                                ))),
                        child: _CorpusCard(
                            corpusData: _corpusData),
                      ),

                    const SizedBox(height: 14),

                    // ── Society spending this month ──
                    _SocietyMonthCard(
                      month:    _currentMonth,
                      expenses: _monthApprovedExpenses,
                    ),

                    const SizedBox(height: 14),

                    // ── Flat Info ────────────────────
                    _FlatInfoCard(
                      flatData:   _flatData,
                      societyId:  widget.societyId,
                    ),

                    const SizedBox(height: 14),

    // ── Quick Links ──────────────────────────────────
    const Text('Quick Access',
    style: AppText.h4),
    const SizedBox(height: 10),
    GridView.count(
    crossAxisCount: 3,
    shrinkWrap: true,
    physics:
    const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 10,
    crossAxisSpacing: 10,
    children: [
    _QuickLink(
    icon: '📞',
    label: 'Contacts',
    onTap: () => Navigator.push(
    context,
    MaterialPageRoute(
    builder: (_) => ContactsScreen(
    societyId: widget.societyId,
    userRole:  UserRole.owner,
    userName:  widget.name,
    ))),
    ),
    _QuickLink(
    icon: '💵',
    label: 'Suggest\nExpense',
    onTap: () => Navigator.push(
    context,
    MaterialPageRoute(
    builder: (_) => AddExpenseScreen(
    societyId: widget.societyId,
    userId:    widget.userId,
    userName:  widget.name,
    userRole:  UserRole.owner,
    ))),
    ),
    _QuickLink(
    icon: '🏦',
    label: 'Corpus',
    onTap: () => Navigator.push(
    context,
    MaterialPageRoute(
    builder: (_) => CorpusScreen(
    societyId: widget.societyId,
    userRole:  UserRole.owner,
    ))),
    ),
    _QuickLink(
    icon: '🗳️',
    label: 'Voting',
    onTap: () => Navigator.push(
    context,
    MaterialPageRoute(
    builder: (_) => VotingScreen(
    societyId: widget.societyId,
    userRole:  UserRole.owner,
    userName:  widget.name,
    ))),
    ),
    ],
    ),

                    const SizedBox(height: 16),
                    const Center(
                        child: BannerAdWidget()),
                    const SizedBox(height: 80),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),

      // ── Bottom Nav ──────────────────────────────────
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentNavIndex,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long),
              label: 'My Bills'),
          BottomNavigationBarItem(
              icon: Icon(Icons.notifications_outlined),
              activeIcon: Icon(Icons.notifications),
              label: 'Notices'),
          BottomNavigationBarItem(
              icon: Icon(Icons.receipt_outlined),
              activeIcon: Icon(Icons.receipt),
              label: 'Expenses'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile'),
        ],
        onTap: (i) {
          if (i == 0 || i == 4) {
            setState(() =>
            _currentNavIndex = i);
            return;
          }
          if (i == 1) {
            // My Bills
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ResidentBillsScreen(
                      societyId: widget.societyId,
                      userId:    widget.userId,
                      name:      widget.name,
                    )));
          }
          if (i == 2) {
            // Notices
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                    const MyNotificationsScreen()));
          }
          if (i == 3) {
            // Expenses (approved society expenses)
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ExpenseListScreen(
                      societyId: widget.societyId,
                      userRole:  UserRole.owner,
                      userName:  widget.name,
                    )));
          }
        },
      ),
    );
  }
}

// ── Bill Card ─────────────────────────────────────────────────────────────────
class _BillCard extends StatelessWidget {
  final Map<String, dynamic>? billData;
  final String month;

  const _BillCard({
    required this.billData,
    required this.month,
  });

  @override
  Widget build(BuildContext context) {
    if (billData == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border)),
        child: Column(children: [
          const Text('📋',
              style: TextStyle(fontSize: 36)),
          const SizedBox(height: 8),
          Text('No bill generated for $month',
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          const Text(
              'Contact your admin if you think\n'
                  'this is a mistake.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted)),
        ]),
      );
    }

    final isPaid   = billData!['status'] == 'paid';
    final total    = (billData!['totalAmount'] as num)
        .toDouble();
    final fixed    = (billData!['fixedAmount'] as num)
        .toDouble();
    final variable =
    (billData!['variableAmount'] as num? ?? 0)
        .toDouble();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isPaid
              ? [AppColors.success,
            const Color(0xFF1B5E20)]
              : [AppColors.primary,
            AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: [
        // Top section
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                      '$month Bill',
                      style: TextStyle(
                          color: Colors.white
                              .withOpacity(0.75),
                          fontSize: 13)),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4),
                    decoration: BoxDecoration(
                        color: isPaid
                            ? Colors.white
                            .withOpacity(0.2)
                            : Colors.white
                            .withOpacity(0.15),
                        borderRadius:
                        BorderRadius.circular(20)),
                    child: Text(
                        isPaid ? '✅ PAID' : '⏳ UNPAID',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight:
                            FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                  '₹${NumberFormat('#,##0').format(total)}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                  isPaid
                      ? 'Payment received. Thank you! 🙏'
                      : 'Please pay and inform your admin',
                  style: TextStyle(
                      color:
                      Colors.white.withOpacity(0.75),
                      fontSize: 12)),
            ],
          ),
        ),

        // Bottom breakdown
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.15),
              borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16))),
          child: Row(
            mainAxisAlignment:
            MainAxisAlignment.spaceAround,
            children: [
              _BillBreakdown(
                  label: 'Fixed',
                  amount: fixed),
              Container(
                  width: 1, height: 30,
                  color: Colors.white
                      .withOpacity(0.3)),
              _BillBreakdown(
                  label: 'Variable',
                  amount: variable),
              Container(
                  width: 1, height: 30,
                  color: Colors.white
                      .withOpacity(0.3)),
              _BillBreakdown(
                  label: 'Total',
                  amount: total,
                  isBold: true),
            ],
          ),
        ),
      ]),
    );
  }
}

class _BillBreakdown extends StatelessWidget {
  final String label;
  final double amount;
  final bool isBold;

  const _BillBreakdown({
    required this.label,
    required this.amount,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
          '₹${NumberFormat('#,##0').format(amount)}',
          style: TextStyle(
              color: Colors.white,
              fontWeight: isBold
                  ? FontWeight.w800
                  : FontWeight.w600,
              fontSize: isBold ? 16 : 14)),
      Text(
          label,
          style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 10)),
    ],
  );
}

// ── Corpus Card ───────────────────────────────────────────────────────────────
class _CorpusCard extends StatelessWidget {
  final Map<String, dynamic>? corpusData;
  const _CorpusCard({required this.corpusData});

  @override
  Widget build(BuildContext context) {
    final balance = corpusData != null
        ? (corpusData!['currentBalance'] as num)
        .toDouble()
        : 0.0;
    final isDeficit = balance < 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isDeficit
                  ? AppColors.danger
                  : AppColors.border)),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
              color: isDeficit
                  ? AppColors.dangerLight
                  : AppColors.accentLight,
              borderRadius:
              BorderRadius.circular(12)),
          child: Center(child: Text(
              isDeficit ? '⚠️' : '🏦',
              style: const TextStyle(fontSize: 22))),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            const Text('Corpus Fund',
                style: AppText.bodyBold),
            Text(
                isDeficit
                    ? 'In deficit'
                    : 'Society reserve fund',
                style: TextStyle(
                    fontSize: 11,
                    color: isDeficit
                        ? AppColors.danger
                        : AppColors.textMuted)),
          ],
        )),
        Text(
            isDeficit
                ? '-₹${NumberFormat('#,##0').format(balance.abs())}'
                : '₹${NumberFormat('#,##0').format(balance)}',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDeficit
                    ? AppColors.danger
                    : AppColors.textPrimary)),
      ]),
    );
  }
}

// ── Society Spending Card ─────────────────────────────────────────────────────
// Shows approved society expenses for the month. Residents
// cannot see other residents' collection totals (privacy +
// security rules), so this card focuses on spending
// transparency only.
class _SocietyMonthCard extends StatelessWidget {
  final String month;
  final double expenses;

  const _SocietyMonthCard({
    required this.month,
    required this.expenses,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
              color: AppColors.warningLight,
              borderRadius:
              BorderRadius.circular(12)),
          child: const Center(
              child: Text('💸',
                  style: TextStyle(fontSize: 22))),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            const Text('Society Spending',
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted)),
            const SizedBox(height: 2),
            Text(
                '₹${NumberFormat('#,##0').format(expenses)}',
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            Text('Approved expenses · $month',
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted)),
          ],
        )),
      ]),
    );
  }
}

// ── Flat Info Card ────────────────────────────────────────────────────────────
class _FlatInfoCard extends StatelessWidget {
  final Map<String, dynamic>? flatData;
  final String societyId;
  const _FlatInfoCard({
    required this.flatData,
    required this.societyId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('My Flat',
              style: AppText.h4),
          const SizedBox(height: 12),
          _InfoRow(
              icon: Icons.door_front_door_outlined,
              label: 'Flat Number',
              value: flatData?['flatNumber'] ?? '—'),
          const Divider(height: 16),
          _InfoRow(
              icon: Icons.home_work_outlined,
              label: 'Status',
              value: 'Occupied'),
          const Divider(height: 16),
          _InfoRow(
              icon: Icons.payment_outlined,
              label: 'Billing',
              value: flatData?['billingRole'] == 'owner'
                  ? 'You pay maintenance'
                  : flatData?['billingRole'] == 'tenant'
                  ? 'You pay maintenance'
                  : 'Set by admin'),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) =>
      Row(children: [
        Icon(icon,
            size: 18,
            color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Text(label, style: AppText.body),
        const Spacer(),
        Text(value, style: AppText.bodyBold),
      ]);
}

// ── Quick Link ────────────────────────────────────────────────────────────────
class _QuickLink extends StatelessWidget {
  final String icon, label;
  final VoidCallback onTap;
  const _QuickLink({
    required this.icon,
    required this.label,
    required this.onTap,
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
          child: Column(
            mainAxisAlignment:
            MainAxisAlignment.center,
            children: [
              Text(icon,
                  style: const TextStyle(fontSize: 26)),
              const SizedBox(height: 6),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
}

// ── Notices quick link with badge (#17) ─────────────────────────────────────
class _NotifQuickLink extends StatelessWidget {
  final String userId;
  final String societyId;
  const _NotifQuickLink({
    required this.userId,
    required this.societyId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: notificationService.watchUnreadCount(userId),
      builder: (context, snap) {
        final count = snap.data ?? 0;
        return GestureDetector(
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                  const MyNotificationsScreen())),
          child: Container(
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Centred content — fills the tile
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text('📢',
                          style: TextStyle(
                              fontSize: 26)),
                      SizedBox(height: 6),
                      Text(
                        'Notices',
                        textAlign:
                        TextAlign.center,
                        style: TextStyle(
                            fontSize: 10,
                            color:
                            AppColors.textSecondary,
                            fontWeight:
                            FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                // Badge — top-right corner
                if (count > 0)
                  Positioned(
                    top: 7, right: 7,
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
                          BorderRadius.circular(
                              9),
                          border: Border.all(
                              color: Colors.white,
                              width: 1.5)),
                      child: Center(child: Text(
                          count > 99
                              ? '99+'
                              : '$count',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight:
                              FontWeight.w800))),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NotifBell extends StatelessWidget {
  final String uid;
  const _NotifBell({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: notificationService
          .watchUnreadCount(uid),
      builder: (context,
          AsyncSnapshot<int> snap) {
        final count = snap.data ?? 0;
        return Stack(children: [
          IconButton(
            icon: const Icon(
                Icons.notifications_outlined,
                color: Colors.white),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                    const MyNotificationsScreen())),
          ),
          if (count > 0)
            Positioned(
                right: 6, top: 6,
                child: Container(
                  width: 16, height: 16,
                  decoration: const BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle),
                  child: Center(child: Text(
                      '$count',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight:
                          FontWeight.w800))),
                )),
        ]);
      },
    );
  }
}

// ── Profile Info Tile ─────────────────────────────────────────────────────────
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
                        color: AppColors.textMuted,
                        fontWeight:
                        FontWeight.w500)),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? '—' : value,
                  style: TextStyle(
                      fontSize:
                      isCode ? 16 : 14,
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

// ── Resident Profile Tab ──────────────────────────────────────────────────────
class _ResidentProfileTab extends StatelessWidget {
  final String name;
  final String flatId;
  final Map<String, dynamic>? flatData;
  final Map<String, dynamic>? societyData;
  final VoidCallback onLogout;

  const _ResidentProfileTab({
    required this.name,
    required this.flatId,
    required this.flatData,
    required this.societyData,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final phone = FirebaseAuth.instance
        .currentUser?.phoneNumber ?? '';
    final initial = name.isNotEmpty
        ? name[0].toUpperCase() : 'R';
    final flatNumber =
        flatData?['flatNumber'] as String?
            ?? flatId;
    final flatType =
        flatData?['flatTypeName'] as String?
            ?? '';
    final societyName =
        societyData?['name'] as String? ?? '';

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
              MediaQuery.of(context).padding.top + 32,
              24,
              32),
          child: Column(
            children: [
              // Avatar
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
                child: Center(
                  child: Text(initial,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight:
                          FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment:
                MainAxisAlignment.center,
                children: [
                  Container(
                    padding:
                    const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.white
                            .withOpacity(0.15),
                        borderRadius:
                        BorderRadius.circular(20)),
                    child: const Text(
                        '🏠 Resident',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight:
                            FontWeight.w600)),
                  ),
                  if (flatType.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding:
                      const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.white
                              .withOpacity(0.12),
                          borderRadius:
                          BorderRadius.circular(20)),
                      child: Text(
                          flatType,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight:
                              FontWeight.w600)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // ── Info tiles ───────────────────────
        _ProfileTile(
          icon: Icons.phone_outlined,
          label: 'Phone',
          value: phone,
        ),
        _ProfileTile(
          icon: Icons.home_outlined,
          label: 'Flat',
          value: flatNumber,
        ),
        if (societyName.isNotEmpty)
          _ProfileTile(
            icon: Icons.apartment_outlined,
            label: 'Society',
            value: societyName,
          ),

        const SizedBox(height: 32),

        // ── Logout ───────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 24),
          child: OutlinedButton.icon(
            onPressed: onLogout,
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