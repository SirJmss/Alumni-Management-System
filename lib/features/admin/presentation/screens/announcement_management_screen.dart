import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// adjust if needed

class AnnouncementManagementScreen extends StatefulWidget {
  const AnnouncementManagementScreen({super.key});

  @override
  State<AnnouncementManagementScreen> createState() => _AnnouncementManagementScreenState();
}

class _AnnouncementManagementScreenState extends State<AnnouncementManagementScreen> {
  String? _selectedFilter = 'all'; // all, published, draft, important

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE6D3AE), // match your mobile bg
      appBar: AppBar(
        title: const Text(
          'Manage Announcements',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: const Color(0xFFE64646),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: DropdownButton<String>(
              value: _selectedFilter,
              underline: const SizedBox(),
              iconEnabledColor: Colors.white,
              dropdownColor: const Color(0xFFE64646),
              style: const TextStyle(color: Colors.white),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All')),
                DropdownMenuItem(value: 'published', child: Text('Published')),
                DropdownMenuItem(value: 'draft', child: Text('Drafts')),
                DropdownMenuItem(value: 'important', child: Text('Important')),
              ],
              onChanged: (value) {
                setState(() => _selectedFilter = value);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateAnnouncementForm,
        backgroundColor: const Color(0xFFE64646),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'New Announcement',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _buildAnnouncementStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFE64646)));
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red, fontSize: 16),
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
                  Icon(Icons.campaign_outlined, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 24),
                  Text(
                    'No announcements found',
                    style: TextStyle(color: Colors.grey[700], fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to create one',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              final title = data['title'] as String? ?? 'No Title';
              final content = data['content'] as String? ?? 'No content';
              final important = data['important'] as bool? ?? false;
              final publishedAt = data['publishedAt'] as Timestamp?;
              final dateStr = publishedAt != null
                  ? DateFormat('MMM dd, yyyy • hh:mm a').format(publishedAt.toDate())
                  : 'Not published';

              return Card(
                elevation: 4,
                shadowColor: Colors.grey.withOpacity(0.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D2D2D),
                              ),
                            ),
                          ),
                          if (important)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE64646),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Text(
                                'Important',
                                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        content,
                        style: TextStyle(fontSize: 16, height: 1.5, color: Colors.grey[800]),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        dateStr,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600], fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Color(0xFFE64646)),
                            onPressed: () => _showEditAnnouncementForm(doc.id, data),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent),
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
    );
  }

  Stream<QuerySnapshot> _buildAnnouncementStream() {
    Query query = FirebaseFirestore.instance.collection('announcements').orderBy('publishedAt', descending: true);

    if (_selectedFilter == 'published') {
      query = query.where('publishedAt', isNotEqualTo: null);
    } else if (_selectedFilter == 'draft') {
      query = query.where('publishedAt', isEqualTo: null);
    } else if (_selectedFilter == 'important') {
      query = query.where('important', isEqualTo: true);
    }

    return query.snapshots();
  }

  void _showCreateAnnouncementForm() {
    _showAnnouncementForm(isEdit: false);
  }

  void _showEditAnnouncementForm(String annId, Map<String, dynamic> data) {
    _showAnnouncementForm(isEdit: true, annId: annId, initialData: data);
  }

  void _showAnnouncementForm({bool isEdit = false, String? annId, Map<String, dynamic>? initialData}) {
    final titleCtrl = TextEditingController(text: initialData?['title'] ?? '');
    final contentCtrl = TextEditingController(text: initialData?['content'] ?? '');
    bool isImportant = initialData?['important'] ?? false;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Edit Announcement' : 'New Announcement'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: contentCtrl,
                maxLines: 6,
                decoration: const InputDecoration(labelText: 'Content', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('Mark as Important'),
                value: isImportant,
                onChanged: (val) {
                  setState(() => isImportant = val ?? false);
                },
                activeColor: const Color(0xFFE64646),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE64646)),
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty || contentCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Title and content required')),
                );
                return;
              }

              final data = {
                'title': titleCtrl.text.trim(),
                'content': contentCtrl.text.trim(),
                'important': isImportant,
                'updatedAt': FieldValue.serverTimestamp(),
                if (!isEdit) ...{
                  'authorUid': FirebaseAuth.instance.currentUser?.uid,
                  'createdAt': FieldValue.serverTimestamp(),
                  'publishedAt': FieldValue.serverTimestamp(), // auto-publish
                },
              };

              try {
                if (isEdit) {
                  await FirebaseFirestore.instance.collection('announcements').doc(annId).update(data);
                } else {
                  await FirebaseFirestore.instance.collection('announcements').add(data);
                }

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isEdit ? 'Announcement updated' : 'Announcement posted'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: Text(isEdit ? 'Update' : 'Post'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(String annId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Announcement'),
        content: Text('Delete "$title" permanently?'),
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
          const SnackBar(content: Text('Deleted'), backgroundColor: Colors.green),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}