import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/dashboard_model.dart';
import '../../data/repositories/dashboard_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../main.dart';
import '../flats/member_requests_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  final _repo = DashboardRepository();
  DashboardStats? _stats;
  bool _loading = true;
  late String _currentMonth;

  @override
  void initState() {
    super.initState();
    _currentMonth = _getMonth();
    _loadStats();
  }

  String _getMonth() {
    final now     = DateTime.now();
    const months  = [
      'JAN','FEB','MAR','APR','MAY','JUN',
      'JUL','AUG','SEP','OCT','NOV','DEC'
    ];
    return '${months[now.month - 1]}-${now.year}';
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final stats = await _repo.getDashboardStats(
        societyId: widget.societyId,
        month:     _currentMonth,
      );
      setState(() => _stats = stats);
    } catch (e) {
      debugPrint('Dashboard error: $e');
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
        onRefresh: _loadStats,
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [

            // ── App Bar ─────────────────────────────────────
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(
                    Icons.logout,
                    color: Colors.white),
                tooltip: 'Logout',
                onPressed: () async {
                  // Show confirmation dialog
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Logout'),
                      content: const Text(
                          'Are you sure you want to logout?'),
                      actions: [
                        TextButton(
                            onPressed: () =>
                                Navigator.pop(ctx, false),
                            child: const Text('Cancel')),
                        ElevatedButton(
                            onPressed: () =>
                                Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.danger),
                            child: const Text('Logout')),
                      ],
                    ),
                  );

                  if (confirm == true && mounted) {
                    await FirebaseAuth.instance.signOut();
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AuthWrapper()),
                          (route) => false,
                    );
                  }
                },
              ),
            ],


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
                  padding: const EdgeInsets.fromLTRB(
                      20, 60, 20, 16),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
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
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight:
                                    FontWeight.w800),
                              ),
                              Container(
                                margin: const EdgeInsets
                                    .only(top: 4),
                                padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white
                                      .withOpacity(0.15),
                                  borderRadius:
                                  BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '👑 Admin',
                                  style: TextStyle(
                                      color: Colors.white
                                          .withOpacity(0.9),
                                      fontSize: 11,
                                      fontWeight:
                                      FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          // Month badge
                          Container(
                            padding:
                            const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white
                                  .withOpacity(0.15),
                              borderRadius:
                              BorderRadius.circular(20),
                            ),
                            child: Text(
                              _currentMonth,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Invite code chip
                      GestureDetector(
                        onTap: () =>
                            _showInviteCode(context),
                        child: Container(
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
                                    .withOpacity(0.2)),
                          ),
                          child: Row(children: [
                            const Icon(
                                Icons.share,
                                color: Colors.white,
                                size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Invite Code: ${widget.inviteCode}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight:
                                  FontWeight.w700,
                                  letterSpacing: 2),
                            ),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Body ────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([

                  // Alerts
                  if (_stats != null) ...[
                    if (_stats!.pendingRequests > 0)
                      GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MemberRequestsScreen(
                                societyId: widget.societyId,
                                adminId:   FirebaseAuth
                                    .instance.currentUser!.uid,
                              ),
                            ),
                          ),
                          child: _AlertBanner(
                        icon: '👥',
                        message:
                        '${_stats!.pendingRequests} member request(s) pending approval',
                        color: AppColors.warning,
                        bgColor: AppColors.warningLight,
                       ),
                      ),
                    if (_stats!.pendingExpenses > 0)
                      _AlertBanner(
                        icon: '💸',
                        message:
                        '${_stats!.pendingExpenses} expense(s) pending approval',
                        color: AppColors.accent,
                        bgColor: AppColors.accentLight,
                      ),
                  ],

                  const SizedBox(height: 8),

                  // Stats cards row
                  if (_loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(
                            color: AppColors.primary),
                      ),
                    )
                  else if (_stats != null) ...[
                    // Collection stats
                    Row(children: [
                      Expanded(child: _StatCard(
                        icon: '✅',
                        label: 'Paid',
                        value: '${_stats!.paidFlats}',
                        sub: 'flats',
                        accent: true,
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _StatCard(
                        icon: '🔴',
                        label: 'Unpaid',
                        value: '${_stats!.unpaidFlats}',
                        sub: 'flats',
                        badgeColor: AppColors.danger,
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _StatCard(
                        icon: '🏠',
                        label: 'Vacant',
                        value: '${_stats!.vacantFlats}',
                        sub: 'flats',
                      )),
                    ]),

                    const SizedBox(height: 12),

                    // Amount cards
                    Row(children: [
                      Expanded(child: _AmountCard(
                        label: 'Collected',
                        amount: _stats!.totalCollected,
                        color: AppColors.success,
                        bgColor: AppColors.successLight,
                        icon: '💰',
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _AmountCard(
                        label: 'Pending',
                        amount: _stats!.totalPending,
                        color: AppColors.danger,
                        bgColor: AppColors.dangerLight,
                        icon: '⏳',
                      )),
                    ]),

                    const SizedBox(height: 12),

                    // Corpus card
                    _CorpusCard(
                        balance: _stats!.corpusBalance),

                    const SizedBox(height: 16),

                    // Collection progress
                    _CollectionProgress(
                        stats: _stats!),

                    const SizedBox(height: 16),
                  ],

                  // Quick Actions
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
                        icon: '💸',
                        label: 'Add\nExpense',
                        onTap: () {},
                      ),
                      _QuickAction(
                        icon: '🔔',
                        label: 'Send\nReminder',
                        onTap: () {},
                      ),
                      _QuickAction(
                        icon: '🏦',
                        label: 'Corpus\nFund',
                        onTap: () {},
                      ),
                      _QuickAction(
                        icon: '📊',
                        label: 'Reports',
                        onTap: () {},
                      ),
                      _QuickAction(
                        icon: '🏠',
                        label: 'Flats',
                        onTap: () {},
                      ),
                      _QuickAction(
                        icon: '👥',
                        label: 'Members',
                        onTap: () {},
                      ),
                      _QuickAction(
                        icon: '🗳️',
                        label: 'Voting',
                        onTap: () {},
                      ),
                      _QuickAction(
                        icon: '📞',
                        label: 'Contacts',
                        onTap: () {},
                      ),
                    ],
                  ),

                  const SizedBox(height: 80),
                ]),
              ),
            ),
          ],
        ),
      ),

      // Bottom Navigation
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
              label: 'Payments'),
          BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart),
              label: 'Reports'),
        ],
        onTap: (i) {
          // TODO: Navigate to screens
        },
      ),
    );
  }

  void _showInviteCode(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Society Invite Code',
            style: TextStyle(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Share this code with residents to join:',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius: BorderRadius.circular(14),
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
                  color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.share),
              label: const Text('Share via WhatsApp'),
            ),
          ),
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
    required this.icon, required this.message,
    required this.color, required this.bgColor});

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
      Text(icon, style: const TextStyle(fontSize: 16)),
      const SizedBox(width: 8),
      Expanded(child: Text(message,
          style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600))),
      Icon(Icons.chevron_right, color: color, size: 18),
    ]),
  );
}

