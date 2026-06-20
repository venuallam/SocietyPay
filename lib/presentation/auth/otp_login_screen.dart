import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/constants/app_constants.dart';
import '../../main.dart';

class OtpLoginScreen extends StatefulWidget {
  const OtpLoginScreen({super.key});

  @override
  State<OtpLoginScreen> createState() => _OtpLoginScreenState();
}

class _OtpLoginScreenState extends State<OtpLoginScreen> {
  // Controllers
  final _phoneCtrl = TextEditingController();
  final _otpCtrl   = TextEditingController();
  final _auth      = FirebaseAuth.instance;

  // State
  bool   _otpSent      = false;
  bool   _loading      = false;
  String? _error;
  // Mobile
  String? _verificationId;
  // Web — stores ConfirmationResult from signInWithPhoneNumber
  ConfirmationResult? _webConfirmation;
  int    _resendSeconds = 60;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  // ── Send OTP ──────────────────────────────────────────────────────────────
  Future<void> _sendOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length != 10) {
      setState(() =>
      _error = 'Enter a valid 10-digit mobile number');
      return;
    }
    setState(() { _loading = true; _error = null; });

    if (kIsWeb) {
      await _sendOtpWeb(phone);
    } else {
      await _sendOtpMobile(phone);
    }
  }

  // ── Web OTP flow — reCAPTCHA + ConfirmationResult ─────────────────────────
  Future<void> _sendOtpWeb(String phone) async {
    try {
      _webConfirmation = await _auth
          .signInWithPhoneNumber('+91$phone');
      setState(() {
        _otpSent       = true;
        _loading       = false;
        _resendSeconds = 60;
      });
      _startResendTimer();
    } on FirebaseAuthException catch (e) {
      setState(() {
        _loading = false;
        _error   = e.message ?? 'Verification failed';
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error   = 'Could not send OTP. '
            'Please try again.';
      });
    }
  }

  // ── Mobile OTP flow — silent push verification ─────────────────────────────
  Future<void> _sendOtpMobile(String phone) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: '+91$phone',
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        await _signIn(credential);
      },
      verificationFailed: (e) {
        setState(() {
          _loading = false;
          _error   = e.message ?? 'Verification failed';
        });
      },
      codeSent: (verificationId, _) {
        setState(() {
          _verificationId = verificationId;
          _otpSent        = true;
          _loading        = false;
          _resendSeconds  = 60;
        });
        _startResendTimer();
      },
      codeAutoRetrievalTimeout: (verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  // ── Verify OTP ────────────────────────────────────────────────────────────
  Future<void> _verifyOtp() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) {
      setState(() => _error = 'Enter the 6-digit OTP');
      return;
    }
    setState(() { _loading = true; _error = null; });

    if (kIsWeb) {
      await _verifyOtpWeb(otp);
    } else {
      await _verifyOtpMobile(otp);
    }
  }

  Future<void> _verifyOtpWeb(String otp) async {
    try {
      await _webConfirmation!.confirm(otp);
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
              builder: (_) => const AuthWrapper()),
              (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _loading = false;
        _error   = e.message ?? 'Invalid OTP';
      });
    }
  }

  Future<void> _verifyOtpMobile(String otp) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      await _signIn(credential);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _loading = false;
        _error   = e.message ?? 'Invalid OTP';
      });
    }
  }

  // ── Sign In ───────────────────────────────────────────────────────────────
  Future<void> _signIn(PhoneAuthCredential credential) async {
    try {
      await _auth.signInWithCredential(credential);
      if (mounted) {
        // Navigate to AuthWrapper — it decides next screen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
              builder: (_) => const AuthWrapper()),
              (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _loading = false;
        _error   = e.message ?? 'Sign in failed';
      });
    }
  }

  // ── Resend Timer ──────────────────────────────────────────────────────────
  void _startResendTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendSeconds--);
      return _resendSeconds > 0;
    });
  }

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header gradient
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primaryDark, AppColors.primary],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.phone_android_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _otpSent ? 'Enter OTP' : 'Verify Your Number',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _otpSent
                      ? 'Enter the 6-digit code sent to\n+91 ${_phoneCtrl.text}'
                      : 'Enter your mobile number to continue',
                  style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.7)),
                ),
              ],
            ),
          ),

          // Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 8),

                  // Error Box
                  if (_error != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.dangerLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.danger.withOpacity(0.3)),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                            color: AppColors.danger, fontSize: 13),
                      ),
                    ),

                  // Phone Input Card
                  if (!_otpSent)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('MOBILE NUMBER',
                                style: AppText.label),
                            const SizedBox(height: 10),
                            Row(children: [
                              // Country code
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 14),
                                decoration: BoxDecoration(
                                  color: AppColors.accentLight,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text('+91',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                      fontSize: 15,
                                    )),
                              ),
                              const SizedBox(width: 10),
                              // Phone field
                              Expanded(
                                child: TextFormField(
                                  controller: _phoneCtrl,
                                  keyboardType: TextInputType.phone,
                                  maxLength: 10,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 2,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: '98765 43210',
                                    counterText: '',
                                  ),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loading ? null : _sendOtp,
                              child: _loading
                                  ? const SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ))
                                  : const Text('Send OTP'),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // OTP Input Card
                  if (_otpSent)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('ENTER 6-DIGIT OTP',
                                style: AppText.label),
                            const SizedBox(height: 14),
                            // OTP input field
                            TextFormField(
                              controller: _otpCtrl,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 12,
                                color: AppColors.primary,
                              ),
                              decoration: const InputDecoration(
                                hintText: '------',
                                hintStyle: TextStyle(
                                  letterSpacing: 12,
                                  fontSize: 24,
                                  color: AppColors.border,
                                ),
                                counterText: '',
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Resend timer
                            Center(
                              child: _resendSeconds > 0
                                  ? Text(
                                'Resend OTP in ${_resendSeconds}s',
                                style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 13),
                              )
                                  : TextButton(
                                onPressed: () {
                                  setState(() => _otpSent = false);
                                },
                                child: const Text('Resend OTP'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: _loading ? null : _verifyOtp,
                              child: _loading
                                  ? const SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ))
                                  : const Text('Verify & Continue'),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 32),

                  // Trust badges
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _TrustBadge(icon: '🔒', label: 'Secure'),
                      const SizedBox(width: 24),
                      _TrustBadge(icon: '⚡', label: 'Instant'),
                      const SizedBox(width: 24),
                      _TrustBadge(icon: '🇮🇳', label: 'India First'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Trust Badge Widget ────────────────────────────────────────────────────────
class _TrustBadge extends StatelessWidget {
  final String icon, label;
  const _TrustBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(icon, style: const TextStyle(fontSize: 22)),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(
          fontSize: 11,
          color: AppColors.textMuted,
          fontWeight: FontWeight.w600)),
    ],
  );
}