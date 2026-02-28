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
  double engagementRate = 0.0;

  List<Map<String, dynamic>> pendingUsers = [];
  List<Map<String, dynamic>> networkPulse = [];
  List<Map<String, dynamic>> recentUserActivity = [];

  bool isLoading = true;
  String? errorMessage;

  String _selectedSection = 'Overview';

  // Controllers for various forms
  final _eventTitleController = TextEditingController();
  final _eventDescController = TextEditingController();
  final _eventDateController = TextEditingController();

  final _jobTitleController = TextEditingController();
  final _jobCompanyController = TextEditingController();
  final _jobDescController = TextEditingController();

  final _internshipTitleController = TextEditingController();
  final _internshipCompanyController = TextEditingController();
  final _internshipDescController = TextEditingController();

  // Search controllers
  final _directorySearchController = TextEditingController();
  String _directoryIndustryFilter = '';
  String _directoryCompanyFilter = '';
  String _directoryGradYearFilter = '';

  // Design Constants (your original palette)
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
        // 1. Total verified/active alumni - COUNT
        firestore
            .collection('users')
            .where('status', whereIn: ['verified', 'active'])
            .count()
            .get(),

        // 2. Pending verifications - COUNT (this is what the card uses)
        firestore
            .collection('users')
            .where('status', isEqualTo: 'pending')
            .count()
            .get(),

        // 3. Active chapters - COUNT
        firestore
            .collection('chapters')
            .where('active', isEqualTo: true)
            .count()
            .get(),

        // 4. ALL pending users for verification queue (no limit)
        firestore
            .collection('users')
            .where('status', isEqualTo: 'pending')
            .orderBy('createdAt', descending: true)
            .get(),  // ← removed .limit(10)

        // 5. Recent events (last 4)
        firestore
            .collection('events')
            .orderBy('createdAt', descending: true)
            .limit(4)
            .get(),

        // 6. Recent announcements (last 4)
        firestore
            .collection('announcements')
            .orderBy('publishedAt', descending: true)
            .limit(4)
            .get(),

        // 7. Recent user activity (last 8)
        firestore
            .collection('users')
            .orderBy('updatedAt', descending: true)
            .limit(8)
            .get(),

        // For engagement rate: users active in last 30 days
        firestore.collection('users').where('lastLogin', isGreaterThan: Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 30)))).count().get(),
      ]);

      final eventsSnap = results[4] as QuerySnapshot;
      final announcementsSnap = results[5] as QuerySnapshot;
      final userActivitySnap = results[6] as QuerySnapshot;

      if (mounted) {
        setState(() {
          totalAlumni = (results[0] as AggregateQuerySnapshot).count ?? 0;
          pendingVerifications = (results[1] as AggregateQuerySnapshot).count ?? 0;
          activeChapters = (results[2] as AggregateQuerySnapshot).count ?? 0;

          int activeUsers = (results[7] as AggregateQuerySnapshot).count ?? 0;
          engagementRate = totalAlumni > 0 ? (activeUsers / totalAlumni) * 100 : 0.0;

          // Pending users table - ALL pending users
          pendingUsers = (results[3] as QuerySnapshot).docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              'name': data['name'] as String? ?? data['fullName'] as String? ?? 'Unknown',
              'degree': '${data['degree'] as String? ?? ''} ${data['batchYear'] as String? ?? ''}'.trim(),
              'gradYear': data['batchYear'] ?? 'N/A',
              'certificate': data['certificateUrl'] ?? null, // Assume field for cert
              'submitted': _formatTimestamp(data['createdAt'] as Timestamp?),
            };
          }).toList();

          // Network Pulse: real events + announcements
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
          ]..sort((a, b) {
              final timeA = a['time'] ?? '';
              final timeB = b['time'] ?? '';
              return timeB.compareTo(timeA);
            });

          networkPulse = networkPulse.take(8).toList();

          // Recent user activity / login logs
          recentUserActivity = userActivitySnap.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = data['name'] as String? ?? data['fullName'] as String? ?? 'Unknown';
            final lastLogin = data['lastLogin'] as Timestamp?;
            final updatedAt = data['updatedAt'] as Timestamp?;
            final latest = lastLogin?.toDate().isAfter(updatedAt?.toDate() ?? DateTime(2000)) == true
                ? lastLogin
                : updatedAt;

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

  Future<void> _verifyUser(String uid, Map<String, dynamic> userData) async {
    // Show modal for review
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Review ${userData['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Grad Year: ${userData['gradYear']}'),
            Text('Degree: ${userData['degree']}'),
            if (userData['certificate'] != null) Text('Certificate: ${userData['certificate']}'), // Could show image
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () async {
            Navigator.pop(ctx);
            await _performVerify(uid);
          }, child: const Text('Approve')),
          TextButton(onPressed: () async {
            Navigator.pop(ctx);
            await _denyUser(uid);
          }, child: const Text('Deny')),
        ],
      ),
    );
  }

  Future<void> _performVerify(String uid) async {
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

  Future<void> _moderateProfile(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'flaggedForUpdate': true,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile flagged for update'), backgroundColor: Colors.blue),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _createEvent() async {
    try {
      await FirebaseFirestore.instance.collection('events').add({
        'title': _eventTitleController.text,
        'description': _eventDescController.text,
        'date': Timestamp.fromDate(DateFormat('yyyy-MM-dd').parse(_eventDateController.text)),
        'createdAt': FieldValue.serverTimestamp(),
        'rsvps': [],
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event created'), backgroundColor: Colors.green),
        );
        _loadAdminData();
      }
      _eventTitleController.clear();
      _eventDescController.clear();
      _eventDateController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _approveJob(String jobId) async {
    try {
      await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
        'status': 'approved',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job approved'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _createJob() async {
    try {
      await FirebaseFirestore.instance.collection('jobs').add({
        'title': _jobTitleController.text,
        'company': _jobCompanyController.text,
        'desc': _jobDescController.text,
        'status': 'pending',
        'postedBy': FirebaseAuth.instance.currentUser?.uid,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job posted for review'), backgroundColor: Colors.green),
        );
      }
      _jobTitleController.clear();
      _jobCompanyController.clear();
      _jobDescController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _createInternship() async {
    try {
      await FirebaseFirestore.instance.collection('internships').add({
        'title': _internshipTitleController.text,
        'company': _internshipCompanyController.text,
        'desc': _internshipDescController.text,
        'status': 'pending',
        'postedBy': FirebaseAuth.instance.currentUser?.uid,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Internship posted'), backgroundColor: Colors.green),
        );
      }
      _internshipTitleController.clear();
      _internshipCompanyController.clear();
      _internshipDescController.clear();
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
    return Scaffold(
      backgroundColor: softWhite,
      body: RefreshIndicator(
        onRefresh: _loadAdminData,
        color: brandRed,
        child: isLoading
            ? Center(child: CircularProgressIndicator(color: brandRed, strokeWidth: 1))
            : Row(
                children: [
                  // Sidebar - original restored
                  _buildSidebar(),

                  // Main Content - original layout restored
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(64),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 64),
                          _buildStatsGrid(),
                          const SizedBox(height: 80),
                          _buildMainContentSections(),
                          const SizedBox(height: 64),

                          // Recent User Activity / Logs
                          Text('Recent User Activity', style: GoogleFonts.cormorantGaramond(fontSize: 24)),
                          const SizedBox(height: 16),
                          if (recentUserActivity.isEmpty)
                            Text('No recent user activity.', style: GoogleFonts.inter(color: mutedText))
                          else
                            ...recentUserActivity.map((log) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    children: [
                                      Icon(Icons.person, color: mutedText, size: 20),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          '${log['name']} – ${log['action']}',
                                          style: GoogleFonts.inter(fontSize: 14, color: darkText),
                                        ),
                                      ),
                                      Text(
                                        log['time'],
                                        style: GoogleFonts.inter(fontSize: 12, color: mutedText),
                                      ),
                                    ],
                                  ),
                                )),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ────────────────────────────────────────────────
  // Original sidebar restored
  // ────────────────────────────────────────────────
  Widget _buildSidebar() {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: borderSubtle, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(40.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ALUMNI',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 24,
                    letterSpacing: 8,
                    color: brandRed,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: 8),
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
          const SizedBox(height: 20),
          _buildSidebarSection('NETWORK', [
            _SidebarItem(label: 'Overview', isActive: _selectedSection == 'Overview', onTap: () => setState(() => _selectedSection = 'Overview')),
            _SidebarItem(label: 'Global Directory', isActive: _selectedSection == 'Directory Access', onTap: () => setState(() => _selectedSection = 'Directory Access')),
            _SidebarItem(label: 'Chapter Management', isActive: _selectedSection == 'Chapter Management', onTap: () => setState(() => _selectedSection = 'Chapter Management')),
            _SidebarItem(label: 'Mentorship Circles', isActive: _selectedSection == 'Mentorship Circles', onTap: () => setState(() => _selectedSection = 'Mentorship Circles')),
          ]),
          const SizedBox(height: 32),
          _buildSidebarSection('ENGAGEMENT', [
            _SidebarItem(label: 'Reunions & Events', isActive: _selectedSection == 'Reunion Planning', onTap: () => setState(() => _selectedSection = 'Reunion Planning')),
            _SidebarItem(label: 'Giving & Endowment', isActive: _selectedSection == 'Giving & Endowment', onTap: () => setState(() => _selectedSection = 'Giving & Endowment')),
            _SidebarItem(label: 'Career Milestones', isActive: _selectedSection == 'Career Milestones', onTap: () => setState(() => _selectedSection = 'Career Milestones')),
            _SidebarItem(label: 'Vetting Requests', isActive: _selectedSection == 'Vetting Requests', onTap: () => setState(() => _selectedSection = 'Vetting Requests')),
            _SidebarItem(label: 'Profile Moderation', isActive: _selectedSection == 'Profile Moderation', onTap: () => setState(() => _selectedSection = 'Profile Moderation')),
            _SidebarItem(label: 'Job Board Moderation', isActive: _selectedSection == 'Job Board Moderation', onTap: () => setState(() => _selectedSection = 'Job Board Moderation')),
            _SidebarItem(label: 'Internship Pipelines', isActive: _selectedSection == 'Internship Pipelines', onTap: () => setState(() => _selectedSection = 'Internship Pipelines')),
            _SidebarItem(label: 'Growth Metrics', isActive: _selectedSection == 'Growth Metrics', onTap: () => setState(() => _selectedSection = 'Growth Metrics')),
          ]),
          const Spacer(),
          _buildSidebarFooter(),
        ],
      ),
    );
  }

  Widget _buildSidebarSection(String title, List<Widget> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 10,
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
              color: mutedText.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 16),
          ...items,
        ],
      ),
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
                child: Text('A', style: GoogleFonts.cormorantGaramond(color: Colors.white, fontSize: 12)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Registrar Admin', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                  Text('NETWORK OVERSEER', style: GoogleFonts.inter(fontSize: 9, color: mutedText)),
                ],
              )
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
          )
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Alumni Intelligence.',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 48,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'INSTITUTIONAL DATA FEED: LIVE',
              style: GoogleFonts.inter(fontSize: 10, letterSpacing: 2, color: mutedText),
            ),
          ],
        ),
        Row(
          children: [
            OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: borderSubtle),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                shape: const RoundedRectangleBorder(),
              ),
              child: Text('DONATION REPORTS', style: GoogleFonts.inter(fontSize: 10, letterSpacing: 2, color: darkText, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: brandRed,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                shape: const RoundedRectangleBorder(),
              ),
              child: Text('BROADCAST NEWSLETTER', style: GoogleFonts.inter(fontSize: 10, letterSpacing: 2, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildStatsGrid() {
    return LayoutBuilder(builder: (context, constraints) {
      int crossAxisCount = constraints.maxWidth > 1200 ? 4 : 2;
      return GridView.count(
        shrinkWrap: true,
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
        childAspectRatio: 1.5,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildStatCard('Total Alumni Verified', totalAlumni.toString(), '+48 new graduates'),
          _buildStatCard('Engagement Rate', '${engagementRate.toStringAsFixed(1)}%', 'Active in mentorship'),
          _buildStatCard('Pending Verifications', pendingVerifications.toString(), 'Requires ID review'),
          _buildStatCard('Endowment Growth', '+8.2%', 'Year-to-date'),
        ],
      );
    });
  }

  Widget _buildStatCard(String title, String value, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(fontSize: 9, letterSpacing: 2, color: mutedText, fontWeight: FontWeight.bold),
          ),
          Text(
            value,
            style: GoogleFonts.cormorantGaramond(fontSize: 40, fontWeight: FontWeight.w300),
          ),
          Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 10, color: title.contains('Rate') || title.contains('Growth') ? Colors.green : (title.contains('Pending') ? brandRed : mutedText)),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContentSections() {
    if (_selectedSection != 'Overview') {
      return _buildSelectedSection();
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Pending Verification Table – ALL pending users + working actions
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Identity Verification Queue', style: GoogleFonts.cormorantGaramond(fontSize: 24)),
                  Text('FULL DIRECTORY', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: brandRed, letterSpacing: 2)),
                ],
              ),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(border: Border.all(color: borderSubtle)),
                child: pendingUsers.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            'No pending verifications at this time.',
                            style: GoogleFonts.inter(color: mutedText, fontSize: 16),
                          ),
                        ),
                      )
                    : DataTable(
                        headingRowColor: WidgetStateProperty.all(softWhite),
                        dataRowMaxHeight: 70,
                        columns: [
                          DataColumn(label: Text('ALUMNUS', style: GoogleFonts.inter(fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold, color: mutedText))),
                          DataColumn(label: Text('BATCH/DEGREE', style: GoogleFonts.inter(fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold, color: mutedText))),
                          DataColumn(label: Text('SUBMITTED', style: GoogleFonts.inter(fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold, color: mutedText))),
                          DataColumn(label: Text('ACTIONS', style: GoogleFonts.inter(fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold, color: mutedText))),
                        ],
                        rows: pendingUsers.map((user) => _buildDataRow(user)).toList(),
                      ),
              ),
              const SizedBox(height: 16),
              // Show the real count of pending users
              Text(
                'Total Pending Verifications: $pendingVerifications',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: brandRed),
              ),
            ],
          ),
        ),
        const SizedBox(width: 64),

        // Network Pulse – REAL recent events + announcements
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Network Pulse', style: GoogleFonts.cormorantGaramond(fontSize: 24)),
              const SizedBox(height: 32),
              if (networkPulse.isEmpty)
                Text('No recent activity in the network.', style: GoogleFonts.inter(color: mutedText, fontSize: 14))
              else
                ...networkPulse.map((item) => _buildActivityItem(
                      item['type'] as String,
                      item['title'] as String,
                      item['desc'] as String,
                      item['time'] as String,
                      item['isUrgent'] as bool? ?? false,
                    )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedSection() {
    switch (_selectedSection) {
      case 'Vetting Requests':
        return _buildVettingSection();
      case 'Profile Moderation':
        return _buildProfileModerationSection();
      case 'Directory Access':
        return _buildDirectorySection();
      case 'Reunion Planning':
        return _buildReunionSection();
      case 'Job Board Moderation':
        return _buildJobBoardSection();
      case 'Internship Pipelines':
        return _buildInternshipSection();
      case 'Growth Metrics':
        return _buildMetricsSection();
      default:
        return Text('Section: $_selectedSection', style: GoogleFonts.cormorantGaramond(fontSize: 24));
    }
  }

  Widget _buildVettingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Vetting Requests', style: GoogleFonts.cormorantGaramond(fontSize: 24)),
        const SizedBox(height: 32),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(border: Border.all(color: borderSubtle)),
          child: pendingUsers.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'No pending verifications at this time.',
                      style: GoogleFonts.inter(color: mutedText, fontSize: 16),
                    ),
                  ),
                )
              : DataTable(
                  headingRowColor: WidgetStateProperty.all(softWhite),
                  dataRowMaxHeight: 70,
                  columns: [
                    DataColumn(label: Text('ALUMNUS', style: GoogleFonts.inter(fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold, color: mutedText))),
                    DataColumn(label: Text('BATCH/DEGREE', style: GoogleFonts.inter(fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold, color: mutedText))),
                    DataColumn(label: Text('SUBMITTED', style: GoogleFonts.inter(fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold, color: mutedText))),
                    DataColumn(label: Text('ACTIONS', style: GoogleFonts.inter(fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold, color: mutedText))),
                  ],
                  rows: pendingUsers.map((user) => DataRow(cells: [
                        DataCell(Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user['name'] ?? '—', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                            Text('Pending Review', style: GoogleFonts.inter(fontSize: 10, color: mutedText)),
                          ],
                        )),
                        DataCell(Text(user['degree'] ?? '—', style: GoogleFonts.inter(fontSize: 10))),
                        DataCell(Text(user['submitted'] ?? '—', style: GoogleFonts.inter(fontSize: 10, color: mutedText))),
                        DataCell(Row(
                          children: [
                            TextButton(
                              onPressed: () => _verifyUser(user['id'], user),
                              child: Text('REVIEW', style: GoogleFonts.inter(fontSize: 10, color: brandRed, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        )),
                      ])).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildProfileModerationSection() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('users').where('status', isEqualTo: 'verified').get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: brandRed));
        }
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}', style: GoogleFonts.inter(color: Colors.red));
        }
        final users = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'name': data['name'] ?? 'Unknown',
            'company': data['company'] ?? 'N/A',
            'location': data['location'] ?? 'N/A',
            'role': data['role'] ?? 'N/A',
            'lastUpdated': _formatTimestamp(data['updatedAt']),
          };
        }).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Profile Moderation', style: GoogleFonts.cormorantGaramond(fontSize: 24)),
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(border: Border.all(color: borderSubtle)),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(softWhite),
                dataRowMaxHeight: 70,
                columns: [
                  DataColumn(label: Text('ALUMNUS', style: GoogleFonts.inter(fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold, color: mutedText))),
                  DataColumn(label: Text('COMPANY', style: GoogleFonts.inter(fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold, color: mutedText))),
                  DataColumn(label: Text('LOCATION', style: GoogleFonts.inter(fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold, color: mutedText))),
                  DataColumn(label: Text('ROLE', style: GoogleFonts.inter(fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold, color: mutedText))),
                  DataColumn(label: Text('LAST UPDATED', style: GoogleFonts.inter(fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold, color: mutedText))),
                  DataColumn(label: Text('ACTIONS', style: GoogleFonts.inter(fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold, color: mutedText))),
                ],
                rows: users.map((user) => DataRow(cells: [
                      DataCell(Text(user['name'] ?? '—', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold))),
                      DataCell(Text(user['company'] ?? '—', style: GoogleFonts.inter(fontSize: 10))),
                      DataCell(Text(user['location'] ?? '—', style: GoogleFonts.inter(fontSize: 10))),
                      DataCell(Text(user['role'] ?? '—', style: GoogleFonts.inter(fontSize: 10))),
                      DataCell(Text(user['lastUpdated'] ?? '—', style: GoogleFonts.inter(fontSize: 10, color: mutedText))),
                      DataCell(TextButton(
                        onPressed: () => _moderateProfile(user['id']),
                        child: Text('FLAG UPDATE', style: GoogleFonts.inter(fontSize: 10, color: brandRed, fontWeight: FontWeight.bold)),
                      )),
                    ])).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDirectorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Global Directory', style: GoogleFonts.cormorantGaramond(fontSize: 24)),
        const SizedBox(height: 32),
        TextField(
          controller: _directorySearchController,
          decoration: const InputDecoration(labelText: 'Search by Name'),
          onChanged: (value) => setState(() {}),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: (value) => setState(() => _directoryIndustryFilter = value),
                decoration: const InputDecoration(labelText: 'Industry Filter'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                onChanged: (value) => setState(() => _directoryCompanyFilter = value),
                decoration: const InputDecoration(labelText: 'Company Filter'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                onChanged: (value) => setState(() => _directoryGradYearFilter = value),
                decoration: const InputDecoration(labelText: 'Graduation Year Filter'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        FutureBuilder<QuerySnapshot>(
          future: _getDirectoryQuery().get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: brandRed));
            }
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}', style: GoogleFonts.inter(color: Colors.red));
            }
            final users = snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return {
                'name': data['name'] ?? 'Unknown',
                'company': data['company'] ?? 'N/A',
                'industry': data['industry'] ?? 'N/A',
                'gradYear': data['batchYear'] ?? 'N/A',
              };
            }).toList();
            return Container(
              width: double.infinity,
              decoration: BoxDecoration(border: Border.all(color: borderSubtle)),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(softWhite),
                columns: [
                  DataColumn(label: Text('NAME', style: GoogleFonts.inter(fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold, color: mutedText))),
                  DataColumn(label: Text('COMPANY', style: GoogleFonts.inter(fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold, color: mutedText))),
                  DataColumn(label: Text('INDUSTRY', style: GoogleFonts.inter(fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold, color: mutedText))),
                  DataColumn(label: Text('GRAD YEAR', style: GoogleFonts.inter(fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold, color: mutedText))),
                ],
                rows: users.map((user) => DataRow(cells: [
                      DataCell(Text(user['name'] ?? '—', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold))),
                      DataCell(Text(user['company'] ?? '—', style: GoogleFonts.inter(fontSize: 10))),
                      DataCell(Text(user['industry'] ?? '—', style: GoogleFonts.inter(fontSize: 10))),
                      DataCell(Text(user['gradYear'] ?? '—', style: GoogleFonts.inter(fontSize: 10))),
                    ])).toList(),
              ),
            );
          },
        ),
      ],
    );
  }

  Query _getDirectoryQuery() {
    var query = FirebaseFirestore.instance.collection('users').where('status', isEqualTo: 'verified');
    if (_directorySearchController.text.isNotEmpty) {
      query = query.where('name', isGreaterThanOrEqualTo: _directorySearchController.text);
      query = query.where('name', isLessThanOrEqualTo: '${_directorySearchController.text}\uf8ff');
    }
    if (_directoryIndustryFilter.isNotEmpty) query = query.where('industry', isEqualTo: _directoryIndustryFilter);
    if (_directoryCompanyFilter.isNotEmpty) query = query.where('company', isEqualTo: _directoryCompanyFilter);
    if (_directoryGradYearFilter.isNotEmpty) query = query.where('batchYear', isEqualTo: _directoryGradYearFilter);
    return query.orderBy('name');
  }

  Widget _buildReunionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reunion Planning', style: GoogleFonts.cormorantGaramond(fontSize: 24)),
        const SizedBox(height: 32),
        TextField(
          controller: _eventTitleController,
          decoration: const InputDecoration(labelText: 'Event Title'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _eventDescController,
          decoration: const InputDecoration(labelText: 'Description'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _eventDateController,
          decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)'),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _createEvent,
          style: ElevatedButton.styleFrom(backgroundColor: brandRed),
          child: Text('Create Event', style: GoogleFonts.inter(color: Colors.white)),
        ),
        const SizedBox(height: 32),
        FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance.collection('events').orderBy('createdAt', descending: true).get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: brandRed));
            }
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}', style: GoogleFonts.inter(color: Colors.red));
            }
            final events = snapshot.data!.docs;
            return Container(
              width: double.infinity,
              decoration: BoxDecoration(border: Border.all(color: borderSubtle)),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(softWhite),
                columns: [
                  DataColumn(label: Text('TITLE', style: GoogleFonts.inter(fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold, color: mutedText))),
                  DataColumn(label: Text('DATE', style: GoogleFonts.inter(fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold, color: mutedText))),
                  DataColumn(label: Text('RSVPS', style: GoogleFonts.inter(fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold, color: mutedText))),
                ],
                rows: events.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return DataRow(cells: [
                    DataCell(Text(data['title'] ?? '—', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold))),
                    DataCell(Text(_formatTimestamp(data['date']), style: GoogleFonts.inter(fontSize: 10))),
                    DataCell(Text('${(data['rsvps'] as List?)?.length ?? 0}', style: GoogleFonts.inter(fontSize: 10))),
                  ]);
                }).toList(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildJobBoardSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Job Board Moderation & Curation', style: GoogleFonts.cormorantGaramond(fontSize: 24)),
        const SizedBox(height: 32),
        TextField(
          controller: _jobTitleController,
          decoration: const InputDecoration(labelText: 'Job Title'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _jobCompanyController,
          decoration: const InputDecoration(labelText: 'Company'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _jobDescController,
          decoration: const InputDecoration(labelText: 'Description'),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _createJob,
          style: ElevatedButton.styleFrom(backgroundColor: brandRed),
          child: Text('Post Job for Review', style: GoogleFonts.inter(color: Colors.white)),
        ),
        const SizedBox(height: 32),
        Text('Pending Job Postings', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance.collection('jobs').where('status', isEqualTo: 'pending').get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: brandRed));
            }
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}', style: GoogleFonts.inter(color: Colors.red));
            }
            final jobs = snapshot.data!.docs;
            return Container(
              width: double.infinity,
              decoration: BoxDecoration(border: Border.all(color: borderSubtle)),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(softWhite),
                columns: [
                  DataColumn(label: Text('TITLE', style: GoogleFonts.inter(fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold, color: mutedText))),
                  DataColumn(label: Text('COMPANY', style: GoogleFonts.inter(fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold, color: mutedText))),
                  DataColumn(label: Text('ACTIONS', style: GoogleFonts.inter(fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold, color: mutedText))),
                ],
                rows: jobs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return DataRow(cells: [
                    DataCell(Text(data['title'] ?? '—', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold))),
                    DataCell(Text(data['company'] ?? '—', style: GoogleFonts.inter(fontSize: 10))),
                    DataCell(TextButton(
                      onPressed: () => _approveJob(doc.id),
                      child: Text('APPROVE', style: GoogleFonts.inter(fontSize: 10, color: brandRed, fontWeight: FontWeight.bold)),
                    )),
                  ]);
                }).toList(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildInternshipSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Internship Pipelines', style: GoogleFonts.cormorantGaramond(fontSize: 24)),
        const SizedBox(height: 32),
        TextField(
          controller: _internshipTitleController,
          decoration: const InputDecoration(labelText: 'Internship Title'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _internshipCompanyController,
          decoration: const InputDecoration(labelText: 'Company'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _internshipDescController,
          decoration: const InputDecoration(labelText: 'Description'),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _createInternship,
          style: ElevatedButton.styleFrom(backgroundColor: brandRed),
          child: Text('Post Internship', style: GoogleFonts.inter(color: Colors.white)),
        ),
        const SizedBox(height: 32),
        Text('Available Internships', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance.collection('internships').get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: brandRed));
            }
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}', style: GoogleFonts.inter(color: Colors.red));
            }
            final internships = snapshot.data!.docs;
            return Container(
              width: double.infinity,
              decoration: BoxDecoration(border: Border.all(color: borderSubtle)),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(softWhite),
                columns: [
                  DataColumn(label: Text('TITLE', style: GoogleFonts.inter(fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold, color: mutedText))),
                  DataColumn(label: Text('COMPANY', style: GoogleFonts.inter(fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold, color: mutedText))),
                  DataColumn(label: Text('STATUS', style: GoogleFonts.inter(fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold, color: mutedText))),
                ],
                rows: internships.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return DataRow(cells: [
                    DataCell(Text(data['title'] ?? '—', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold))),
                    DataCell(Text(data['company'] ?? '—', style: GoogleFonts.inter(fontSize: 10))),
                    DataCell(Text(data['status'] ?? '—', style: GoogleFonts.inter(fontSize: 10))),
                  ]);
                }).toList(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMetricsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Growth Metrics', style: GoogleFonts.cormorantGaramond(fontSize: 24)),
        const SizedBox(height: 32),
        Text('Engagement Rate: ${engagementRate.toStringAsFixed(1)}%', style: GoogleFonts.inter(fontSize: 18, color: Colors.green)),
        const SizedBox(height: 16),
        // Placeholder for more metrics/charts
        Text('More metrics coming soon...', style: GoogleFonts.inter(color: mutedText)),
      ],
    );
  }

  DataRow _buildDataRow(Map<String, dynamic> user) {
    return DataRow(cells: [
      DataCell(Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(user['name'] as String? ?? '—', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
          Text('Pending Review', style: GoogleFonts.inter(fontSize: 10, color: mutedText)),
        ],
      )),
      DataCell(Text(user['degree'] as String? ?? '—', style: GoogleFonts.inter(fontSize: 10))),
      DataCell(Text(user['submitted'] as String? ?? '—', style: GoogleFonts.inter(fontSize: 10, color: mutedText))),
      DataCell(Row(
        children: [
          TextButton(
            onPressed: () => _verifyUser(user['id'] as String, user),
            child: Text('VERIFY', style: GoogleFonts.inter(fontSize: 10, color: brandRed, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => _denyUser(user['id'] as String),
            child: Text('DENY', style: GoogleFonts.inter(fontSize: 10, color: mutedText)),
          ),
        ],
      )),
    ]);
  }

  Widget _buildActivityItem(String type, String title, String desc, String time, bool isUrgent) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 2,
            height: 40,
            color: isUrgent ? brandRed : borderSubtle,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type.toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 9, letterSpacing: 2, color: mutedText, fontWeight: FontWeight.bold),
                ),
                Text(desc, style: GoogleFonts.inter(fontSize: 12, color: darkText)),
                Text(time, style: GoogleFonts.inter(fontSize: 9, color: mutedText)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _SidebarItem({required String label, bool isActive = false, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: isActive ? brandRed : darkText,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}