class _StatCard extends StatelessWidget {
  final String icon, label, value, sub;
  final bool accent;
  final Color? badgeColor;
  const _StatCard({
    required this.icon, required this.label,
    required this.value, required this.sub,
    this.accent = false, this.badgeColor});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: accent ? AppColors.primary : Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
          color: accent
              ? Colors.transparent : AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon,
            style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: accent
                ? Colors.white : AppColors.textPrimary)),
        Text(label, style: TextStyle(
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
    required this.label, required this.amount,
    required this.color, required this.bgColor,
    required this.icon});

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
        Text(label, style: TextStyle(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Corpus Fund',
              style: AppText.bodyBold),
          Text(
              balance < 0
                  ? 'Deficit!'
                  : 'Healthy',
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
            value: stats.collectionPercentage / 100,
            minHeight: 10,
            backgroundColor: AppColors.border,
            valueColor: const AlwaysStoppedAnimation(
                AppColors.success),
          ),
        ),
        const SizedBox(height: 8),
        Text(
            '${stats.paidFlats} of ${stats.totalFlats - stats.vacantFlats} occupied flats paid',
            style: AppText.small),
      ],
    ),
  );
}

class _QuickAction extends StatelessWidget {
  final String icon, label;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon, required this.label,
    required this.onTap});

  @override
  Widget build(BuildContext context) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
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