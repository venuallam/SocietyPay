import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/bill_model.dart';
import '../../data/repositories/billing_repository.dart';

class PaymentTrackingScreen extends StatefulWidget {
  final String societyId;

  const PaymentTrackingScreen({
    super.key,
    required this.societyId,
  });

  @override
  State<PaymentTrackingScreen> createState() =>
      _PaymentTrackingScreenState();
}

class _PaymentTrackingScreenState
    extends State<PaymentTrackingScreen> {
  final _repo = BillingRepository();
  late String _selectedMonth;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _selectedMonth = _currentMonth();
  }

  String _currentMonth() {
    final now    = DateTime.now();
    const months = [
      'JAN','FEB','MAR','APR','MAY','JUN',
      'JUL','AUG','SEP','OCT','NOV','DEC',
    ];
    return '${months[now.month - 1]}-${now.year}';
  }

  List<String> get _months {
    const m = [
      'JAN','FEB','MAR','APR','MAY','JUN',
      'JUL','AUG','SEP','OCT','NOV','DEC',
    ];
    final now = DateTime.now();
    return List.generate(6, (i) {
      final d = DateTime(now.year, now.month - i);
      return '${m[d.month - 1]}-${d.year}';
    });
  }

  Future<void> _showGenerateBillsDialog() async {
    final varCtrl = TextEditingController(text: '0');
    final alreadyGenerated =
    await _repo.billsAlreadyGenerated(
        widget.societyId, _selectedMonth);

    if (!mounted) return;

    if (alreadyGenerated) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '⚠️ Bills for $_selectedMonth '
                      'are already generated!'),
              backgroundColor: AppColors.warning));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text(
            'Generate Monthly Bills',
            style: TextStyle(
                fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
                'Generate bills for '
                    '$_selectedMonth for all '
                    'occupied flats.',
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13)),
            const SizedBox(height: 16),
            TextFormField(
              controller: varCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText:
                'Variable Component (₹)',
                hintText: '0',
                prefixText: '₹ ',
                helperText:
                'Extra charge this month '
                    '(e.g. water tanker)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () =>
                  Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final variable = double.tryParse(
                    varCtrl.text.trim()) ?? 0;
                await _generateBills(variable);
              },
              child: const Text('Generate Bills')),
        ],
      ),
    );
  }

  Future<void> _generateBills(
      double variableAmount,
      ) async {
    try {
      final adminId = FirebaseAuth
          .instance.currentUser!.uid;
      final result = await _repo.generateBills(
        societyId:      widget.societyId,
        adminId:        adminId,
        variableAmount: variableAmount,
      );

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(
            content: Text(
                '✅ ${result['count']} bills '
                    'generated for '
                    '${result['month']}'),
            backgroundColor:
            AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(
            content: Text('❌ $e'),
            backgroundColor: AppColors.danger));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Tracking'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          // Month picker
          Padding(
            padding: const EdgeInsets.only(
                right: 8),
            child: DropdownButton<String>(
              value: _selectedMonth,
              dropdownColor: AppColors.primaryDark,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
              iconEnabledColor: Colors.white,
              underline: const SizedBox(),
              items: _months.map((m) =>
                  DropdownMenuItem(
                      value: m,
                      child: Text(m))).toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() =>
                  _selectedMonth = v);
                }
              },
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<BillModel>>(
        stream: _repo.watchMonthBills(
            widget.societyId, _selectedMonth),
        builder: (context, snap) {
          if (snap.connectionState ==
              ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(
                    color: AppColors.primary));
          }

          final allBills = snap.data ?? [];

          // Apply filter. 'unpaid' includes reported
          // (not-yet-confirmed) bills.
          final bills = switch (_filter) {
            'paid'     => allBills.where(
                    (b) => b.isPaid).toList(),
            'unpaid'   => allBills.where(
                    (b) => b.isUnpaid
                        || b.isReported).toList(),
            'reported' => allBills.where(
                    (b) => b.isReported).toList(),
            _          => allBills,
          };

          if (allBills.isEmpty) {
            return _NoBillsState(
              month:     _selectedMonth,
              onGenerate:
              _showGenerateBillsDialog,
            );
          }

          // Calculate summary
          final paid      = allBills.where(
                  (b) => b.isPaid);
          final unpaid    = allBills.where(
                  (b) => b.isUnpaid);
          final reported  = allBills.where(
                  (b) => b.isReported);
          final collected = paid.fold(0.0,
                  (s, b) => s + b.totalAmount);
          final pending   = unpaid.fold(0.0,
                  (s, b) => s + b.totalAmount);

          return Column(children: [
            // ── Summary Header ─────────────────────
            Container(
              color: AppColors.primaryDark,
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Row(children: [
                  _SummaryBox(
                    label:  'Collected',
                    value:
                    '₹${_fmt(collected)}',
                    sub:
                    '${paid.length} flats',
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 10),
                  _SummaryBox(
                    label: 'Pending',
                    value:
                    '₹${_fmt(pending)}',
                    sub:
                    '${unpaid.length} flats',
                    color: AppColors.danger,
                  ),
                  const SizedBox(width: 10),
                  _SummaryBox(
                    label: 'Total',
                    value:
                    '${allBills.length}',
                    sub: 'flats billed',
                    color: Colors.white,
                  ),
                ]),
                const SizedBox(height: 10),
                // Progress bar
                ClipRRect(
                  borderRadius:
                  BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: allBills.isEmpty
                        ? 0
                        : paid.length /
                        allBills.length,
                    minHeight: 8,
                    backgroundColor:
                    Colors.white
                        .withOpacity(0.2),
                    valueColor:
                    const AlwaysStoppedAnimation(
                        AppColors.success),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment:
                  MainAxisAlignment
                      .spaceBetween,
                  children: [
                    Text(
                        '${paid.length} of '
                            '${allBills.length} paid',
                        style: TextStyle(
                            color: Colors.white
                                .withOpacity(0.7),
                            fontSize: 11)),
                    Text(
                        '${allBills.isEmpty ? 0 : (paid.length / allBills.length * 100).toStringAsFixed(0)}% collected',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight:
                            FontWeight.w700)),
                  ],
                ),
              ]),
            ),

            // ── Filter chips ───────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              child: Row(children: [
                _FilterChip(
                  label: 'All',
                  count: allBills.length,
                  selected: _filter == 'all',
                  color: AppColors.primary,
                  onTap: () => setState(
                          () => _filter = 'all'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Unpaid',
                  count: unpaid.length,
                  selected: _filter == 'unpaid',
                  color: AppColors.danger,
                  onTap: () => setState(
                          () => _filter = 'unpaid'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Reported',
                  count: reported.length,
                  selected: _filter == 'reported',
                  color: AppColors.warning,
                  onTap: () => setState(
                          () => _filter = 'reported'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Paid',
                  count: paid.length,
                  selected: _filter == 'paid',
                  color: AppColors.success,
                  onTap: () => setState(
                          () => _filter = 'paid'),
                ),
              ]),
            ),

            // ── Bill List ──────────────────────────
            Expanded(
              child: bills.isEmpty
                  ? Center(
                  child: Text(
                      'No $_filter bills',
                      style: const TextStyle(
                          color:
                          AppColors.textMuted)))
                  : ListView.separated(
                padding:
                const EdgeInsets.all(16),
                itemCount: bills.length,
                separatorBuilder: (_, __) =>
                const SizedBox(height: 10),
                itemBuilder: (ctx, i) =>
                    _BillTile(
                      bill:      bills[i],
                      societyId: widget.societyId,
                      adminId:   FirebaseAuth
                          .instance
                          .currentUser!.uid,
                    ),
              ),
            ),
          ]);
        },
      ),

      // ── FAB — Generate Bills ────────────────────────
      floatingActionButton:
      FloatingActionButton.extended(
        onPressed: _showGenerateBillsDialog,
        backgroundColor: AppColors.primary,
        icon: const Icon(
            Icons.receipt_long,
            color: Colors.white),
        label: const Text(
            'Generate Bills',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700)),
      ),
    );
  }

  String _fmt(double v) =>
      NumberFormat('#,##0').format(v);
}

