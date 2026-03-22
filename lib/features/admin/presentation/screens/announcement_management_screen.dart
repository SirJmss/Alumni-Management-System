import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:alumni/core/constants/app_colors.dart';

class AnnouncementManagementScreen extends StatefulWidget {
  const AnnouncementManagementScreen({super.key});

  @override
  State<AnnouncementManagementScreen> createState() =>
      _AnnouncementManagementScreenState();
}

class _AnnouncementManagementScreenState
    extends State<AnnouncementManagementScreen> {
  String _filter = 'all';
  String _searchQuery = '';
String _adminName = 'Admin';

  @override
  void initState() {
    super.initState();
    _loadAdminName();
  }

  Future<void> _loadAdminName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _adminName = doc.data()?['name']?.toString() ??
              doc.data()?['fullName']?.toString() ??
              user.displayName ??
              'Admin';
        });
      }
    } catch (_) {}
  }

  Stream<QuerySnapshot> get _stream {
    Query query = FirebaseFirestore.instance
        .collection('announcements')
        .orderBy('createdAt', descending: true);
    if (_filter == 'published') {
      query =
          query.where('publishedAt', isNotEqualTo: null);
    } else if (_filter == 'draft') {
      query = query.where('publishedAt', isEqualTo: null);
    } else if (_filter == 'important') {
      query = query.where('important', isEqualTo: true);
    }
    return query.snapshots();
  }

  void _showSnackBar(String message,
      {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter()),
        backgroundColor:
            isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  Future<void> _togglePublish(
      String id, bool publish) async {
    final action = publish ? 'Publish' : 'Unpublish';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('$action Announcement',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700)),
        content: Text(
            'Are you sure you want to $action this announcement?',
            style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(
                    color: AppColors.mutedText)),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, true),
            child: Text(action,
                style: GoogleFonts.inter(
                    color: publish
                        ? Colors.green
                        : Colors.orange,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await FirebaseFirestore.instance
          .collection('announcements')
          .doc(id)
          .update({
        'publishedAt': publish
            ? FieldValue.serverTimestamp()
            : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _showSnackBar(
          publish
              ? 'Announcement published'
              : 'Moved to drafts',
          isError: false);
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  Future<void> _confirmDelete(
      String id, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Announcement',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: AppColors.brandRed)),
        content: Text(
            'Delete "$title" permanently? This cannot be undone.',
            style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(
                    color: AppColors.mutedText)),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, true),
            child: Text('Delete',
                style: GoogleFonts.inter(
                    color: AppColors.brandRed,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await FirebaseFirestore.instance
          .collection('announcements')
          .doc(id)
          .delete();
      _showSnackBar('Announcement deleted',
          isError: false);
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  void _showForm({
    String? id,
    Map<String, dynamic>? data,
  }) {
    final isEdit = id != null;
    final titleCtrl = TextEditingController(
        text: data?['title']?.toString() ?? '');
    final contentCtrl = TextEditingController(
        text: data?['content']?.toString() ?? '');
    bool isImportant =
        data?['important'] as bool? ?? false;
    bool isPublished = data?['publishedAt'] != null;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) =>
            DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.97,
          minChildSize: 0.5,
          builder: (_, controller) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                  top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(
                      vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderSubtle,
                    borderRadius:
                        BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        isEdit
                            ? 'Edit Announcement'
                            : 'New Announcement',
                        style:
                            GoogleFonts.cormorantGaramond(
                                fontSize: 22,
                                fontWeight:
                                    FontWeight.w600),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final title =
                                    titleCtrl.text
                                        .trim();
                                final content =
                                    contentCtrl.text
                                        .trim();
                                if (title.isEmpty) {
                                  _showSnackBar(
                                      'Title is required',
                                      isError: true);
                                  return;
                                }
                                if (content.isEmpty) {
                                  _showSnackBar(
                                      'Content is required',
                                      isError: true);
                                  return;
                                }
                                setSheet(() =>
                                    isSubmitting = true);
                                final payload =
                                    <String, dynamic>{
                                  'title': title,
                                  'content': content,
                                  'important':
                                      isImportant,
                                  'updatedAt': FieldValue
                                      .serverTimestamp(),
                                };
                                if (isEdit) {
                                  payload[
                                          'publishedAt'] =
                                      isPublished
                                          ? (data?[
                                                  'publishedAt'] ??
                                              FieldValue
                                                  .serverTimestamp())
                                          : null;
                                } else {
                                  payload.addAll({
                                    'createdAt': FieldValue
                                        .serverTimestamp(),
                                    'createdBy':
                                        FirebaseAuth
                                            .instance
                                            .currentUser
                                            ?.uid,
                                    'authorName':
                                        _adminName
                                                .isNotEmpty
                                            ? _adminName
                                            : 'Admin',
                                    'publishedAt': isPublished
                                        ? FieldValue
                                            .serverTimestamp()
                                        : null,
                                  });
                                }
                                try {
                                  if (isEdit) {
                                    await FirebaseFirestore
                                        .instance
                                        .collection(
                                            'announcements')
                                        .doc(id)
                                        .update(payload);
                                  } else {
                                    await FirebaseFirestore
                                        .instance
                                        .collection(
                                            'announcements')
                                        .add(payload);
                                  }
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                    _showSnackBar(
                                      isEdit
                                          ? 'Announcement updated!'
                                          : isPublished
                                              ? 'Announcement published!'
                                              : 'Draft saved!',
                                      isError: false,
                                    );
                                  }
                                } catch (e) {
                                  setSheet(() =>
                                      isSubmitting =
                                          false);
                                  if (ctx.mounted) {
                                    _showSnackBar(
                                        'Error: $e',
                                        isError: true);
                                  }
                                }
                              },
                        child: Text(
                          isSubmitting
                              ? 'Saving...'
                              : isEdit
                                  ? 'Save'
                                  : 'Post',
                          style: GoogleFonts.inter(
                            color: AppColors.brandRed,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    controller: controller,
                    padding: const EdgeInsets.all(20),
                    children: [
                      // ─── Title ───
                      TextFormField(
                        controller: titleCtrl,
                        style: GoogleFonts.inter(
                            fontSize: 15),
                        decoration: _inputDeco(
                            'Title',
                            'e.g. Enrollment Reminder for AY 2026'),
                      ),
                      const SizedBox(height: 16),

                      // ─── Content ───
                      TextFormField(
                        controller: contentCtrl,
                        maxLines: 8,
                        style: GoogleFonts.inter(
                            fontSize: 14),
                        decoration: _inputDeco(
                            'Content',
                            'Write your announcement here...',
                            alignHint: true),
                      ),
                      const SizedBox(height: 16),

                      // ─── Important toggle ───
                      _toggleTile(
                        icon: Icons.star_outline,
                        title: 'Mark as Important',
                        subtitle:
                            'Highlighted for all alumni',
                        value: isImportant,
                        onChanged: (v) => setSheet(
                            () => isImportant = v),
                      ),
                      const SizedBox(height: 10),

                      // ─── Published toggle ───
                      _toggleTile(
                        icon: Icons.public_outlined,
                        title: 'Publish Immediately',
                        subtitle:
                            'Visible to all alumni right away',
                        value: isPublished,
                        color: Colors.green,
                        onChanged: (v) => setSheet(
                            () => isPublished = v),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softWhite,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Sidebar ───
          Container(
            width: 280,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                  right: BorderSide(
                      color: AppColors.borderSubtle,
                      width: 0.5)),
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ALUMNI',
                        style:
                            GoogleFonts.cormorantGaramond(
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        _sidebarSection('NETWORK', [
                          _sidebarItem('Overview',
                              route: '/admin_dashboard'),
                          _sidebarItem(
                              'Chapter Management',
                              route:
                                  '/chapter_management'),
                        ]),
                        const SizedBox(height: 32),
                        _sidebarSection('ENGAGEMENT', [
                          _sidebarItem(
                              'Reunions & Events',
                              route: '/reunions_events'),
                          _sidebarItem(
                              'Career Milestones',
                              route: '/career_milestones'),
                        ]),
                        const SizedBox(height: 32),
                        _sidebarSection(
                            'ADMIN FEATURES', [
                          _sidebarItem(
                              'User Verification & Moderation',
                              route:
                                  '/user_verification_moderation'),
                          _sidebarItem('Event Planning',
                              route: '/event_planning'),
                          _sidebarItem(
                              'Job Board Management',
                              route:
                                  '/job_board_management'),
                          _sidebarItem('Growth Metrics',
                              route: '/growth_metrics'),
                          _sidebarItem(
                              'Announcement Management',
                              route:
                                  '/announcement_management',
                              isActive: true),
                        ]),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    border: Border(
                        top: BorderSide(
                            color: AppColors.borderSubtle
                                .withOpacity(0.3))),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor:
                                AppColors.brandRed,
                            child: Text(
                              _adminName.isNotEmpty
                                  ? _adminName[0]
                                      .toUpperCase()
                                  : 'A',
                              style: GoogleFonts
                                  .cormorantGaramond(
                                      color: Colors.white,
                                      fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                Text(
                                  _adminName.isNotEmpty
                                      ? _adminName
                                      : 'Admin',
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight:
                                          FontWeight.bold),
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow.ellipsis,
                                ),
                                Text('NETWORK OVERSEER',
                                    style: GoogleFonts.inter(
                                        fontSize: 9,
                                        color: AppColors
                                            .mutedText)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: () async {
                          await FirebaseAuth.instance
                              .signOut();
                          if (mounted) {
                            Navigator
                                .pushReplacementNamed(
                                    context, '/login');
                          }
                        },
                        child: Text(
                          'DISCONNECT',
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              letterSpacing: 2,
                              color: AppColors.mutedText,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ─── Main content ───
          Expanded(
            child: Column(
              children: [
                // ─── Top bar ───
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 16),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Announcement Management',
                            style: GoogleFonts
                                .cormorantGaramond(
                              fontSize: 32,
                              fontWeight: FontWeight.w400,
                              color: AppColors.darkText,
                            ),
                          ),
                          Text(
                            'Create, edit, publish and moderate alumni announcements.',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.mutedText),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showForm(),
                        icon: const Icon(Icons.add,
                            size: 18),
                        label: Text('New Announcement',
                            style: GoogleFonts.inter(
                                fontWeight:
                                    FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              AppColors.brandRed,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                      8)),
                        ),
                      ),
                    ],
                  ),
                ),

                // ─── Search + filter chips ───
                Container(
                  color: AppColors.cardWhite,
                  padding: const EdgeInsets.fromLTRB(
                      32, 12, 32, 12),
                  child: Column(
                    children: [
                      TextField(
                        style: GoogleFonts.inter(
                            fontSize: 14),
                        decoration: InputDecoration(
                          hintText:
                              'Search announcements...',
                          hintStyle: GoogleFonts.inter(
                              color: AppColors.mutedText,
                              fontSize: 13),
                          prefixIcon: const Icon(
                              Icons.search,
                              color: AppColors.mutedText,
                              size: 20),
                          filled: true,
                          fillColor: AppColors.softWhite,
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12),
                        ),
                        onChanged: (v) => setState(() =>
                            _searchQuery =
                                v.toLowerCase()),
                      ),
                      const SizedBox(height: 10),
                      Row(children: [
                        _filterChip('All', 'all'),
                        const SizedBox(width: 8),
                        _filterChip(
                            'Published', 'published'),
                        const SizedBox(width: 8),
                        _filterChip('Drafts', 'draft'),
                        const SizedBox(width: 8),
                        _filterChip(
                            'Important', 'important'),
                      ]),
                    ],
                  ),
                ),

                // ─── List ───
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _stream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                            child:
                                CircularProgressIndicator(
                                    color:
                                        AppColors.brandRed));
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                              'Error: ${snapshot.error}',
                              style: GoogleFonts.inter(
                                  color: Colors.red)),
                        );
                      }

                      var docs =
                          snapshot.data?.docs ?? [];

                      // ─── Client search ───
                      if (_searchQuery.isNotEmpty) {
                        docs = docs.where((d) {
                          final data = d.data()
                              as Map<String, dynamic>;
                          final title = data['title']
                                  ?.toString()
                                  .toLowerCase() ??
                              '';
                          final content = data['content']
                                  ?.toString()
                                  .toLowerCase() ??
                              '';
                          return title.contains(
                                  _searchQuery) ||
                              content
                                  .contains(_searchQuery);
                        }).toList();
                      }

                      if (docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              const Icon(
                                  Icons.campaign_outlined,
                                  size: 72,
                                  color: AppColors
                                      .borderSubtle),
                              const SizedBox(height: 16),
                              Text(
                                'No announcements found',
                                style: GoogleFonts
                                    .cormorantGaramond(
                                        fontSize: 22,
                                        color: AppColors
                                            .darkText),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _filter == 'all'
                                    ? 'Tap New Announcement to get started'
                                    : 'No announcements match this filter',
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color:
                                        AppColors.mutedText),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.all(32),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data()
                              as Map<String, dynamic>;
                          return _announcementCard(
                              doc.id, data);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _announcementCard(
      String id, Map<String, dynamic> data) {
    final title =
        data['title']?.toString() ?? 'Untitled';
    final content =
        data['content']?.toString() ?? '';
    final important =
        data['important'] as bool? ?? false;
    final publishedAt =
        (data['publishedAt'] as Timestamp?)?.toDate();
    final createdAt =
        (data['createdAt'] as Timestamp?)?.toDate();
    final updatedAt =
        (data['updatedAt'] as Timestamp?)?.toDate();
    final authorName =
        data['authorName']?.toString() ?? 'Admin';
    final isPublished = publishedAt != null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: important
              ? AppColors.brandRed.withOpacity(0.3)
              : AppColors.borderSubtle,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Top row ───
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: important
                      ? AppColors.brandRed
                          .withOpacity(0.08)
                      : AppColors.softWhite,
                  borderRadius:
                      BorderRadius.circular(10),
                ),
                child: Icon(
                  important
                      ? Icons.campaign
                      : Icons.campaign_outlined,
                  color: important
                      ? AppColors.brandRed
                      : AppColors.mutedText,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkText),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      'By $authorName${createdAt != null ? ' • ${DateFormat('MMM dd, yyyy').format(createdAt)}' : ''}',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.mutedText),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment:
                    CrossAxisAlignment.end,
                children: [
                  _badge(
                    isPublished ? 'PUBLISHED' : 'DRAFT',
                    isPublished
                        ? Colors.green
                        : AppColors.mutedText,
                  ),
                  if (important) ...[
                    const SizedBox(height: 4),
                    _badge('IMPORTANT',
                        AppColors.brandRed),
                  ],
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ─── Content preview ───
          Text(
            content,
            style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.mutedText,
                height: 1.5),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),

          if (updatedAt != null &&
              updatedAt.isAfter(
                  createdAt ?? DateTime(2000))) ...[
            const SizedBox(height: 6),
            Text(
              'Updated ${DateFormat('MMM dd, yyyy').format(updatedAt)}',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.mutedText,
                  fontStyle: FontStyle.italic),
            ),
          ],

          const SizedBox(height: 12),
          const Divider(color: AppColors.borderSubtle),
          const SizedBox(height: 4),

          // ─── Actions ───
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // ─── Publish / Unpublish ───
              _actionBtn(
                icon: isPublished
                    ? Icons.unpublished_outlined
                    : Icons.publish_outlined,
                label: isPublished
                    ? 'Unpublish'
                    : 'Publish',
                color: isPublished
                    ? Colors.orange
                    : Colors.green,
                onTap: () =>
                    _togglePublish(id, !isPublished),
              ),
              const SizedBox(width: 8),
              _actionBtn(
                icon: Icons.edit_outlined,
                label: 'Edit',
                color: AppColors.mutedText,
                onTap: () =>
                    _showForm(id: id, data: data),
              ),
              const SizedBox(width: 8),
              _actionBtn(
                icon: Icons.delete_outline,
                label: 'Delete',
                color: Colors.red,
                onTap: () =>
                    _confirmDelete(id, title),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w600)),
            ]),
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brandRed
              : AppColors.softWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.brandRed
                : AppColors.borderSubtle,
          ),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? Colors.white
                  : AppColors.mutedText,
            )),
      ),
    );
  }

  Widget _toggleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    Color? color,
  }) {
    final c = color ?? AppColors.brandRed;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.softWhite,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppColors.borderSubtle),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 4),
        secondary: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: c.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: c, size: 20),
        ),
        title: Text(title,
            style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle,
            style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.mutedText)),
        value: value,
        activeColor: c,
        onChanged: onChanged,
      ),
    );
  }

  InputDecoration _inputDeco(String label, String hint,
      {bool alignHint = false}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: alignHint,
      labelStyle: GoogleFonts.inter(
          color: AppColors.brandRed,
          fontWeight: FontWeight.w500),
      hintStyle: GoogleFonts.inter(
          color: AppColors.mutedText, fontSize: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: AppColors.borderSubtle),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: AppColors.borderSubtle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
            color: AppColors.brandRed, width: 1.5),
      ),
      filled: true,
      fillColor: AppColors.softWhite,
      contentPadding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 14),
    );
  }

  // ─── Sidebar helpers ───
  Widget _sidebarSection(
      String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: GoogleFonts.inter(
              fontSize: 10,
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
              color: AppColors.mutedText.withOpacity(0.7),
            )),
        const SizedBox(height: 16),
        ...items,
      ],
    );
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
                color: isActive
                    ? AppColors.brandRed
                    : AppColors.darkText,
                fontWeight: isActive
                    ? FontWeight.w600
                    : FontWeight.w400,
              )),
        ),
      ),
    );
  }
}