import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:alumni/core/constants/app_colors.dart';

class AnnouncementManagementScreen extends StatefulWidget {
  const AnnouncementManagementScreen({super.key});

  @override
  State<AnnouncementManagementScreen> createState() => _AnnouncementManagementScreenState();
}

class _AnnouncementManagementScreenState extends State<AnnouncementManagementScreen> {
  String? selectedFilter = 'all'; // all, published, draft, important

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softWhite,
      appBar: AppBar(
        backgroundColor: AppColors.cardWhite,
        elevation: 0,
        title: Text(
          'Announcements',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 26,
            fontWeight: FontWeight.w300,
            color: AppColors.darkText,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButton<String?>(
              value: selectedFilter,
              hint: Text('Filter', style: GoogleFonts.inter(color: AppColors.mutedText)),
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All')),
                DropdownMenuItem(value: 'published', child: Text('Published')),
                DropdownMenuItem(value: 'draft', child: Text('Drafts')),
                DropdownMenuItem(value: 'important', child: Text('Important')),
              ],
              onChanged: (value) => setState(() => selectedFilter = value),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAnnouncementForm(isEdit: false),
        backgroundColor: AppColors.brandRed,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Announcement', style: TextStyle(color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Announcement Management',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 36,
                fontWeight: FontWeight.w300,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create, edit, publish and moderate announcements for the alumni community',
              style: GoogleFonts.inter(fontSize: 15, color: AppColors.mutedText),
            ),
            const SizedBox(height: 32),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _buildAnnouncementStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.brandRed));
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading announcements:\n${snapshot.error}',
                        style: GoogleFonts.inter(color: Colors.red, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.campaign_outlined, size: 90, color: Colors.grey[350]),
                          const SizedBox(height: 32),
                          Text(
                            'No announcements found',
                            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.darkText),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            selectedFilter == 'all'
                                ? 'Tap + to create your first announcement'
                                : 'No announcements match the current filter',
                            style: GoogleFonts.inter(fontSize: 15, color: AppColors.mutedText),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;

                      final title = data['title'] ?? 'Untitled Announcement';
                      final content = data['content'] ?? 'No content';
                      final important = data['important'] as bool? ?? false;
                      final publishedAt = (data['publishedAt'] as Timestamp?)?.toDate();
                      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                      final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();
                      final authorName = data['authorName'] ?? 'Admin';
                      final status = publishedAt != null ? 'published' : 'draft';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  if (important)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppColors.brandRed.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        'IMPORTANT',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.brandRed,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                content,
                                style: GoogleFonts.inter(fontSize: 15, height: 1.5, color: AppColors.darkText),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Text(
                                    'By $authorName • ${createdAt != null ? DateFormat('MMM dd, yyyy').format(createdAt) : '—'}',
                                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.mutedText),
                                  ),
                                  if (updatedAt != null && updatedAt.isAfter(createdAt ?? DateTime(2000))) ...[
                                    const SizedBox(width: 12),
                                    Text(
                                      '(Updated: ${DateFormat('MMM dd, yyyy').format(updatedAt)})',
                                      style: GoogleFonts.inter(fontSize: 13, color: Colors.blueGrey),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (status == 'draft')
                                    IconButton(
                                      icon: const Icon(Icons.publish, color: Colors.green, size: 24),
                                      tooltip: 'Publish now',
                                      onPressed: () => _togglePublish(doc.id, true),
                                    ),
                                  if (status == 'published')
                                    IconButton(
                                      icon: const Icon(Icons.unpublished, color: Colors.orange, size: 24),
                                      tooltip: 'Unpublish (move to draft)',
                                      onPressed: () => _togglePublish(doc.id, false),
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: AppColors.brandRed, size: 24),
                                    tooltip: 'Edit announcement',
                                    onPressed: () => _showAnnouncementForm(isEdit: true, annId: doc.id, initialData: data),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 24),
                                    tooltip: 'Delete announcement',
                                    onPressed: () => _confirmDelete(doc.id, title),
                                  ),
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
            ),
          ],
        ),
      ),
    );
  }

  Stream<QuerySnapshot> _buildAnnouncementStream() {
    Query query = FirebaseFirestore.instance.collection('announcements').orderBy('createdAt', descending: true);

    if (selectedFilter == 'published') {
      query = query.where('publishedAt', isNotEqualTo: null);
    } else if (selectedFilter == 'draft') {
      query = query.where('publishedAt', isEqualTo: null);
    } else if (selectedFilter == 'important') {
      query = query.where('important', isEqualTo: true);
    }

    return query.snapshots();
  }

  Future<void> _togglePublish(String annId, bool shouldPublish) async {
    final action = shouldPublish ? 'Publish' : 'Unpublish';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$action Announcement'),
        content: Text('Are you sure you want to $action this announcement?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: shouldPublish ? Colors.green : Colors.orange),
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('announcements').doc(annId).update({
        'publishedAt': shouldPublish ? FieldValue.serverTimestamp() : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(shouldPublish ? 'Announcement published' : 'Moved to drafts'),
          backgroundColor: shouldPublish ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showAnnouncementForm({bool isEdit = false, String? annId, Map<String, dynamic>? initialData}) {
    final titleCtrl = TextEditingController(text: initialData?['title'] as String? ?? '');
    final contentCtrl = TextEditingController(text: initialData?['content'] as String? ?? '');
    bool isImportant = initialData?['important'] as bool? ?? false;
    bool isPublished = initialData?['publishedAt'] != null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Announcement' : 'New Announcement'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Title *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: contentCtrl,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Content *',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  CheckboxListTile(
                    title: const Text('Mark as Important'),
                    value: isImportant,
                    onChanged: (val) => setDialogState(() => isImportant = val ?? false),
                    activeColor: AppColors.brandRed,
                  ),
                  if (isEdit)
                    CheckboxListTile(
                      title: const Text('Published (visible to users)'),
                      value: isPublished,
                      onChanged: (val) => setDialogState(() => isPublished = val ?? false),
                      activeColor: Colors.green,
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.brandRed),
              onPressed: () async {
                final title = titleCtrl.text.trim();
                final content = contentCtrl.text.trim();
                if (title.isEmpty || content.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Title and content are required')),
                  );
                  return;
                }

                final data = <String, dynamic>{
                  'title': title,
                  'content': content,
                  'important': isImportant,
                  'updatedAt': FieldValue.serverTimestamp(),
                };

                if (isEdit) {
                  data['publishedAt'] = isPublished
                      ? (initialData?['publishedAt'] ?? FieldValue.serverTimestamp())
                      : null;
                } else {
                  data.addAll(<String, dynamic>{
                    'createdAt': FieldValue.serverTimestamp(),
                    'authorUid': FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
                    'authorName': 'Admin', // Replace with real name fetch if needed
                    'publishedAt': isPublished ? FieldValue.serverTimestamp() : null,
                  });
                }

                try {
                  if (isEdit) {
                    await FirebaseFirestore.instance.collection('announcements').doc(annId).update(data);
                  } else {
                    await FirebaseFirestore.instance.collection('announcements').add(data);
                  }
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isEdit ? 'Announcement updated' : 'Announcement created'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              child: Text(isEdit ? 'Save Changes' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(String annId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Announcement'),
        content: Text('Delete "$title" permanently? This cannot be undone.'),
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
        await FirebaseFirestore.instance.collection('announcements').doc(annId).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Announcement deleted'), backgroundColor: Colors.green),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}