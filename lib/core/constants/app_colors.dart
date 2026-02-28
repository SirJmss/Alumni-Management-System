import 'package:flutter/material.dart';

/// Centralized color palette for the entire Alumni Management System
/// Follows the established brand identity (deep red, soft neutrals, modern grays)
class AppColors {
  // ── Primary / Brand Colors ───────────────────────────────────────
  static const Color brandRed     = Color(0xFF991B1B);   // Main accent / danger / call-to-action
  static const Color brandRedDark = Color(0xFF7A1414);   // Darker variant for hover/pressed states

  // ── Background / Surface Colors ──────────────────────────────────
  static const Color softWhite    = Color(0xFFFDFDFD);   // Main background (very light warm white)
  static const Color cardWhite    = Color(0xFFFFFFFF);   // Cards / elevated surfaces
  static const Color offWhite     = Color(0xFFFAFAFA);   // Subtle alternate background

  // ── Text Colors ──────────────────────────────────────────────────
  static const Color darkText     = Color(0xFF111827);   // Primary text (almost black)
  static const Color mutedText    = Color(0xFF6B7280);   // Secondary / caption / placeholder text
  static const Color lightText    = Color(0xFF9CA3AF);   // Very light gray text (disabled, subtle)

  // ── Border / Divider Colors ──────────────────────────────────────
  static const Color borderSubtle = Color(0xFFE5E7EB);   // Light borders, dividers
  static const Color borderMedium = Color(0xFFD1D5DB);   // Slightly stronger borders

  // ── Status / Semantic Colors ─────────────────────────────────────
  static const Color success      = Color(0xFF10B981);   // Verified, success, green
  static const Color warning      = Color(0xFFF59E0B);   // Pending, warning, orange
  static const Color error        = Color(0xFFEF4444);   // Denied, error, red
  static const Color info         = Color(0xFF3B82F6);   // Info, links, blue

  // ── Utility / Overlay Colors ─────────────────────────────────────
  static const Color overlayLight = Color(0x1A000000);   // 10% black overlay
  static const Color overlayDark  = Color(0x33000000);   // 20% black overlay

  // ── Gradients (example usage) ────────────────────────────────────
  static const LinearGradient brandGradient = LinearGradient(
    colors: [brandRed, Color(0xFFB91C1C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}