import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'presentation/auth/otp_login_screen.dart';
import 'presentation/auth/invite_code_screen.dart';
import 'presentation/auth/select_role_screen.dart';
import 'presentation/auth/pending_approval_screen.dart';
import 'presentation/dashboard/admin_dashboard_screen.dart';
import 'data/models/society_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const SocietyPayApp());
}

class SocietyPayApp extends StatelessWidget {
  const SocietyPayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SocietyPay',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthWrapper(),
    );
  }
}

// ── Loading Screen ────────────────────────────────────────────────────────────
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppColors.accentLight,
                borderRadius:
                BorderRadius.circular(24),
              ),
              child: const Icon(
                  Icons.apartment_rounded,
                  size: 50,
                  color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            const Text('SocietyPay',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            const Text(
                'Making Society Management Simple',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted)),
            const SizedBox(height: 32),
            const CircularProgressIndicator(
                color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

// ── Auth Wrapper ──────────────────────────────────────────────────────────────
// Routes user to correct screen based on their state
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState ==
            ConnectionState.waiting) {
          return const LoadingScreen();
        }
        // Not logged in → OTP Login
        if (!authSnap.hasData) {
          return const OtpLoginScreen();
        }
        // Logged in → check profile
        return _ProfileChecker(
            uid: authSnap.data!.uid);
      },
    );
  }
}

// ── Step 1: Check user profile ────────────────────────────────────────────────
class _ProfileChecker extends StatelessWidget {
  final String uid;
  const _ProfileChecker({required this.uid});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get(),
      builder: (context, snap) {
        if (snap.connectionState ==
            ConnectionState.waiting) {
          return const LoadingScreen();
        }

        final data = snap.data?.data()
        as Map<String, dynamic>?;

        // No profile → new user
        if (data == null) {
          return const InviteCodeScreen();
        }

        final role      =
            data['role'] as String? ?? 'pending';
        final societyId =
        data['societyId'] as String?;
        final name      =
            data['name'] as String? ?? '';
        final phone     =
            data['phone'] as String? ?? '';
        final flatId    =
        data['flatId'] as String?;

        // No societyId → hasn't joined yet
        if (societyId == null) {
          return const InviteCodeScreen();
        }

        // ── Admin → Admin Dashboard ───────────────────
        if (role == 'admin') {
          return _AdminLoader(
              societyId: societyId);
        }

        // ── Approved Member → Resident Dashboard ──────
        // flatId is set only after admin approves
        if (flatId != null &&
            (role == 'owner' || role == 'tenant')) {
          return _ApprovedMemberScreen(
              name:   name,
              flatId: flatId);
        }

        // ── Has societyId but not yet approved ────────
        // Could be:
        // a) Submitted request → pending
        // b) Verified code → not yet submitted role
        return _RequestStatusChecker(
          uid:       uid,
          societyId: societyId,
          name:      name,
          phone:     phone,
        );
      },
    );
  }
}

// ── Step 2: Check request status ─────────────────────────────────────────────
class _RequestStatusChecker extends StatelessWidget {
  final String uid;
  final String societyId;
  final String name;
  final String phone;

  const _RequestStatusChecker({
    required this.uid,
    required this.societyId,
    required this.name,
    required this.phone,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('societies')
          .doc(societyId)
          .collection('memberRequests')
          .where('userId', isEqualTo: uid)
          .limit(1)
          .get(),
      builder: (context, snap) {
        if (snap.connectionState ==
            ConnectionState.waiting) {
          return const LoadingScreen();
        }

        // Error
        if (snap.hasError) {
          return _ErrorScreen(
              message: snap.error.toString(),
              uid: uid);
        }

        // No request yet → show role selection
        // User verified code but hasn't
        // picked role/flat yet
        if (!snap.hasData ||
            snap.data!.docs.isEmpty) {
          return _SocietyLoader(
            societyId: societyId,
            name:      name,
            phone:     phone,
            showRoleSelection: true,
          );
        }

        final req = snap.data!.docs.first.data()
        as Map<String, dynamic>;
        final status =
            req['status'] as String? ?? 'pending';

        // Pending → show waiting screen
        if (status == 'pending') {
          return _SocietyLoader(
            societyId:  societyId,
            name:       name,
            phone:      phone,
            flatNumber:
            req['flatNumber'] as String? ?? '',
            role:
            req['role'] as String? ?? 'owner',
            showRoleSelection: false,
          );
        }

        // Rejected → clear societyId, retry
        if (status == 'rejected') {
          _clearAndRetry(uid);
          return const InviteCodeScreen();
        }

        // Any other status → invite code
        return const InviteCodeScreen();
      },
    );
  }

