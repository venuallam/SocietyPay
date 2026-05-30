import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';
import '../../data/repositories/society_repository.dart';
import '../../data/models/society_model.dart';
import '../society/society_wizard_screen.dart';
import 'select_role_screen.dart';

class InviteCodeScreen extends StatefulWidget {
  const InviteCodeScreen({super.key});

  @override
  State<InviteCodeScreen> createState() =>
      _InviteCodeScreenState();
}

class _InviteCodeScreenState
    extends State<InviteCodeScreen> {
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool    _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    final name = _nameCtrl.text.trim();

    if (name.isEmpty) {
      setState(() =>
      _error = 'Please enter your name');
      return;
    }
    if (code.length != 6) {
      setState(() =>
      _error = 'Enter a valid 6-character code');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      // Find society by invite code
      final society = await SocietyRepository()
          .getSocietyByInviteCode(code);

      if (society == null) {
        setState(() {
          _error = 'Invalid invite code. '
              'Please check with your admin.';
          _loading = false;
        });
        return;
      }

      final uid   = FirebaseAuth
          .instance.currentUser!.uid;
      final phone = FirebaseAuth
          .instance.currentUser!.phoneNumber ?? '';

      // ── KEY FIX ──────────────────────────────────
      // Save societyId AND name IMMEDIATELY
      // This prevents going back to InviteCodeScreen
      // when app is reopened
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({
        'name':      name,
        'phone':     phone,
        'role':      'pending',  // pending until approved
        'societyId': society.id, // ← saved now!
        'flatId':    null,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SelectRoleScreen(
              society:   society,
              userName:  name,
              userPhone: phone,
            ),
          ),
        );
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
      body: Column(children: [
        // ── Header ──────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(
              24, 60, 24, 32),
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
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              const Text('🏢',
                  style: TextStyle(fontSize: 40)),
              const SizedBox(height: 16),
              const Text('Join Your Society',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
              const SizedBox(height: 8),
              Text(
                'Enter the invite code shared '
                    'by your society admin.',
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.white
                        .withOpacity(0.7)),
              ),
            ],
          ),
        ),

        // ── Body ─────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const SizedBox(height: 8),

              // Error box
              if (_error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(
                      bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius:
                    BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.danger
                            .withOpacity(0.3)),
                  ),
                  child: Text(_error!,
                      style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 13)),
                ),

              // Input card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      // Name field
                      const Text('YOUR NAME',
                          style: AppText.label),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameCtrl,
                        textCapitalization:
                        TextCapitalization.words,
                        decoration:
                        const InputDecoration(
                          hintText:
                          'e.g. Vikram Mehta',
                          prefixIcon: Icon(
                              Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Invite code field
                      const Text('INVITE CODE',
                          style: AppText.label),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _codeCtrl,
                        textCapitalization:
                        TextCapitalization.characters,
                        maxLength: 6,
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 6,
                            color: AppColors.primary),
                        decoration:
                        const InputDecoration(
                          hintText: 'XXXXXX',
                          hintStyle: TextStyle(
                              letterSpacing: 4,
                              fontSize: 22,
                              color: AppColors.border),
                          counterText: '',
                        ),
                        onChanged: (_) => setState(
                                () => _error = null),
                      ),
                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading
                              ? null : _verify,
                          child: _loading
                              ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                              CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white))
                              : const Text(
                              'Find My Society →'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // OR divider
              const Row(children: [
                Expanded(child: Divider()),
                Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 12),
                    child: Text('OR',
                        style: AppText.small)),
                Expanded(child: Divider()),
              ]),

              const SizedBox(height: 20),

              // Create society button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                        const SocietyWizardScreen()),
                  ),
                  icon: const Icon(
                      Icons.add_business),
                  label: const Text(
                      'Create a New Society'),
                ),
              ),

              const SizedBox(height: 16),
              const Text(
                  'Are you the society admin?\n'
                      'Tap "Create a New Society" above.',
                  textAlign: TextAlign.center,
                  style: AppText.small),
            ]),
          ),
        ),
      ]),
    );
  }
}