import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/society_model.dart';
import '../../data/models/user_model.dart';
import 'select_flat_screen.dart';

class SelectRoleScreen extends StatelessWidget {
  final SocietyModel society;
  final String userName;
  final String userPhone;

  const SelectRoleScreen({
    super.key,
    required this.society,
    required this.userName,
    required this.userPhone,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [
        // Header
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('👤',
                  style: TextStyle(fontSize: 40)),
              const SizedBox(height: 16),
              const Text('Select Your Role',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
              const SizedBox(height: 8),
              // Society name chip
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '🏢 ${society.name}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),

        // Body
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text('Hi $userName! I am a...',
                    style: AppText.h3),
                const SizedBox(height: 20),

                // Owner tile
                _RoleTile(
                  icon: '🏠',
                  title: 'Flat Owner',
                  subtitle: 'I own a flat in this society',
                  points: const [
                    'Can approve or reject tenants',
                    'Responsible for flat maintenance',
                    'Full access to society features',
                  ],
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SelectFlatScreen(
                        society:   society,
                        userName:  userName,
                        userPhone: userPhone,
                        role:      UserRole.owner,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Tenant tile
                _RoleTile(
                  icon: '🔑',
                  title: 'Tenant',
                  subtitle: 'I am renting a flat here',
                  points: const [
                    'Approved by Owner then Admin',
                    'View society expenses',
                    'Participate in voting',
                  ],
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SelectFlatScreen(
                        society:   society,
                        userName:  userName,
                        userPhone: userPhone,
                        role:      UserRole.tenant,
                      ),
                    ),
                  ),
                ),

                const Spacer(),
                const Text(
                    'Your role cannot be changed after approval.',
                    style: AppText.small,
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                // Wrong society? Logout
                TextButton.icon(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                  },
                  icon: const Icon(
                      Icons.logout,
                      size: 14,
                      color: AppColors.textMuted),
                  label: const Text(
                      'Wrong society? Logout',
                      style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12)),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

class _RoleTile extends StatelessWidget {
  final String icon, title, subtitle;
  final List<String> points;
  final VoidCallback onTap;

  const _RoleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.points,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
            boxShadow: [BoxShadow(
                color: AppColors.primary.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))],
          ),
          child: Row(children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius: BorderRadius.circular(14)),
              child: Center(child: Text(icon,
                  style: const TextStyle(fontSize: 28))),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.h4),
                const SizedBox(height: 3),
                Text(subtitle, style: AppText.body),
                const SizedBox(height: 8),
                ...points.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(children: [
                    const Icon(Icons.check_circle_rounded,
                        color: AppColors.success, size: 14),
                    const SizedBox(width: 6),
                    Text(p, style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary)),
                  ]),
                )),
              ],
            )),
            const Icon(Icons.chevron_right,
                color: AppColors.textMuted),
          ]),
        ),
      );
}