  void _clearAndRetry(String uid) {
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'societyId': null, 'role': 'pending'});
  }
}

// ── Step 3: Load society data ─────────────────────────────────────────────────
class _SocietyLoader extends StatelessWidget {
  final String societyId;
  final String name;
  final String phone;
  final String flatNumber;
  final String role;
  final bool showRoleSelection;

  const _SocietyLoader({
    required this.societyId,
    required this.name,
    required this.phone,
    this.flatNumber = '',
    this.role = 'owner',
    required this.showRoleSelection,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('societies')
          .doc(societyId)
          .get(),
      builder: (context, snap) {
        if (snap.connectionState ==
            ConnectionState.waiting) {
          return const LoadingScreen();
        }

        final soc = snap.data?.data()
        as Map<String, dynamic>?;

        if (soc == null) {
          return const InviteCodeScreen();
        }

        final society = SocietyModel(
          id:         societyId,
          name:       soc['name'] as String? ?? '',
          totalFlats: soc['totalFlats'] as int? ?? 0,
          inviteCode:
          soc['inviteCode'] as String? ?? '',
          adminId:
          soc['adminId'] as String? ?? '',
          createdAt:  DateTime.now(),
        );

        // Show role selection screen
        if (showRoleSelection) {
          return SelectRoleScreen(
            society:   society,
            userName:  name,
            userPhone: phone,
          );
        }

        // Show pending approval screen
        return PendingApprovalScreen(
          userName:    name,
          societyName: society.name,
          flatNumber:  flatNumber,
          role:        role,
        );
      },
    );
  }
}

// ── Admin Loader ──────────────────────────────────────────────────────────────
class _AdminLoader extends StatelessWidget {
  final String societyId;
  const _AdminLoader({required this.societyId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('societies')
          .doc(societyId)
          .get(),
      builder: (context, snap) {
        if (snap.connectionState ==
            ConnectionState.waiting) {
          return const LoadingScreen();
        }
        final soc = snap.data?.data()
        as Map<String, dynamic>?;
        if (soc == null) {
          return const InviteCodeScreen();
        }
        return AdminDashboardScreen(
          societyId:   societyId,
          societyName: soc['name'] as String? ?? '',
          inviteCode:
          soc['inviteCode'] as String? ?? '',
        );
      },
    );
  }
}

// ── Approved Member Screen (temp) ─────────────────────────────────────────────
class _ApprovedMemberScreen extends StatelessWidget {
  final String name;
  final String flatId;

  const _ApprovedMemberScreen({
    required this.name,
    required this.flatId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment:
            MainAxisAlignment.center,
            children: [
              const Text('🏠',
                  style: TextStyle(fontSize: 60)),
              const SizedBox(height: 16),
              const Text('Resident Dashboard',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Text('Welcome back, $name!',
                  style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text('Flat: $flatId',
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted)),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger),
                  onPressed: () async {
                    await FirebaseAuth
                        .instance.signOut();
                  },
                  child: const Text('Logout'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Error Screen ──────────────────────────────────────────────────────────────
class _ErrorScreen extends StatelessWidget {
  final String message;
  final String uid;

  const _ErrorScreen({
    required this.message,
    required this.uid,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment:
            MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  color: AppColors.danger, size: 48),
              const SizedBox(height: 16),
              const Text('Something went wrong',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger),
                  onPressed: () async {
                    await FirebaseAuth
                        .instance.signOut();
                  },
                  child: const Text(
                      'Logout & Retry'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}