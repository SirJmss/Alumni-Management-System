import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class ChapterManagementScreen extends StatefulWidget {
  const ChapterManagementScreen({super.key});

  @override
  State<ChapterManagementScreen> createState() => _ChapterManagementScreenState();
}

class _ChapterManagementScreenState extends State<ChapterManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Design system — matching your admin dashboard style
  static const Color brandRed = Color(0xFF991B1B);
  static const Color softWhite = Color(0xFFFDFDFD);
  static const Color darkText = Color(0xFF111827);
  static const Color mutedText = Color(0xFF6B7280);
  static const Color borderSubtle = Color(0xFFE5E7EB);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });

    // Optional: run once on init to help debug field names
    _debugFirestoreFields();
  }

  Future<void> _debugFirestoreFields() async {
    // Events debug
    try {
      final eventsSnap = await FirebaseFirestore.instance.collection('events').limit(5).get();
      debugPrint('=== EVENTS DEBUG ===');
      for (var doc in eventsSnap.docs) {
        debugPrint('Event ${doc.id}: status=${doc['status']}, date=${doc['date']}, title=${doc['title']}');
      }
    } catch (e) {
      debugPrint('Events debug error: $e');
    }

    // Users debug
    try {
      final usersSnap = await FirebaseFirestore.instance.collection('users').limit(5).get();
      debugPrint('=== USERS DEBUG ===');
      for (var doc in usersSnap.docs) {
        debugPrint('User ${doc.id}: status=${doc['status']}, name=${doc['name']}, fullName=${doc['fullName']}');
      }
    } catch (e) {
      debugPrint('Users debug error: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final horizontalPadding = (size.width * 0.04).clamp(32.0, 80.0);
    final verticalPadding = (size.height * 0.025).clamp(40.0, 72.0);

    return Scaffold(
      backgroundColor: softWhite,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sidebar – now clickable
          Container(
            width: size.width < 1100 ? 260.0 : 300.0,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: borderSubtle, width: 0.5)),
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
                          _SidebarItem(label: 'Overview', route: '/admin_dashboard'),
                          _SidebarItem(label: 'Chapter Management', isActive: true, route: '/chapter_management'),
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
                          _SidebarItem(label: 'Announcement Management', route: '/announcement_management'),
                        ]),
                      ],
                    ),
                  ),
                ),
                Container(
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
                ),
              ],
            ),
          ),
          // Main content
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chapter Oversight.',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 44,
                        fontWeight: FontWeight.w300,
                        fontStyle: FontStyle.italic,
                        color: darkText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'COORDINATION HUB',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        letterSpacing: 2,
                        fontWeight: FontWeight.bold,
                        color: mutedText,
                      ),
                    ),
                    const SizedBox(height: 48),
                    // Stats
                    LayoutBuilder(
                      builder: (context, constraints) {
                        int count = 4;
                        if (constraints.maxWidth < 1200) count = 2;
                        if (constraints.maxWidth < 700) count = 1;
                        return GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: count,
                          crossAxisSpacing: 24,
                          mainAxisSpacing: 24,
                          childAspectRatio: count >= 3 ? 1.8 : 2.1,
                          children: [
                            _StatCard('ACTIVE HUBS', '24', 'Global'),
                            _StatCard('ENGAGEMENT', '78%', 'Avg. Activity', Colors.green),
                            _StatCard('MENTORS', '142', 'Chapter-led'),
                            _StatCard('ATTENDANCE', '4.2k', 'YTD Events'),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 56),
                    // Chapter Registry section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Chapter Registry',
                          style: GoogleFonts.cormorantGaramond(fontSize: 28),
                        ),
                        Row(
                          children: [
                            SizedBox(
                              width: 340,
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: 'Search chapters…',
                                  hintStyle: GoogleFonts.inter(color: mutedText, fontSize: 13),
                                  prefixIcon: Icon(Icons.search, color: mutedText, size: 20),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderSide: BorderSide(color: borderSubtle),
                                    borderRadius: BorderRadius.circular(0),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                ),
                              ),
                            ),
                            const SizedBox(width: 24),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('ESTABLISH NEW'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: brandRed,
                                side: const BorderSide(color: brandRed),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                shape: const RoundedRectangleBorder(),
                              ),
                              onPressed: () => _showChapterForm(),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Container(
                      decoration: BoxDecoration(border: Border.all(color: borderSubtle)),
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('chapters')
                            .orderBy('createdAt', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.all(80),
                              child: Center(child: CircularProgressIndicator(color: brandRed)),
                            );
                          }
                          if (snapshot.hasError) {
                            debugPrint('Chapters stream error: ${snapshot.error}');
                            return Padding(
                              padding: const EdgeInsets.all(80),
                              child: Text('Error loading chapters: ${snapshot.error}', style: GoogleFonts.inter(color: brandRed)),
                            );
                          }
                          final chapters = snapshot.data?.docs ?? [];
                          final filtered = chapters.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final name = (data['name'] as String?)?.toLowerCase() ?? '';
                            return name.contains(_searchQuery);
                          }).toList();
                          if (filtered.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.all(80),
                              child: Text('No chapters found', style: GoogleFonts.inter(fontSize: 15, color: mutedText)),
                            );
                          }
                          return Column(
                            children: filtered.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final name = data['name'] ?? 'Unnamed Chapter';
                              final region = data['region'] ?? data['location'] ?? 'N/A';
                              final leadUid = data['presidentUid'] as String?;
                              final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                              return FutureBuilder<int>(
                                future: _getMemberCount(doc.id),
                                builder: (context, countSnap) {
                                  final count = countSnap.data ?? 0;
                                  return FutureBuilder<String>(
                                    future: leadUid != null && leadUid.isNotEmpty
                                        ? _getUserName(leadUid)
                                        : Future.value('None'),
                                    builder: (context, leadSnap) {
                                      final leadName = leadSnap.data ?? 'None';
                                      return Container(
                                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                                        decoration: BoxDecoration(
                                          border: Border(bottom: BorderSide(color: borderSubtle)),
                                        ),
                                        child: IntrinsicHeight(
                                          child: Row(
                                            children: [
                                              Expanded(
                                                flex: 4,
                                                child: Padding(
                                                  padding: const EdgeInsets.only(right: 8.0),
                                                  child: Text(
                                                    name,
                                                    overflow: TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                    softWrap: false,
                                                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14.5),
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Padding(
                                                  padding: const EdgeInsets.only(right: 8.0),
                                                  child: Text(
                                                    region,
                                                    overflow: TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                    softWrap: false,
                                                    style: GoogleFonts.inter(fontSize: 13, color: mutedText),
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Padding(
                                                  padding: const EdgeInsets.only(right: 8.0),
                                                  child: Text(
                                                    leadName,
                                                    overflow: TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                    softWrap: false,
                                                    style: GoogleFonts.inter(fontSize: 13),
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Padding(
                                                  padding: const EdgeInsets.only(right: 8.0),
                                                  child: Text(
                                                    '$count Alumni',
                                                    overflow: TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                    softWrap: false,
                                                    style: GoogleFonts.inter(
                                                      fontSize: 13,
                                                      color: count > 0 ? Colors.green.shade700 : mutedText,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Padding(
                                                  padding: const EdgeInsets.only(right: 8.0),
                                                  child: Text(
                                                    createdAt != null ? DateFormat('MMM dd, yyyy').format(createdAt) : 'N/A',
                                                    overflow: TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                    softWrap: false,
                                                    style: GoogleFonts.inter(fontSize: 13, color: mutedText),
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.end,
                                                  children: [
                                                    IconButton(
                                                      icon: Icon(Icons.edit_outlined, color: mutedText, size: 20),
                                                      onPressed: () => _showChapterForm(chapterId: doc.id, initialData: data),
                                                    ),
                                                    IconButton(
                                                      icon: Icon(Icons.delete_outline, color: mutedText, size: 20),
                                                      onPressed: () => _confirmDeleteChapter(doc.id, name),
                                                    ),
                                                    IconButton(
                                                      icon: Icon(Icons.group_outlined, color: mutedText, size: 20),
                                                      onPressed: () => _showMembersDialog(doc.id, name),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Right sidebar – now dynamic
          Container(
            width: 380,
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(40, 56, 40, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Reunions / Events – approved only
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Reunions & Events',
                      style: GoogleFonts.cormorantGaramond(fontSize: 26),
                    ),
                    Text(
                      'VIEW ALL',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: brandRed,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('events')
                      // .where('status', isEqualTo: 'approved')  // commented – adjust after checking real value
                      .orderBy('createdAt', descending: true) // fallback
                      .limit(8)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: brandRed));
                    }
                    if (snapshot.hasError) {
                      debugPrint('Events stream error: ${snapshot.error}');
                      return Text('Error loading events: ${snapshot.error}', style: GoogleFonts.inter(color: Colors.red));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Text('No events found\n(check console for debug info)', style: GoogleFonts.inter(color: mutedText));
                    }
                    final events = snapshot.data!.docs;
                    return Column(
                      children: events.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final title = data['title'] ?? 'Untitled Event';
                        final location = data['location'] ?? '';
                        final dateField = data['date'] ?? data['createdAt'] ?? data['eventDate'];
                        final dateStr = dateField is Timestamp
                            ? DateFormat('MMM d').format(dateField.toDate())
                            : '—';
                        final status = (data['status'] as String?)?.toLowerCase() ?? 'unknown';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14.5)),
                                    if (location.isNotEmpty)
                                      Text(location, style: GoogleFonts.inter(fontSize: 13, color: mutedText)),
                                    Text('Status: $status', style: GoogleFonts.inter(fontSize: 11, color: mutedText)),
                                  ],
                                ),
                              ),
                              Text(dateStr, style: GoogleFonts.inter(fontSize: 13, color: mutedText)),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 64),
                // Mentorship Matches – all verified users
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Verified Mentor',
                      style: GoogleFonts.cormorantGaramond(fontSize: 26),
                    ),
                    Text(
                      'MATCH NEW PAIR',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: brandRed,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      // .where('status', isEqualTo: 'verified')  // commented – adjust after debug
                      .orderBy('createdAt', descending: true) // fallback
                      .limit(12)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: brandRed));
                    }
                    if (snapshot.hasError) {
                      debugPrint('Users stream error: ${snapshot.error}');
                      return Text('Error loading users: ${snapshot.error}', style: GoogleFonts.inter(color: Colors.red));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Text('No users found\n(check console for debug info)', style: GoogleFonts.inter(color: mutedText));
                    }
                    final users = snapshot.data!.docs;
                    return Column(
                      children: users.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final name = data['name'] ?? data['fullName'] ?? 'Unknown';
                        final role = data['role'] ?? data['position'] ?? 'Alumni';
                        final statusRaw = data['status'] ?? 'unknown';
                        final status = (statusRaw is String) ? statusRaw.toLowerCase() : 'unknown';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14.5)),
                                    Text(role, style: GoogleFonts.inter(fontSize: 13, color: mutedText)),
                                    Text('Status: $status', style: GoogleFonts.inter(fontSize: 11, color: mutedText)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: status.contains('verified') || status.contains('active')
                                      ? Colors.green.withOpacity(0.08)
                                      : Colors.blue.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: status.contains('verified') || status.contains('active')
                                        ? Colors.green.shade700
                                        : Colors.blue.shade700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
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

  Widget _SidebarItem({required String label, bool isActive = false, String? route}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: route != null
            ? () {
                Navigator.pushNamed(context, route);
              }
            : null,
        child: MouseRegion(
          cursor: route != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              color: isActive ? brandRed : darkText,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _StatCard(String title, String value, String subtitle, [Color? accentColor]) {
    return Container(
      padding: const EdgeInsets.all(28),
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
            style: GoogleFonts.inter(
              fontSize: 10,
              letterSpacing: 1.5,
              color: mutedText,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 42,
                fontWeight: FontWeight.w300,
                color: accentColor ?? darkText,
              ),
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 11, color: mutedText),
          ),
        ],
      ),
    );
  }

  Future<int> _getMemberCount(String chapterId) async {
    try {
      final countSnap = await FirebaseFirestore.instance
          .collection('chapters')
          .doc(chapterId)
          .collection('members')
          .count()
          .get();
      return countSnap.count ?? 0;
    } catch (e) {
      debugPrint('Member count error: $e');
      return 0;
    }
  }

  Future<String> _getUserName(String uid) async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = userDoc.data();
      return data?['name'] ?? data?['fullName'] ?? data?['email']?.split('@')[0] ?? 'None';
    } catch (e) {
      return 'None';
    }
  }

  void _showChapterForm({String? chapterId, Map<String, dynamic>? initialData}) {
    final isEdit = chapterId != null;
    final nameCtrl = TextEditingController(text: initialData?['name'] ?? '');
    final descCtrl = TextEditingController(text: initialData?['description'] ?? '');
    final locationCtrl = TextEditingController(text: initialData?['location'] ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Edit Chapter' : 'Create New Chapter'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Chapter Name *')),
                const SizedBox(height: 16),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description', alignLabelWithHint: true),
                ),
                const SizedBox(height: 16),
                TextField(controller: locationCtrl, decoration: const InputDecoration(labelText: 'Location (City/Province)')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE64646)),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Chapter name is required')),
                );
                return;
              }
              final data = {
                'name': nameCtrl.text.trim(),
                'description': descCtrl.text.trim(),
                'location': locationCtrl.text.trim(),
                'updatedAt': FieldValue.serverTimestamp(),
                if (!isEdit) ...{
                  'createdAt': FieldValue.serverTimestamp(),
                  'createdBy': FirebaseAuth.instance.currentUser?.uid,
                },
              };
              try {
                if (isEdit) {
                  await FirebaseFirestore.instance.collection('chapters').doc(chapterId).update(data);
                } else {
                  await FirebaseFirestore.instance.collection('chapters').add(data);
                }
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isEdit ? 'Chapter updated' : 'Chapter created'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: Text(isEdit ? 'Update' : 'Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteChapter(String chapterId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chapter'),
        content: Text('Are you sure you want to delete "$name"?\nThis will also delete all member associations.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('chapters').doc(chapterId).delete();
        final membersSnap = await FirebaseFirestore.instance
            .collection('chapters')
            .doc(chapterId)
            .collection('members')
            .get();
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in membersSnap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chapter and members deleted'), backgroundColor: Colors.green),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showMembersDialog(String chapterId, String chapterName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text('$chapterName Members')),
            FilledButton.icon(
              icon: const Icon(Icons.person_add, size: 18),
              label: const Text('Add Member'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE64646),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onPressed: () => _showAddMemberDialog(chapterId),
            ),
          ],
        ),
        content: SizedBox(
          width: 600,
          height: 500,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('chapters')
                .doc(chapterId)
                .collection('members')
                .orderBy('joinedAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              final memberDocs = snapshot.data?.docs ?? [];
              if (memberDocs.isEmpty) {
                return const Center(child: Text('No members in this chapter yet'));
              }
              return ListView.builder(
                itemCount: memberDocs.length,
                itemBuilder: (context, index) {
                  final memberDoc = memberDocs[index];
                  final memberData = memberDoc.data() as Map<String, dynamic>;
                  final uid = memberDoc.id;
                  return FutureBuilder<Map<String, dynamic>>(
                    future: _fetchUserDetails(uid),
                    builder: (context, userSnap) {
                      if (userSnap.connectionState == ConnectionState.waiting) {
                        return const ListTile(title: Text('Loading...'));
                      }
                      final user = userSnap.data ?? {'name': 'Unknown', 'email': 'No email'};
                      final isPresident = memberData['role'] == 'president';
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isPresident ? brandRed : brandRed.withOpacity(0.1),
                          child: Text(
                            user['name']?[0] ?? '?',
                            style: TextStyle(color: isPresident ? Colors.white : brandRed),
                          ),
                        ),
                        title: Text(user['name'] ?? 'Unknown'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user['email'] ?? 'No email', style: const TextStyle(fontSize: 12)),
                            Text(
                              'Role: ${memberData['role'] ?? 'Member'}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isPresident ? brandRed : null,
                              ),
                            ),
                            if (memberData['joinedAt'] != null)
                              Text(
                                'Joined ${DateFormat('MMM dd, yyyy').format((memberData['joinedAt'] as Timestamp).toDate())}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isPresident)
                              IconButton(
                                icon: Icon(Icons.star_border, color: brandRed, size: 22),
                                tooltip: 'Set as President',
                                onPressed: () => _setAsPresident(chapterId, uid, user['name'] ?? 'this member'),
                              ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                              tooltip: 'Remove from chapter',
                              onPressed: () => _removeMember(chapterId, uid, user['name'] ?? 'this member'),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _setAsPresident(String chapterId, String userUid, String userName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set as President'),
        content: Text('Make $userName the president of this chapter?\nThis will replace the current president if any.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Set President'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final chapterRef = FirebaseFirestore.instance.collection('chapters').doc(chapterId);
      final chapterDoc = await chapterRef.get();
      final currentPresidentUid = chapterDoc.data()?['presidentUid'] as String?;
      if (currentPresidentUid != null &&
          currentPresidentUid != userUid &&
          currentPresidentUid.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('chapters')
            .doc(chapterId)
            .collection('members')
            .doc(currentPresidentUid)
            .update({'role': 'member'});
      }
      await FirebaseFirestore.instance
          .collection('chapters')
          .doc(chapterId)
          .collection('members')
          .doc(userUid)
          .update({'role': 'president'});
      await chapterRef.update({
        'presidentUid': userUid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$userName is now the president'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error setting president: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showAddMemberDialog(String chapterId) {
    final searchCtrl = TextEditingController();
    List<Map<String, dynamic>> searchResults = [];
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Member to Chapter'),
          content: SizedBox(
            width: 500,
            height: 400,
            child: Column(
              children: [
                TextField(
                  controller: searchCtrl,
                  decoration: InputDecoration(
                    labelText: 'Search alumni by name or email',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () async {
                        if (searchCtrl.text.trim().isEmpty) return;
                        final query = searchCtrl.text.trim().toLowerCase();
                        final nameSnap = await FirebaseFirestore.instance
                            .collection('users')
                            .where('name', isGreaterThanOrEqualTo: query)
                            .where('name', isLessThanOrEqualTo: '$query\uf8ff')
                            .limit(10)
                            .get();
                        final emailSnap = await FirebaseFirestore.instance
                            .collection('users')
                            .where('email', isGreaterThanOrEqualTo: query)
                            .where('email', isLessThanOrEqualTo: '$query\uf8ff')
                            .limit(10)
                            .get();
                        final results = [...nameSnap.docs, ...emailSnap.docs]
                            .map((doc) => {
                                  'uid': doc.id,
                                  'name': doc['name'] ?? doc['fullName'] ?? 'Unknown',
                                  'email': doc['email'] ?? 'No email',
                                })
                            .toSet()
                            .toList();
                        setDialogState(() => searchResults = results);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: searchResults.isEmpty
                      ? const Center(child: Text('Search for alumni to add'))
                      : ListView.builder(
                          itemCount: searchResults.length,
                          itemBuilder: (context, index) {
                            final user = searchResults[index];
                            return ListTile(
                              leading: CircleAvatar(child: Text(user['name']?[0] ?? '?')),
                              title: Text(user['name']),
                              subtitle: Text(user['email']),
                              trailing: IconButton(
                                icon: const Icon(Icons.add_circle_outline, color: Color(0xFF4CAF50)),
                                onPressed: () => _addMemberToChapter(chapterId, user['uid'], user['name']),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        ),
      ),
    );
  }

  Future<void> _addMemberToChapter(String chapterId, String userUid, String userName) async {
    try {
      final memberRef = FirebaseFirestore.instance
          .collection('chapters')
          .doc(chapterId)
          .collection('members')
          .doc(userUid);
      final existing = await memberRef.get();
      if (existing.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$userName is already a member')),
        );
        return;
      }
      await memberRef.set({
        'joinedAt': FieldValue.serverTimestamp(),
        'role': 'member',
        'status': 'active',
        'addedBy': FirebaseAuth.instance.currentUser?.uid,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$userName added to chapter'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding member: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<Map<String, dynamic>> _fetchUserDetails(String uid) async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = userDoc.data() ?? {};
      return {
        'name': data['name'] ?? data['fullName'] ?? data['email']?.split('@')[0] ?? 'Unknown',
        'email': data['email'] ?? 'No email',
      };
    } catch (e) {
      return {'name': 'Unknown', 'email': 'Error loading'};
    }
  }

  Future<void> _removeMember(String chapterId, String userUid, String memberName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Remove $memberName from this chapter?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await FirebaseFirestore.instance
          .collection('chapters')
          .doc(chapterId)
          .collection('members')
          .doc(userUid)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$memberName removed from chapter'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
}