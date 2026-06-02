import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/bill_model.dart';
import '../../data/repositories/billing_repository.dart';

class ResidentBillsScreen extends StatelessWidget {
  final String societyId;
  final String userId;
  final String name;

  const ResidentBillsScreen({
    super.key,
    required this.societyId,
    required this.userId,
    required this.name,
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
      ),
    );
  }
}

class _ResidentBillList extends StatelessWidget {
  final String societyId;
  final String userId;

  const _ResidentBillList({
    required this.societyId,
    required this.userId,
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

        final bills = snap.data ?? [];

        if (bills.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment:
              MainAxisAlignment.center,
              children: [
                Text('🧾',
                    style: TextStyle(
                        fontSize: 52)),
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

        // Summary
        final totalPaid = bills
            .where((b) => b.isPaid)
            .fold(0.0, (s, b) => s + b.totalAmount);
        final totalPending = bills
            .where((b) => b.isUnpaid)
            .fold(0.0, (s, b) => s + b.totalAmount);

        return Column(children: [
          // Summary header
          Container(
            color: AppColors.primaryDark,
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(child: _SummaryBox(
                  label: 'Total Paid',
                  value: '₹${NumberFormat('#,##0').format(totalPaid)}',
                  color: AppColors.success)),
              const SizedBox(width: 10),
              Expanded(child: _SummaryBox(
                  label: 'Pending',
                  value: '₹${NumberFormat('#,##0').format(totalPending)}',
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

          // Bill list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: bills.length,
              separatorBuilder: (_, __) =>
              const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final bill = bills[i];
                final isPaid = bill.isPaid;

                return Container(
                  padding:
                  const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                      BorderRadius.circular(14),
                      border: Border.all(
                          color: isPaid
                              ? AppColors.success
                              .withOpacity(0.3)
                              : AppColors.danger
                              .withOpacity(0.3))),
                  child: Column(children: [
                    Row(children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                            color: isPaid
                                ? AppColors.successLight
                                : AppColors.dangerLight,
                            borderRadius:
                            BorderRadius.circular(
                                12)),
                        child: Center(child: Text(
                            isPaid ? '✅' : '⏳',
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
                                  fontWeight:
                                  FontWeight.w700,
                                  color:
                                  AppColors
                                      .textPrimary)),
                          Text(bill.flatTypeName,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color:
                                  AppColors
                                      .textSecondary)),
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
                                  fontWeight:
                                  FontWeight.w800,
                                  color:
                                  AppColors
                                      .textPrimary)),
                          Container(
                              padding:
                              const EdgeInsets
                                  .symmetric(
                                  horizontal: 8,
                                  vertical: 3),
                              decoration: BoxDecoration(
                                  color: isPaid
                                      ? AppColors
                                      .successLight
                                      : AppColors
                                      .dangerLight,
                                  borderRadius:
                                  BorderRadius
                                      .circular(20)),
                              child: Text(
                                  isPaid
                                      ? '✅ PAID'
                                      : '⏳ UNPAID',
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight:
                                      FontWeight.w700,
                                      color: isPaid
                                          ? AppColors
                                          .success
                                          : AppColors
                                          .danger))),
                        ],
                      ),
                    ]),

                    if (isPaid &&
                        bill.paidAt != null) ...[
                      const Divider(height: 16),
                      Row(children: [
                        const Icon(
                            Icons.check_circle,
                            color: AppColors.success,
                            size: 14),
                        const SizedBox(width: 6),
                        Text(
                            'Paid on ${DateFormat('d MMM yyyy').format(bill.paidAt!)}',
                            style: const TextStyle(
                                fontSize: 11,
                                color:
                                AppColors.success)),
                      ]),
                    ],

                    if (!isPaid) ...[
                      const Divider(height: 16),
                      Row(children: [
                        const Icon(
                            Icons.info_outline,
                            color: AppColors.warning,
                            size: 14),
                        const SizedBox(width: 6),
                        const Text(
                            'Please pay and inform '
                                'your admin',
                            style: TextStyle(
                                fontSize: 11,
                                color:
                                AppColors.warning)),
                      ]),
                    ],
                  ]),
                );
              },
            ),
          ),
        ]);
      },
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
            borderRadius: BorderRadius.circular(10)),
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: color)),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withOpacity(0.7))),
        ]),
      );
}