import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../data/repositories/corpus_repository.dart';

class SetReserveScreen extends StatefulWidget {
  final String societyId;
  final double current;

  const SetReserveScreen({
    super.key,
    required this.societyId,
    required this.current,
  });

  @override
  State<SetReserveScreen> createState() =>
      _SetReserveScreenState();
}

class _SetReserveScreenState
    extends State<SetReserveScreen> {
  late final TextEditingController _ctrl;
  final _repo = CorpusRepository();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.current > 0
            ? widget.current.toStringAsFixed(0)
            : '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount =
    double.tryParse(_ctrl.text.trim());
    if (amount == null || amount < 0) {
      setState(() =>
      _error = 'Enter a valid amount');
      return;
    }

    setState(() {
      _loading = true;
      _error   = null;
    });

    try {
      await _repo.setMinimumReserve(
        societyId: widget.societyId,
        amount:    amount,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(
            content: Text(
                '✅ Minimum reserve updated'),
            backgroundColor:
            AppColors.success));
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
        title: const Text('Set Minimum Reserve'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            // Info
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius:
                  BorderRadius.circular(12)),
              child: const Row(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        color: AppColors.accent,
                        size: 18),
                    SizedBox(width: 8),
                    Expanded(child: Text(
                        'You will be alerted when '
                            'corpus balance falls below '
                            'this amount. Set to 0 to '
                            'disable the warning.',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.accent,
                            height: 1.5))),
                  ]),
            ),
            const SizedBox(height: 20),

            // Input
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    const Text(
                        'MINIMUM RESERVE AMOUNT',
                        style: AppText.label),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _ctrl,
                      keyboardType:
                      TextInputType.number,
                      decoration:
                      const InputDecoration(
                        hintText: '50000',
                        prefixText: '₹ ',
                        helperText:
                        'Alert when corpus '
                            'drops below this',
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(_error!,
                          style: const TextStyle(
                              color: AppColors.danger,
                              fontSize: 13)),
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
                            'Save Reserve Amount'),
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