import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/bill_model.dart';
import '../../data/repositories/billing_repository.dart';

class ResidentBillsScreen extends StatelessWidget {
  final String societyId;
  final String userId;
  final String name;
  // When the admin opens their OWN flat's bills they can
  // confirm payment directly (self-confirm). Residents
  // can only report a payment for admin to confirm.
  final bool isAdmin;

  const ResidentBillsScreen({
    super.key,
    required this.societyId,
    required this.userId,
    required this.name,
    this.isAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bills'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _ResidentBillList(
        societyId: societyId,
        userId:    userId,
        isAdmin:   isAdmin,
      ),
    );
  }
}

class _ResidentBillList extends StatelessWidget {
  final String societyId;
  final String userId;
  final bool isAdmin;

  const _ResidentBillList({
    required this.societyId,
    required this.userId,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: BillingRepository()
          .watchResidentBills(societyId, userId),
      builder: (BuildContext context,
          AsyncSnapshot<List<BillModel>> snap) {

        if (snap.connectionState ==
            ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary));
        }

        final bills = (snap.data ?? [])
          ..sort((a, b) =>
              b.generatedAt.compareTo(a.generatedAt));

        if (bills.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment:
              MainAxisAlignment.center,
              children: [
                Text('🧾',
                    style: TextStyle(fontSize: 52)),
                SizedBox(height: 16),
                Text('No bills yet',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                SizedBox(height: 8),
                Text(
                    'Your monthly bills will '
                        'appear here.',
                    style: TextStyle(
                        color:
                        AppColors.textSecondary)),
              ],
            ),
          );
        }

        final totalPaid = bills
            .where((b) => b.isPaid)
            .fold(0.0, (s, b) => s + b.totalAmount);
        final totalPending = bills
            .where((b) => !b.isPaid)
            .fold(0.0, (s, b) => s + b.totalAmount);

        return Column(children: [
          // Summary header
          Container(
            color: AppColors.primaryDark,
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(child: _SummaryBox(
                  label: 'Total Paid',
                  value:
                  '₹${NumberFormat('#,##0').format(totalPaid)}',
                  color: AppColors.success)),
              const SizedBox(width: 10),
              Expanded(child: _SummaryBox(
                  label: 'Pending',
                  value:
                  '₹${NumberFormat('#,##0').format(totalPending)}',
                  color: totalPending > 0
                      ? AppColors.danger
                      : AppColors.success)),
              const SizedBox(width: 10),
              Expanded(child: _SummaryBox(
                  label: 'Total Bills',
                  value: '${bills.length}',
                  color: Colors.white)),
            ]),
          ),

          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: bills.length,
              separatorBuilder: (_, __) =>
              const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                // Arrears brought forward: dues from
                // older unpaid/reported bills (the list
                // is sorted newest-first, so older bills
                // are at higher indices).
                double previousDues = 0;
                for (var j = i + 1;
                    j < bills.length; j++) {
                  if (!bills[j].isPaid) {
                    previousDues +=
                        bills[j].totalAmount;
                  }
                }
                return _BillCardTile(
                  bill:         bills[i],
                  societyId:    societyId,
                  userId:       userId,
                  isAdmin:      isAdmin,
                  previousDues: previousDues,
                );
              },
            ),
          ),
        ]);
      },
    );
  }
}

// ── Bill Card with actions ────────────────────────────────────────────────────
class _BillCardTile extends StatefulWidget {
  final BillModel bill;
  final String societyId;
  final String userId;
  final bool isAdmin;
  final double previousDues;

  const _BillCardTile({
    required this.bill,
    required this.societyId,
    required this.userId,
    required this.isAdmin,
    this.previousDues = 0,
  });

  @override
  State<_BillCardTile> createState() =>
      _BillCardTileState();
}

