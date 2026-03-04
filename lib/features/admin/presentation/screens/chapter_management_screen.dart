import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:alumni/core/constants/app_colors.dart'; // adjust import if needed

class ChapterManagementScreen extends StatefulWidget {
  const ChapterManagementScreen({super.key});

  @override
  State<ChapterManagementScreen> createState() => _ChapterManagementScreenState();
}

class _ChapterManagementScreenState extends State<ChapterManagementScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softWhite,
      appBar: AppBar(
        backgroundColor: AppColors.cardWhite,
        elevation: 0,
        title: Text(
          'Chapter Management',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 26,
            fontWeight: FontWeight.w300,
            color: AppColors.darkText,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 24),
            child: FilledButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New Chapter'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandRed,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () => _showChapterForm(),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'All Chapters',
              style: GoogleFonts.cormorantGaramond(fontSize: 24, color: AppColors.darkText),
            ),
            const SizedBox(height: 8),
            Text(
              'Manage alumni chapters, leaders, and members',
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.mutedText),
            ),
            const SizedBox(height: 24),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('chapters')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                  }

                  final chapters = snapshot.data?.docs ?? [];

                  if (chapters.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.group_off, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            'No chapters created yet',
                            style: GoogleFonts.inter(fontSize: 18, color: Colors.grey[700]),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Click "New Chapter" to add one',
                            style: GoogleFonts.inter(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: chapters.length,
                    itemBuilder: (context, index) {
                      final doc = chapters[index];
                      final data = doc.data() as Map<String, dynamic>;

                      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                      final presidentUid = data['presidentUid'] as String?;

                      return FutureBuilder<int>(
                        future: _getMemberCount(doc.id),
                        builder: (context, memberSnap) {
                          final memberCount = memberSnap.data ?? 0;

                          return FutureBuilder<String>(
                            future: presidentUid != null && presidentUid.isNotEmpty
                                ? _getUserName(presidentUid)
                                : Future.value('None'),
                            builder: (context, presidentSnap) {
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 1,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  leading: CircleAvatar(
                                    radius: 28,
                                    backgroundColor: AppColors.brandRed.withOpacity(0.15),
                                    child: const Icon(Icons.group, color: AppColors.brandRed),
                                  ),
                                  title: Text(
                                    data['name'] ?? 'Unnamed Chapter',
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data['description']?.toString() ?? 'No description',
                                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.mutedText),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppColors.success.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              '$memberCount members',
                                              style: GoogleFonts.inter(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            'President: ${presidentSnap.data ?? 'None'}',
                                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedText),
                                          ),
                                          const SizedBox(width: 12),
                                          if (createdAt != null)
                                            Text(
                                              'Created ${DateFormat('MMM dd, yyyy').format(createdAt)}',
                                              style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedText),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 22),
                                        tooltip: 'Edit',
                                        onPressed: () => _showChapterForm(chapterId: doc.id, initialData: data),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 22, color: Colors.redAccent),
                                        tooltip: 'Delete',
                                        onPressed: () => _confirmDeleteChapter(doc.id, data['name'] ?? 'this chapter'),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.people_alt_outlined, size: 22),
                                        tooltip: 'View Members',
                                        onPressed: () => _showMembersDialog(doc.id, data['name'] ?? 'Chapter'),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
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
      return data?['name'] ?? data?['fullName'] ?? data?['email']?.split('@')[0] ?? 'Unknown';
    } catch (e) {
      return 'Unknown';
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
                backgroundColor: AppColors.brandRed,
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
                          backgroundColor: isPresident ? AppColors.brandRed : AppColors.brandRed.withOpacity(0.1),
                          child: Text(
                            user['name']?[0] ?? '?',
                            style: TextStyle(color: isPresident ? Colors.white : AppColors.brandRed),
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
                                color: isPresident ? AppColors.brandRed : null,
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
                                icon: const Icon(Icons.star_border, color: AppColors.brandRed, size: 22),
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

      // Safety: only downgrade if there's a valid different president
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

      // Set new president role
      await FirebaseFirestore.instance
          .collection('chapters')
          .doc(chapterId)
          .collection('members')
          .doc(userUid)
          .update({'role': 'president'});

      // Update chapter doc
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
                                icon: const Icon(Icons.add_circle_outline, color: AppColors.success),
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