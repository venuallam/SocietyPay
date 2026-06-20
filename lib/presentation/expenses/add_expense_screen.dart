import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/expense_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/expense_repository.dart';

class AddExpenseScreen extends StatefulWidget {
  final String societyId;
  final String userId;
  final String userName;
  final UserRole userRole;

  const AddExpenseScreen({
    super.key,
    required this.societyId,
    required this.userId,
    required this.userName,
    required this.userRole,
  });

  @override
  State<AddExpenseScreen> createState() =>
      _AddExpenseScreenState();
}

class _AddExpenseScreenState
    extends State<AddExpenseScreen> {
  final _descCtrl    = TextEditingController();
  final _amountCtrl  = TextEditingController();
  final _receiptCtrl = TextEditingController();
  final _repo        = ExpenseRepository();

  ExpenseCategory _category =
      ExpenseCategory.society;
  bool _loading  = false;
  String? _error;

  bool get _isAdmin =>
      widget.userRole == UserRole.admin;

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    _receiptCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final desc   = _descCtrl.text.trim();
    final amount =
    double.tryParse(_amountCtrl.text.trim());
    final receipt = _receiptCtrl.text.trim();

    if (desc.isEmpty) {
      setState(() =>
      _error = 'Please enter a description');
      return;
    }
    if (amount == null || amount <= 0) {
      setState(() =>
      _error = 'Please enter a valid amount');
      return;
    }

    // Warn if no receipt link attached
    if (receipt.isEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius:
              BorderRadius.circular(16)),
          title: const Row(children: [
            Text('⚠️ ',
                style: TextStyle(fontSize: 20)),
            Expanded(child: Text('No Receipt',
                style: TextStyle(
                    fontWeight:
                    FontWeight.w800,
                    fontSize: 17))),
          ]),
          content: const Text(
              'You haven\'t attached a receipt '
              'link. Adding one (Google Drive / '
              'Photos link) keeps records '
              'transparent.\n\nSubmit without '
              'a receipt?'),
          actions: [
            TextButton(
                onPressed: () =>
                    Navigator.pop(ctx, false),
                child: const Text(
                    'Add Receipt')),
            ElevatedButton(
                onPressed: () =>
                    Navigator.pop(ctx, true),
                child: const Text(
                    'Submit Anyway')),
          ],
        ),
      );
      if (proceed != true) return;
    }

    setState(() {
      _loading = true;
      _error   = null;
    });

    try {
      if (_isAdmin) {
        await _repo.addExpense(
          societyId:         widget.societyId,
          adminId:           widget.userId,
          adminName:         widget.userName,
          category:          _category,
          description:       desc,
          amount:            amount,
          isCorpusDeduction: false,
          receiptLink:       receipt.isEmpty
              ? null : receipt,
        );
      } else {
        await _repo.submitExpenseRequest(
          societyId:         widget.societyId,
          userId:            widget.userId,
          userName:          widget.userName,
          category:          _category,
          description:       desc,
          amount:            amount,
          isCorpusDeduction: false,
          receiptLink:       receipt.isEmpty
              ? null : receipt,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(
            content: Text(_isAdmin
                ? '✅ Expense added successfully'
                : '✅ Expense request submitted'),
            backgroundColor: AppColors.success));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isAdmin
            ? 'Add Expense'
            : 'Suggest Expense'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [

            // Info banner for members
            if (!_isAdmin) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: AppColors.accentLight,
                    borderRadius:
                    BorderRadius.circular(10)),
                child: const Row(children: [
                  Icon(Icons.info_outline,
                      color: AppColors.accent,
                      size: 16),
                  SizedBox(width: 8),
                  Expanded(child: Text(
                      'Your expense request will be '
                          'sent to admin for approval.',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.accent))),
                ]),
              ),
              const SizedBox(height: 16),
            ],

            // ── Category ──────────────────────────────
            const Text('CATEGORY',
                style: AppText.label),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ExpenseCategory.values
                  .map((cat) {
                final selected = _category == cat;
                final icon  = cat.icon;
                final label = cat.label;
                return GestureDetector(
                  onTap: () => setState(
                          () => _category = cat),
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8),
                    decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary
                            : AppColors.bgLight,
                        borderRadius:
                        BorderRadius.circular(20),
                        border: Border.all(
                            color: selected
                                ? AppColors.primary
                                : AppColors.border)),
                    child: Text(
                        '$icon $label',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                            FontWeight.w600,
                            color: selected
                                ? Colors.white
                                : AppColors
                                .textSecondary)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // ── Description ────────────────────────────
            const Text('DESCRIPTION',
                style: AppText.label),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText:
                'e.g. Watchman salary for May',
              ),
            ),
            const SizedBox(height: 16),

            // ── Amount ─────────────────────────────────
            const Text('AMOUNT',
                style: AppText.label),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: '0',
                prefixText: '₹ ',
              ),
            ),
            const SizedBox(height: 16),

            // ── Receipt link (optional) ───────────────
            const Text('RECEIPT LINK (OPTIONAL)',
                style: AppText.label),
            const SizedBox(height: 8),
            TextFormField(
              controller: _receiptCtrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                hintText:
                'Paste Google Drive / Photos link',
                prefixIcon:
                Icon(Icons.link, size: 20),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
                'Tip: upload the bill photo to Google '
                'Drive or Photos and paste the share '
                'link here.',
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted)),
            const SizedBox(height: 16),

            // ── Error ─────────────────────────────────
            if (_error != null) ...[
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
              const SizedBox(height: 16),
            ],

            // ── Submit button ─────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _save,
                child: _loading
                    ? const SizedBox(
                    width: 20, height: 20,
                    child:
                    CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white))
                    : Text(_isAdmin
                    ? 'Add Expense'
                    : 'Submit for Approval'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}