class _BillCardTileState
    extends State<_BillCardTile> {
  final _repo = BillingRepository();
  bool _loading = false;

  // ── Resident: report a payment ────────────────────
  Future<void> _reportPayment() async {
    final proofCtrl = TextEditingController();

    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(16)),
        title: const Text("I've Paid",
            style: TextStyle(
                fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            const Text(
                'Add a payment reference so your '
                'admin can verify:',
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: proofCtrl,
              decoration: const InputDecoration(
                hintText:
                'UTR / txn no. or receipt link',
                prefixIcon:
                Icon(Icons.link, size: 20),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
                'Tip: paste the UPI reference number '
                'or a Google Drive / Photos link to '
                'the receipt.',
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, null),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(
                  ctx,
                  proofCtrl.text.trim()),
              // sentinel handled below
              child: const Text('Submit')),
        ],
      ),
    );

    // null = cancelled
    if (result == null) return;

    // Warn if no proof entered
    if (result.isEmpty) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius:
              BorderRadius.circular(16)),
          title: const Text('No Reference'),
          content: const Text(
              'You didn\'t add a reference or '
              'receipt link. Report the payment '
              'anyway?'),
          actions: [
            TextButton(
                onPressed: () =>
                    Navigator.pop(ctx, false),
                child:
                const Text('Add Reference')),
            ElevatedButton(
                onPressed: () =>
                    Navigator.pop(ctx, true),
                child:
                const Text('Report Anyway')),
          ],
        ),
      );
      if (go != true) return;
    }

    setState(() => _loading = true);
    try {
      await _repo.reportPayment(
        societyId: widget.societyId,
        billId:    widget.bill.id,
        userId:    widget.userId,
        proof:     result.isEmpty ? null : result,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(
            content: Text(
                '✅ Payment reported — '
                'awaiting admin confirmation'),
            backgroundColor: AppColors.success));
      }
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ── Admin (own flat): mark paid directly ──────────
  Future<void> _markPaid() async {
    setState(() => _loading = true);
    try {
      await _repo.markAsPaid(
        societyId: widget.societyId,
        billId:    widget.bill.id,
        adminId:   widget.userId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(
            content: Text('✅ Marked as paid'),
            backgroundColor: AppColors.success));
      }
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openProof(String proof) async {
    final uri = Uri.tryParse(proof);
    if (uri != null &&
        (proof.startsWith('http'))) {
      await launchUrl(uri,
          mode: LaunchMode.externalApplication);
    } else {
      // Not a URL — just show the reference
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(
          content: Text('Reference: $proof')));
    }
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: AppColors.danger));
  }

  Widget _breakdownRow(String label, double amt,
      {bool bold = false, bool muted = false}) {
    final style = TextStyle(
      fontSize: bold ? 14 : 12,
      fontWeight:
      bold ? FontWeight.w800 : FontWeight.w500,
      color: muted
          ? AppColors.textMuted
          : AppColors.textPrimary,
    );
    return Row(
      mainAxisAlignment:
      MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text('₹${NumberFormat('#,##0').format(amt)}',
            style: style),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bill = widget.bill;
    final (bg, fg, emoji, label) = switch (bill.status) {
      PaymentStatus.paid => (
        AppColors.successLight,
        AppColors.success,
        '✅', 'PAID'),
      PaymentStatus.reported => (
        AppColors.warningLight,
        AppColors.warning,
        '⏳', 'REPORTED'),
      PaymentStatus.unpaid => (
        AppColors.dangerLight,
        AppColors.danger,
        '🔴', 'UNPAID'),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
          BorderRadius.circular(14),
          border: Border.all(
              color: fg.withOpacity(0.3))),
      child: Column(children: [
        Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
                color: bg,
                borderRadius:
                BorderRadius.circular(12)),
            child: Center(child: Text(emoji,
                style: const TextStyle(
                    fontSize: 22))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(bill.month,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color:
                      AppColors.textPrimary)),
              Text(bill.flatTypeName,
                  style: const TextStyle(
                      fontSize: 12,
                      color:
                      AppColors.textSecondary)),
            ],
          )),
          Column(
            crossAxisAlignment:
            CrossAxisAlignment.end,
            children: [
              Text(
                  '₹${NumberFormat('#,##0').format(bill.totalAmount)}',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color:
                      AppColors.textPrimary)),
              Container(
                  padding:
                  const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3),
                  decoration: BoxDecoration(
                      color: bg,
                      borderRadius:
                      BorderRadius.circular(20)),
                  child: Text('$emoji $label',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight:
                          FontWeight.w700,
                          color: fg))),
            ],
          ),
        ]),

        // ── Paid info ──────────────────────────
        if (bill.isPaid && bill.paidAt != null) ...[
          const Divider(height: 16),
          Row(children: [
            const Icon(Icons.check_circle,
                color: AppColors.success,
                size: 14),
            const SizedBox(width: 6),
            Text(
                'Paid on ${DateFormat('d MMM yyyy').format(bill.paidAt!)}',
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.success)),
          ]),
        ],

        // ── Reported info ──────────────────────
        if (bill.isReported) ...[
          const Divider(height: 16),
          Row(children: [
            const Icon(Icons.hourglass_top,
                color: AppColors.warning,
                size: 14),
            const SizedBox(width: 6),
            const Expanded(child: Text(
                'Payment reported — awaiting '
                'admin confirmation',
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.warning))),
            if ((bill.paymentProof ?? '')
                .isNotEmpty)
              TextButton(
                onPressed: () => _openProof(
                    bill.paymentProof!),
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize:
                    const Size(50, 30)),
                child: const Text('View proof',
                    style:
                    TextStyle(fontSize: 11)),
              ),
          ]),
        ],

        // ── Arrears brought forward breakdown ──
        if (widget.previousDues > 0) ...[
          const Divider(height: 16),
          _breakdownRow('Previous dues',
              widget.previousDues,
              muted: true),
          const SizedBox(height: 4),
          _breakdownRow('This month',
              bill.totalAmount, muted: true),
          const SizedBox(height: 6),
          _breakdownRow('Total payable',
              widget.previousDues +
                  bill.totalAmount,
              bold: true),
        ],

        // ── Unpaid → action button ─────────────
        if (bill.isUnpaid) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading
                  ? null
                  : (widget.isAdmin
                      ? _markPaid
                      : _reportPayment),
              icon: _loading
                  ? const SizedBox(
                  width: 16, height: 16,
                  child:
                  CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white))
                  : Icon(widget.isAdmin
                      ? Icons.check_circle_outline
                      : Icons.upload_outlined,
                  size: 18),
              label: Text(widget.isAdmin
                  ? 'Mark as Paid'
                  : "I've Paid"),
            ),
          ),
        ],
      ]),
    );
  }
}

class _SummaryBox extends StatelessWidget {
  final String label, value;
  final Color color;
  const _SummaryBox({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) =>
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius:
            BorderRadius.circular(10)),
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: color)),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: Colors.white
                      .withOpacity(0.7))),
        ]),
      );
}
