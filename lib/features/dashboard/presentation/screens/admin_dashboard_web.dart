import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:alumni/core/constants/app_colors.dart';
import 'package:alumni/features/admin/presentation/screens/admin_post_approval.dart';
import 'package:alumni/features/gallery/presentation/screens/gallery_screen.dart'
    show AdminAchievementQueue;

// ═══════════════════════════════════════════════════════════════════════════
//  ROLE PERMISSIONS MODEL
//
//  admin      — full access
//  registrar  — user verification, growth metrics, career milestones
//  moderator  — post approval, announcements, event planning
// ═══════════════════════════════════════════════════════════════════════════

enum StaffRole { admin, registrar, moderator, unknown }

extension StaffRoleX on StaffRole {
  bool get canVerifyUsers          => this == StaffRole.admin || this == StaffRole.registrar;
  bool get canSeeGrowthMetrics     => this == StaffRole.admin || this == StaffRole.registrar;
  bool get canManageEvents         => this == StaffRole.admin || this == StaffRole.moderator;
  bool get canManageJobs           => this == StaffRole.admin;
  bool get canManageAnnouncements  => this == StaffRole.admin || this == StaffRole.moderator;
  bool get canApprovePost          => this == StaffRole.admin || this == StaffRole.moderator;
  bool get canSeeCareerMilestones  => this == StaffRole.admin || this == StaffRole.registrar;
  bool get canSeeDonationReports   => this == StaffRole.admin;
  bool get canSendNewsletter       => this == StaffRole.admin;

  // Stats
  bool get canSeeAlumniCount       => this == StaffRole.admin || this == StaffRole.registrar;
  bool get canSeePendingVerif      => this == StaffRole.admin || this == StaffRole.registrar;
  bool get canSeeChapters          => this == StaffRole.admin;
  bool get canSeeEventStats        => this == StaffRole.admin || this == StaffRole.moderator;
  bool get canSeeJobStats          => this == StaffRole.admin;
  bool get canSeeAnnouncementStats => this == StaffRole.admin || this == StaffRole.moderator;
  bool get canSeePendingPosts      => this == StaffRole.admin || this == StaffRole.moderator;

  // Sections
  bool get canSeeVerifQueue        => this == StaffRole.admin || this == StaffRole.registrar;
  bool get canSeeNetworkPulse      => this == StaffRole.admin || this == StaffRole.moderator;
  bool get canSeeRecentActivity    => this == StaffRole.admin || this == StaffRole.registrar;
  bool get canSeePostApproval      => this == StaffRole.admin || this == StaffRole.moderator;

  String get displayName {
    switch (this) {
      case StaffRole.admin:     return 'ADMIN';
      case StaffRole.registrar: return 'REGISTRAR';
      case StaffRole.moderator: return 'MODERATOR';
      case StaffRole.unknown:   return 'STAFF';
    }
  }

  Color get roleColor {
    switch (this) {
      case StaffRole.admin:     return AppColors.brandRed;
      case StaffRole.registrar: return Colors.blue;
      case StaffRole.moderator: return Colors.purple;
      case StaffRole.unknown:   return AppColors.mutedText;
    }
  }

  String get roleDescription {
    switch (this) {
      case StaffRole.admin:     return 'Full system access';
      case StaffRole.registrar: return 'Verification & metrics';
      case StaffRole.moderator: return 'Content & events';
      case StaffRole.unknown:   return 'Limited access';
    }
  }

  static StaffRole from(String? raw) {
    switch (raw?.toLowerCase().trim()) {
      case 'admin':     return StaffRole.admin;
      case 'registrar': return StaffRole.registrar;
      case 'moderator': return StaffRole.moderator;
      default:          return StaffRole.unknown;
    }
  }
}

class _PermItem {
  final String label;
  final bool allowed;
  const _PermItem(this.label, this.allowed);
}

// ═══════════════════════════════════════════════════════════════════════════
//  ADMIN DASHBOARD WEB
// ═══════════════════════════════════════════════════════════════════════════

class AdminDashboardWeb extends StatefulWidget {
  const AdminDashboardWeb({super.key});
  @override
  State<AdminDashboardWeb> createState() => _AdminDashboardWebState();
}

class _AdminDashboardWebState extends State<AdminDashboardWeb> {
  int _totalAlumni          = 0;
  int _pendingVerifications = 0;
  int _activeChapters       = 0;
  int _totalEvents          = 0;
  int _totalJobs            = 0;
  int _totalAnnouncements   = 0;
  int _pendingPosts         = 0;

  List<Map<String, dynamic>> _pendingUsers   = [];
  List<Map<String, dynamic>> _networkPulse   = [];
  List<Map<String, dynamic>> _recentActivity = [];

  String    _adminName   = 'Admin';
  StaffRole _role        = StaffRole.unknown;
  int       _postQueueTab = 0;

