import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:alumni/core/constants/app_colors.dart';
import 'package:alumni/features/notification/notification_service.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() =>
      _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  String? _userRole;
  String? _currentUid;
  String _filter = 'all'; // all, important

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _userRole = doc.data()?['role'] as String? ?? 'alumni';
          _currentUid = user.uid;
        });
      }
    } catch (_) {}
  }

  bool get _canPost =>
      _userRole == 'admin' ||
      _userRole == 'registrar' ||
      _userRole == 'staff' ||
      _userRole == 'moderator';

  Future<void> _deleteAnnouncement(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Announcement',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text(
            'This announcement will be permanently deleted.',
            style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(
                    color: AppColors.mutedText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete',
                style: GoogleFonts.inter(
                    color: AppColors.brandRed,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await FirebaseFirestore.instance
        .collection('announcements')
        .doc(docId)
        .delete();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Announcement deleted'),
            backgroundColor: Colors.grey),
      );
    }
  }

  void _showAddEditSheet({
    String? docId,
    String? existingTitle,
    String? existingContent,
    bool existingImportant = false,
  }) {
    final titleController =
        TextEditingController(text: existingTitle ?? '');
    final contentController =
        TextEditingController(text: existingContent ?? '');
    bool isImportant = existingImportant;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (_, controller) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // ─── Handle ───
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderSubtle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // ─── Header ───
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        docId == null
                            ? 'New Announcement'
                            : 'Edit Announcement',
                        style: GoogleFonts.cormorantGaramond(
                            fontSize: 22,
                            fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (titleController.text
                                    .trim()
                                    .isEmpty) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('Title is required')),
                                  );
                                  return;
                                }
                                if (contentController.text
                                    .trim()
                                    .isEmpty) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Content is required')),
                                  );
                                  return;
                                }

                                setSheetState(
                                    () => isSubmitting = true);

                                try {
                                  if (docId == null) {
                                    // ─── Create ───
                                    final ref =
                                        await FirebaseFirestore
                                            .instance
                                            .collection(
                                                'announcements')
                                            .add({
                                      'title': titleController.text
                                          .trim(),
                                      'content': contentController
                                          .text
                                          .trim(),
                                      'important': isImportant,
                                      'publishedAt': FieldValue
                                          .serverTimestamp(),
                                      'createdBy': _currentUid,
                                      'createdByRole': _userRole,
                                    });

                                    // ─── Notify all ───
                                    await NotificationService
                                        .sendAnnouncementNotificationToAll(
                                      announcementTitle:
                                          titleController.text
                                              .trim(),
                                      announcementId: ref.id,
                                    );
                                  } else {
                                    // ─── Update ───
                                    await FirebaseFirestore.instance
                                        .collection('announcements')
                                        .doc(docId)
                                        .update({
                                      'title': titleController.text
                                          .trim(),
                                      'content': contentController
                                          .text
                                          .trim(),
                                      'important': isImportant,
                                      'updatedAt': FieldValue
                                          .serverTimestamp(),
                                    });
                                  }

                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text(docId == null
                                            ? 'Announcement posted!'
                                            : 'Announcement updated!'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setSheetState(
                                      () => isSubmitting = false);
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      SnackBar(
                                          content: Text('Error: $e'),
                                          backgroundColor:
                                              Colors.red),
                                    );
                                  }
                                }
                              },
                        child: Text(
                          isSubmitting
                              ? 'Saving...'
                              : docId == null
                                  ? 'Publish'
                                  : 'Update',
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
                      TextField(
                        controller: titleController,
                        style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          labelText: 'Title',
                          labelStyle: GoogleFonts.inter(
                              color: AppColors.brandRed,
                              fontWeight: FontWeight.w500),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AppColors.borderSubtle),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AppColors.borderSubtle),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AppColors.brandRed,
                                width: 1.5),
                          ),
                          filled: true,
                          fillColor: AppColors.softWhite,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ─── Content ───
                      TextField(
                        controller: contentController,
                        maxLines: 10,
                        style: GoogleFonts.inter(fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'Content',
                          alignLabelWithHint: true,
                          labelStyle: GoogleFonts.inter(
                              color: AppColors.brandRed,
                              fontWeight: FontWeight.w500),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AppColors.borderSubtle),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AppColors.borderSubtle),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AppColors.brandRed,
                                width: 1.5),
                          ),
                          filled: true,
                          fillColor: AppColors.softWhite,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ─── Important toggle ───
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.softWhite,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.borderSubtle),
                        ),
                        child: SwitchListTile(
                          secondary: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.brandRed
                                  .withOpacity(0.08),
                              borderRadius:
                                  BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.star_outline,
                                color: AppColors.brandRed,
                                size: 20),
                          ),
                          title: Text('Mark as Important',
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500)),
                          subtitle: Text(
                              'Highlighted for all alumni',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.mutedText)),
                          value: isImportant,
                          activeColor: AppColors.brandRed,
                          onChanged: (v) =>
                              setSheetState(() => isImportant = v),
                        ),
                      ),
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

  void _showDetail(Map<String, dynamic> data, String docId) {
    final title = data['title']?.toString() ?? '';
    final content = data['content']?.toString() ?? '';
    final important = data['important'] as bool? ?? false;
    final publishedAt = data['publishedAt'] as Timestamp?;
    final updatedAt = data['updatedAt'] as Timestamp?;
    final dateStr = publishedAt != null
        ? DateFormat('EEEE, MMMM dd yyyy • hh:mm a')
            .format(publishedAt.toDate())
        : 'Date not available';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (important)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.brandRed,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('IMPORTANT',
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1)),
                ),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                  children: [
                    Text(title,
                        style: GoogleFonts.cormorantGaramond(
                            fontSize: 26,
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkText)),
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.access_time,
                          size: 14, color: AppColors.mutedText),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(dateStr,
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.mutedText)),
                      ),
                    ]),
                    if (updatedAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Updated ${DateFormat('MMM dd yyyy').format(updatedAt.toDate())}',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.mutedText,
                            fontStyle: FontStyle.italic),
                      ),
                    ],
                    const SizedBox(height: 20),
                    const Divider(color: AppColors.borderSubtle),
                    const SizedBox(height: 20),
                    Text(content,
                        style: GoogleFonts.inter(
                            fontSize: 15,
                            height: 1.7,
                            color: AppColors.darkText)),
                    if (_canPost) ...[
                      const SizedBox(height: 32),
                      const Divider(color: AppColors.borderSubtle),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _showAddEditSheet(
                                docId: docId,
                                existingTitle: title,
                                existingContent: content,
                                existingImportant: important,
                              );
                            },
                            icon: const Icon(Icons.edit_outlined,
                                size: 16),
                            label: Text('Edit',
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.brandRed,
                              side: const BorderSide(
                                  color: AppColors.brandRed),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _deleteAnnouncement(docId);
                            },
                            icon: const Icon(Icons.delete_outline,
                                size: 16),
                            label: Text('Delete',
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(
                                  color: Colors.red),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ]),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softWhite,
      appBar: AppBar(
        backgroundColor: AppColors.cardWhite,
        elevation: 0,
        iconTheme:
            const IconThemeData(color: AppColors.darkText),
        title: Text('Announcements',
            style: GoogleFonts.cormorantGaramond(fontSize: 26)),
        centerTitle: true,
        actions: [
          if (_canPost)
            IconButton(
              icon: const Icon(Icons.add,
                  color: AppColors.brandRed),
              tooltip: 'Post Announcement',
              onPressed: () => _showAddEditSheet(),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _filterChip('All', 'all'),
                const SizedBox(width: 8),
                _filterChip('Important', 'important'),
              ],
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('announcements')
            .orderBy('publishedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(
                    color: AppColors.brandRed));
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}',
                  style: GoogleFonts.inter(color: Colors.red)),
            );
          }

          if (!snapshot.hasData ||
              snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.campaign_outlined,
                      size: 72, color: AppColors.borderSubtle),
                  const SizedBox(height: 16),
                  Text('No announcements yet',
                      style: GoogleFonts.cormorantGaramond(
                          fontSize: 24,
                          color: AppColors.darkText)),
                  const SizedBox(height: 8),
                  Text(
                    _canPost
                        ? 'Tap + to post the first announcement'
                        : 'Check back later for updates',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.mutedText),
                  ),
                ],
              ),
            );
          }

          var docs = snapshot.data!.docs;

          // ─── Filter ───
          if (_filter == 'important') {
            docs = docs.where((d) {
              final data = d.data() as Map<String, dynamic>;
              return data['important'] == true;
            }).toList();
          }

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star_border,
                      size: 64, color: AppColors.borderSubtle),
                  const SizedBox(height: 16),
                  Text('No important announcements',
                      style: GoogleFonts.cormorantGaramond(
                          fontSize: 22,
                          color: AppColors.darkText)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final title =
                  data['title']?.toString() ?? 'Announcement';
              final content =
                  data['content']?.toString() ?? '';
              final publishedAt =
                  data['publishedAt'] as Timestamp?;
              final important =
                  data['important'] as bool? ?? false;
              final dateStr = publishedAt != null
                  ? DateFormat('MMM dd, yyyy')
                      .format(publishedAt.toDate())
                  : '';

              return GestureDetector(
                onTap: () => _showDetail(data, doc.id),
                child: Container(
                  padding: const EdgeInsets.all(18),
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
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        if (important) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.brandRed,
                              borderRadius:
                                  BorderRadius.circular(6),
                            ),
                            child: Text('IMPORTANT',
                                style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5)),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            dateStr,
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.mutedText),
                          ),
                        ),
                        if (_canPost)
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert,
                                color: AppColors.mutedText,
                                size: 18),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12)),
                            onSelected: (val) {
                              if (val == 'edit') {
                                _showAddEditSheet(
                                  docId: doc.id,
                                  existingTitle: title,
                                  existingContent: content,
                                  existingImportant: important,
                                );
                              } else if (val == 'delete') {
                                _deleteAnnouncement(doc.id);
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(children: [
                                  const Icon(Icons.edit_outlined,
                                      size: 16,
                                      color: AppColors.brandRed),
                                  const SizedBox(width: 8),
                                  Text('Edit',
                                      style: GoogleFonts.inter()),
                                ]),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(children: [
                                  const Icon(Icons.delete_outline,
                                      size: 16,
                                      color: Colors.red),
                                  const SizedBox(width: 8),
                                  Text('Delete',
                                      style: GoogleFonts.inter(
                                          color: Colors.red)),
                                ]),
                              ),
                            ],
                          ),
                      ]),
                      const SizedBox(height: 10),
                      Text(title,
                          style: GoogleFonts.cormorantGaramond(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: AppColors.darkText)),
                      const SizedBox(height: 6),
                      Text(content,
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.mutedText,
                              height: 1.5),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('Read more',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.brandRed,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward,
                              size: 14,
                              color: AppColors.brandRed),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.brandRed : AppColors.cardWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.brandRed
                : AppColors.borderSubtle,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.mutedText,
          ),
        ),
      ),
    );
  }
}