// FILE: lib/features/admin/presentation/components/sidebar.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alumni/core/constants/app_colors.dart';
import 'package:alumni/features/admin/presentation/screens/admin_post_approval.dart'
    show CombinedPendingBadge;

// ─────────────────────────────────────────────────────────────────────────────
// Shared staff role + permissions, used by Sidebar to decide which nav
// items to show. If you already have a StaffRole enum elsewhere (e.g. in
// user_verification_moderation_screen.dart), delete the duplicate there
// and import this one instead, so there's a single source of truth.
// ─────────────────────────────────────────────────────────────────────────────
enum StaffRole { admin, registrar, moderator, unknown }

extension StaffRoleX on StaffRole {
  bool get canVerifyUsers         => this == StaffRole.admin || this == StaffRole.registrar;
  bool get canManageEvents        => this == StaffRole.admin || this == StaffRole.moderator;
  bool get canManageJobs          => this == StaffRole.admin;
  bool get canManageAnnouncements => this == StaffRole.admin || this == StaffRole.moderator;
  bool get canSeeGrowthMetrics    => this == StaffRole.admin || this == StaffRole.registrar;
  bool get canApprovePost         => this == StaffRole.admin || this == StaffRole.moderator;

  static StaffRole from(String? raw) {
    switch (raw?.toLowerCase().trim()) {
      case 'admin':     return StaffRole.admin;
      case 'registrar': return StaffRole.registrar;
      case 'moderator': return StaffRole.moderator;
      default:          return StaffRole.unknown;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sidebar
//
// Reusable admin nav sidebar. Pass in the current route so the matching
// nav item is highlighted as active.
//
// USAGE:
//   Row(
//     children: [
//       Sidebar(activeRoute: '/job_board_management'),
//       Expanded(child: ...your page content...),
//     ],
//   )
// ─────────────────────────────────────────────────────────────────────────────

class Sidebar extends StatelessWidget {
  /// The route name of the screen currently using this sidebar,
  /// e.g. '/job_board_management'. Used to highlight the active nav item.
  final String activeRoute;

  /// The signed-in staff member's role. Controls which restricted nav
  /// items (Job Board, Growth Metrics, etc.) are shown.
  final StaffRole role;

  /// Optional display info for the footer. Falls back to generic text.
  final String? adminName;
  final String? adminRole;

  const Sidebar({
    super.key,
    required this.activeRoute,
    this.role = StaffRole.admin,
    this.adminName,
    this.adminRole,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 272,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFEEF0F4))),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text('ALUMNI',
                style: GoogleFonts.cormorantGaramond(
                    fontSize: 22,
                    letterSpacing: 6,
                    color: AppColors.brandRed,
                    fontWeight: FontWeight.w300)),
            const SizedBox(height: 4),
            Text('ARCHIVE PORTAL',
                style: GoogleFonts.inter(
                    fontSize: 9, letterSpacing: 2,
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.bold)),
          ]),
        ),
        const Divider(height: 1, color: Color(0xFFF0F0F0)),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              _navSection('NETWORK', [
                _navItem(context, Icons.dashboard_outlined, 'Overview',
                    route: '/admin_dashboard'),
              ]),
              const SizedBox(height: 20),
              _navSection('ENGAGEMENT', [
                _navItem(context, Icons.emoji_events_outlined,
                    'Career Milestones',
                    route: '/career_milestones'),
              ]),
              const SizedBox(height: 20),
              _navSection('ADMIN FEATURES', [
                if (role.canVerifyUsers)
                  _navItem(context, Icons.verified_user_outlined,
                      'User Verification',
                      route: '/user_verification_moderation'),
                if (role.canManageEvents)
                  _navItem(context, Icons.event_outlined, 'Event Planning',
                      route: '/event_planning'),
                if (role.canManageJobs)
                  _navItem(context, Icons.work_outline, 'Job Board',
                      route: '/job_board_management'),
                if (role.canSeeGrowthMetrics)
                  _navItem(context, Icons.bar_chart_outlined, 'Growth Metrics',
                      route: '/growth_metrics'),
                if (role.canManageAnnouncements)
                  _navItem(context, Icons.campaign_outlined, 'Announcements',
                      route: '/announcement_management'),
                if (role.canApprovePost)
                  _navItem(context, Icons.rate_review_outlined, 'Post Approval',
                      route: '/post_approval', badge: const CombinedPendingBadge()),
              ]),
            ]),
          ),
        ),
        const Divider(height: 1, color: Color(0xFFF0F0F0)),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.brandRed.withOpacity(0.1),
              child: Text((adminName?.isNotEmpty == true ? adminName![0] : 'A')
                      .toUpperCase(),
                  style: GoogleFonts.cormorantGaramond(
                      color: AppColors.brandRed, fontSize: 16)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(adminName ?? 'Registrar Admin',
                    style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                Text(adminRole ?? 'NETWORK OVERSEER',
                    style: GoogleFonts.inter(
                        fontSize: 9, color: AppColors.mutedText)),
              ]),
            ),
            IconButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
              icon: const Icon(Icons.logout_rounded,
                  size: 16, color: AppColors.mutedText),
              tooltip: 'Sign out',
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _navSection(String title, List<Widget> items) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 12, bottom: 8),
        child: Text(title,
            style: GoogleFonts.inter(
                fontSize: 9, letterSpacing: 2,
                fontWeight: FontWeight.w700,
                color: AppColors.mutedText.withOpacity(0.6))),
      ),
      ...items,
    ]);
  }

  Widget _navItem(BuildContext context, IconData icon, String label,
      {required String route, Widget? badge}) {
    final isActive = activeRoute == route;
    return Material(
      color: isActive
          ? AppColors.brandRed.withOpacity(0.07)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: !isActive
            ? () => Navigator.pushNamed(context, route)
            : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            Icon(icon,
                size: 17,
                color: isActive ? AppColors.brandRed : AppColors.mutedText),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: isActive ? AppColors.brandRed : AppColors.darkText,
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.w400)),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
              badge,
            ],
          ]),
        ),
      ),
    );
  }
}