// ── Bill Tile ─────────────────────────────────────────────────────────────────
class _BillTile extends StatefulWidget {
  final BillModel bill;
  final String societyId;
  final String adminId;

  const _BillTile({
    required this.bill,
    required this.societyId,
    required this.adminId,
  });

  @override
  State<_BillTile> createState() =>
      _BillTileState();
}

class _BillTileState extends State<_BillTile> {
  bool _loading = false;
  final _repo   = BillingRepository();

  Future<void> _rejectReport() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Report'),
        content: Text(
            'Mark ${widget.bill.flatNumber} as '
            'unpaid again? The resident will be '
            'notified to recheck.'),
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
              child: const Text('Reject')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      await _repo.rejectPaymentReport(
        societyId: widget.societyId,
        billId:    widget.bill.id,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.danger));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openProof(String proof) async {
    if (proof.startsWith('http')) {
      final uri = Uri.tryParse(proof);
      if (uri != null) {
        await launchUrl(uri,
            mode: LaunchMode
                .externalApplication);
        return;
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(
          content: Text('Reference: $proof')));
    }
  }

  Future<void> _markPaid() async {
    setState(() => _loading = true);
    try {
      await _repo.markAsPaid(
        societyId: widget.societyId,
        billId:    widget.bill.id,
        adminId:   widget.adminId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(
            content: Text(
                '✅ ${widget.bill.flatNumber} '
                    'marked as paid'),
            backgroundColor:
            AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor:
            AppColors.danger));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _undoPayment() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Undo Payment'),
        content: Text(
            'Mark ${widget.bill.flatNumber} '
                'as unpaid again?'),
        actions: [
          TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () =>
                  Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning),
              child: const Text('Undo')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      await _repo.undoPayment(
        societyId: widget.societyId,
        billId:    widget.bill.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(
            content: Text('Payment undone'),
            backgroundColor:
            AppColors.warning));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor:
            AppColors.danger));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bill       = widget.bill;
    final isPaid     = bill.isPaid;
    final isReported = bill.isReported;
    // Accent colour by status
    final accent = isPaid
        ? AppColors.success
        : isReported
            ? AppColors.warning
            : AppColors.danger;
    final accentBg = isPaid
        ? AppColors.successLight
        : isReported
            ? AppColors.warningLight
            : AppColors.dangerLight;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: accent.withOpacity(0.3)),
      ),
      child: Column(children: [
        // ── Main Info ──────────────────────────────
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            // Flat number circle
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                  color: accentBg,
                  borderRadius:
                  BorderRadius.circular(14)),
              child: Center(child: Text(
                widget.bill.flatNumber
                    .replaceAll('Flat-', ''),
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: accent),
              )),
            ),
            const SizedBox(width: 12),

            // Details
            Expanded(child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                    widget.bill.flatNumber,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 3),
                Text(
                    widget.bill.flatTypeName,
                    style: const TextStyle(
                        fontSize: 12,
                        color:
                        AppColors.textSecondary)),
                const SizedBox(height: 3),
                Text(
                    widget.bill
                        .billingResponsibleName
                        .isNotEmpty
                        ? '👤 ${widget.bill.billingResponsibleName}'
                        : '👤 Resident',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted)),
              ],
            )),

            // Amount + Status
            Column(
              crossAxisAlignment:
              CrossAxisAlignment.end,
              children: [
                Text(
                    '₹${NumberFormat('#,##0').format(widget.bill.totalAmount)}',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color:
                        AppColors.textPrimary)),
                const SizedBox(height: 4),
                Container(
                    padding:
                    const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3),
                    decoration: BoxDecoration(
                        color: accentBg,
                        borderRadius:
                        BorderRadius.circular(20)),
                    child: Text(
                        isPaid
                            ? '✅ PAID'
                            : isReported
                                ? '⏳ REPORTED'
                                : '🔴 UNPAID',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight:
                            FontWeight.w700,
                            color: accent))),
              ],
            ),
          ]),
        ),

        // ── Bill breakdown ─────────────────────────
        if (widget.bill.variableAmount > 0) ...[
          Container(
            margin: const EdgeInsets.fromLTRB(
                14, 0, 14, 8),
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: AppColors.bgLight,
                borderRadius:
                BorderRadius.circular(8)),
            child: Row(children: [
              Text(
                  'Fixed: ₹${NumberFormat('#,##0').format(widget.bill.fixedAmount)}',
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary)),
              const Text(' + ',
                  style: TextStyle(
                      color: AppColors.textMuted)),
              Text(
                  'Variable: ₹${NumberFormat('#,##0').format(widget.bill.variableAmount)}',
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.accent)),
            ]),
          ),
        ],

        // ── Paid date ──────────────────────────────
        if (isPaid && widget.bill.paidAt != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
                14, 0, 14, 8),
            child: Row(children: [
              const Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 14),
              const SizedBox(width: 6),
              Text(
                  'Paid on ${DateFormat('d MMM yyyy, h:mm a').format(widget.bill.paidAt!)}',
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.success)),
            ]),
          ),
        ],

        // ── Reported proof row ─────────────────────
        if (isReported) ...[
          Container(
            margin: const EdgeInsets.fromLTRB(
                14, 0, 14, 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius:
                BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.hourglass_top,
                  size: 14,
                  color: AppColors.warning),
              const SizedBox(width: 6),
              Expanded(child: Text(
                  (bill.paymentProof ?? '')
                      .isEmpty
                      ? 'Resident reported payment '
                        '(no reference given)'
                      : 'Ref: ${bill.paymentProof}',
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.warning))),
              if ((bill.paymentProof ?? '')
                  .startsWith('http'))
                TextButton(
                  onPressed: () => _openProof(
                      bill.paymentProof!),
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize:
                      const Size(40, 28)),
                  child: const Text('Open',
                      style: TextStyle(
                          fontSize: 11)),
                ),
            ]),
          ),
        ],

        const Divider(height: 1),

        // ── Action button(s) ───────────────────────
        Padding(
          padding: const EdgeInsets.all(10),
          child: _loading
              ? const Center(
              child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary)))
              : isPaid
              // PAID → Undo
              ? SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _undoPayment,
                icon: const Icon(Icons.undo,
                    size: 16,
                    color: AppColors.warning),
                label: const Text('Undo Payment',
                    style: TextStyle(
                        color: AppColors.warning,
                        fontSize: 13)),
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                        color:
                        AppColors.warning),
                    padding:
                    const EdgeInsets.symmetric(
                        vertical: 8)),
              ))
              : isReported
              // REPORTED → Confirm / Reject
              ? Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _rejectReport,
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                        color:
                        AppColors.danger),
                    padding:
                    const EdgeInsets.symmetric(
                        vertical: 8)),
                child: const Text('Reject',
                    style: TextStyle(
                        color: AppColors.danger,
                        fontSize: 13)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _markPaid,
                icon: const Icon(
                    Icons.check, size: 16),
                label: const Text(
                    'Confirm Payment',
                    style:
                    TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                    backgroundColor:
                    AppColors.success,
                    padding:
                    const EdgeInsets.symmetric(
                        vertical: 8)),
              ),
            ),
          ])
              // UNPAID → Mark as Paid
              : SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _markPaid,
                icon: const Icon(Icons.check,
                    size: 16),
                label: const Text('Mark as Paid',
                    style: TextStyle(
                        fontSize: 13)),
                style: ElevatedButton.styleFrom(
                    backgroundColor:
                    AppColors.success,
                    padding:
                    const EdgeInsets.symmetric(
                        vertical: 8)),
              )),
        ),
      ]),
    );
  }
}

