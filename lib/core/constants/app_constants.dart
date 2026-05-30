import 'package:flutter/material.dart';

// ── Brand Colors ──────────────────────────────────────────────────────────────
class AppColors {
  AppColors._();

  static const primary       = Color(0xFF1A3A6B);
  static const primaryDark   = Color(0xFF0F2347);
  static const primaryLight  = Color(0xFF2952A3);
  static const accent        = Color(0xFF2979FF);
  static const accentLight   = Color(0xFFE8F0FE);
  static const success       = Color(0xFF1B8A4E);
  static const successLight  = Color(0xFFE6F4ED);
  static const warning       = Color(0xFFD97706);
  static const warningLight  = Color(0xFFFEF3C7);
  static const danger        = Color(0xFFC0392B);
  static const dangerLight   = Color(0xFFFDE8E8);
  static const bgLight       = Color(0xFFF4F7FC);
  static const border        = Color(0xFFD6E0F0);
  static const textPrimary   = Color(0xFF0F2347);
  static const textSecondary = Color(0xFF4A6080);
  static const textMuted     = Color(0xFF8FA3BF);
  static const white         = Color(0xFFFFFFFF);
}

// ── Text Styles ───────────────────────────────────────────────────────────────
class AppText {
  AppText._();

  static const h1 = TextStyle(
      fontSize: 28, fontWeight: FontWeight.w800,
      color: AppColors.textPrimary);
  static const h2 = TextStyle(
      fontSize: 22, fontWeight: FontWeight.w700,
      color: AppColors.textPrimary);
  static const h3 = TextStyle(
      fontSize: 18, fontWeight: FontWeight.w700,
      color: AppColors.textPrimary);
  static const h4 = TextStyle(
      fontSize: 15, fontWeight: FontWeight.w700,
      color: AppColors.textPrimary);
  static const body = TextStyle(
      fontSize: 14, color: AppColors.textSecondary);
  static const bodyBold = TextStyle(
      fontSize: 14, fontWeight: FontWeight.w700,
      color: AppColors.textPrimary);
  static const small = TextStyle(
      fontSize: 12, color: AppColors.textMuted);
  static const label = TextStyle(
      fontSize: 11, fontWeight: FontWeight.w700,
      letterSpacing: 0.8, color: AppColors.textMuted);
}

// ── App Strings ───────────────────────────────────────────────────────────────
class AppStrings {
  AppStrings._();

  static const appName  = 'SocietyPay';
  static const tagline  = 'Making Society Management Simple';
  static const currency = '₹';
}