// =============================================================================
// FILE: lib/features/admin/presentation/screens/growth_metrics_screen.dart
//
// Live analytics using StreamBuilder throughout — no polling, no Future.wait.
// Same sidebar + design system as JobBoardManagementScreen / AdminDashboardScreen.
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:alumni/core/constants/app_colors.dart';
import 'package:alumni/features/admin/presentation/screens/admin_post_approval.dart'
    show CombinedPendingBadge;

// ══════════════════════════════════════════════════════════════════════════
//  ROLE PERMISSIONS
// ══════════════════════════════════════════════════════════════════════════
enum StaffRole { admin, registrar, moderator, unknown }

extension StaffRoleX on StaffRole {
  bool get canSeeGrowthMetrics => this == StaffRole.admin || this == StaffRole.registrar;

  static StaffRole from(String? raw) {
    switch (raw?.toLowerCase().trim()) {
      case 'admin':     return StaffRole.admin;
      case 'registrar': return StaffRole.registrar;
      case 'moderator': return StaffRole.moderator;
      default:          return StaffRole.unknown;
    }
  }
}

class GrowthMetricsScreen extends StatefulWidget {
  const GrowthMetricsScreen({super.key});

  @override
  State<GrowthMetricsScreen> createState() => _GrowthMetricsScreenState();
}

class _GrowthMetricsScreenState extends State<GrowthMetricsScreen> {
  String _adminName = 'Admin';
  String _adminRole = 'ADMIN';
  StaffRole _role = StaffRole.unknown;

  @override
  void initState() {
    super.initState();
    _loadAdmin();
  }