// ── Supporting Widgets ────────────────────────────────────────────────────────
class _NoBillsState extends StatelessWidget {
  final String month;
  final VoidCallback onGenerate;

  const _NoBillsState({
    required this.month,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment:
        MainAxisAlignment.center,
        children: [
          const Text('🧾',
              style: TextStyle(fontSize: 60)),
          const SizedBox(height: 16),
          Text(
              'No bills for $month',
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          const Text(
              'Generate bills to start tracking\n'
                  'payments for this month.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onGenerate,
            icon: const Icon(Icons.receipt_long),
            label: Text('Generate $month Bills'),
          ),
        ],
      ),
    ),
  );
}

class _SummaryBox extends StatelessWidget {
  final String label, value, sub;
  final Color color;

  const _SummaryBox({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Text(value,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color)),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: Colors.white.withOpacity(0.7),
                fontWeight: FontWeight.w600)),
        Text(sub,
            style: TextStyle(
                fontSize: 9,
                color: Colors.white.withOpacity(0.5))),
      ]),
    ),
  );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
              color: selected
                  ? color : color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: selected
                      ? color : color.withOpacity(0.3))),
          child: Row(children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? Colors.white : color)),
            const SizedBox(width: 6),
            Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withOpacity(0.25)
                        : color.withOpacity(0.15),
                    borderRadius:
                    BorderRadius.circular(10)),
                child: Text(
                    '$count',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? Colors.white : color))),
          ]),
        ),
      );
}