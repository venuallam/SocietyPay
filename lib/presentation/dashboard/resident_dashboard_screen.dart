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
import '../payments/resident_bills_screen.dart';
import '../notifications/my_notifications_screen.dart';
import '../voting/voting_screen.dart';

class ResidentDashboardScreen extends StatefulWidget {
  final String userId;
  final String societyId;
  final String flatId;
  final String name;

  const ResidentDashboardScreen({
    super.key,
    required this.userId,
    required this.societyId,
    required this.flatId,
    required this.name,
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
  double _monthAccumulation      = 0;
  double _monthApprovedExpenses  = 0;
  bool _loading = true;
  late String _currentMonth;

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

        // Current month bill
        FirebaseFirestore.instance
            .collection('societies')
            .doc(widget.societyId)
            .collection('bills')
            .where('flatId',
            isEqualTo: widget.flatId)
            .where('month',
            isEqualTo: _currentMonth)
            .limit(1)
            .get(),

        // Corpus balance
        FirebaseFirestore.instance
            .collection('corpus')
            .doc(widget.societyId)
            .get(),

        // Society-wide paid bills this month
        FirebaseFirestore.instance
            .collection('societies')
            .doc(widget.societyId)
            .collection('bills')
            .where('month', isEqualTo: _currentMonth)
            .where('status', isEqualTo: 'paid')
            .get(),

        // Society-wide approved expenses this month
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
      final paidBillsSnap  = results[4] as QuerySnapshot;
      final approvedExpSnap= results[5] as QuerySnapshot;

      final accumulation = paidBillsSnap.docs.fold(0.0,
          (s, d) => s +
              ((d.data() as Map)['totalAmount'] as num)
                  .toDouble());

      final approvedExp = approvedExpSnap.docs.fold(0.0,
          (s, d) => s +
              ((d.data() as Map)['amount'] as num)
                  .toDouble());

      setState(() {
        _flatData    = flatSnap.data()
        as Map<String, dynamic>?;
        _societyData = societySnap.data()
        as Map<String, dynamic>?;
        _billData    = billsSnap.docs.isNotEmpty
            ? billsSnap.docs.first.data()
        as Map<String, dynamic>
            : null;
        _corpusData             = corpusSnap.data()
        as Map<String, dynamic>?;
        _monthAccumulation      = accumulation;
        _monthApprovedExpenses  = approvedExp;
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
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [

            // ── App Bar ─────────────────────────────
            SliverAppBar(
              expandedHeight: 200,
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
                  padding:
                  const EdgeInsets.fromLTRB(
                      20, 60, 20, 16),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment
                            .spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                            children: [
                              Text(
                                  _greeting(),
                                  style: TextStyle(
                                      color: Colors
                                          .white
                                          .withOpacity(
                                          0.65),
                                      fontSize: 13)),
                              Text(
                                  widget.name,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight:
                                      FontWeight.w800)),
                              const SizedBox(height: 4),
                              // Role badge
                              Container(
                                padding:
                                const EdgeInsets
                                    .symmetric(
                                    horizontal: 8,
                                    vertical: 3),
                                decoration:
                                BoxDecoration(
                                    color: Colors
                                        .white
                                        .withOpacity(
                                        0.15),
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
                            ],
                          ),
                          // Month badge
                          Container(
                            padding:
                            const EdgeInsets
                                .symmetric(
                                horizontal: 12,
                                vertical: 6),
                            decoration: BoxDecoration(
                                color: Colors.white
                                    .withOpacity(0.15),
                                borderRadius:
                                BorderRadius
                                    .circular(20)),
                            child: Text(
                                _currentMonth,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight:
                                    FontWeight.w700)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
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
                                  ?? widget.flatId,
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
              actions: [
                IconButton(
                  icon: const Icon(
                      Icons.logout,
                      color: Colors.white),
                  onPressed: _logout,
                ),
              ],
            ),

            // ── Body ────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([

                  if (_loading)
                    const Center(
                        child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(
                                color: AppColors.primary)))
                  else ...[

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

                    // ── Society This Month ───────────
                    _SocietyMonthCard(
                      month:         _currentMonth,
                      accumulation:  _monthAccumulation,
                      expenses:      _monthApprovedExpenses,
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
    icon: '📊',
    label: 'Expenses',
    onTap: () => Navigator.push(
    context,
    MaterialPageRoute(
    builder: (_) => ExpenseListScreen(
    societyId: widget.societyId,
    userRole:  UserRole.owner,
    userName:  widget.name,
    userId:    widget.userId,
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
    _QuickLink(
    icon: '📄',
    label: 'My Bills',
    onTap: () => Navigator.push(
    context,
    MaterialPageRoute(
    builder: (_) =>
    ResidentBillsScreen(
    societyId: widget.societyId,
    userId:    widget.userId,
    name:      widget.name,
    ))),
    ),
    _NotifQuickLink(
    userId:    widget.userId,
    societyId: widget.societyId,
    ),
    ],
    ),

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
        currentIndex: 0,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
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
              label: 'Bills'),
          BottomNavigationBarItem(
              icon: Icon(Icons.phone_outlined),
              activeIcon: Icon(Icons.phone),
              label: 'Contacts'),
        ],
          onTap: (i) {
            if (i == 1) {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ExpenseListScreen(
                        societyId: widget.societyId,
                        userRole:  UserRole.owner,
                        userName:  widget.name,
                        userId:    widget.userId,
                      )));
            }
            if (i == 2) {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ResidentBillsScreen(
                        societyId: widget.societyId,
                        userId:    widget.userId,
                        name:      widget.name,
                      )));
            }
            if (i == 3) {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ContactsScreen(
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

// ── Society Month Card ────────────────────────────────────────────────────────
class _SocietyMonthCard extends StatelessWidget {
  final String month;
  final double accumulation;
  final double expenses;

  const _SocietyMonthCard({
    required this.month,
    required this.accumulation,
    required this.expenses,
  });

  @override
  Widget build(BuildContext context) {
    final net        = accumulation - expenses;
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
              const Text('Society This Month',
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
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isPositive
                            ? AppColors.success
                            : AppColors.danger)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(children: [
            // Accumulation
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
                        '₹${NumberFormat('#,##0').format(accumulation)}',
                        style: const TextStyle(
                            fontSize: 15,
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
                        '₹${NumberFormat('#,##0').format(expenses)}',
                        style: const TextStyle(
                            fontSize: 15,
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