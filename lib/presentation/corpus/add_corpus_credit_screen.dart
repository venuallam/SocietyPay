import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/constants/app_constants.dart';
import '../../data/repositories/corpus_repository.dart';

class AddCorpusCreditScreen extends StatefulWidget {
  final String societyId;
  const AddCorpusCreditScreen({
    super.key,
    required this.societyId,
  });

  @override
  State<AddCorpusCreditScreen> createState() =>
      _AddCorpusCreditScreenState();
}

class _AddCorpusCreditScreenState
    extends State<AddCorpusCreditScreen> {
  final _amountCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _repo       = CorpusRepository();
  bool _loading     = false;
  String? _error;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount =
    double.tryParse(_amountCtrl.text.trim());
    final reason = _reasonCtrl.text.trim();

    if (amount == null || amount <= 0) {
      setState(() =>
      _error = 'Enter a valid amount');
      return;
    }
    if (reason.isEmpty) {
      setState(() =>
      _error = 'Enter a reason for this credit');
      return;
    }

    setState(() {
      _loading = true;
      _error   = null;
    });

    try {
      final adminId =
          FirebaseAuth.instance.currentUser!.uid;

      await _repo.addManualCredit(
        societyId: widget.societyId,
        amount:    amount,
        reason:    reason,
        adminId:   adminId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(
            content: Text(
                '✅ Corpus credit added'),
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
        title: const Text('Add Corpus Credit'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            // Info box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius:
                  BorderRadius.circular(12)),
              child: const Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text('📌 When to add credits:',
                      style: AppText.h4),
                  SizedBox(height: 8),
                  Text(
                      '• Special levy collected '
                          'from all flats\n'
                          '• One-time donation from '
                          'a member\n'
                          '• External grant or '
                          'interest income\n'
                          '• Correction entry by admin',
                      style: TextStyle(
                          fontSize: 13,
                          color:
                          AppColors.textSecondary,
                          height: 1.6)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Form card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    const Text('AMOUNT',
                        style: AppText.label),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _amountCtrl,
                      keyboardType:
                      TextInputType.number,
                      decoration:
                      const InputDecoration(
                        hintText: '10000',
                        prefixText: '₹ ',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('REASON',
                        style: AppText.label),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _reasonCtrl,
                      maxLines: 3,
                      decoration:
                      const InputDecoration(
                        hintText:
                        'e.g. Special levy '
                            'collected from all flats',
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                          padding:
                          const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color:
                              AppColors.dangerLight,
                              borderRadius:
                              BorderRadius
                                  .circular(8)),
                          child: Text(_error!,
                              style: const TextStyle(
                                  color: AppColors.danger,
                                  fontSize: 13))),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading
                            ? null : _save,
                        child: _loading
                            ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                            CircularProgressIndicator(
                                strokeWidth: 2,
                                color:
                                Colors.white))
                            : const Text(
                            'Add Credit to Corpus'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}