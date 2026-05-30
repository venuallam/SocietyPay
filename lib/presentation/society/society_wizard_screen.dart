import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/society_model.dart';
import '../../data/repositories/society_repository.dart';
import '../dashboard/admin_dashboard_screen.dart';

class SocietyWizardScreen extends StatefulWidget {
  const SocietyWizardScreen({super.key});

  @override
  State<SocietyWizardScreen> createState() =>
      _SocietyWizardScreenState();
}

class _SocietyWizardScreenState
    extends State<SocietyWizardScreen> {
  // Controllers
  final _pageCtrl  = PageController();
  final _nameCtrl  = TextEditingController();
  final _flatsCtrl = TextEditingController();

  // State
  int     _step    = 0;
  bool    _loading = false;
  String? _error;

  // Flat types list
  final List<Map<String, dynamic>> _flatTypes = [];

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    _flatsCtrl.dispose();
    super.dispose();
  }

  // ── Step Titles ─────────────────────────────────────────────────────────────
  static const _titles = [
    'Society Name',
    'Total Flats',
    'Flat Types & Charges',
  ];

  static const _subtitles = [
    'What is your apartment society called?',
    'How many flats are in your society?',
    'Define flat types and monthly maintenance',
  ];

  // ── Navigation ───────────────────────────────────────────────────────────────
  void _next() {
    setState(() => _error = null);

    // Validate each step
    if (_step == 0 && _nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter the society name');
      return;
    }
    if (_step == 1) {
      final n = int.tryParse(_flatsCtrl.text.trim());
      if (n == null || n < 1) {
        setState(() => _error = 'Enter a valid number of flats');
        return;
      }
    }
    if (_step == 2) {
      if (_flatTypes.isEmpty) {
        setState(() => _error = 'Add at least one flat type');
        return;
      }
      _createSociety();
      return;
    }

    setState(() => _step++);
    _pageCtrl.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _prev() {
    if (_step > 0) {
      setState(() { _step--; _error = null; });
      _pageCtrl.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // ── Create Society ───────────────────────────────────────────────────────────
  Future<void> _createSociety() async {
    setState(() { _loading = true; _error = null; });
    try {
      final uid  = FirebaseAuth.instance.currentUser!.uid;
      final repo = SocietyRepository();

      final flatTypes = _flatTypes.map((ft) => FlatTypeModel(
        id:                '',
        typeName:          ft['typeName'] as String,
        maintenanceAmount: ft['amount'] as double,
      )).toList();

      final society = await repo.createSociety(
        adminId:    uid,
        name:       _nameCtrl.text.trim(),
        totalFlats: int.parse(_flatsCtrl.text.trim()),
        flatTypes:  flatTypes,
      );

      if (mounted) {
        _showSuccessDialog(
          society.inviteCode,
          society.id,
          society.name,
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  // ── Success Dialog ───────────────────────────────────────────────────────────
  void _showSuccessDialog(
      String inviteCode,
      String societyId,
      String societyName,
      ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Column(children: [
          Text('🎉', style: TextStyle(fontSize: 48)),
          SizedBox(height: 8),
          Text('Society Created!',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share this invite code with your residents:',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.accent),
              ),
              child: Text(
                inviteCode,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: 8,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'This code is permanent.\nShare it in your society WhatsApp group.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminDashboardScreen(
                      societyId:   societyId,
                      societyName: societyName,
                      inviteCode:  inviteCode,
                    ),
                  ),
                );
              },
              child: const Text('Go to Dashboard →'),
            ),
          ),
        ],
      ),
    );
  }

  // ── Add Flat Type Dialog ─────────────────────────────────────────────────────
  void _showAddFlatTypeDialog() {
    final nameCtrl   = TextEditingController();
    final amountCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Flat Type',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Flat Type',
                hintText: 'e.g. 1BHK, 2BHK, 3BHK',
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Monthly Maintenance (₹)',
                prefixText: '₹ ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name   = nameCtrl.text.trim();
              final amount = double.tryParse(
                  amountCtrl.text.trim());
              if (name.isNotEmpty &&
                  amount != null && amount > 0) {
                setState(() => _flatTypes.add({
                  'typeName': name,
                  'amount':   amount,
                }));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // ── UI ───────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [

        // ── Header ──────────────────────────────────────────
        Container(
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
              24, 60, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress bar
              Row(
                children: List.generate(3, (i) =>
                    Expanded(
                      child: Container(
                        margin: EdgeInsets.only(
                            right: i < 2 ? 6 : 0),
                        height: 4,
                        decoration: BoxDecoration(
                          color: i <= _step
                              ? Colors.white
                              : Colors.white.withOpacity(0.3),
                          borderRadius:
                          BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Step ${_step + 1} of 3',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                _titles[_step],
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                _subtitles[_step],
                style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13),
              ),
            ],
          ),
        ),

        // ── Page Content ─────────────────────────────────────
        Expanded(
          child: PageView(
            controller: _pageCtrl,
            physics: const NeverScrollableScrollPhysics(),
            children: [

              // ── Step 1 — Society Name ──────────────────────
              _WizardPage(children: [
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameCtrl,
                  autofocus: true,
                  textCapitalization:
                  TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Society Name',
                    hintText: 'e.g. Sunrise Apartments',
                    prefixIcon: Icon(Icons.apartment),
                  ),
                ),
                const SizedBox(height: 16),
                _InfoBox(
                  icon: '💡',
                  text: 'This name appears in all '
                      'notifications and reports '
                      'sent to residents.',
                ),
              ]),

              // ── Step 2 — Total Flats ───────────────────────
              _WizardPage(children: [
                const SizedBox(height: 8),
                TextFormField(
                  controller: _flatsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Total Number of Flats',
                    hintText: 'e.g. 24',
                    prefixIcon: Icon(
                        Icons.door_front_door_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                _InfoBox(
                  icon: '⚠️',
                  text: 'This cannot be changed after '
                      'society creation. Please enter '
                      'the correct count.',
                ),
              ]),

              // ── Step 3 — Flat Types ────────────────────────
              _WizardPage(children: [
                const SizedBox(height: 8),

                // List of added flat types
                ..._flatTypes.asMap().entries.map((entry) {
                  final i  = entry.key;
                  final ft = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(
                        bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.accentLight,
                      borderRadius:
                      BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.border),
                    ),
                    child: Row(children: [
                      // Type initial circle
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius:
                          BorderRadius.circular(10),
                        ),
                        child: Center(child: Text(
                          ft['typeName']
                              .toString()
                              .substring(0, 1),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18),
                        )),
                      ),
                      const SizedBox(width: 12),
                      // Type details
                      Expanded(child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            ft['typeName'] as String,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: AppColors.textPrimary),
                          ),
                          Text(
                            '₹${(ft['amount'] as double).toStringAsFixed(0)}/month',
                            style: const TextStyle(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w600,
                                fontSize: 13),
                          ),
                        ],
                      )),
                      // Remove button
                      IconButton(
                        onPressed: () => setState(
                                () => _flatTypes.removeAt(i)),
                        icon: const Icon(
                            Icons.remove_circle_outline,
                            color: AppColors.danger),
                      ),
                    ]),
                  );
                }),

                // Add flat type button
                OutlinedButton.icon(
                  onPressed: _showAddFlatTypeDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Flat Type'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(
                        double.infinity, 50),
                  ),
                ),
                const SizedBox(height: 16),
                _InfoBox(
                  icon: '💡',
                  text: 'Add each flat type with its '
                      'monthly maintenance amount. '
                      'E.g. 1BHK at ₹1,500, '
                      '2BHK at ₹2,000.',
                ),
              ]),
            ],
          ),
        ),

        // ── Error Box ─────────────────────────────────────────
        if (_error != null)
          Container(
            width: double.infinity,
            color: AppColors.dangerLight,
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 10),
            child: Text(
              _error!,
              style: const TextStyle(
                  color: AppColors.danger,
                  fontSize: 13),
            ),
          ),

        // ── Navigation Buttons ────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
              20, 12, 20, 32),
          child: Row(children: [
            if (_step > 0) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: _loading ? null : _prev,
                  child: const Text('← Back'),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _loading ? null : _next,
                child: _loading
                    ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white))
                    : Text(
                    _step < 2
                        ? 'Next →'
                        : '🎉 Create Society'),
              ),
            ),
          ]),
        ),

      ]),
    );
  }
}

// ── Helper Widgets ─────────────────────────────────────────────────────────────
class _WizardPage extends StatelessWidget {
  final List<Widget> children;
  const _WizardPage({required this.children});

  @override
  Widget build(BuildContext context) =>
      SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );
}

class _InfoBox extends StatelessWidget {
  final String icon, text;
  const _InfoBox({
    required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.accentLight,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon,
            style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary))),
      ],
    ),
  );
}