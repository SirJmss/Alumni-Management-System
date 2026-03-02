import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AdminDashboardWeb extends StatefulWidget {
  const AdminDashboardWeb({super.key});

  @override
  State<AdminDashboardWeb> createState() => _AdminDashboardWebState();
}

class _AdminDashboardWebState extends State<AdminDashboardWeb> {
  int totalAlumni = 0;
  int pendingVerifications = 0;
  int activeChapters = 0;

  List<Map<String, dynamic>> pendingUsers = [];
  List<Map<String, dynamic>> networkPulse = [];
  List<Map<String, dynamic>> recentUserActivity = [];

  bool isLoading = true;
  String? errorMessage;

  // Design Constants
  final Color brandRed = const Color(0xFF991B1B);
  final Color softWhite = const Color(0xFFFDFDFD);
  final Color darkText = const Color(0xFF111827);
  final Color mutedText = const Color(0xFF6B7280);
  final Color borderSubtle = const Color(0xFFE5E7EB);

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final firestore = FirebaseFirestore.instance;

      final results = await Future.wait([
        firestore.collection('users').where('status', whereIn: ['verified', 'active']).count().get(),
        firestore.collection('users').where('status', isEqualTo: 'pending').count().get(),
        firestore.collection('chapters').where('active', isEqualTo: true).count().get(),
        firestore.collection('users').where('status', isEqualTo: 'pending').orderBy('createdAt', descending: true).get(),
        firestore.collection('events').orderBy('createdAt', descending: true).limit(4).get(),
        firestore.collection('announcements').orderBy('publishedAt', descending: true).limit(4).get(),
        firestore.collection('users').orderBy('updatedAt', descending: true).limit(8).get(),
      ]);

      final eventsSnap = results[4] as QuerySnapshot;
      final announcementsSnap = results[5] as QuerySnapshot;
      final userActivitySnap = results[6] as QuerySnapshot;

      if (mounted) {
        setState(() {
          totalAlumni = (results[0] as AggregateQuerySnapshot).count ?? 0;
          pendingVerifications = (results[1] as AggregateQuerySnapshot).count ?? 0;
          activeChapters = (results[2] as AggregateQuerySnapshot).count ?? 0;

          pendingUsers = (results[3] as QuerySnapshot).docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              'name': data['name'] as String? ?? data['fullName'] as String? ?? 'Unknown',
              'degree': '${data['degree'] as String? ?? ''} ${data['batchYear'] as String? ?? ''}'.trim(),
              'submitted': _formatTimestamp(data['createdAt'] as Timestamp?),
            };
          }).toList();

