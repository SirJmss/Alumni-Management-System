import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:alumni/core/constants/app_colors.dart';

class UserVerificationScreen extends StatefulWidget {
  const UserVerificationScreen({super.key});

  @override
  State<UserVerificationScreen> createState() => _UserVerificationScreenState();
}

class _UserVerificationScreenState extends State<UserVerificationScreen> {
  bool isVerificationTab = true; // true = User Verification, false = Reports & Moderation

  List<Map<String, dynamic>> pendingVerifications = [];
  List<Map<String, dynamic>> moderationReports = [];

  bool isLoading = true;
  String? errorMessage;

  int pendingCount = 0;
  int avgApprovalHours = 14;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final firestore = FirebaseFirestore.instance;

      final pendingSnap = await firestore
          .collection('users')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      final pending = pendingSnap.docs.map((doc) {
        final data = doc.data();
        final name = (data['name'] ?? data['fullName'] ?? 'Unknown').trim();
        return {
          'id': doc.id,
          'name': name,
          'degree': data['degree'] ?? '',
          'batchYear': data['batchYear'] ?? data['batch'] ?? '',
          'submittedVia': data['verificationMethod'] ?? 'Unknown',
          'reqId': 'REQ-${doc.id.substring(0, 6).toUpperCase()}',
          'timeAgo': _timeAgo((data['createdAt'] as Timestamp?)?.toDate()),
          'profilePhoto': data['profilePhotoUrl'],
          'idFront': data['idPhotoFrontUrl'],
          'idBack': data['idPhotoBackUrl'],
        };
      }).toList();

      final reportsSnap = await firestore
          .collection('reports')
          .where('status', isEqualTo: 'pending')
          .orderBy('reportedAt', descending: true)
          .limit(15)
          .get();

      final reports = reportsSnap.docs.map((doc) {
        final data = doc.data();
        final type = data['type'] ?? 'Unknown';
        final priority = data['priority'] ?? 'Medium';
        final color = priority == 'High' ? Colors.red : Colors.orange;
        return {
          'id': doc.id,
          'type': type,
          'priority': priority,
          'reportedBy': data['reportedByName'] ?? 'System',
          'timeAgo': _timeAgo((data['reportedAt'] as Timestamp?)?.toDate()),
          'snippet': (data['content'] ?? '').toString().substring(0, 140) + ((data['content']?.toString().length ?? 0) > 140 ? '...' : ''),
          'offender': data['offenderName'] ?? 'Unknown',
          'severityColor': color,
        };
      }).toList();

      final statsSnap = await firestore.collection('stats').doc('verification').get();
      final stats = statsSnap.data() ?? {};