  bool    _isLoading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  // ── Load ─────────────────────────────────────────────

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      final fs  = FirebaseFirestore.instance;
      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid != null) {
        final doc = await fs.collection('users').doc(uid).get();
        if (doc.exists && mounted) {
          final d = doc.data()!;
          _adminName = d['name']?.toString() ?? d['fullName']?.toString() ??
              FirebaseAuth.instance.currentUser?.displayName ?? 'Admin';
          _role = StaffRoleX.from(d['role']?.toString());
        }
      }

      Future<Object?> maybe(bool cond, Future<Object?> f) => cond ? f : Future.value(null);

      final r = await Future.wait([
        maybe(_role.canSeeAlumniCount,
            fs.collection('users').where('status', whereIn: ['verified','active']).count().get()),
        maybe(_role.canSeePendingVerif,
            fs.collection('users').where('status', isEqualTo: 'pending').count().get()),
        maybe(_role.canSeeChapters,
            fs.collection('chapters').where('status', isEqualTo: 'active').count().get()),
        maybe(_role.canSeeEventStats,
            fs.collection('events').count().get()),
        maybe(_role.canSeeJobStats,
            fs.collection('job_posting').count().get()),
        maybe(_role.canSeeAnnouncementStats,
            fs.collection('announcements').count().get()),
        maybe(_role.canVerifyUsers,
            fs.collection('users').where('status', isEqualTo: 'pending')
                .orderBy('createdAt', descending: true).limit(6).get()),
        maybe(_role.canSeeNetworkPulse,
            fs.collection('events').orderBy('createdAt', descending: true).limit(5).get()),
        maybe(_role.canSeeNetworkPulse,
            fs.collection('announcements').orderBy('publishedAt', descending: true).limit(5).get()),
        maybe(_role.canSeeRecentActivity,
            fs.collection('users').orderBy('lastLogin', descending: true).limit(10).get()),
        maybe(_role.canSeePendingPosts,
            fs.collection('alumni_posts').where('status', isEqualTo: 'pending').count().get()),
        maybe(_role.canSeePendingPosts,
            fs.collection('achievement_posts').where('status', isEqualTo: 'pending').count().get()),
      ]);

      // Pending users
      final pendingSnap = r[6] as QuerySnapshot?;
      final pending = pendingSnap?.docs.map((doc) {
        final d = doc.data() as Map<String, dynamic>;
        return {
          'id'     : doc.id,
          'name'   : d['name']?.toString() ?? d['fullName']?.toString() ?? 'Unknown',
          'email'  : d['email']?.toString()     ?? '—',
          'role'   : d['role']?.toString()      ?? 'alumni',
          'batch'  : d['batchYear']?.toString() ?? d['batch']?.toString()   ?? '—',
          'course' : d['course']?.toString()    ?? d['program']?.toString() ?? '—',
          'submitted'          : _fmt(d['createdAt'] as Timestamp?),
          'photoUrl'           : d['profilePictureUrl']?.toString(),
          'verificationStatus' : d['verificationStatus']?.toString() ?? 'pending',
        };
      }).toList() ?? [];

      // Network pulse
      final eventsSnap        = r[7] as QuerySnapshot?;
      final announcementsSnap = r[8] as QuerySnapshot?;
      final pulse = <Map<String, dynamic>>[];
      for (final doc in eventsSnap?.docs ?? []) {
        final d = doc.data() as Map<String, dynamic>;
        pulse.add({
          'type'    : 'EVENT',
          'title'   : d['title']?.toString()      ?? 'New Event',
          'desc'    : d['description']?.toString() ?? 'No description',
          'time'    : _fmt(d['createdAt'] as Timestamp?),
          'ts'      : (d['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0,
          'isUrgent': d['isImportant'] as bool? ?? false,
        });
      }
      for (final doc in announcementsSnap?.docs ?? []) {
        final d = doc.data() as Map<String, dynamic>;
        pulse.add({
          'type'    : 'ANNOUNCEMENT',
          'title'   : d['title']?.toString()  ?? 'Announcement',
          'desc'    : d['content']?.toString() ?? 'No content',
          'time'    : _fmt(d['publishedAt'] as Timestamp?),
          'ts'      : (d['publishedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0,
          'isUrgent': d['important'] as bool? ?? false,
        });
      }
      pulse.sort((a, b) => (b['ts'] as int).compareTo(a['ts'] as int));

      // Recent activity
      final activitySnap = r[9] as QuerySnapshot?;
      final activity = activitySnap?.docs.map((doc) {
        final d         = doc.data() as Map<String, dynamic>;
        final name      = d['name']?.toString() ?? d['fullName']?.toString() ?? 'Unknown';
        final lastLogin = d['lastLogin'] as Timestamp?;
        final updatedAt = d['updatedAt'] as Timestamp?;
        final latest    = lastLogin?.toDate().isAfter(
                updatedAt?.toDate() ?? DateTime(2000)) == true ? lastLogin : updatedAt;
        return {
          'name'    : name,
          'action'  : lastLogin == latest ? 'Logged in' : 'Profile updated',
          'time'    : _fmt(latest),
          'role'    : d['role']?.toString()             ?? 'alumni',
          'photoUrl': d['profilePictureUrl']?.toString(),
        };
      }).toList() ?? [];

      if (!mounted) return;
      setState(() {
        _totalAlumni          = (r[0]  as AggregateQuerySnapshot?)?.count ?? 0;
        _pendingVerifications = (r[1]  as AggregateQuerySnapshot?)?.count ?? 0;
        _activeChapters       = (r[2]  as AggregateQuerySnapshot?)?.count ?? 0;
        _totalEvents          = (r[3]  as AggregateQuerySnapshot?)?.count ?? 0;
        _totalJobs            = (r[4]  as AggregateQuerySnapshot?)?.count ?? 0;
        _totalAnnouncements   = (r[5]  as AggregateQuerySnapshot?)?.count ?? 0;
        _pendingPosts         = ((r[10] as AggregateQuerySnapshot?)?.count ?? 0) +
                                ((r[11] as AggregateQuerySnapshot?)?.count ?? 0);
        _pendingUsers         = pending;
        _networkPulse         = pulse.take(8).toList();
        _recentActivity       = activity;
        _isLoading            = false;
      });
    } catch (e) {
      debugPrint('Dashboard error: $e');
      if (mounted) setState(() { _error = 'Failed to load: $e'; _isLoading = false; });
    }
  }

  String _fmt(Timestamp? ts) {
    if (ts == null) return '—';
    final date = ts.toDate();
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24) return '${diff.inHours}h ago';
    if (diff.inDays    < 7)  return '${diff.inDays}d ago';
    return DateFormat('MMM d, yyyy').format(date);
  }

  void _snack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: GoogleFonts.inter()),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ));
  }

  // ── Verify / Deny ─────────────────────────────────────

  Future<void> _verifyUser(String uid, String name) async {
    if (!_role.canVerifyUsers) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Verify User', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text('Verify $name and grant alumni access?', style: GoogleFonts.inter()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.mutedText))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: Text('Verify', style: GoogleFonts.inter(
                  color: Colors.green, fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'status': 'active', 'verificationStatus': 'verified',
        'verifiedAt': FieldValue.serverTimestamp(),
        'verifiedBy': FirebaseAuth.instance.currentUser?.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _snack('$name verified', isError: false);
      _load();
    } catch (e) { _snack('Error: $e', isError: true); }
  }

  Future<void> _denyUser(String uid, String name) async {
    if (!_role.canVerifyUsers) return;
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Deny Verification', style: GoogleFonts.inter(
            fontWeight: FontWeight.w700, color: AppColors.brandRed)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Deny verification for $name?', style: GoogleFonts.inter()),
          const SizedBox(height: 16),
          TextFormField(
            controller: ctrl, maxLines: 3,
            style: GoogleFonts.inter(fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Reason (optional)',
              labelStyle: GoogleFonts.inter(color: AppColors.brandRed, fontWeight: FontWeight.w500),
              hintText: 'e.g. Incomplete documents',
              hintStyle: GoogleFonts.inter(color: AppColors.mutedText, fontSize: 13),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.brandRed, width: 1.5)),
              filled: true, fillColor: AppColors.softWhite,
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.mutedText))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: Text('Deny', style: GoogleFonts.inter(
                  color: AppColors.brandRed, fontWeight: FontWeight.w600))),
        ],
      ),
    );
    final reason = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true) return;
    try {
      final update = <String, dynamic>{
        'status': 'denied', 'verificationStatus': 'rejected',
        'deniedAt': FieldValue.serverTimestamp(),
        'deniedBy': FirebaseAuth.instance.currentUser?.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (reason.isNotEmpty) update['rejectionReason'] = reason;
      await FirebaseFirestore.instance.collection('users').doc(uid).update(update);
      _snack('Denied for $name', isError: false);
      _load();
    } catch (e) { _snack('Error: $e', isError: true); }
  }

  // ══════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
          backgroundColor: AppColors.softWhite,
          body: Center(child: CircularProgressIndicator(color: AppColors.brandRed)));
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.softWhite,
        body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(_error!, style: GoogleFonts.inter(color: Colors.red, fontSize: 14),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton.icon(onPressed: _load,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text('Retry', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
        ])),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.softWhite,
      body: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _buildSidebar(),
        Expanded(child: _buildMainContent()),
      ]),
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

        // Logo
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ALUMNI', style: GoogleFonts.cormorantGaramond(
                fontSize: 22, letterSpacing: 6,
                color: AppColors.brandRed, fontWeight: FontWeight.w300)),
            const SizedBox(height: 4),
            Text('ARCHIVE PORTAL', style: GoogleFonts.inter(
                fontSize: 9, letterSpacing: 2,
                color: AppColors.mutedText, fontWeight: FontWeight.bold)),
          ]),
        ),

        // Role badge
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 14, 28, 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: _role.roleColor.withOpacity(0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _role.roleColor.withOpacity(0.25)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 6, height: 6,
                  decoration: BoxDecoration(color: _role.roleColor, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_role.displayName, style: GoogleFonts.inter(
                    fontSize: 10, fontWeight: FontWeight.w800,
                    color: _role.roleColor, letterSpacing: 1)),
                Text(_role.roleDescription, style: GoogleFonts.inter(
                    fontSize: 9, color: _role.roleColor.withOpacity(0.65))),
              ]),
            ]),
          ),
        ),

        const Divider(color: AppColors.borderSubtle, height: 1),
        const SizedBox(height: 18),

        // Nav items
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              _sidebarSection('NETWORK', [
                _navItem('Overview', isActive: true),
              ]),

              if (_role.canSeeCareerMilestones) ...[
                const SizedBox(height: 26),
                _sidebarSection('ENGAGEMENT', [
                  _navItem('Career Milestones', route: '/career_milestones'),
                ]),
              ],

              const SizedBox(height: 26),
              _sidebarSection('FEATURES', [
                if (_role.canVerifyUsers)
                  _navItem('User Verification & Moderation',
                      route: '/user_verification_moderation'),
                if (_role.canManageEvents)
                  _navItem('Event Planning', route: '/event_planning'),
                if (_role.canManageJobs)
                  _navItem('Job Board Management', route: '/job_board_management'),
                if (_role.canSeeGrowthMetrics)
                  _navItem('Growth Metrics', route: '/growth_metrics'),
                if (_role.canManageAnnouncements)
                  _navItem('Announcement Management', route: '/announcement_management'),
                if (_role.canApprovePost)
                  _navItemBadge('Post Approval', '/post_approval',
                      const CombinedPendingBadge()),
              ]),

              const SizedBox(height: 20),
              _roleAccessCard(),
              const SizedBox(height: 20),
            ]),
          ),
        ),

        // Footer
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
              border: Border(top: BorderSide(
                  color: AppColors.borderSubtle.withOpacity(0.4)))),
          child: Column(children: [
            Row(children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                    color: _role.roleColor.withOpacity(0.1),
                    shape: BoxShape.circle),
                child: Center(child: Text(_adminName[0].toUpperCase(),
                    style: GoogleFonts.cormorantGaramond(
                        color: _role.roleColor, fontSize: 15,
                        fontWeight: FontWeight.w600))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_adminName, style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.bold),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(_role.displayName, style: GoogleFonts.inter(
                    fontSize: 9, color: _role.roleColor,
                    fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              ])),
            ]),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (mounted) Navigator.pushNamedAndRemoveUntil(
                      context, '/login', (r) => false);
                },
                icon: const Icon(Icons.logout, size: 13, color: AppColors.mutedText),
                label: Text('DISCONNECT', style: GoogleFonts.inter(
                    fontSize: 10, letterSpacing: 2,
                    color: AppColors.mutedText, fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _roleAccessCard() {
    final perms = [
      _PermItem('Verify Alumni',        _role.canVerifyUsers),
      _PermItem('Approve Posts',        _role.canApprovePost),
      _PermItem('Manage Events',        _role.canManageEvents),
      _PermItem('Manage Announcements', _role.canManageAnnouncements),
      _PermItem('Job Board',            _role.canManageJobs),
      _PermItem('Growth Metrics',       _role.canSeeGrowthMetrics),
      _PermItem('Send Newsletter',      _role.canSendNewsletter),
      _PermItem('Donation Reports',     _role.canSeeDonationReports),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.softWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.shield_outlined, size: 12, color: _role.roleColor),
          const SizedBox(width: 6),
          Text('ACCESS SUMMARY', style: GoogleFonts.inter(
              fontSize: 9, fontWeight: FontWeight.w800,
              color: AppColors.mutedText, letterSpacing: 1)),
        ]),
        const SizedBox(height: 10),
        ...perms.map((p) => Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(children: [
            Container(
              width: 14, height: 14,
              decoration: BoxDecoration(
                color: p.allowed
                    ? Colors.green.withOpacity(0.12)
                    : Colors.red.withOpacity(0.07),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Icon(p.allowed ? Icons.check : Icons.close,
                  size: 9,
                  color: p.allowed ? Colors.green : Colors.red.withOpacity(0.45)),
            ),
            const SizedBox(width: 8),
            Text(p.label, style: GoogleFonts.inter(
                fontSize: 11,
                color: p.allowed ? AppColors.darkText : AppColors.mutedText,
                fontWeight: p.allowed ? FontWeight.w500 : FontWeight.w400)),
          ]),
        )),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════
  //  MAIN CONTENT
  // ══════════════════════════════════════════════════════

  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildHeader(),
        const SizedBox(height: 28),
        _buildStatsGrid(),

        if (_role.canSeeVerifQueue || _role.canSeeNetworkPulse) ...[
          const SizedBox(height: 32),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (_role.canSeeVerifQueue)
              Expanded(
                flex: _role.canSeeNetworkPulse ? 3 : 5,
                child: _buildVerifQueue(),
              ),
            if (_role.canSeeVerifQueue && _role.canSeeNetworkPulse)
              const SizedBox(width: 24),
            if (_role.canSeeNetworkPulse)
              Expanded(
                flex: _role.canSeeVerifQueue ? 2 : 5,
                child: _buildNetworkPulse(),
              ),
          ]),
        ],

        if (_role.canSeeRecentActivity) ...[
          const SizedBox(height: 32),
          _buildRecentActivity(),
        ],

        if (_role.canSeePostApproval) ...[
          const SizedBox(height: 32),
          _buildPostApprovalSection(),
        ],

        if (!_role.canSeeVerifQueue && !_role.canSeeNetworkPulse &&
            !_role.canSeeRecentActivity && !_role.canSeePostApproval) ...[
          const SizedBox(height: 32),
          _buildAccessNotice(),
        ],

        const SizedBox(height: 40),
      ]),
    );
  }

  // ── Header ───────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            _role == StaffRole.admin ? 'Alumni Intelligence Dashboard'
                : _role == StaffRole.registrar ? 'Registrar Dashboard'
                : 'Moderator Dashboard',
            style: GoogleFonts.cormorantGaramond(
                fontSize: 34, fontWeight: FontWeight.w400, color: AppColors.darkText),
          ),
          Text(
            _role == StaffRole.admin ? 'LIVE INSTITUTIONAL OVERVIEW'
                : _role == StaffRole.registrar ? 'VERIFICATION & METRICS'
                : 'CONTENT MODERATION',
            style: GoogleFonts.inter(fontSize: 10, letterSpacing: 2, color: AppColors.mutedText),
          ),
        ]),
        Row(children: [
          if (_role.canSeeDonationReports) ...[
            OutlinedButton.icon(
              onPressed: () => _snack('Donation reports coming soon', isError: false),
              icon: const Icon(Icons.bar_chart_outlined, size: 16),
              label: Text('Donation Reports', style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.darkText,
                side: const BorderSide(color: AppColors.borderSubtle),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 12),
          ],
          if (_role.canSendNewsletter) ...[
            ElevatedButton.icon(
              onPressed: _showNewsletterDialog,
              icon: const Icon(Icons.send, size: 16),
              label: Text('Send Newsletter', style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandRed, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 12),
          ],
          IconButton(onPressed: _load,
              icon: const Icon(Icons.refresh, color: AppColors.mutedText),
              tooltip: 'Refresh'),
        ]),
      ],
    );
  }

  // ── Stats grid ───────────────────────────────────────

  Widget _buildStatsGrid() {
    final cards = <Widget>[];
    if (_role.canSeeAlumniCount)
      cards.add(_statCard(Icons.people_outline, 'Verified Alumni',
          _totalAlumni.toString(), 'Total active accounts', Colors.blue));
    if (_role.canSeePendingVerif)
      cards.add(_statCard(Icons.hourglass_empty_outlined, 'Pending Verifications',
          _pendingVerifications.toString(), 'Awaiting review',
          _pendingVerifications > 0 ? AppColors.brandRed : Colors.green));
    if (_role.canSeeChapters)
      cards.add(_statCard(Icons.apartment_outlined, 'Active Chapters',
          _activeChapters.toString(), 'Regional & batch groups', Colors.purple));
    if (_role.canSeeEventStats)
      cards.add(_statCard(Icons.event_outlined, 'Total Events',
          _totalEvents.toString(), 'All time', Colors.orange));
    if (_role.canSeeJobStats)
      cards.add(_statCard(Icons.work_outline, 'Job Postings',
          _totalJobs.toString(), 'Active opportunities', Colors.teal));
    if (_role.canSeeAnnouncementStats)
      cards.add(_statCard(Icons.campaign_outlined, 'Announcements',
          _totalAnnouncements.toString(), 'Published to alumni', Colors.indigo));
    if (_role.canSeePendingPosts)
      cards.add(_pendingPostsCard());
    if (cards.isEmpty) return const SizedBox.shrink();
    final cols = cards.length >= 4 ? 4 : cards.length;
    return GridView.count(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: cols, crossAxisSpacing: 16, mainAxisSpacing: 16,
      childAspectRatio: 1.6, children: cards,
    );
  }

  Widget _pendingPostsCard() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(12),
      border: Border.all(
          color: _pendingPosts > 0
              ? const Color(0xFFF59E0B).withOpacity(0.5) : AppColors.borderSubtle,
          width: _pendingPosts > 0 ? 1.5 : 1),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 32, height: 32,
            decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.pending_actions_outlined,
                color: Color(0xFFF59E0B), size: 16)),
        const SizedBox(width: 8),
        Expanded(child: Text('PENDING POSTS', style: GoogleFonts.inter(
            fontSize: 9, letterSpacing: 1,
            color: AppColors.mutedText, fontWeight: FontWeight.w700), maxLines: 2)),
        if (_pendingPosts > 0)
          Container(width: 8, height: 8,
              decoration: const BoxDecoration(
                  color: Color(0xFFF59E0B), shape: BoxShape.circle)),
      ]),
      const Spacer(),
      Text('$_pendingPosts', style: GoogleFonts.cormorantGaramond(
          fontSize: 36, fontWeight: FontWeight.w600, color: const Color(0xFFF59E0B))),
      Text('Awaiting approval', style: GoogleFonts.inter(
          fontSize: 10, color: AppColors.mutedText)),
    ]),
  );

  // ── Post Approval ─────────────────────────────────────

  Widget _buildPostApprovalSection() => Container(
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.borderSubtle),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Row(children: [
          Container(width: 32, height: 32,
              decoration: BoxDecoration(
                  color: AppColors.brandRed.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.rate_review_outlined,
                  color: AppColors.brandRed, size: 16)),
          const SizedBox(width: 12),
          Text('Post Approval', style: GoogleFonts.cormorantGaramond(
              fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.darkText)),
          const SizedBox(width: 10),
          const CombinedPendingBadge(),
        ]),
      ),
      const SizedBox(height: 6),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text('Review and moderate all alumni posts before they go live',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedText)),
      ),
      const SizedBox(height: 16),
      const Divider(height: 1, color: AppColors.borderSubtle),
      Container(
        color: AppColors.softWhite,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(children: [
          _queueTabBtn(0, Icons.feed_outlined, 'Feed Posts', 'General alumni posts'),
          const SizedBox(width: 10),
          _queueTabBtn(1, Icons.emoji_events_outlined,
              'Gallery Achievements', 'Photo submissions'),
        ]),
      ),
      const Divider(height: 1, color: AppColors.borderSubtle),
      Padding(
        padding: const EdgeInsets.all(20),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _postQueueTab == 0
              ? PostApprovalPanel(key: const ValueKey('feed'), onRefreshStats: _load)
              : _buildAchievementsTab(),
        ),
      ),
    ]),
  );

  Widget _queueTabBtn(int idx, IconData icon, String label, String sub) {
    final active = _postQueueTab == idx;
    return GestureDetector(
      onTap: () => setState(() => _postQueueTab = idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.brandRed : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? AppColors.brandRed : AppColors.borderSubtle),
          boxShadow: active
              ? [BoxShadow(color: AppColors.brandRed.withOpacity(0.2),
                  blurRadius: 8, offset: const Offset(0, 2))]
              : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: active ? Colors.white : AppColors.mutedText),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700,
                color: active ? Colors.white : AppColors.darkText)),
            Text(sub, style: GoogleFonts.inter(fontSize: 10,
                color: active ? Colors.white.withOpacity(0.7) : AppColors.mutedText)),
          ]),
        ]),
      ),
    );
  }

  Widget _buildAchievementsTab() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Text('Achievement Queue', style: GoogleFonts.cormorantGaramond(
            fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.darkText)),
        const SizedBox(width: 10),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('achievement_posts')
              .where('status', isEqualTo: 'pending').snapshots(),
          builder: (_, snap) {
            final n = snap.data?.docs.length ?? 0;
            if (n == 0) return const SizedBox.shrink();
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(20)),
              child: Text('$n pending', style: GoogleFonts.inter(
                  fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
            );
          },
        ),
      ]),
      Text('Review gallery achievement submissions',
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedText)),
      const SizedBox(height: 12),
      const Divider(color: AppColors.borderSubtle),
      const SizedBox(height: 8),
      const AdminAchievementQueue(),
    ],
  );

  // ── Verification queue ────────────────────────────────

  Widget _buildVerifQueue() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Verification Queue', style: GoogleFonts.cormorantGaramond(
              fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.darkText)),
          Text('$_pendingVerifications pending review', style: GoogleFonts.inter(
              fontSize: 12,
              color: _pendingVerifications > 0 ? AppColors.brandRed : Colors.green,
              fontWeight: FontWeight.w600)),
        ]),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/user_verification_moderation'),
          child: Text('VIEW ALL →', style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: AppColors.brandRed, letterSpacing: 1)),
        ),
      ]),
      const SizedBox(height: 16),
      const Divider(color: AppColors.borderSubtle),
      if (_pendingUsers.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Center(child: Column(children: [
            const Icon(Icons.check_circle_outline, size: 40, color: Colors.green),
            const SizedBox(height: 8),
            Text('All caught up!', style: GoogleFonts.inter(
                color: Colors.green, fontWeight: FontWeight.w600)),
            Text('No pending verifications', style: GoogleFonts.inter(
                fontSize: 12, color: AppColors.mutedText)),
          ])),
        )
      else
        ...(_pendingUsers.map(_verifRow)),
    ]),
  );

  Widget _verifRow(Map<String, dynamic> u) {
    final name = u['name'].toString(), email = u['email'].toString();
    final batch = u['batch'].toString(), course = u['course'].toString();
    final submitted = u['submitted'].toString(), uid = u['id'].toString();
    final photoUrl = u['photoUrl']?.toString();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.borderSubtle))),
      child: Row(children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.brandRed.withOpacity(0.1),
          backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
          child: photoUrl == null
              ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: GoogleFonts.inter(color: AppColors.brandRed,
                      fontWeight: FontWeight.w700, fontSize: 13))
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600,
              color: AppColors.darkText)),
          Text(email, style: GoogleFonts.inter(fontSize: 11, color: AppColors.mutedText)),
          Row(children: [
            if (batch != '—') _chip('Batch $batch', Colors.purple),
            if (batch != '—') const SizedBox(width: 4),
            if (course != '—') _chip(course, Colors.teal),
          ]),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(submitted, style: GoogleFonts.inter(fontSize: 10, color: AppColors.mutedText)),
          const SizedBox(height: 6),
          Row(children: [
            _actionBtn('Verify', Colors.green, () => _verifyUser(uid, name)),
            const SizedBox(width: 6),
            _actionBtn('Deny', AppColors.brandRed, () => _denyUser(uid, name)),
          ]),
        ]),
      ]),
    );
  }

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
        color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(4)),
    child: Text(label, style: GoogleFonts.inter(
        fontSize: 9, color: color, fontWeight: FontWeight.w600)),
  );

  Widget _actionBtn(String label, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6)),
          child: Text(label, style: GoogleFonts.inter(
              fontSize: 11, color: color, fontWeight: FontWeight.w700)),
        ),
      );

  // ── Network Pulse ─────────────────────────────────────

  Widget _buildNetworkPulse() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Network Pulse', style: GoogleFonts.cormorantGaramond(
          fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.darkText)),
      Text('Recent events & announcements', style: GoogleFonts.inter(
          fontSize: 12, color: AppColors.mutedText)),
      const SizedBox(height: 12),
      const Divider(color: AppColors.borderSubtle),
      if (_networkPulse.isEmpty)
        Padding(padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('No recent activity',
                style: GoogleFonts.inter(color: AppColors.mutedText))))
      else
        ...(_networkPulse.map(_pulseItem)),
    ]),
  );

  Widget _pulseItem(Map<String, dynamic> item) {
    final type = item['type'].toString();
    final isUrgent = item['isUrgent'] as bool? ?? false;
    final isEvent  = type == 'EVENT';
    final color    = isUrgent ? AppColors.brandRed : isEvent ? Colors.blue : Colors.orange;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 3, height: 48,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 12),
        Container(width: 28, height: 28,
            decoration: BoxDecoration(
                color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
            child: Icon(isEvent ? Icons.event_outlined : Icons.campaign_outlined,
                size: 14, color: color)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(3)),
              child: Text(type, style: GoogleFonts.inter(
                  fontSize: 8, color: color, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            ),
            if (isUrgent) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                    color: AppColors.brandRed, borderRadius: BorderRadius.circular(3)),
                child: Text('IMPORTANT', style: GoogleFonts.inter(
                    fontSize: 8, color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ],
          ]),
          const SizedBox(height: 2),
          Text(item['title'].toString(), style: GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.darkText),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(item['desc'].toString(), style: GoogleFonts.inter(
              fontSize: 11, color: AppColors.mutedText, height: 1.3),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          Text(item['time'].toString(), style: GoogleFonts.inter(
              fontSize: 10, color: AppColors.mutedText)),
        ])),
      ]),
    );
  }

  // ── Recent Activity ───────────────────────────────────

  Widget _buildRecentActivity() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Recent User Activity', style: GoogleFonts.cormorantGaramond(
              fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.darkText)),
          Text('Latest logins and profile updates', style: GoogleFonts.inter(
              fontSize: 12, color: AppColors.mutedText)),
        ]),
        if (_role.canVerifyUsers)
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/user_verification_moderation'),
            child: Text('VIEW ALL →', style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: AppColors.brandRed, letterSpacing: 1)),
          ),
      ]),
      const SizedBox(height: 12),
      const Divider(color: AppColors.borderSubtle),
      if (_recentActivity.isEmpty)
        Padding(padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('No recent activity',
                style: GoogleFonts.inter(color: AppColors.mutedText))))
      else
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, childAspectRatio: 5,
              crossAxisSpacing: 12, mainAxisSpacing: 4),
          itemCount: _recentActivity.length,
          itemBuilder: (_, i) {
            final log     = _recentActivity[i];
            final name    = log['name'].toString();
            final action  = log['action'].toString();
            final time    = log['time'].toString();
            final role    = log['role'].toString();
            final photo   = log['photoUrl']?.toString();
            final isLogin = action == 'Logged in';
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: AppColors.softWhite,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borderSubtle)),
              child: Row(children: [
                CircleAvatar(
                  radius: 16, backgroundColor: AppColors.brandRed.withOpacity(0.1),
                  backgroundImage: photo != null ? NetworkImage(photo) : null,
                  child: photo == null ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: GoogleFonts.inter(color: AppColors.brandRed,
                          fontWeight: FontWeight.w700, fontSize: 10)) : null,
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(name, style: GoogleFonts.inter(fontSize: 12,
                        fontWeight: FontWeight.w600, color: AppColors.darkText),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    Row(children: [
                      Icon(isLogin ? Icons.login_outlined : Icons.edit_outlined,
                          size: 10, color: isLogin ? Colors.green : Colors.blue),
                      const SizedBox(width: 3),
                      Text(action, style: GoogleFonts.inter(fontSize: 10,
                          color: isLogin ? Colors.green : Colors.blue)),
                    ]),
                  ],
                )),
                Column(crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(time, style: GoogleFonts.inter(
                      fontSize: 10, color: AppColors.mutedText)),
                  Text(role.toUpperCase(), style: GoogleFonts.inter(
                      fontSize: 8, color: AppColors.mutedText, letterSpacing: 0.5)),
                ]),
              ]),
            );
          },
        ),
    ]),
  );

  // ── Access notice ─────────────────────────────────────

  Widget _buildAccessNotice() => Container(
    padding: const EdgeInsets.all(48),
    decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle)),
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 60, height: 60,
          decoration: BoxDecoration(
              color: AppColors.mutedText.withOpacity(0.07), shape: BoxShape.circle),
          child: const Icon(Icons.lock_outline, size: 28, color: AppColors.mutedText)),
      const SizedBox(height: 16),
      Text('Limited Access', style: GoogleFonts.cormorantGaramond(
          fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.darkText)),
      const SizedBox(height: 8),
      Text(
        'Your role (${_role.displayName}) has restricted dashboard access.\nContact an administrator to update your permissions.',
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(fontSize: 13, color: AppColors.mutedText, height: 1.6),
      ),
    ])),
  );

  // ── Newsletter ────────────────────────────────────────

  void _showNewsletterDialog() {
    if (!_role.canSendNewsletter) return;
    final subCtrl = TextEditingController();
    final bodCtrl = TextEditingController();
    bool sending  = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => DraggableScrollableSheet(
          initialChildSize: 0.75, maxChildSize: 0.95, minChildSize: 0.4,
          builder: (_, ctrl) => Container(
            decoration: const BoxDecoration(color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            child: Column(children: [
              Container(margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: AppColors.borderSubtle,
                      borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(children: [
                  Text('Send Newsletter', style: GoogleFonts.cormorantGaramond(
                      fontSize: 22, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  TextButton(
                    onPressed: sending ? null : () async {
                      final s = subCtrl.text.trim(), b = bodCtrl.text.trim();
                      if (s.isEmpty) { _snack('Subject required', isError: true); return; }
                      if (b.isEmpty) { _snack('Body required', isError: true); return; }
                      ss(() => sending = true);
                      try {
                        await FirebaseFirestore.instance.collection('newsletters').add({
                          'subject': s, 'body': b,
                          'sentBy': FirebaseAuth.instance.currentUser?.uid,
                          'sentByName': _adminName,
                          'sentAt': FieldValue.serverTimestamp(),
                          'recipientCount': _totalAlumni,
                          'status': 'queued',
                        });
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          _snack('Queued for $_totalAlumni alumni', isError: false);
                        }
                      } catch (e) {
                        ss(() => sending = false);
                        _snack('Error: $e', isError: true);
                      }
                    },
                    child: Text(sending ? 'Queuing…' : 'Send',
                        style: GoogleFonts.inter(color: AppColors.brandRed,
                            fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ]),
              ),
              const Divider(height: 1),
              Expanded(child: ListView(controller: ctrl, padding: const EdgeInsets.all(20),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blue.withOpacity(0.2))),
                      child: Row(children: [
                        const Icon(Icons.info_outline, color: Colors.blue, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                            'Will be queued for $_totalAlumni verified alumni.',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: Colors.blue.shade700))),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    _field(subCtrl, 'Subject', 'e.g. Alumni Homecoming 2026'),
                    const SizedBox(height: 16),
                    _field(bodCtrl, 'Message', 'Write your newsletter…', lines: 10),
                    const SizedBox(height: 32),
                  ])),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Shared helpers ────────────────────────────────────

  Widget _field(TextEditingController c, String label, String hint, {int lines = 1}) =>
      TextFormField(
        controller: c, maxLines: lines, style: GoogleFonts.inter(fontSize: 14),
        decoration: InputDecoration(
          labelText: label, hintText: hint,
          labelStyle: GoogleFonts.inter(color: AppColors.brandRed, fontWeight: FontWeight.w500),
          hintStyle: GoogleFonts.inter(color: AppColors.mutedText, fontSize: 13),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.borderSubtle)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.borderSubtle)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.brandRed, width: 1.5)),
          filled: true, fillColor: AppColors.softWhite,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      );

  Widget _statCard(IconData icon, String label,
      String value, String sub, Color color) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 32, height: 32,
            decoration: BoxDecoration(
                color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 16)),
        const SizedBox(width: 8),
        Expanded(child: Text(label.toUpperCase(), style: GoogleFonts.inter(
            fontSize: 9, letterSpacing: 1, color: AppColors.mutedText,
            fontWeight: FontWeight.w700), maxLines: 2)),
      ]),
      const Spacer(),
      Text(value, style: GoogleFonts.cormorantGaramond(
          fontSize: 36, fontWeight: FontWeight.w600, color: color)),
      Text(sub, style: GoogleFonts.inter(fontSize: 10, color: AppColors.mutedText)),
    ]),
  );

  Widget _sidebarSection(String title, List<Widget> items) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.inter(fontSize: 10, letterSpacing: 2,
            fontWeight: FontWeight.bold,
            color: AppColors.mutedText.withOpacity(0.7))),
        const SizedBox(height: 14),
        ...items,
      ]);

  Widget _navItem(String label, {String? route, bool isActive = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: GestureDetector(
      onTap: route != null && !isActive ? () => Navigator.pushNamed(context, route) : null,
      child: MouseRegion(
        cursor: route != null && !isActive
            ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Text(label, style: GoogleFonts.inter(fontSize: 13.5,
            color: isActive ? AppColors.brandRed : AppColors.darkText,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400)),
      ),
    ),
  );

  Widget _navItemBadge(String label, String route, Widget badge) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Row(children: [
          Text(label, style: GoogleFonts.inter(fontSize: 13.5,
              color: AppColors.darkText, fontWeight: FontWeight.w400)),
          const SizedBox(width: 8),
          badge,
        ]),
      ),
    ),
  );
}