  Future<void> _loadAdmin() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        final d = doc.data()!;
        setState(() {
          _adminName = d['name']?.toString() ??
              d['fullName']?.toString() ??
              FirebaseAuth.instance.currentUser?.displayName ??
              'Admin';
          _adminRole = d['role']?.toString().toUpperCase() ?? 'ADMIN';
          _role = StaffRoleX.from(d['role']?.toString());
        });
      }
    } catch (_) {}
  }

  // ══════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    // ─── Role-based access guard ───
    if (!_role.canSeeGrowthMetrics) {
      return Scaffold(
        backgroundColor: AppColors.softWhite,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.brandRed.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outline,
                    size: 40, color: AppColors.brandRed),
              ),
              const SizedBox(height: 24),
              Text('Access Denied',
                  style: GoogleFonts.cormorantGaramond(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkText)),
              const SizedBox(height: 12),
              Text(
                'Your role (${_adminRole}) does not have\npermission to access this page.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.mutedText,
                    height: 1.6),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () =>
                    Navigator.pushNamedAndRemoveUntil(
                        context, '/admin_dashboard', (r) => false),
                icon: const Icon(Icons.arrow_back, size: 16),
                label: Text('Back to Dashboard',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.softWhite,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSidebar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 28),

                  // ── Row 1: primary KPIs ──────────────────────────────────
                  _buildKpiRow(),
                  const SizedBox(height: 24),

                  // ── Row 2: secondary KPIs ────────────────────────────────
                  _buildSecondaryKpis(),
                  const SizedBox(height: 32),

                  // ── Row 3: users table + engagement ─────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _buildUserBreakdown()),
                      const SizedBox(width: 24),
                      Expanded(flex: 2, child: _buildEngagementCard()),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // ── Row 4: recent events + recent jobs ───────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildRecentSection(
                        title: 'Event Activity',
                        sub: 'Events created over time',
                        collection: 'events',
                        icon: Icons.event_outlined,
                        color: Colors.blue,
                        labelField: 'title',
                        dateField: 'createdAt',
                      )),
                      const SizedBox(width: 24),
                      Expanded(child: _buildRecentSection(
                        title: 'Job Board Activity',
                        sub: 'Job postings over time',
                        collection: 'job_posting',
                        icon: Icons.work_outline,
                        color: Colors.teal,
                        labelField: 'title',
                        dateField: 'createdAt',
                      )),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  SIDEBAR
  // ══════════════════════════════════════════════════════

  Widget _buildSidebar() {
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AppColors.borderSubtle, width: 0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.all(32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ALUMNI',
                style: GoogleFonts.cormorantGaramond(
                    fontSize: 22, letterSpacing: 6,
                    color: AppColors.brandRed, fontWeight: FontWeight.w300)),
            const SizedBox(height: 6),
            Text('ARCHIVE PORTAL',
                style: GoogleFonts.inter(
                    fontSize: 9, letterSpacing: 2,
                    color: AppColors.mutedText, fontWeight: FontWeight.bold)),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sidebarSection('NETWORK', [
                  _sidebarItem('Overview', route: '/admin_dashboard'),
                ]),
                const SizedBox(height: 32),
                _sidebarSection('ENGAGEMENT', [
                  _sidebarItem('Career Milestones', route: '/career_milestones'),
                ]),
                const SizedBox(height: 32),
                _sidebarSection('ADMIN FEATURES', [
                  _sidebarItem('User Verification & Moderation',
                      route: '/user_verification_moderation'),
                  _sidebarItem('Event Planning', route: '/event_planning'),
                  _sidebarItem('Job Board Management',
                      route: '/job_board_management'),
                  _sidebarItem('Growth Metrics',
                      route: '/growth_metrics', isActive: true),
                  _sidebarItem('Announcement Management',
                      route: '/announcement_management'),
                  _sidebarItemWithBadge(
                    label: 'Post Approval',
                    route: '/post_approval',
                    badge: const CombinedPendingBadge(),
                  ),
                ]),
              ],
            ),
          ),
        ),
        // Footer
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            border: Border(
                top: BorderSide(color: AppColors.borderSubtle.withOpacity(0.3))),
          ),
          child: Column(children: [
            Row(children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.brandRed.withOpacity(0.1),
                child: Text(
                    _adminName.isNotEmpty ? _adminName[0].toUpperCase() : 'A',
                    style: GoogleFonts.cormorantGaramond(
                        color: AppColors.brandRed, fontSize: 14)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_adminName,
                      style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.bold),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(_adminRole,
                      style: GoogleFonts.inter(
                          fontSize: 9, color: AppColors.mutedText)),
                ]),
              ),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (mounted) {
                    Navigator.pushNamedAndRemoveUntil(
                        context, '/login', (r) => false);
                  }
                },
                icon: const Icon(Icons.logout, size: 13, color: AppColors.mutedText),
                label: Text('DISCONNECT',
                    style: GoogleFonts.inter(
                        fontSize: 10, letterSpacing: 2,
                        color: AppColors.mutedText, fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════
  //  HEADER
  // ══════════════════════════════════════════════════════

  Widget _buildHeader() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Growth Metrics',
                style: GoogleFonts.cormorantGaramond(
                    fontSize: 36, fontWeight: FontWeight.w400,
                    color: AppColors.darkText)),
            Text('LIVE ANALYTICS  ·  ALL DATA UPDATES IN REAL-TIME',
                style: GoogleFonts.inter(
                    fontSize: 10, letterSpacing: 2,
                    color: AppColors.mutedText)),
          ]),
          // Live indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 7, height: 7,
                decoration: const BoxDecoration(
                    color: Colors.green, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text('LIVE',
                  style: GoogleFonts.inter(
                      fontSize: 9, fontWeight: FontWeight.w800,
                      color: Colors.green, letterSpacing: 1)),
            ]),
          ),
        ],
      ),
    ]);
  }

  // ══════════════════════════════════════════════════════
  //  PRIMARY KPI ROW  (3 large cards)
  // ══════════════════════════════════════════════════════

  Widget _buildKpiRow() {
    return Row(children: [
      Expanded(child: _liveKpiCard(
        title: 'Total Registered Alumni',
        subtitle: 'All accounts — any status',
        icon: Icons.people_outline,
        color: Colors.blue,
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        large: true,
      )),
      const SizedBox(width: 16),
      Expanded(child: _liveKpiCard(
        title: 'Verified Alumni',
        subtitle: 'Active & verified accounts',
        icon: Icons.verified_outlined,
        color: Colors.green,
        stream: FirebaseFirestore.instance.collection('users')
            .where('status', whereIn: ['verified', 'active']).snapshots(),
        large: true,
      )),
      const SizedBox(width: 16),
      Expanded(child: _liveKpiCard(
        title: 'Pending Verification',
        subtitle: 'Awaiting admin review',
        icon: Icons.hourglass_empty_outlined,
        color: AppColors.brandRed,
        stream: FirebaseFirestore.instance.collection('users')
            .where('status', isEqualTo: 'pending').snapshots(),
        large: true,
        alertWhenNonZero: true,
      )),
    ]);
  }

  // ══════════════════════════════════════════════════════
  //  SECONDARY KPI ROW  (4 smaller cards)
  // ══════════════════════════════════════════════════════

  Widget _buildSecondaryKpis() {
    return Row(children: [
      Expanded(child: _liveKpiCard(
        title: 'Total Events',
        subtitle: 'All time',
        icon: Icons.event_outlined,
        color: Colors.orange,
        stream: FirebaseFirestore.instance.collection('events').snapshots(),
      )),
      const SizedBox(width: 16),
      Expanded(child: _liveKpiCard(
        title: 'Job Postings',
        subtitle: 'Active opportunities',
        icon: Icons.work_outline,
        color: Colors.teal,
        stream: FirebaseFirestore.instance.collection('job_posting').snapshots(),
      )),
      const SizedBox(width: 16),
      Expanded(child: _liveKpiCard(
        title: 'Announcements',
        subtitle: 'Published to alumni',
        icon: Icons.campaign_outlined,
        color: Colors.indigo,
        stream: FirebaseFirestore.instance.collection('announcements').snapshots(),
      )),
      const SizedBox(width: 16),
      Expanded(child: _liveKpiCard(
        title: 'Active Chapters',
        subtitle: 'Regional & batch groups',
        icon: Icons.apartment_outlined,
        color: Colors.purple,
        stream: FirebaseFirestore.instance.collection('chapters')
            .where('status', isEqualTo: 'active').snapshots(),
      )),
    ]);
  }

  // ══════════════════════════════════════════════════════
  //  LIVE KPI CARD
  // ══════════════════════════════════════════════════════

  Widget _liveKpiCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Stream<QuerySnapshot> stream,
    bool large = false,
    bool alertWhenNonZero = false,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snap) {
        final count = snap.data?.docs.length ?? 0;
        final isAlert = alertWhenNonZero && count > 0;
        final isLoading =
            snap.connectionState == ConnectionState.waiting && !snap.hasData;

        return Container(
          padding: EdgeInsets.all(large ? 22 : 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isAlert ? color.withOpacity(0.4) : AppColors.borderSubtle,
              width: isAlert ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: large ? 38 : 32,
                    height: large ? 38 : 32,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: large ? 18 : 15),
                  ),
                  if (isAlert)
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                          color: color, shape: BoxShape.circle),
                    ),
                ],
              ),
              SizedBox(height: large ? 16 : 12),
              if (isLoading)
                SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color.withOpacity(0.5)))
              else
                Text('$count',
                    style: large
                        ? GoogleFonts.cormorantGaramond(
                            fontSize: 48, fontWeight: FontWeight.w600,
                            color: color, height: 1.0)
                        : GoogleFonts.cormorantGaramond(
                            fontSize: 36, fontWeight: FontWeight.w600,
                            color: color, height: 1.0)),
              const SizedBox(height: 4),
              Text(title,
                  style: GoogleFonts.inter(
                      fontSize: large ? 13 : 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkText),
                  maxLines: 2),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: GoogleFonts.inter(
                      fontSize: 10, color: AppColors.mutedText)),
            ],
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════
  //  USER BREAKDOWN TABLE
  // ══════════════════════════════════════════════════════

  Widget _buildUserBreakdown() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('User Status Breakdown',
            style: GoogleFonts.cormorantGaramond(
                fontSize: 22, fontWeight: FontWeight.w600,
                color: AppColors.darkText)),
        Text('Live count per status',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedText)),
        const SizedBox(height: 16),
        const Divider(color: AppColors.borderSubtle),
        const SizedBox(height: 8),

        // Header row
        Row(children: [
          Expanded(child: Text('STATUS',
              style: GoogleFonts.inter(
                  fontSize: 9, fontWeight: FontWeight.w700,
                  color: AppColors.mutedText, letterSpacing: 1))),
          Text('COUNT',
              style: GoogleFonts.inter(
                  fontSize: 9, fontWeight: FontWeight.w700,
                  color: AppColors.mutedText, letterSpacing: 1)),
          const SizedBox(width: 80),
          Text('SHARE',
              style: GoogleFonts.inter(
                  fontSize: 9, fontWeight: FontWeight.w700,
                  color: AppColors.mutedText, letterSpacing: 1)),
        ]),
        const SizedBox(height: 10),

        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('users').snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator(
                    color: AppColors.brandRed, strokeWidth: 2)),
              );
            }

            final all   = snap.data!.docs;
            final total = all.length;

            final statusCounts = <String, int>{};
            for (final doc in all) {
              final status = doc.data()['status']?.toString() ?? 'unknown';
              statusCounts[status] = (statusCounts[status] ?? 0) + 1;
            }

            final statuses = [
              ('active',   'Active',   Colors.green),
              ('verified', 'Verified', Colors.blue),
              ('pending',  'Pending',  Colors.orange),
              ('denied',   'Denied',   Colors.red),
            ];

            return Column(
              children: statuses.map((s) {
                final (key, label, color) = s;
                final count = statusCounts[key] ?? 0;
                final pct   = total > 0 ? count / total : 0.0;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(children: [
                    Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(
                          color: color, borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(label,
                          style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w500,
                              color: AppColors.darkText)),
                    ),
                    SizedBox(
                      width: 50,
                      child: Text('$count',
                          textAlign: TextAlign.right,
                          style: GoogleFonts.cormorantGaramond(
                              fontSize: 20, fontWeight: FontWeight.w600,
                              color: color)),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 80,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                        Text('${(pct * 100).toStringAsFixed(1)}%',
                            style: GoogleFonts.inter(
                                fontSize: 11, color: AppColors.mutedText)),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: pct,
                            backgroundColor: AppColors.borderSubtle,
                            valueColor: AlwaysStoppedAnimation(color),
                            minHeight: 5,
                          ),
                        ),
                      ]),
                    ),
                  ]),
                );
              }).toList(),
            );
          },
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════
  //  ENGAGEMENT CARD
  // ══════════════════════════════════════════════════════

  Widget _buildEngagementCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Platform Engagement',
            style: GoogleFonts.cormorantGaramond(
                fontSize: 22, fontWeight: FontWeight.w600,
                color: AppColors.darkText)),
        Text('Content created on platform',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedText)),
        const SizedBox(height: 16),
        const Divider(color: AppColors.borderSubtle),
        const SizedBox(height: 8),

        _engagementRow(
          icon: Icons.emoji_events_outlined,
          label: 'Achievement Posts',
          color: AppColors.brandRed,
          stream: FirebaseFirestore.instance
              .collection('achievement_posts')
              .where('status', isEqualTo: 'approved')
              .snapshots(),
        ),
        _engagementRow(
          icon: Icons.feed_outlined,
          label: 'Alumni Feed Posts',
          color: Colors.blue,
          stream: FirebaseFirestore.instance
              .collection('alumni_posts')
              .where('status', isEqualTo: 'approved')
              .snapshots(),
        ),
        _engagementRow(
          icon: Icons.pending_actions_outlined,
          label: 'Pending Posts',
          color: const Color(0xFFF59E0B),
          stream: FirebaseFirestore.instance
              .collection('alumni_posts')
              .where('status', isEqualTo: 'pending')
              .snapshots(),
        ),
        _engagementRow(
          icon: Icons.forum_outlined,
          label: 'Discussions',
          color: Colors.indigo,
          stream: FirebaseFirestore.instance
              .collection('discussions').snapshots(),
        ),
        _engagementRow(
          icon: Icons.star_outline,
          label: 'Career Milestones',
          color: Colors.orange,
          stream: FirebaseFirestore.instance
              .collection('career_milestones').snapshots(),
        ),
        _engagementRow(
          icon: Icons.person_add_outlined,
          label: 'Friend Connections',
          color: Colors.teal,
          stream: FirebaseFirestore.instance
              .collection('friend_requests')
              .where('status', isEqualTo: 'accepted')
              .snapshots(),
        ),
      ]),
    );
  }

  Widget _engagementRow({
    required IconData icon,
    required String label,
    required Color color,
    required Stream<QuerySnapshot> stream,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snap) {
          final count = snap.data?.docs.length ?? 0;
          return Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 15, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w500,
                      color: AppColors.darkText)),
            ),
            snap.connectionState == ConnectionState.waiting && !snap.hasData
                ? SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: color.withOpacity(0.4)))
                : Text('$count',
                    style: GoogleFonts.cormorantGaramond(
                        fontSize: 22, fontWeight: FontWeight.w600,
                        color: color)),
          ]);
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  RECENT ACTIVITY SECTION (generic)
  // ══════════════════════════════════════════════════════

  Widget _buildRecentSection({
    required String title,
    required String sub,
    required String collection,
    required IconData icon,
    required Color color,
    required String labelField,
    required String dateField,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: GoogleFonts.cormorantGaramond(
                fontSize: 20, fontWeight: FontWeight.w600,
                color: AppColors.darkText)),
        Text(sub,
            style: GoogleFonts.inter(
                fontSize: 11, color: AppColors.mutedText)),
        const SizedBox(height: 12),
        const Divider(color: AppColors.borderSubtle),

        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection(collection)
              .orderBy(dateField, descending: true)
              .limit(6)
              .snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator(
                    color: AppColors.brandRed, strokeWidth: 2)),
              );
            }
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Center(child: Text('No data yet',
                    style: GoogleFonts.inter(color: AppColors.mutedText))),
              );
            }

            return Column(
              children: docs.map((doc) {
                final d     = doc.data();
                final label = d[labelField]?.toString() ?? 'Untitled';
                final ts    = d[dateField] as Timestamp?;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(icon, size: 15, color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(label,
                          style: GoogleFonts.inter(
                              fontSize: 12, fontWeight: FontWeight.w500,
                              color: AppColors.darkText),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    if (ts != null)
                      Text(_fmt(ts),
                          style: GoogleFonts.inter(
                              fontSize: 10, color: AppColors.mutedText)),
                  ]),
                );
              }).toList(),
            );
          },
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════
  //  SIDEBAR HELPERS
  // ══════════════════════════════════════════════════════

  Widget _sidebarSection(String title, List<Widget> items) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: GoogleFonts.inter(
                fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold,
                color: AppColors.mutedText.withOpacity(0.7))),
        const SizedBox(height: 16),
        ...items,
      ]);

  Widget _sidebarItem(String label, {String? route, bool isActive = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: GestureDetector(
          onTap: route != null && !isActive
              ? () => Navigator.pushNamed(context, route)
              : null,
          child: MouseRegion(
            cursor: route != null && !isActive
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 13.5,
                    color: isActive ? AppColors.brandRed : AppColors.darkText,
                    fontWeight:
                        isActive ? FontWeight.w600 : FontWeight.w400)),
          ),
        ),
      );

  Widget _sidebarItemWithBadge({
    required String label,
    required String route,
    required Widget badge,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: GestureDetector(
          onTap: () => Navigator.pushNamed(context, route),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Row(children: [
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 13.5,
                      color: AppColors.darkText,
                      fontWeight: FontWeight.w400)),
              const SizedBox(width: 8),
              badge,
            ]),
          ),
        ),
      );

  String _fmt(Timestamp ts) {
    final date = ts.toDate();
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    if (diff.inDays < 7)     return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(date);
  }
}


// CareerMilestonesScreen(),