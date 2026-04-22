import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:alumni/core/constants/app_colors.dart';
import 'package:alumni/features/admin/presentation/screens/admin_post_approval.dart';
import 'package:alumni/features/gallery/presentation/screens/gallery_screen.dart'
    show AdminAchievementQueue;

class AdminDashboardWeb extends StatefulWidget {
  const AdminDashboardWeb({super.key});

  @override
  State<AdminDashboardWeb> createState() => _AdminDashboardWebState();
}

class _AdminDashboardWebState extends State<AdminDashboardWeb> {
  // ─── Stats ───
  int _totalAlumni          = 0;
  int _pendingVerifications = 0;
  int _totalEvents          = 0;
  int _totalJobs            = 0;
  int _totalAnnouncements   = 0;
  int _pendingPosts         = 0;

  // ─── Lists ───
  List<Map<String, dynamic>> _pendingUsers   = [];
  List<Map<String, dynamic>> _networkPulse   = [];
  List<Map<String, dynamic>> _recentActivity = [];

  // ─── Admin profile ───
  String _adminName = 'Admin';
  String _adminRole = 'ADMIN';

  // ─── Post queue sub-tab: 0 = Feed Posts, 1 = Gallery Achievements ───
  int _postQueueTab = 0;

  bool   _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ══════════════════════════════════════════════════════
  //  LOAD
  // ══════════════════════════════════════════════════════

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _error = null; });

    try {
      final fs  = FirebaseFirestore.instance;
      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid != null) {
        final adminDoc = await fs.collection('users').doc(uid).get();
        if (adminDoc.exists && mounted) {
          final d = adminDoc.data()!;
          _adminName = d['name']?.toString() ??
              d['fullName']?.toString() ??
              FirebaseAuth.instance.currentUser?.displayName ??
              'Admin';
          _adminRole = d['role']?.toString().toUpperCase() ?? 'ADMIN';
        }
      }

      final results = await Future.wait([
        fs.collection('users')
            .where('status', whereIn: ['verified', 'active']).count().get(),
        fs.collection('users')
            .where('status', isEqualTo: 'pending').count().get(),
        fs.collection('chapters')
            .where('status', isEqualTo: 'active').count().get(),
        fs.collection('events').count().get(),
        fs.collection('job_posting').count().get(),
        fs.collection('announcements').count().get(),
        fs.collection('users')
            .where('status', isEqualTo: 'pending')
            .orderBy('createdAt', descending: true).limit(6).get(),
        fs.collection('events')
            .orderBy('createdAt', descending: true).limit(5).get(),
        fs.collection('announcements')
            .orderBy('publishedAt', descending: true).limit(5).get(),
        fs.collection('users')
            .orderBy('lastLogin', descending: true).limit(10).get(),
        fs.collection('alumni_posts')
            .where('status', isEqualTo: 'pending').count().get(),
        fs.collection('achievement_posts')
            .where('status', isEqualTo: 'pending').count().get(),
      ]);

      final pendingSnap       = results[6]  as QuerySnapshot;
      final eventsSnap        = results[7]  as QuerySnapshot;
      final announcementsSnap = results[8]  as QuerySnapshot;
      final activitySnap      = results[9]  as QuerySnapshot;

      // ─── Build pending users ───
      final pending = pendingSnap.docs.map((doc) {
        final d = doc.data() as Map<String, dynamic>;
        return {
          'id'     : doc.id,
          'name'   : d['name']?.toString() ?? d['fullName']?.toString() ?? 'Unknown',
          'email'  : d['email']?.toString()     ?? '—',
          'role'   : d['role']?.toString()      ?? 'alumni',
          'batch'  : d['batchYear']?.toString() ?? d['batch']?.toString() ?? '—',
          'course' : d['course']?.toString()    ?? d['program']?.toString() ?? '—',
          'submitted'          : _fmt(d['createdAt'] as Timestamp?),
          'photoUrl'           : d['profilePictureUrl']?.toString(),
          'verificationStatus' : d['verificationStatus']?.toString() ?? 'pending',
        };
      }).toList();

      // ─── Build network pulse ───
      final pulse = <Map<String, dynamic>>[];
      for (final doc in eventsSnap.docs) {
        final d = doc.data() as Map<String, dynamic>;
        pulse.add({
          'type'    : 'EVENT',
          'title'   : d['title']?.toString()      ?? 'New Event',
          'desc'    : d['description']?.toString() ?? 'No description',
          'time'    : _fmt(d['createdAt'] as Timestamp?),
          'ts'      : (d['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0,
          'isUrgent': d['isImportant'] as bool? ?? false,
          'status'  : d['status']?.toString() ?? 'draft',
        });
      }
      for (final doc in announcementsSnap.docs) {
        final d = doc.data() as Map<String, dynamic>;
        pulse.add({
          'type'    : 'ANNOUNCEMENT',
          'title'   : d['title']?.toString()   ?? 'Announcement',
          'desc'    : d['content']?.toString()  ?? 'No content',
          'time'    : _fmt(d['publishedAt'] as Timestamp?),
          'ts'      : (d['publishedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0,
          'isUrgent': d['important'] as bool? ?? false,
          'status'  : 'published',
        });
      }
      pulse.sort((a, b) => (b['ts'] as int).compareTo(a['ts'] as int));

      // ─── Build recent activity ───
      final activity = activitySnap.docs.map((doc) {
        final d         = doc.data() as Map<String, dynamic>;
        final name      = d['name']?.toString() ?? d['fullName']?.toString() ?? 'Unknown';
        final lastLogin = d['lastLogin'] as Timestamp?;
        final updatedAt = d['updatedAt'] as Timestamp?;
        final latest    = lastLogin?.toDate().isAfter(
                updatedAt?.toDate() ?? DateTime(2000)) == true
            ? lastLogin
            : updatedAt;
        return {
          'name'    : name,
          'action'  : lastLogin == latest ? 'Logged in' : 'Profile updated',
          'time'    : _fmt(latest),
          'ts'      : latest?.millisecondsSinceEpoch ?? 0,
          'role'    : d['role']?.toString()             ?? 'alumni',
          'photoUrl': d['profilePictureUrl']?.toString(),
          'status'  : d['status']?.toString()           ?? '—',
        };
      }).toList();

      if (!mounted) return;
      setState(() {
        _totalAlumni          = (results[0]  as AggregateQuerySnapshot).count ?? 0;
        _pendingVerifications = (results[1]  as AggregateQuerySnapshot).count ?? 0;
        _totalEvents          = (results[3]  as AggregateQuerySnapshot).count ?? 0;
        _totalJobs            = (results[4]  as AggregateQuerySnapshot).count ?? 0;
        _totalAnnouncements   = (results[5]  as AggregateQuerySnapshot).count ?? 0;
        final feedPending     = (results[10] as AggregateQuerySnapshot).count ?? 0;
        final achPending      = (results[11] as AggregateQuerySnapshot).count ?? 0;
        _pendingPosts         = feedPending + achPending;
        _pendingUsers         = pending;
        _networkPulse         = pulse.take(8).toList();
        _recentActivity       = activity;
        _isLoading            = false;
      });
    } catch (e) {
      debugPrint('Dashboard error: $e');
      if (mounted) {
        setState(() { _error = 'Failed to load dashboard: $e'; _isLoading = false; });
      }
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

  void _showSnackBar(String msg, {required bool isError}) {
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

  // ══════════════════════════════════════════════════════
  //  VERIFY / DENY USER
  // ══════════════════════════════════════════════════════

  Future<void> _verifyUser(String uid, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Verify User',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text('Verify $name and grant them alumni access?',
            style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppColors.mutedText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Verify',
                style: GoogleFonts.inter(
                    color: Colors.green, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'status'             : 'active',
        'verificationStatus' : 'verified',
        'verifiedAt'         : FieldValue.serverTimestamp(),
        'verifiedBy'         : FirebaseAuth.instance.currentUser?.uid,
        'updatedAt'          : FieldValue.serverTimestamp(),
      });
      _showSnackBar('$name verified successfully', isError: false);
      _load();
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  Future<void> _denyUser(String uid, String name) async {
    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Deny Verification',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700, color: AppColors.brandRed)),
        content: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Deny verification for $name?', style: GoogleFonts.inter()),
            const SizedBox(height: 16),
            TextFormField(
              controller: reasonCtrl,
              maxLines: 3,
              style: GoogleFonts.inter(fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Reason (optional)',
                labelStyle: GoogleFonts.inter(
                    color: AppColors.brandRed, fontWeight: FontWeight.w500),
                hintText: 'e.g. Incomplete documents',
                hintStyle: GoogleFonts.inter(
                    color: AppColors.mutedText, fontSize: 13),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppColors.brandRed, width: 1.5)),
                filled: true,
                fillColor: AppColors.softWhite,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppColors.mutedText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Deny',
                style: GoogleFonts.inter(
                    color: AppColors.brandRed, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    final reason = reasonCtrl.text.trim();
    reasonCtrl.dispose();
    if (confirm != true) return;
    try {
      final update = <String, dynamic>{
        'status'             : 'denied',
        'verificationStatus' : 'rejected',
        'deniedAt'           : FieldValue.serverTimestamp(),
        'deniedBy'           : FirebaseAuth.instance.currentUser?.uid,
        'updatedAt'          : FieldValue.serverTimestamp(),
      };
      if (reason.isNotEmpty) update['rejectionReason'] = reason;
      await FirebaseFirestore.instance
          .collection('users').doc(uid).update(update);
      _showSnackBar('Verification denied for $name', isError: false);
      _load();
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  // ══════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.softWhite,
        body: Center(child: CircularProgressIndicator(color: AppColors.brandRed)),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.softWhite,
        body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(_error!,
              style: GoogleFonts.inter(color: Colors.red, fontSize: 14),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh, size: 16),
            label: Text('Retry',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ])),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.softWhite,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSidebar(),
          Expanded(child: _buildMainContent()),
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
                  _sidebarItem('Overview', isActive: true),
                ]),
                const SizedBox(height: 32),
                _sidebarSection('ENGAGEMENT', [
                  _sidebarItem('Career Milestones',
                      route: '/career_milestones'),
                ]),
                const SizedBox(height: 32),
                _sidebarSection('ADMIN FEATURES', [
                  _sidebarItem('User Verification & Moderation',
                      route: '/user_verification_moderation'),
                  _sidebarItem('Event Planning',
                      route: '/event_planning'),
                  _sidebarItem('Job Board Management',
                      route: '/job_board_management'),
                  _sidebarItem('Growth Metrics',
                      route: '/growth_metrics'),
                  _sidebarItem('Announcement Management',
                      route: '/announcement_management'),

                  // ── Post Approval with live combined badge ──────
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

        // ─── Footer ───
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
                child: Text(_adminName[0].toUpperCase(),
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
                icon: const Icon(Icons.logout,
                    size: 13, color: AppColors.mutedText),
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
  //  MAIN CONTENT
  // ══════════════════════════════════════════════════════

  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 28),
          _buildStatsGrid(),
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _buildVerificationQueue()),
              const SizedBox(width: 24),
              Expanded(flex: 2, child: _buildNetworkPulse()),
            ],
          ),
          const SizedBox(height: 32),
          _buildRecentActivity(),
          const SizedBox(height: 32),
          _buildPostApprovalSection(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── Header ───────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Alumni Intelligence Dashboard',
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 36, fontWeight: FontWeight.w400,
                  color: AppColors.darkText)),
          Text('LIVE INSTITUTIONAL OVERVIEW',
              style: GoogleFonts.inter(
                  fontSize: 10, letterSpacing: 2, color: AppColors.mutedText)),
        ]),
       
      ],
    );
  }

  // ── Stats grid ───────────────────────────────────────

  Widget _buildStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.6,
      children: [
        _statCard(Icons.people_outline, 'Verified Alumni',
            _totalAlumni.toString(), 'Total active accounts', Colors.blue),
        _statCard(Icons.hourglass_empty_outlined, 'Pending Verifications',
            _pendingVerifications.toString(), 'Awaiting review',
            _pendingVerifications > 0 ? AppColors.brandRed : Colors.green),
        _statCard(Icons.event_outlined, 'Total Events',
            _totalEvents.toString(), 'All time', Colors.orange),
        _statCard(Icons.work_outline, 'Job Postings',
            _totalJobs.toString(), 'Active opportunities', Colors.teal),
        _statCard(Icons.campaign_outlined, 'Announcements',
            _totalAnnouncements.toString(), 'Published to alumni',
            Colors.indigo),
        _pendingPostsCard(),
      ],
    );
  }

  Widget _pendingPostsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _pendingPosts > 0
              ? const Color(0xFFF59E0B).withOpacity(0.5)
              : AppColors.borderSubtle,
          width: _pendingPosts > 0 ? 1.5 : 1,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.pending_actions_outlined,
                color: Color(0xFFF59E0B), size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text('PENDING POSTS',
                style: GoogleFonts.inter(
                    fontSize: 9, letterSpacing: 1,
                    color: AppColors.mutedText, fontWeight: FontWeight.w700),
                maxLines: 2),
          ),
          if (_pendingPosts > 0)
            Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(
                  color: Color(0xFFF59E0B), shape: BoxShape.circle),
            ),
        ]),
        const Spacer(),
        Text('$_pendingPosts',
            style: GoogleFonts.cormorantGaramond(
                fontSize: 36, fontWeight: FontWeight.w600,
                color: const Color(0xFFF59E0B))),
        Text('Awaiting approval',
            style: GoogleFonts.inter(
                fontSize: 10, color: AppColors.mutedText)),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════
  //  POST APPROVAL SECTION
  // ══════════════════════════════════════════════════════

  Widget _buildPostApprovalSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Section header ───────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.brandRed.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.rate_review_outlined,
                          color: AppColors.brandRed, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Text('Post Approval',
                        style: GoogleFonts.cormorantGaramond(
                            fontSize: 24, fontWeight: FontWeight.w600,
                            color: AppColors.darkText)),
                    const SizedBox(width: 10),
                    // Live combined badge — no polling, pure streams
                    const CombinedPendingBadge(),
                  ]),
                  const SizedBox(height: 2),
                  Text('Review and moderate all alumni posts before they go live',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.mutedText)),
                ]),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.borderSubtle),

          // ─── Sub-tabs ─────────────────────────────────
          Container(
            color: AppColors.softWhite,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(children: [
              _queueTabBtn(0, Icons.feed_outlined, 'Feed Posts',
                  'General alumni posts'),
              const SizedBox(width: 10),
              _queueTabBtn(1, Icons.emoji_events_outlined, 'Gallery Achievements',
                  'Photo achievement submissions'),
            ]),
          ),

          const Divider(height: 1, color: AppColors.borderSubtle),

          // ─── Queue content ────────────────────────────
          Padding(
            padding: const EdgeInsets.all(20),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _postQueueTab == 0
                  ? PostApprovalPanel(
                      key: const ValueKey('feed'),
                      onRefreshStats: _load,
                    )
                  : _buildAchievementQueue(),
            ),
          ),
        ],
      ),
    );
  }

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
          border: Border.all(
            color: active ? AppColors.brandRed : AppColors.borderSubtle,
          ),
          boxShadow: active
              ? [BoxShadow(
                  color: AppColors.brandRed.withOpacity(0.2),
                  blurRadius: 8, offset: const Offset(0, 2))]
              : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15,
              color: active ? Colors.white : AppColors.mutedText),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: active ? Colors.white : AppColors.darkText)),
            Text(sub,
                style: GoogleFonts.inter(
                    fontSize: 10,
                    color: active
                        ? Colors.white.withOpacity(0.7)
                        : AppColors.mutedText)),
          ]),
        ]),
      ),
    );
  }

  Widget _buildAchievementQueue() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('Achievement Queue',
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 22, fontWeight: FontWeight.w600,
                  color: AppColors.darkText)),
          const SizedBox(width: 10),
          // Live badge — typed stream, no cast
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('achievement_posts')
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (_, snap) {
              final n = snap.data?.docs.length ?? 0;
              if (n == 0) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$n pending',
                    style: GoogleFonts.inter(
                        fontSize: 10, fontWeight: FontWeight.w800,
                        color: Colors.white)),
              );
            },
          ),
        ]),
        Text('Review gallery achievement submissions',
            style: GoogleFonts.inter(
                fontSize: 12, color: AppColors.mutedText)),
        const SizedBox(height: 12),
        const Divider(color: AppColors.borderSubtle),
        const SizedBox(height: 8),
        const AdminAchievementQueue(),
      ],
    );
  }

  // ══════════════════════════════════════════════════════
  //  VERIFICATION QUEUE
  // ══════════════════════════════════════════════════════

  Widget _buildVerificationQueue() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Verification Queue',
                  style: GoogleFonts.cormorantGaramond(
                      fontSize: 22, fontWeight: FontWeight.w600,
                      color: AppColors.darkText)),
              Text('$_pendingVerifications pending review',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: _pendingVerifications > 0
                          ? AppColors.brandRed : Colors.green,
                      fontWeight: FontWeight.w600)),
            ]),
            GestureDetector(
              onTap: () => Navigator.pushNamed(
                  context, '/user_verification_moderation'),
              child: Text('VIEW ALL →',
                  style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: AppColors.brandRed, letterSpacing: 1)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(color: AppColors.borderSubtle),
        if (_pendingUsers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(child: Column(children: [
              const Icon(Icons.check_circle_outline,
                  size: 40, color: Colors.green),
              const SizedBox(height: 8),
              Text('All caught up!',
                  style: GoogleFonts.inter(
                      color: Colors.green, fontWeight: FontWeight.w600)),
              Text('No pending verifications',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.mutedText)),
            ])),
          )
        else
          ...(_pendingUsers.map((u) => _verificationRow(u))),
      ]),
    );
  }

  Widget _verificationRow(Map<String, dynamic> user) {
    final name      = user['name'].toString();
    final email     = user['email'].toString();
    final batch     = user['batch'].toString();
    final course    = user['course'].toString();
    final submitted = user['submitted'].toString();
    final photoUrl  = user['photoUrl']?.toString();
    final uid       = user['id'].toString();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.brandRed.withOpacity(0.1),
          backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
          child: photoUrl == null
              ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: GoogleFonts.inter(
                      color: AppColors.brandRed,
                      fontWeight: FontWeight.w700, fontSize: 13))
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: AppColors.darkText)),
            Text(email,
                style: GoogleFonts.inter(
                    fontSize: 11, color: AppColors.mutedText)),
            Row(children: [
              if (batch != '—') _miniChip('Batch $batch', Colors.purple),
              if (batch != '—') const SizedBox(width: 4),
              if (course != '—') _miniChip(course, Colors.teal),
            ]),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(submitted,
              style: GoogleFonts.inter(
                  fontSize: 10, color: AppColors.mutedText)),
          const SizedBox(height: 6),
          Row(children: [
            GestureDetector(
              onTap: () => _verifyUser(uid, name),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Verify',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: Colors.green,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => _denyUser(uid, name),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.brandRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Deny',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: AppColors.brandRed,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ]),
      ]),
    );
  }

  Widget _miniChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 9, color: color, fontWeight: FontWeight.w600)),
    );
  }

  // ══════════════════════════════════════════════════════
  //  NETWORK PULSE
  // ══════════════════════════════════════════════════════

  Widget _buildNetworkPulse() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Network Pulse',
            style: GoogleFonts.cormorantGaramond(
                fontSize: 22, fontWeight: FontWeight.w600,
                color: AppColors.darkText)),
        Text('Recent events & announcements',
            style: GoogleFonts.inter(
                fontSize: 12, color: AppColors.mutedText)),
        const SizedBox(height: 12),
        const Divider(color: AppColors.borderSubtle),
        if (_networkPulse.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('No recent activity',
                style: GoogleFonts.inter(color: AppColors.mutedText))),
          )
        else
          ...(_networkPulse.map((item) => _pulseItem(item))),
      ]),
    );
  }

  Widget _pulseItem(Map<String, dynamic> item) {
    final type     = item['type'].toString();
    final isUrgent = item['isUrgent'] as bool? ?? false;
    final isEvent  = type == 'EVENT';
    final color    = isUrgent
        ? AppColors.brandRed
        : isEvent ? Colors.blue : Colors.orange;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 3, height: 48,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 12),
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            isEvent ? Icons.event_outlined : Icons.campaign_outlined,
            size: 14, color: color,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(type,
                    style: GoogleFonts.inter(
                        fontSize: 8, color: color,
                        fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              ),
              if (isUrgent) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.brandRed,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text('IMPORTANT',
                      style: GoogleFonts.inter(
                          fontSize: 8, color: Colors.white,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ]),
            const SizedBox(height: 2),
            Text(item['title'].toString(),
                style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: AppColors.darkText),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(item['desc'].toString(),
                style: GoogleFonts.inter(
                    fontSize: 11, color: AppColors.mutedText, height: 1.3),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            Text(item['time'].toString(),
                style: GoogleFonts.inter(
                    fontSize: 10, color: AppColors.mutedText)),
          ]),
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════
  //  RECENT ACTIVITY
  // ══════════════════════════════════════════════════════

  Widget _buildRecentActivity() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Recent User Activity',
                  style: GoogleFonts.cormorantGaramond(
                      fontSize: 22, fontWeight: FontWeight.w600,
                      color: AppColors.darkText)),
              Text('Latest logins and profile updates',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.mutedText)),
            ]),
            GestureDetector(
              onTap: () => Navigator.pushNamed(
                  context, '/user_verification_moderation'),
              child: Text('VIEW ALL →',
                  style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: AppColors.brandRed, letterSpacing: 1)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(color: AppColors.borderSubtle),
        if (_recentActivity.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('No recent activity',
                style: GoogleFonts.inter(color: AppColors.mutedText))),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 4,
            ),
            itemCount: _recentActivity.length,
            itemBuilder: (context, i) {
              final log      = _recentActivity[i];
              final name     = log['name'].toString();
              final action   = log['action'].toString();
              final time     = log['time'].toString();
              final role     = log['role'].toString();
              final photoUrl = log['photoUrl']?.toString();
              final isLogin  = action == 'Logged in';

              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.softWhite,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.brandRed.withOpacity(0.1),
                    backgroundImage: photoUrl != null
                        ? NetworkImage(photoUrl) : null,
                    child: photoUrl == null
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: GoogleFonts.inter(
                                color: AppColors.brandRed,
                                fontWeight: FontWeight.w700,
                                fontSize: 10))
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(name,
                            style: GoogleFonts.inter(
                                fontSize: 12, fontWeight: FontWeight.w600,
                                color: AppColors.darkText),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        Row(children: [
                          Icon(
                            isLogin
                                ? Icons.login_outlined
                                : Icons.edit_outlined,
                            size: 10,
                            color: isLogin ? Colors.green : Colors.blue,
                          ),
                          const SizedBox(width: 3),
                          Text(action,
                              style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: isLogin ? Colors.green : Colors.blue)),
                        ]),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(time,
                          style: GoogleFonts.inter(
                              fontSize: 10, color: AppColors.mutedText)),
                      Text(role.toUpperCase(),
                          style: GoogleFonts.inter(
                              fontSize: 8, color: AppColors.mutedText,
                              letterSpacing: 0.5)),
                    ],
                  ),
                ]),
              );
            },
          ),
      ]),
    );
  }



  Widget _statCard(IconData icon, String label,
      String value, String sub, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label.toUpperCase(),
                style: GoogleFonts.inter(
                    fontSize: 9, letterSpacing: 1,
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.w700),
                maxLines: 2),
          ),
        ]),
        const Spacer(),
        Text(value,
            style: GoogleFonts.cormorantGaramond(
                fontSize: 36, fontWeight: FontWeight.w600, color: color)),
        Text(sub,
            style: GoogleFonts.inter(
                fontSize: 10, color: AppColors.mutedText)),
      ]),
    );
  }

  Widget _sidebarSection(String title, List<Widget> items) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: GoogleFonts.inter(
              fontSize: 10, letterSpacing: 2,
              fontWeight: FontWeight.bold,
              color: AppColors.mutedText.withOpacity(0.7))),
      const SizedBox(height: 16),
      ...items,
    ]);
  }

  Widget _sidebarItem(String label,
      {String? route, bool isActive = false}) {
    return Padding(
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
  }

  /// Sidebar item with an inline live badge widget on the right
  Widget _sidebarItemWithBadge({
    required String label,
    required String route,
    required Widget badge,
  }) {
    return Padding(
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
  }
}