          networkPulse = [
            ...eventsSnap.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return {
                'type': 'EVENT',
                'title': data['title'] as String? ?? 'Event Update',
                'desc': data['description'] as String? ?? 'No description',
                'time': _formatTimestamp(data['createdAt'] as Timestamp?),
                'isUrgent': false,
              };
            }),
            ...announcementsSnap.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return {
                'type': 'ANNOUNCEMENT',
                'title': data['title'] as String? ?? 'Announcement',
                'desc': data['content'] as String? ?? 'No content',
                'time': _formatTimestamp(data['publishedAt'] as Timestamp?),
                'isUrgent': (data['priority'] as String?) == 'high',
              };
            }),
          ]..sort((a, b) => (b['time'] as String).compareTo(a['time'] as String));

          networkPulse = networkPulse.take(8).toList();

          recentUserActivity = userActivitySnap.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = data['name'] as String? ?? data['fullName'] as String? ?? 'Unknown';
            final lastLogin = data['lastLogin'] as Timestamp?;
            final updatedAt = data['updatedAt'] as Timestamp?;
            final latest = lastLogin?.toDate().isAfter(updatedAt?.toDate() ?? DateTime(2000)) == true ? lastLogin : updatedAt;

            return {
              'name': name,
              'action': lastLogin == latest ? 'Logged in' : 'Profile updated',
              'time': _formatTimestamp(latest),
            };
          }).toList();

          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Admin dashboard load error: $e');
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to load dashboard data: $e';
          isLoading = false;
        });
      }
    }
  }

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return 'N/A';
    final date = ts.toDate();
    final now = DateTime.now();
    if (date.isAfter(now.subtract(const Duration(days: 1)))) {
      return DateFormat('h:mm a').format(date);
    }
    return DateFormat('MMM d, h:mm a').format(date);
  }

  Future<void> _verifyUser(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'status': 'verified',
        'updatedAt': FieldValue.serverTimestamp(),
        'verifiedBy': FirebaseAuth.instance.currentUser?.uid,
        'verifiedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User verified'), backgroundColor: Colors.green),
        );
        _loadAdminData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _denyUser(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'status': 'denied',
        'updatedAt': FieldValue.serverTimestamp(),
        'deniedBy': FirebaseAuth.instance.currentUser?.uid,
        'deniedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User denied'), backgroundColor: Colors.orange),
        );
        _loadAdminData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isNarrow = size.width < 1100;
    final horizontalPadding = (size.width * 0.04).clamp(24.0, 64.0);
    final verticalPadding = (size.height * 0.025).clamp(28.0, 56.0);
    final sidebarWidth = isNarrow ? 240.0 : 280.0;

    return Scaffold(
      backgroundColor: softWhite,
      body: RefreshIndicator(
        onRefresh: _loadAdminData,
        color: brandRed,
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF991B1B)))
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Sidebar
                  Container(
                    width: sidebarWidth,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(right: BorderSide(color: borderSubtle, width: 0.5)),
                    ),
                    child: _buildSidebar(),
                  ),

                  // Main content
                  Expanded(
                    child: SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: size.height),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                            vertical: verticalPadding,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHeader(),
                              const SizedBox(height: 40),
                              _buildStatsGrid(),
                              const SizedBox(height: 48),
                              _buildMainContentSections(),
                              const SizedBox(height: 48),
                              _buildRecentActivity(),
                              const SizedBox(height: 80),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSidebar() {
    return Column(
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
                  color: brandRed,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'ARCHIVE PORTAL',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  letterSpacing: 2,
                  color: mutedText,
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
                  _SidebarItem(label: 'Overview', isActive: true),
                  _SidebarItem(label: 'Chapter Management', route: '/chapter_management'),
                ]),
                const SizedBox(height: 32),
                _buildSidebarSection('ENGAGEMENT', [
                  _SidebarItem(label: 'Reunions & Events', route: '/reunions_events'),
                  _SidebarItem(label: 'Career Milestones', route: '/career_milestones'),
                ]),
                const SizedBox(height: 32),
                _buildSidebarSection('ADMIN FEATURES', [
                  _SidebarItem(label: 'User Verification & Moderation', route: '/user_verification_moderation'),
                  _SidebarItem(label: 'Event Planning', route: '/event_planning'),
                  _SidebarItem(label: 'Job Board Management', route: '/job_board_management'),
                  _SidebarItem(label: 'Growth Metrics', route: '/growth_metrics'),
                ]),
              ],
            ),
          ),
        ),
        _buildSidebarFooter(),
      ],
    );
  }

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
            color: mutedText.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 16),
        ...items,
      ],
    );
  }

  Widget _buildSidebarFooter() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: borderSubtle.withOpacity(0.3))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: brandRed,
                child: Text('A', style: GoogleFonts.cormorantGaramond(color: Colors.white, fontSize: 14)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Registrar Admin', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                  Text('NETWORK OVERSEER', style: GoogleFonts.inter(fontSize: 9, color: mutedText)),
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
              style: GoogleFonts.inter(fontSize: 10, letterSpacing: 2, color: mutedText, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 800;
        return narrow
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Alumni Intelligence.',
                    style: GoogleFonts.cormorantGaramond(fontSize: 36, fontStyle: FontStyle.italic, fontWeight: FontWeight.w300),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'INSTITUTIONAL DATA FEED: LIVE',
                    style: GoogleFonts.inter(fontSize: 10, letterSpacing: 2, color: mutedText),
                  ),
                  const SizedBox(height: 24),
                  Wrap(spacing: 16, runSpacing: 16, children: [
                    _buildActionButton('DONATION REPORTS', false),
                    _buildActionButton('BROADCAST NEWSLETTER', true),
                  ]),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Alumni Intelligence.',
                        style: GoogleFonts.cormorantGaramond(fontSize: 44, fontStyle: FontStyle.italic, fontWeight: FontWeight.w300),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'INSTITUTIONAL DATA FEED: LIVE',
                        style: GoogleFonts.inter(fontSize: 10, letterSpacing: 2, color: mutedText),
                      ),
                    ],
                  ),
                  Wrap(spacing: 16, children: [
                    _buildActionButton('DONATION REPORTS', false),
                    _buildActionButton('BROADCAST NEWSLETTER', true),
                  ]),
                ],
              );
      },
    );
  }

  Widget _buildActionButton(String text, bool primary) {
    final style = primary
        ? ElevatedButton.styleFrom(backgroundColor: brandRed, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16))
        : OutlinedButton.styleFrom(side: BorderSide(color: borderSubtle), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16));

    // Choose the appropriate button type explicitly rather than trying to
    // invoke a constructor through a ternary expression. The previous code
    // caused an analyzer error because the expression returned a Type, not a
    // callable constructor.
    if (primary) {
      return ElevatedButton(
        onPressed: () {},
        style: style.copyWith(
            shape: const MaterialStatePropertyAll(RoundedRectangleBorder())),
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 11,
            letterSpacing: 1.5,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else {
      return OutlinedButton(
        onPressed: () {},
        style: style.copyWith(
            shape: const MaterialStatePropertyAll(RoundedRectangleBorder())),
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 11,
            letterSpacing: 1.5,
            color: darkText,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
  }

  Widget _buildStatsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int count = 4;
        if (constraints.maxWidth < 1400) count = 3;
        if (constraints.maxWidth < 1000) count = 2;
        if (constraints.maxWidth < 600) count = 1;

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: count,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          childAspectRatio: count >= 3 ? 1.65 : 1.9,
          children: [
            _buildStatCard('Total Alumni Verified', totalAlumni.toString(), '+48 new graduates'),
            _buildStatCard('Engagement Rate', '24.8%', 'Active in mentorship', Colors.green),
            _buildStatCard('Pending Verifications', pendingVerifications.toString(), 'Requires ID review', brandRed),
            _buildStatCard('Endowment Growth', '+8.2%', 'Year-to-date', Colors.green),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, String subtitle, [Color? color]) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: borderSubtle)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, letterSpacing: 1.5, color: mutedText, fontWeight: FontWeight.bold)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: GoogleFonts.cormorantGaramond(fontSize: 38, fontWeight: FontWeight.w300)),
          ),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: color ?? mutedText)),
        ],
      ),
    );
  }

  Widget _buildMainContentSections() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 1100;
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: _buildVerificationQueue()),
              const SizedBox(width: 48),
              Expanded(flex: 3, child: _buildNetworkPulse()),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildVerificationQueue(),
            const SizedBox(height: 56),
            _buildNetworkPulse(),
          ],
        );
      },
    );
  }

  Widget _buildVerificationQueue() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'Identity Verification Queue',
                style: GoogleFonts.cormorantGaramond(fontSize: 26),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              'FULL DIRECTORY',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: brandRed, letterSpacing: 1.5),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(border: Border.all(color: borderSubtle)),
          child: pendingUsers.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(child: Text('No pending verifications at this time.', style: GoogleFonts.inter(color: mutedText, fontSize: 15))),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(softWhite),
                    dataRowMaxHeight: 68,
                    columns: const [
                      DataColumn(label: Text('ALUMNUS')),
                      DataColumn(label: Text('BATCH/DEGREE')),
                      DataColumn(label: Text('SUBMITTED')),
                      DataColumn(label: Text('ACTIONS')),
                    ],
                    rows: pendingUsers.map(_buildDataRow).toList(),
                  ),
                ),
        ),
        const SizedBox(height: 16),
        Text('Total Pending: $pendingVerifications', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: brandRed)),
      ],
    );
  }

  Widget _buildNetworkPulse() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Network Pulse', style: GoogleFonts.cormorantGaramond(fontSize: 26)),
        const SizedBox(height: 24),
        if (networkPulse.isEmpty)
          Text('No recent activity.', style: GoogleFonts.inter(color: mutedText, fontSize: 14))
        else
          ...networkPulse.map((item) => _buildActivityItem(
                item['type'] as String,
                item['title'] as String,
                item['desc'] as String,
                item['time'] as String,
                item['isUrgent'] as bool? ?? false,
              )),
      ],
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent User Activity', style: GoogleFonts.cormorantGaramond(fontSize: 24)),
        const SizedBox(height: 16),
        if (recentUserActivity.isEmpty)
          Text('No recent user activity.', style: GoogleFonts.inter(color: mutedText))
        else
          ...recentUserActivity.map((log) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(Icons.person_outline_rounded, color: mutedText, size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${log['name']} – ${log['action']}',
                        style: GoogleFonts.inter(fontSize: 14, color: darkText),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(log['time'], style: GoogleFonts.inter(fontSize: 12, color: mutedText)),
                  ],
                ),
              )),
      ],
    );
  }

  DataRow _buildDataRow(Map<String, dynamic> user) {
    return DataRow(cells: [
      DataCell(Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(user['name'] ?? '—', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
          Text('Pending Review', style: GoogleFonts.inter(fontSize: 10, color: mutedText)),
        ],
      )),
      DataCell(Text(user['degree'] ?? '—', style: GoogleFonts.inter(fontSize: 12))),
      DataCell(Text(user['submitted'] ?? '—', style: GoogleFonts.inter(fontSize: 12, color: mutedText))),
      DataCell(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () => _verifyUser(user['id']),
            child: Text('VERIFY', style: GoogleFonts.inter(fontSize: 11, color: brandRed, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => _denyUser(user['id']),
            child: Text('DENY', style: GoogleFonts.inter(fontSize: 11, color: mutedText)),
          ),
        ],
      )),
    ]);
  }

  Widget _buildActivityItem(String type, String title, String desc, String time, bool isUrgent) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 3, height: 40, color: isUrgent ? brandRed : borderSubtle),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, letterSpacing: 1.5, color: mutedText, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(desc, style: GoogleFonts.inter(fontSize: 13, color: darkText), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(time, style: GoogleFonts.inter(fontSize: 11, color: mutedText)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _SidebarItem({required String label, bool isActive = false, String? route}) {
    final color = isActive ? brandRed : darkText;
    final weight = isActive ? FontWeight.w600 : FontWeight.w400;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: route != null && !isActive ? () => Navigator.pushNamed(context, route) : null,
        child: MouseRegion(
          cursor: route != null && !isActive ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: Text(
            label,
            style: GoogleFonts.inter(fontSize: 13.5, color: color, fontWeight: weight),
          ),
        ),
      ),
    );
  }
}