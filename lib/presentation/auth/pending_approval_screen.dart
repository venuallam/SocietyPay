import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';
import '../../main.dart';

class PendingApprovalScreen extends StatelessWidget {
  final String userName;
  final String societyName;
  final String flatNumber;
  final String role;

  const PendingApprovalScreen({
    super.key,
    required this.userName,
    required this.societyName,
    required this.flatNumber,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated waiting icon
              Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.warning,
                      width: 3),
                ),
                child: const Center(
                    child: Text('⏳',
                        style: TextStyle(fontSize: 52))),
              ),
              const SizedBox(height: 32),

              const Text('Request Submitted!',
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),

              Text(
                  'Hi $userName! Your request to join\n'
                      '$societyName as $role\n'
                      'for $flatNumber is pending approval.',
                  style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                      height: 1.6),
                  textAlign: TextAlign.center),

              const SizedBox(height: 32),

              // Status card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.warning
                          .withOpacity(0.3)),
                ),
                child: Column(children: [
                  _StatusStep(
                      icon: '✅',
                      title: 'Request Submitted',
                      subtitle: 'Your join request is sent',
                      done: true),
                  const SizedBox(height: 12),
                  _StatusStep(
                      icon: '⏳',
                      title: 'Admin Review',
                      subtitle:
                      'Admin will approve your request',
                      done: false),
                  const SizedBox(height: 12),
                  _StatusStep(
                      icon: '🎉',
                      title: 'Get Access',
                      subtitle:
                      'Access society features',
                      done: false),
                ]),
              ),

              const SizedBox(height: 32),

              const Text(
                'The admin has been notified.\n'
                    'Please check back after approval.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13),
              ),

              const SizedBox(height: 24),

              // Refresh button
              OutlinedButton.icon(
                onPressed: () {
                  // Refresh — go back to AuthWrapper
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AuthWrapper()),
                        (route) => false,
                  );
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Check Approval Status'),
              ),

              const SizedBox(height: 12),

              // Logout option
              TextButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                          const AuthWrapper()),
                          (route) => false,
                    );
                  }
                },
                child: const Text(
                    'Logout',
                    style: TextStyle(
                        color: AppColors.textMuted)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusStep extends StatelessWidget {
  final String icon, title, subtitle;
  final bool done;
  const _StatusStep({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.done,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
    Text(icon, style: const TextStyle(fontSize: 24)),
    const SizedBox(width: 12),
    Expanded(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: done
                ? AppColors.success
                : AppColors.textPrimary)),
        Text(subtitle, style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary)),
      ],
    )),
    if (done)
      const Icon(Icons.check_circle,
          color: AppColors.success, size: 20),
  ]);
}