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
          // Sidebar
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
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alumni Chapters & Batches',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 44,
                        fontWeight: FontWeight.w300,
                        fontStyle: FontStyle.italic,
                        color: darkText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'REGIONAL & BATCH COORDINATION',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        letterSpacing: 2,
                        fontWeight: FontWeight.bold,
                        color: mutedText,
                      ),
                    ),
                    const SizedBox(height: 48),

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

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Registered Chapters & Batches',
                          style: GoogleFonts.cormorantGaramond(fontSize: 28),
                        ),
                        Row(
                          children: [
                            SizedBox(
                              width: 340,
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: 'Search by name, type, region, batch...',
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
                              label: const Text('CREATE CHAPTER'),
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
                            return Padding(
                              padding: const EdgeInsets.all(80),
                              child: Text('Error: ${snapshot.error}', style: GoogleFonts.inter(color: brandRed)),
                            );
                          }

                          final chapters = snapshot.data?.docs ?? [];
                          final filtered = chapters.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final name = (data['name'] as String?)?.toLowerCase() ?? '';
                            final type = (data['type'] as String?)?.toLowerCase() ?? '';
                            final region = (data['region'] as String?)?.toLowerCase() ?? '';
                            final batchYear = data['batchYear']?.toString() ?? '';
                            return name.contains(_searchQuery) ||
                                type.contains(_searchQuery) ||
                                region.contains(_searchQuery) ||
                                batchYear.contains(_searchQuery);
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
                              final chapterTypeRaw = (data['type'] as String?)?.toLowerCase() ?? 'unknown';
                              final typeDisplay = chapterTypeRaw.toUpperCase();
                              final batchYearRaw = data['batchYear'];
                              final batchYearStr = (batchYearRaw is num) ? batchYearRaw.toStringAsFixed(0) : null;
                              final region = (data['region'] as String?)?.trim() ?? (data['location'] as String?)?.trim() ?? '—';
                              final displayLocation = (chapterTypeRaw == 'batch' && batchYearStr != null && batchYearStr.isNotEmpty)
                                  ? '$batchYearStr Batch'
                                  : region;
                              final leadUid = data['presidentUid'] as String?;
                              final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

                              return FutureBuilder<int>(
                                future: _getMemberCount(doc.id),
                                builder: (context, countSnap) {
                                  final count = countSnap.data ?? 0;
                                  return FutureBuilder<String>(
                                    future: leadUid != null && leadUid.isNotEmpty ? _getUserName(leadUid) : Future.value('None'),
                                    builder: (context, leadSnap) {
                                      final leadName = leadSnap.data ?? 'None';

                                      return Container(
                                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                                        decoration: BoxDecoration(
                                          border: Border(bottom: BorderSide(color: borderSubtle)),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 5,
                                              child: Text(
                                                name,
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14.5),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                typeDisplay,
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                                style: GoogleFonts.inter(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                  color: brandRed,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                displayLocation,
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                                style: GoogleFonts.inter(fontSize: 13, color: mutedText),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                leadName,
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                                style: GoogleFonts.inter(fontSize: 13),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                '$count Alumni',
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                                style: GoogleFonts.inter(
                                                  fontSize: 13,
                                                  color: count > 0 ? Colors.green.shade700 : mutedText,
                                                  fontWeight: count > 0 ? FontWeight.w500 : FontWeight.normal,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                createdAt != null ? DateFormat('MMM dd, yyyy').format(createdAt) : '—',
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                                style: GoogleFonts.inter(fontSize: 13, color: mutedText),
                                              ),
                                            ),
                                            SizedBox(
                                              width: 100,
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
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Chapter Form
  // ──────────────────────────────────────────────

  void _showChapterForm({String? chapterId, Map<String, dynamic>? initialData}) {
    final isEdit = chapterId != null;

    String? selectedType = initialData?['type'] as String? ?? 'regional';
    final nameCtrl = TextEditingController(text: initialData?['name'] as String? ?? '');
    final descCtrl = TextEditingController(text: initialData?['description'] as String? ?? '');
    final regionCtrl = TextEditingController(text: initialData?['region'] as String? ?? '');
    final locationCtrl = TextEditingController(text: initialData?['location'] as String? ?? '');
    final batchYearCtrl = TextEditingController(text: (initialData?['batchYear'] as num?)?.toString() ?? '');
    final programCtrl = TextEditingController(text: initialData?['program'] as String? ?? '');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Chapter' : 'Create New Chapter'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'regional', child: Text('Regional / Geographic')),
                      DropdownMenuItem(value: 'batch', child: Text('Batch / Graduation Year')),
                      DropdownMenuItem(value: 'course', child: Text('Course / Program-Based')),
                      DropdownMenuItem(value: 'professional', child: Text('Professional / Career Field')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (value) => setDialogState(() => selectedType = value),
                    decoration: const InputDecoration(labelText: 'Chapter Type *', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Chapter Name *', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  if (selectedType == 'batch') ...[
                    TextField(
                      controller: batchYearCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Batch Year (e.g. 2018)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (selectedType == 'course') ...[
                    TextField(
                      controller: programCtrl,
                      decoration: const InputDecoration(labelText: 'Course / Program (e.g. BS Nursing)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: regionCtrl,
                    decoration: const InputDecoration(labelText: 'Region / Province', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: locationCtrl,
                    decoration: const InputDecoration(labelText: 'Specific Location (optional)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Description', alignLabelWithHint: true, border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: brandRed),
              onPressed: () async {
                final trimmedName = nameCtrl.text.trim();
                if (trimmedName.isEmpty || selectedType == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name and Type required')));
                  return;
                }

                int? batchYearValue;
                if (selectedType == 'batch') {
                  final yearText = batchYearCtrl.text.trim();
                  if (yearText.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Batch year required for batch chapters')));
                    return;
                  }
                  try {
                    batchYearValue = int.parse(yearText);
                  } catch (_) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid batch year')));
                    return;
                  }
                }

                final data = <String, dynamic>{
                  'name': trimmedName,
                  'type': selectedType,
                  'description': descCtrl.text.trim(),
                  'region': regionCtrl.text.trim(),
                  'location': locationCtrl.text.trim(),
                  'updatedAt': FieldValue.serverTimestamp(),
                };

                if (selectedType == 'batch' && batchYearValue != null) data['batchYear'] = batchYearValue;
                if (selectedType == 'course') {
                  final p = programCtrl.text.trim();
                  if (p.isNotEmpty) data['program'] = p;
                }

                if (!isEdit) {
                  data.addAll({
                    'createdAt': FieldValue.serverTimestamp(),
                    'createdBy': FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
                    'status': 'active',
                  });
                }

                try {
                  if (isEdit) {
                    await FirebaseFirestore.instance.collection('chapters').doc(chapterId).update(data);
                  } else {
                    await FirebaseFirestore.instance.collection('chapters').add(data);
                  }
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isEdit ? 'Updated' : 'Created'), backgroundColor: Colors.green),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                }
              },
              child: Text(isEdit ? 'Update' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Helper widgets
  // ──────────────────────────────────────────────

  Widget _buildSidebarSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold, color: mutedText.withOpacity(0.7)),
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
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: borderSubtle)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, letterSpacing: 1.5, color: mutedText, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: GoogleFonts.cormorantGaramond(fontSize: 42, fontWeight: FontWeight.w300, color: accentColor ?? darkText)),
          ),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: mutedText)),
        ],
      ),
    );
  }

  Future<int> _getMemberCount(String chapterId) async {
    try {
      final snap = await FirebaseFirestore.instance.collection('chapters').doc(chapterId).collection('members').count().get();
      return snap.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<String> _getUserName(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data();
      return data?['name'] ?? data?['fullName'] ?? data?['email']?.split('@')[0] ?? 'None';
    } catch (_) {
      return 'None';
    }
  }

  Future<void> _confirmDeleteChapter(String chapterId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chapter'),
        content: Text('Delete "$name" and all its members? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      final members = await FirebaseFirestore.instance.collection('chapters').doc(chapterId).collection('members').get();
      for (var doc in members.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(FirebaseFirestore.instance.collection('chapters').doc(chapterId));
      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chapter and members deleted'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting: $e'), backgroundColor: Colors.red),
      );
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
              style: FilledButton.styleFrom(backgroundColor: brandRed),
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
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(child: Text('No members yet'));
              }
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final memberDoc = docs[index];
                  final uid = memberDoc.id;
                  final memberData = memberDoc.data() as Map<String, dynamic>;
                  final isPresident = memberData['role'] == 'president';

                  return FutureBuilder<Map<String, dynamic>>(
                    future: _fetchUserDetails(uid),
                    builder: (context, userSnap) {
                      if (userSnap.connectionState == ConnectionState.waiting) {
                        return const ListTile(title: Text('Loading...'));
                      }
                      final user = userSnap.data ?? {'name': 'Unknown', 'email': '—'};
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isPresident ? brandRed : brandRed.withOpacity(0.15),
                          child: Text(
                            user['name']?[0] ?? '?',
                            style: TextStyle(color: isPresident ? Colors.white : brandRed),
                          ),
                        ),
                        title: Text(user['name'] ?? 'Unknown'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user['email'] ?? '—', style: const TextStyle(fontSize: 12)),
                            Text(
                              'Role: ${memberData['role'] ?? 'Member'}',
                              style: TextStyle(fontSize: 12, color: isPresident ? brandRed : null),
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
                                icon: Icon(Icons.star_border, color: brandRed),
                                tooltip: 'Promote to President',
                                onPressed: () => _setAsPresident(chapterId, uid, user['name'] ?? 'this member'),
                              ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                              tooltip: 'Remove member',
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

  Future<void> _setAsPresident(String chapterId, String uid, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set as President'),
        content: Text('Make $name the president? This replaces the current president.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final chapterRef = FirebaseFirestore.instance.collection('chapters').doc(chapterId);
      final chapter = await chapterRef.get();
      final current = chapter.data()?['presidentUid'] as String?;

      final batch = FirebaseFirestore.instance.batch();

      if (current != null && current != uid) {
        batch.update(
          FirebaseFirestore.instance.collection('chapters').doc(chapterId).collection('members').doc(current),
          {'role': 'member'},
        );
      }

      batch.update(
        FirebaseFirestore.instance.collection('chapters').doc(chapterId).collection('members').doc(uid),
        {'role': 'president'},
      );

      batch.update(chapterRef, {
        'presidentUid': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name is now president'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  void _showAddMemberDialog(String chapterId) {
    final searchCtrl = TextEditingController();
    List<Map<String, dynamic>> results = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Add Member to Chapter'),
          content: SizedBox(
            width: 500,
            height: 400,
            child: Column(
              children: [
                TextField(
                  controller: searchCtrl,
                  decoration: InputDecoration(
                    labelText: 'Search by name or email',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () async {
                        final q = searchCtrl.text.trim().toLowerCase();
                        if (q.isEmpty) return;

                        final nameQuery = await FirebaseFirestore.instance
                            .collection('users')
                            .where('name', isGreaterThanOrEqualTo: q)
                            .where('name', isLessThanOrEqualTo: '$q\uf8ff')
                            .limit(10)
                            .get();

                        final emailQuery = await FirebaseFirestore.instance
                            .collection('users')
                            .where('email', isGreaterThanOrEqualTo: q)
                            .where('email', isLessThanOrEqualTo: '$q\uf8ff')
                            .limit(10)
                            .get();

                        final combined = [...nameQuery.docs, ...emailQuery.docs]
                            .map((d) => {
                                  'uid': d.id,
                                  'name': d['name'] ?? d['fullName'] ?? 'Unknown',
                                  'email': d['email'] ?? '—',
                                })
                            .toSet()
                            .toList();

                        setStateDialog(() => results = combined);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: results.isEmpty
                      ? const Center(child: Text('Search for alumni'))
                      : ListView.builder(
                          itemCount: results.length,
                          itemBuilder: (context, i) {
                            final user = results[i];
                            return ListTile(
                              leading: CircleAvatar(child: Text(user['name']?[0] ?? '?')),
                              title: Text(user['name']),
                              subtitle: Text(user['email']),
                              trailing: IconButton(
                                icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                                onPressed: () => _addMemberToChapter(chapterId, user['uid'], user['name']),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
        ),
      ),
    );
  }

  Future<void> _addMemberToChapter(String chapterId, String uid, String name) async {
    try {
      final ref = FirebaseFirestore.instance.collection('chapters').doc(chapterId).collection('members').doc(uid);
      final exists = await ref.get();
      if (exists.exists) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name is already a member')));
        return;
      }

      await ref.set({
        'joinedAt': FieldValue.serverTimestamp(),
        'role': 'member',
        'status': 'active',
        'addedBy': FirebaseAuth.instance.currentUser?.uid,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name added'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<Map<String, dynamic>> _fetchUserDetails(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data() ?? {};
      return {
        'name': data['name'] ?? data['fullName'] ?? data['email']?.split('@')[0] ?? 'Unknown',
        'email': data['email'] ?? '—',
      };
    } catch (_) {
      return {'name': 'Unknown', 'email': 'Error'};
    }
  }

  Future<void> _removeMember(String chapterId, String uid, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Remove $name from this chapter?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance.collection('chapters').doc(chapterId).collection('members').doc(uid).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name removed'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }
}