      if (mounted) {
        setState(() {
          pendingVerifications = pending;
          moderationReports = reports;
          pendingCount = pending.length;
          avgApprovalHours = stats['avgApprovalHours']?.toInt() ?? 14;
          isLoading = false;
        });
      }
    } catch (e, stack) {
      debugPrint('Dashboard load error: $e\n$stack');
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to load data.\n$e';
          isLoading = false;
        });
      }
    }
  }

  String _timeAgo(DateTime? date) {
    if (date == null) return 'N/A';
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }

  Future<void> _approveUser(String userId) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'status': 'verified',
      'verifiedAt': FieldValue.serverTimestamp(),
      'verifiedBy': FirebaseAuth.instance.currentUser?.uid,
    });
    await _loadData();
  }

  Future<void> _rejectUser(String userId) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'status': 'rejected',
      'rejectedAt': FieldValue.serverTimestamp(),
      'rejectedBy': FirebaseAuth.instance.currentUser?.uid,
    });
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softWhite,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sidebar ────────────────────────────────────────────────────────────────
          Container(
            width: 300,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: AppColors.borderSubtle, width: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ALUMNI',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 22,
                          letterSpacing: 6,
                          color: AppColors.brandRed,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'ARCHIVE PORTAL',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          letterSpacing: 2,
                          color: AppColors.mutedText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSidebarSection('NETWORK', [
                          _SidebarItem(label: 'Overview', route: '/overview'),
                          _SidebarItem(label: 'Chapter Management', route: '/chapter_management'),
                        ]),
                        const SizedBox(height: 32),
                        _buildSidebarSection('ENGAGEMENT', [
                          _SidebarItem(label: 'Reunions & Events', route: '/reunions_events'),
                          _SidebarItem(label: 'Career Milestones', route: '/career_milestones'),
                        ]),
                        const SizedBox(height: 32),
                        _buildSidebarSection('ADMIN FEATURES', [
                          _SidebarItem(label: 'User Verification & Moderation', isActive: true, route: '/user_verification_moderation'),
                          _SidebarItem(label: 'Event Planning', route: '/event_planning'),
                          _SidebarItem(label: 'Job Board Management', route: '/job_board_management'),
                          _SidebarItem(label: 'Growth Metrics', route: '/growth_metrics'),
                          _SidebarItem(label: 'Announcement Management', route: '/announcement_management'),
                        ]),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.borderSubtle.withOpacity(0.3))),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.brandRed,
                            child: Text('A', style: GoogleFonts.cormorantGaramond(color: Colors.white, fontSize: 14)),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Registrar Admin', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                              Text('NETWORK OVERSEER', style: GoogleFonts.inter(fontSize: 9, color: AppColors.mutedText)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: () async {
                          await FirebaseAuth.instance.signOut();
                          if (mounted) Navigator.pushReplacementNamed(context, '/');
                        },
                        child: Text(
                          'DISCONNECT',
                          style: GoogleFonts.inter(fontSize: 10, letterSpacing: 2, color: AppColors.mutedText, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main content ────────────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row ───────────────────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Trust & Safety Dashboard',
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 40,
                              fontWeight: FontWeight.w400,
                              color: AppColors.darkText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Verify identities and moderate community interactions.',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: AppColors.mutedText,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => setState(() => isVerificationTab = true),
                            child: _TabButton(label: 'User Verification', active: isVerificationTab),
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () => setState(() => isVerificationTab = false),
                            child: _TabButton(label: 'Reports & Moderation', active: !isVerificationTab),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),

                  // Tab content ────────────────────────────────────────────────────────
                  if (isVerificationTab)
                    _buildVerificationTab()
                  else
                    _buildModerationTab(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left column ── Verification Health + Critical Alerts
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Card(
                    title: 'VERIFICATION HEALTH',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _StatRow(label: 'Avg. Approval Time', value: '$avgApprovalHours h'),
                        const SizedBox(height: 24),
                        _StatRow(
                          label: 'Pending Requests',
                          value: pendingCount.toString(),
                          progress: pendingCount / 200.clamp(0.0, 1.0),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  _Card(
                    title: 'CRITICAL ALERTS',
                    accentColor: Colors.red,
                    child: Column(
                      children: [
                        _AlertItem(
                          icon: Icons.warning_amber_rounded,
                          title: 'Spam Attack Detected',
                          subtitle: '12 new accounts flagged from same IP range.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 32),

            // Right column ── Identity Verification Queue
            Expanded(
              flex: 5,
              child: _Card(
                title: 'Identity Verification Queue',
                search: true,
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : pendingVerifications.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 100),
                              child: Text(
                                'No pending verification requests',
                                style: GoogleFonts.inter(fontSize: 17, color: AppColors.mutedText),
                              ),
                            ),
                          )
                        : Column(
                            children: pendingVerifications.map((user) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 20),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 26,
                                      backgroundColor: AppColors.brandRed.withOpacity(0.1),
                                      child: Text(
                                        (user['name'] as String)[0],
                                        style: GoogleFonts.inter(color: AppColors.brandRed, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            user['name'] as String,
                                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${user['degree']} • Class of ${user['batchYear']}',
                                            style: GoogleFonts.inter(fontSize: 13, color: AppColors.mutedText),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Via ${user['submittedVia']} • ${user['reqId']} • ${user['timeAgo']}',
                                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedText),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        _ActionChip(
                                          label: 'View Docs',
                                          icon: Icons.description_outlined,
                                          color: AppColors.brandRed,
                                          onTap: () => _showUserDocs(user),
                                        ),
                                        const SizedBox(width: 12),
                                        _ActionChip(
                                          label: 'Approve',
                                          icon: Icons.check_circle_outline,
                                          color: Colors.green,
                                          onTap: () => _approveUser(user['id'] as String),
                                        ),
                                        const SizedBox(width: 12),
                                        _ActionChip(
                                          label: 'Reject',
                                          icon: Icons.cancel_outlined,
                                          color: Colors.red,
                                          onTap: () => _rejectUser(user['id'] as String),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModerationTab() {
    return _Card(
      title: 'Reports & Moderation Queue',
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : moderationReports.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 100),
                    child: Text(
                      'No pending reports at the moment.',
                      style: GoogleFonts.inter(fontSize: 17, color: AppColors.mutedText),
                    ),
                  ),
                )
              : Column(
                  children: moderationReports.map((report) {
                    final color = report['severityColor'] as Color;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(Icons.warning_amber, color: color, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      report['type'] as String,
                                      style: GoogleFonts.inter(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: color,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        (report['priority'] as String).toUpperCase(),
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: color,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Reported by ${report['reportedBy']} • ${report['timeAgo']}',
                                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.mutedText),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  report['snippet'] as String,
                                  style: GoogleFonts.inter(fontSize: 14),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Offender: ${report['offender']}',
                                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              _ActionChip(
                                label: 'View History',
                                icon: Icons.history,
                                color: AppColors.brandRed,
                                onTap: () {},
                              ),
                              const SizedBox(height: 10),
                              _ActionChip(
                                label: 'Warn User',
                                icon: Icons.warning_amber,
                                color: Colors.orange,
                                onTap: () {},
                              ),
                              const SizedBox(height: 10),
                              _ActionChip(
                                label: 'Remove & Ban',
                                icon: Icons.block,
                                color: Colors.red,
                                onTap: () {},
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
    );
  }

  // ── Reusable components ────────────────────────────────────────────────────────

  Widget _TabButton({required String label, required bool active}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      decoration: BoxDecoration(
        color: active ? AppColors.brandRed : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: active ? AppColors.brandRed : AppColors.borderSubtle),
        boxShadow: active
            ? [BoxShadow(color: AppColors.brandRed.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 6))]
            : null,
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: active ? Colors.white : AppColors.darkText,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _Card({
    required String title,
    bool search = false,
    Widget? child,
    Color? accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 28,
                  fontWeight: FontWeight.w400,
                  color: accentColor ?? AppColors.darkText,
                ),
              ),
              if (search) ...[
                const Spacer(),
                SizedBox(
                  width: 300,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by name or degree...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      filled: true,
                      fillColor: AppColors.softWhite,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 28),
          if (child != null) child,
        ],
      ),
    );
  }

  Widget _StatRow({
    required String label,
    required String value,
    double? progress,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.mutedText,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.cormorantGaramond(
            fontSize: 36,
            fontWeight: FontWeight.w300,
            color: AppColors.darkText,
          ),
        ),
        if (progress != null) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: AppColors.softWhite,
              color: AppColors.brandRed,
              minHeight: 10,
            ),
          ),
        ],
      ],
    );
  }

  Widget _AlertItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.red, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(fontSize: 14, color: AppColors.mutedText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ActionChip({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.inter(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserDocs(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${user['name']} - Documents'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (user['profilePhoto'] != null) ...[
                const Text('Profile Photo:'),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(user['profilePhoto'], height: 180, fit: BoxFit.cover),
                ),
                const SizedBox(height: 24),
              ],
              if (user['idFront'] != null) ...[
                const Text('ID Front:'),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(user['idFront'], height: 180, fit: BoxFit.cover),
                ),
                const SizedBox(height: 24),
              ],
              if (user['idBack'] != null) ...[
                const Text('ID Back:'),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(user['idBack'], height: 180, fit: BoxFit.cover),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  // Sidebar helpers ──────────────────────────────────────────────────────────────
  Widget _buildSidebarSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
            color: AppColors.mutedText.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 16),
        ...items,
      ],
    );
  }

  Widget _SidebarItem({required String label, bool isActive = false, String? route}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: route != null ? () => Navigator.pushNamed(context, route) : null,
        child: MouseRegion(
          cursor: route != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              color: isActive ? AppColors.brandRed : AppColors.darkText,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}