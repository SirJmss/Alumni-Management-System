import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:alumni/core/constants/app_colors.dart';

class DiscussionsScreen extends StatefulWidget {
  const DiscussionsScreen({super.key});

  @override
  State<DiscussionsScreen> createState() =>
      _DiscussionsScreenState();
}

class _DiscussionsScreenState
    extends State<DiscussionsScreen> {
  String _category = 'All';
  String _searchQuery = '';
  String? _currentUid;
  String? _currentRole;
  String? _currentName;
  String? _currentAvatar;
  String? _currentBatch;
  String? _currentCourse;
  bool _isLoading = true;

  final _categories = [
    'All',
    'General',
    'Career',
    'Events',
    'Batch',
    'Announcements',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && mounted) {
        final d = doc.data()!;
        setState(() {
          _currentUid = user.uid;
          _currentRole =
              d['role']?.toString() ?? 'alumni';
          _currentName = d['name']?.toString() ??
              d['fullName']?.toString() ??
              'Alumni';
          _currentAvatar =
              d['profilePictureUrl']?.toString();
          _currentBatch =
              d['batch']?.toString() ?? '';
          _currentCourse =
              d['course']?.toString() ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _canPost =>
      _currentRole == 'alumni' ||
      _currentRole == 'admin' ||
      _currentRole == 'staff' ||
      _currentRole == 'moderator' ||
      _currentRole == 'registrar';

  bool get _isStaff =>
      _currentRole == 'admin' ||
      _currentRole == 'staff' ||
      _currentRole == 'moderator' ||
      _currentRole == 'registrar';

  Stream<QuerySnapshot> get _stream {
    Query q = FirebaseFirestore.instance
        .collection('discussions')
        .orderBy('isPinned', descending: true)
        .orderBy('createdAt', descending: true);
    if (_category != 'All') {
      q = q.where('category',
          isEqualTo: _category);
    }
    return q.snapshots();
  }

  void _showSnackBar(String msg,
      {required bool isError}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter()),
        backgroundColor:
            isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  // ─── Create / Edit post ───
  void _showPostForm({
    String? docId,
    Map<String, dynamic>? initial,
  }) {
    final isEdit = docId != null;
    final titleCtrl = TextEditingController(
        text: initial?['title']?.toString() ?? '');
    final bodyCtrl = TextEditingController(
        text: initial?['body']?.toString() ?? '');
    String category =
        initial?['category']?.toString() ?? 'General';
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) =>
            DraggableScrollableSheet(
          initialChildSize: 0.88,
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
                // ─── Handle ───
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

                // ─── Header ───
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        isEdit
                            ? 'Edit Discussion'
                            : 'Start a Discussion',
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
                                final title = titleCtrl
                                    .text
                                    .trim();
                                final body =
                                    bodyCtrl.text.trim();

                                // ─── Validation ───
                                if (title.length < 10) {
                                  _showSnackBar(
                                      'Title must be at least 10 characters',
                                      isError: true);
                                  return;
                                }
                                if (title.length > 150) {
                                  _showSnackBar(
                                      'Title cannot exceed 150 characters',
                                      isError: true);
                                  return;
                                }
                                if (body.length < 20) {
                                  _showSnackBar(
                                      'Body must be at least 20 characters',
                                      isError: true);
                                  return;
                                }
                                if (body.length > 2000) {
                                  _showSnackBar(
                                      'Body cannot exceed 2000 characters',
                                      isError: true);
                                  return;
                                }

                                // ─── Spam check ───
                                if (!isEdit) {
                                  final recent = await FirebaseFirestore
                                      .instance
                                      .collection(
                                          'discussions')
                                      .where('authorId',
                                          isEqualTo:
                                              _currentUid)
                                      .orderBy(
                                          'createdAt',
                                          descending: true)
                                      .limit(1)
                                      .get();
                                  if (recent
                                      .docs.isNotEmpty) {
                                    final lastPost = (recent
                                                .docs.first
                                                .data()['createdAt']
                                            as Timestamp?)
                                        ?.toDate();
                                    if (lastPost != null &&
                                        DateTime.now().difference(lastPost).inSeconds > 30) {
                                      _showSnackBar(
                                          'Please wait before posting again',
                                          isError: true);
                                      return;
                                    }
                                  }
                                }

                                setSheet(() =>
                                    isSubmitting = true);

                                try {
                                  if (isEdit) {
                                    await FirebaseFirestore
                                        .instance
                                        .collection(
                                            'discussions')
                                        .doc(docId)
                                        .update({
                                      'title': title,
                                      'body': body,
                                      'category':
                                          category,
                                      'isEdited': true,
                                      'updatedAt': FieldValue
                                          .serverTimestamp(),
                                    });
                                  } else {
                                    await FirebaseFirestore
                                        .instance
                                        .collection(
                                            'discussions')
                                        .add({
                                      'title': title,
                                      'body': body,
                                      'category':
                                          category,
                                      'authorId':
                                          _currentUid,
                                      'authorName':
                                          _currentName,
                                      'authorAvatar':
                                          _currentAvatar,
                                      'authorBatch':
                                          _currentBatch,
                                      'authorCourse':
                                          _currentCourse,
                                      'likesCount': 0,
                                      'repliesCount': 0,
                                      'isPinned': false,
                                      'isLocked': false,
                                      'isEdited': false,
                                      'createdAt': FieldValue
                                          .serverTimestamp(),
                                      'updatedAt': FieldValue
                                          .serverTimestamp(),
                                    });
                                  }
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                    _showSnackBar(
                                      isEdit
                                          ? 'Discussion updated!'
                                          : 'Discussion posted!',
                                      isError: false,
                                    );
                                  }
                                } catch (e) {
                                  setSheet(() =>
                                      isSubmitting =
                                          false);
                                  _showSnackBar(
                                      'Error: $e',
                                      isError: true);
                                }
                              },
                        child: Text(
                          isSubmitting
                              ? 'Posting...'
                              : isEdit
                                  ? 'Save'
                                  : 'Post',
                          style: GoogleFonts.inter(
                              color: AppColors.brandRed,
                              fontWeight: FontWeight.w700,
                              fontSize: 15),
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
                      // ─── Category ───
                      _dropdownField(
                        label: 'CATEGORY',
                        value: category,
                        items: _categories
                            .where((c) => c != 'All')
                            .toList(),
                        onChanged: (v) =>
                            setSheet(() => category = v!),
                      ),
                      const SizedBox(height: 16),

                      // ─── Title ───
                      _formField(
                        ctrl: titleCtrl,
                        label: 'TITLE',
                        hint:
                            'What do you want to discuss?',
                        maxLines: 2,
                        onChanged: (_) => setSheet(() {}),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${titleCtrl.text.length}/150',
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              color:
                                  titleCtrl.text.length >
                                          150
                                      ? Colors.red
                                      : AppColors.mutedText),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ─── Body ───
                      _formField(
                        ctrl: bodyCtrl,
                        label: 'BODY',
                        hint:
                            'Share your thoughts, questions, or updates...',
                        maxLines: 10,
                        onChanged: (_) => setSheet(() {}),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${bodyCtrl.text.length}/2000',
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              color:
                                  bodyCtrl.text.length >
                                          2000
                                      ? Colors.red
                                      : AppColors.mutedText),
                        ),
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

  // ─── Delete post ───
  Future<void> _deletePost(
      String id, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Discussion',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: AppColors.brandRed)),
        content: Text(
            'Delete "$title"? All replies will also be deleted.',
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
          .collection('discussions')
          .doc(id)
          .delete();
      _showSnackBar('Discussion deleted',
          isError: false);
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  // ─── Toggle like ───
  Future<void> _toggleLike(
      String id, int currentCount) async {
    if (_currentUid == null) return;
    final ref = FirebaseFirestore.instance
        .collection('discussions')
        .doc(id);
    final likeRef =
        ref.collection('likes').doc(_currentUid);
    final liked = await likeRef.get();

    if (liked.exists) {
      await likeRef.delete();
      await ref.update(
          {'likesCount': FieldValue.increment(-1)});
    } else {
      await likeRef
          .set({'likedAt': FieldValue.serverTimestamp()});
      await ref.update(
          {'likesCount': FieldValue.increment(1)});
    }
  }

  // ─── Toggle pin (staff only) ───
  Future<void> _togglePin(
      String id, bool current) async {
    await FirebaseFirestore.instance
        .collection('discussions')
        .doc(id)
        .update({'isPinned': !current});
  }

  // ─── Toggle lock (staff only) ───
  Future<void> _toggleLock(
      String id, bool current) async {
    await FirebaseFirestore.instance
        .collection('discussions')
        .doc(id)
        .update({'isLocked': !current});
    _showSnackBar(
        current ? 'Thread unlocked' : 'Thread locked',
        isError: false);
  }

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '—';
    final diff =
        DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    }
    return DateFormat('MMM dd, yyyy')
        .format(ts.toDate());
  }

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'Career':
        return Colors.blue;
      case 'Events':
        return Colors.purple;
      case 'Batch':
        return Colors.orange;
      case 'Announcements':
        return AppColors.brandRed;
      default:
        return Colors.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softWhite,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: AppColors.darkText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Discussions',
                style: GoogleFonts.cormorantGaramond(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkText)),
            Text('Alumni Community Board',
                style: GoogleFonts.inter(
                    fontSize: 10,
                    color: AppColors.mutedText)),
          ],
        ),
        actions: [
          if (_canPost)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton.icon(
                onPressed: () => _showPostForm(),
                icon: const Icon(Icons.add, size: 16),
                label: Text('Post',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandRed,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.brandRed))
          : Column(
              children: [
                // ─── Search ───
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(
                      16, 8, 16, 8),
                  child: TextField(
                    style:
                        GoogleFonts.inter(fontSize: 14),
                    decoration: InputDecoration(
                      hintText:
                          'Search discussions...',
                      hintStyle: GoogleFonts.inter(
                          color: AppColors.mutedText,
                          fontSize: 13),
                      prefixIcon: const Icon(
                          Icons.search,
                          color: AppColors.mutedText,
                          size: 18),
                      filled: true,
                      fillColor: AppColors.softWhite,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10),
                    ),
                    onChanged: (v) => setState(() =>
                        _searchQuery =
                            v.toLowerCase()),
                  ),
                ),

                // ─── Category chips ───
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(
                      16, 0, 16, 12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _categories.map((cat) {
                        final isActive =
                            _category == cat;
                        return GestureDetector(
                          onTap: () => setState(
                              () => _category = cat),
                          child: Container(
                            margin: const EdgeInsets
                                .only(right: 8),
                            padding: const EdgeInsets
                                .symmetric(
                                horizontal: 12,
                                vertical: 6),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.brandRed
                                  : AppColors.softWhite,
                              borderRadius:
                                  BorderRadius.circular(
                                      16),
                              border: Border.all(
                                  color: isActive
                                      ? AppColors.brandRed
                                      : AppColors
                                          .borderSubtle),
                            ),
                            child: Text(cat,
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight:
                                        FontWeight.w600,
                                    color: isActive
                                        ? Colors.white
                                        : AppColors
                                            .mutedText)),
                          ),
                        );
                      }).toList(),
                    ),
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
                                    color: Colors.red)));
                      }

                      var docs =
                          snapshot.data?.docs ?? [];

                      if (_searchQuery.isNotEmpty) {
                        docs = docs.where((d) {
                          final data = d.data()
                              as Map<String, dynamic>;
                          final title = data['title']
                                  ?.toString()
                                  .toLowerCase() ??
                              '';
                          final body = data['body']
                                  ?.toString()
                                  .toLowerCase() ??
                              '';
                          return title.contains(
                                  _searchQuery) ||
                              body.contains(
                                  _searchQuery);
                        }).toList();
                      }

                      if (docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              const Icon(
                                  Icons.forum_outlined,
                                  size: 64,
                                  color: AppColors
                                      .borderSubtle),
                              const SizedBox(height: 16),
                              Text(
                                'No discussions yet',
                                style: GoogleFonts
                                    .cormorantGaramond(
                                        fontSize: 22,
                                        color: AppColors
                                            .darkText),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _canPost
                                    ? 'Be the first to start a discussion!'
                                    : 'Check back later',
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color:
                                        AppColors.mutedText),
                              ),
                              if (_canPost) ...[
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () =>
                                      _showPostForm(),
                                  style: ElevatedButton
                                      .styleFrom(
                                    backgroundColor:
                                        AppColors.brandRed,
                                    foregroundColor:
                                        Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius
                                                .circular(8)),
                                  ),
                                  child: Text('Start Discussion',
                                      style: GoogleFonts.inter(
                                          fontWeight:
                                              FontWeight
                                                  .w600)),
                                ),
                              ],
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final doc = docs[i];
                          final data = doc.data()
                              as Map<String, dynamic>;
                          return _discussionCard(
                              doc.id, data);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _discussionCard(
      String id, Map<String, dynamic> data) {
    final title =
        data['title']?.toString() ?? 'Untitled';
    final body = data['body']?.toString() ?? '';
    final authorName =
        data['authorName']?.toString() ?? 'Alumni';
    final authorAvatar =
        data['authorAvatar']?.toString();
    final authorBatch =
        data['authorBatch']?.toString() ?? '';
    final category =
        data['category']?.toString() ?? 'General';
    final likesCount =
        data['likesCount'] as int? ?? 0;
    final repliesCount =
        data['repliesCount'] as int? ?? 0;
    final isPinned =
        data['isPinned'] as bool? ?? false;
    final isLocked =
        data['isLocked'] as bool? ?? false;
    final isEdited =
        data['isEdited'] as bool? ?? false;
    final createdAt =
        data['createdAt'] as Timestamp?;
    final authorId =
        data['authorId']?.toString() ?? '';
    final isOwner = authorId == _currentUid;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DiscussionDetailScreen(
            discussionId: id,
            data: data,
            currentUid: _currentUid ?? '',
            currentName: _currentName ?? '',
            currentAvatar: _currentAvatar,
            currentRole: _currentRole ?? 'alumni',
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isPinned
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
            Row(children: [
              if (isPinned) ...[
                const Icon(Icons.push_pin,
                    size: 12, color: AppColors.brandRed),
                const SizedBox(width: 4),
                Text('PINNED',
                    style: GoogleFonts.inter(
                        fontSize: 9,
                        color: AppColors.brandRed,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1)),
                const SizedBox(width: 8),
              ],
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _categoryColor(category)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(category,
                    style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: _categoryColor(category),
                        letterSpacing: 0.5)),
              ),
              if (isLocked) ...[
                const SizedBox(width: 8),
                const Icon(Icons.lock,
                    size: 12, color: AppColors.mutedText),
                Text(' Locked',
                    style: GoogleFonts.inter(
                        fontSize: 9,
                        color: AppColors.mutedText)),
              ],
              const Spacer(),
              Text(_timeAgo(createdAt),
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppColors.mutedText)),
            ]),

            const SizedBox(height: 10),

            // ─── Title ───
            Text(title,
                style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText,
                    height: 1.3),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),

            const SizedBox(height: 6),

            // ─── Body preview ───
            Text(body,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.mutedText,
                    height: 1.5),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),

            const SizedBox(height: 12),

            // ─── Author + stats ───
            Row(children: [
              CircleAvatar(
                radius: 14,
                backgroundColor:
                    AppColors.brandRed.withOpacity(0.1),
                backgroundImage: authorAvatar != null
                    ? NetworkImage(authorAvatar)
                    : null,
                child: authorAvatar == null
                    ? Text(
                        authorName.isNotEmpty
                            ? authorName[0].toUpperCase()
                            : '?',
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            color: AppColors.brandRed,
                            fontWeight: FontWeight.w700))
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(authorName,
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkText)),
                    if (authorBatch.isNotEmpty)
                      Text('Batch $authorBatch',
                          style: GoogleFonts.inter(
                              fontSize: 9,
                              color: AppColors.mutedText)),
                  ],
                ),
              ),
              if (isEdited)
                Text('edited',
                    style: GoogleFonts.inter(
                        fontSize: 9,
                        color: AppColors.mutedText,
                        fontStyle: FontStyle.italic)),
              const SizedBox(width: 8),

              // ─── Like ───
              GestureDetector(
                onTap: () =>
                    _toggleLike(id, likesCount),
                child: Row(children: [
                  StreamBuilder<DocumentSnapshot>(
                    stream: _currentUid != null
                        ? FirebaseFirestore.instance
                            .collection('discussions')
                            .doc(id)
                            .collection('likes')
                            .doc(_currentUid)
                            .snapshots()
                        : null,
                    builder: (context, snap) {
                      final liked =
                          snap.data?.exists ?? false;
                      return Icon(
                        liked
                            ? Icons.favorite
                            : Icons.favorite_border,
                        size: 16,
                        color: liked
                            ? AppColors.brandRed
                            : AppColors.mutedText,
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  Text('$likesCount',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.mutedText)),
                ]),
              ),

              const SizedBox(width: 14),

              // ─── Replies ───
              Row(children: [
                const Icon(Icons.chat_bubble_outline,
                    size: 15, color: AppColors.mutedText),
                const SizedBox(width: 4),
                Text('$repliesCount',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.mutedText)),
              ]),

              // ─── Actions ───
              if (isOwner || _isStaff) ...[
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz,
                      size: 18,
                      color: AppColors.mutedText),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(12)),
                  onSelected: (v) {
                    if (v == 'edit') {
                      _showPostForm(
                          docId: id, initial: data);
                    } else if (v == 'delete') {
                      _deletePost(id, title);
                    } else if (v == 'pin') {
                      _togglePin(id, isPinned);
                    } else if (v == 'lock') {
                      _toggleLock(id, isLocked);
                    }
                  },
                  itemBuilder: (_) => [
                    if (isOwner)
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [
                          const Icon(
                              Icons.edit_outlined,
                              size: 16,
                              color: AppColors.mutedText),
                          const SizedBox(width: 8),
                          Text('Edit',
                              style: GoogleFonts.inter(
                                  fontSize: 13)),
                        ]),
                      ),
                    if (isOwner || _isStaff)
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          const Icon(
                              Icons.delete_outline,
                              size: 16,
                              color: Colors.red),
                          const SizedBox(width: 8),
                          Text('Delete',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.red)),
                        ]),
                      ),
                    if (_isStaff)
                      PopupMenuItem(
                        value: 'pin',
                        child: Row(children: [
                          Icon(
                              isPinned
                                  ? Icons.push_pin
                                  : Icons.push_pin_outlined,
                              size: 16,
                              color: AppColors.brandRed),
                          const SizedBox(width: 8),
                          Text(
                              isPinned
                                  ? 'Unpin'
                                  : 'Pin',
                              style: GoogleFonts.inter(
                                  fontSize: 13)),
                        ]),
                      ),
                    if (_isStaff)
                      PopupMenuItem(
                        value: 'lock',
                        child: Row(children: [
                          Icon(
                              isLocked
                                  ? Icons.lock_open_outlined
                                  : Icons.lock_outlined,
                              size: 16,
                              color: Colors.orange),
                          const SizedBox(width: 8),
                          Text(
                              isLocked
                                  ? 'Unlock'
                                  : 'Lock',
                              style: GoogleFonts.inter(
                                  fontSize: 13)),
                        ]),
                      ),
                  ],
                ),
              ],
            ]),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ───
  Widget _dropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 9,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
                color: AppColors.mutedText)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: AppColors.softWhite,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: AppColors.borderSubtle),
          ),
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 2),
          child: DropdownButtonFormField<String>(
            value: value,
            decoration: const InputDecoration(
                border: InputBorder.none),
            items: items
                .map((v) => DropdownMenuItem(
                    value: v,
                    child: Text(v,
                        style: GoogleFonts.inter(
                            fontSize: 14))))
                .toList(),
            onChanged: onChanged,
            style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.darkText),
          ),
        ),
      ],
    );
  }

  Widget _formField({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 9,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
                color: AppColors.mutedText)),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          onChanged: onChanged,
          style: GoogleFonts.inter(
              fontSize: 14, color: AppColors.darkText),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
                color: AppColors.borderSubtle,
                fontSize: 13),
            filled: true,
            fillColor: AppColors.softWhite,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                  color: AppColors.borderSubtle),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                  color: AppColors.borderSubtle),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                  color: AppColors.brandRed, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════
// Discussion Detail Screen
// ════════════════════════════════════════════════════

class DiscussionDetailScreen extends StatefulWidget {
  final String discussionId;
  final Map<String, dynamic> data;
  final String currentUid;
  final String currentName;
  final String? currentAvatar;
  final String currentRole;

  const DiscussionDetailScreen({
    super.key,
    required this.discussionId,
    required this.data,
    required this.currentUid,
    required this.currentName,
    this.currentAvatar,
    required this.currentRole,
  });

  @override
  State<DiscussionDetailScreen> createState() =>
      _DiscussionDetailScreenState();
}

class _DiscussionDetailScreenState
    extends State<DiscussionDetailScreen> {
  final _replyCtrl = TextEditingController();
  bool _isReplying = false;
  String? _editingReplyId;

  bool get _isStaff =>
      widget.currentRole == 'admin' ||
      widget.currentRole == 'staff' ||
      widget.currentRole == 'moderator' ||
      widget.currentRole == 'registrar';

  bool get _isLocked =>
      widget.data['isLocked'] as bool? ?? false;

  void _showSnackBar(String msg,
      {required bool isError}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter()),
        backgroundColor:
            isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  Future<void> _postReply() async {
    final body = _replyCtrl.text.trim();
    if (body.length < 2) {
      _showSnackBar('Reply is too short',
          isError: true);
      return;
    }
    if (body.length > 1000) {
      _showSnackBar('Reply cannot exceed 1000 characters',
          isError: true);
      return;
    }

    setState(() => _isReplying = true);
    try {
      if (_editingReplyId != null) {
        // ─── Edit reply ───
        await FirebaseFirestore.instance
            .collection('discussions')
            .doc(widget.discussionId)
            .collection('replies')
            .doc(_editingReplyId)
            .update({
          'body': body,
          'isEdited': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        setState(() => _editingReplyId = null);
        _showSnackBar('Reply updated', isError: false);
      } else {
        // ─── New reply ───
        final batch = FirebaseFirestore.instance.batch();
        final replyRef = FirebaseFirestore.instance
            .collection('discussions')
            .doc(widget.discussionId)
            .collection('replies')
            .doc();

        batch.set(replyRef, {
          'body': body,
          'authorId': widget.currentUid,
          'authorName': widget.currentName,
          'authorAvatar': widget.currentAvatar,
          'likesCount': 0,
          'isEdited': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        batch.update(
          FirebaseFirestore.instance
              .collection('discussions')
              .doc(widget.discussionId),
          {'repliesCount': FieldValue.increment(1)},
        );

        await batch.commit();
        _showSnackBar('Reply posted!', isError: false);
      }
      _replyCtrl.clear();
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isReplying = false);
    }
  }

  Future<void> _deleteReply(String replyId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Reply',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: AppColors.brandRed)),
        content: Text('Delete this reply?',
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

    final batch = FirebaseFirestore.instance.batch();
    batch.delete(FirebaseFirestore.instance
        .collection('discussions')
        .doc(widget.discussionId)
        .collection('replies')
        .doc(replyId));
    batch.update(
      FirebaseFirestore.instance
          .collection('discussions')
          .doc(widget.discussionId),
      {'repliesCount': FieldValue.increment(-1)},
    );
    await batch.commit();
    _showSnackBar('Reply deleted', isError: false);
  }

  Future<void> _toggleReplyLike(
      String replyId, int count) async {
    final ref = FirebaseFirestore.instance
        .collection('discussions')
        .doc(widget.discussionId)
        .collection('replies')
        .doc(replyId);
    final likeRef = ref
        .collection('likes')
        .doc(widget.currentUid);
    final liked = await likeRef.get();
    if (liked.exists) {
      await likeRef.delete();
      await ref.update(
          {'likesCount': FieldValue.increment(-1)});
    } else {
      await likeRef
          .set({'likedAt': FieldValue.serverTimestamp()});
      await ref.update(
          {'likesCount': FieldValue.increment(1)});
    }
  }

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '—';
    final diff =
        DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    }
    return DateFormat('MMM dd, yyyy')
        .format(ts.toDate());
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.data['title']?.toString() ?? '';
    final body =
        widget.data['body']?.toString() ?? '';
    final authorName =
        widget.data['authorName']?.toString() ??
            'Alumni';
    final authorAvatar =
        widget.data['authorAvatar']?.toString();
    final authorBatch =
        widget.data['authorBatch']?.toString() ?? '';
    final authorCourse =
        widget.data['authorCourse']?.toString() ?? '';
    final category =
        widget.data['category']?.toString() ?? 'General';
    final likesCount =
        widget.data['likesCount'] as int? ?? 0;
    final isPinned =
        widget.data['isPinned'] as bool? ?? false;
    final isEdited =
        widget.data['isEdited'] as bool? ?? false;
    final createdAt =
        widget.data['createdAt'] as Timestamp?;

    return Scaffold(
      backgroundColor: AppColors.softWhite,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: AppColors.darkText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Discussion',
            style: GoogleFonts.cormorantGaramond(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.darkText)),
        actions: [
          if (isPinned)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.push_pin,
                  size: 18, color: AppColors.brandRed),
            ),
          if (_isLocked)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.lock,
                  size: 18, color: AppColors.mutedText),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                // ─── Main post ───
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(14),
                      border: Border.all(
                          color: isPinned
                              ? AppColors.brandRed
                                  .withOpacity(0.3)
                              : AppColors.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        // ─── Category + badges ───
                        Row(children: [
                          Container(
                            padding: const EdgeInsets
                                .symmetric(
                                horizontal: 8,
                                vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.brandRed
                                  .withOpacity(0.1),
                              borderRadius:
                                  BorderRadius.circular(4),
                            ),
                            child: Text(category,
                                style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight:
                                        FontWeight.w700,
                                    color:
                                        AppColors.brandRed,
                                    letterSpacing: 0.5)),
                          ),
                          if (_isLocked) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets
                                  .symmetric(
                                  horizontal: 8,
                                  vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.orange
                                    .withOpacity(0.1),
                                borderRadius:
                                    BorderRadius.circular(
                                        4),
                              ),
                              child: Row(children: [
                                const Icon(Icons.lock,
                                    size: 9,
                                    color: Colors.orange),
                                const SizedBox(width: 3),
                                Text('LOCKED',
                                    style: GoogleFonts.inter(
                                        fontSize: 9,
                                        fontWeight:
                                            FontWeight.w700,
                                        color:
                                            Colors.orange,
                                        letterSpacing: 0.5)),
                              ]),
                            ),
                          ],
                          const Spacer(),
                          Text(_timeAgo(createdAt),
                              style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color:
                                      AppColors.mutedText)),
                          if (isEdited) ...[
                            const SizedBox(width: 6),
                            Text('· edited',
                                style: GoogleFonts.inter(
                                    fontSize: 9,
                                    color:
                                        AppColors.mutedText,
                                    fontStyle:
                                        FontStyle.italic)),
                          ],
                        ]),

                        const SizedBox(height: 14),

                        // ─── Title ───
                        Text(title,
                            style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.darkText,
                                height: 1.3)),

                        const SizedBox(height: 12),

                        // ─── Body ───
                        Text(body,
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                color: AppColors.darkText,
                                height: 1.7)),

                        const SizedBox(height: 16),
                        const Divider(
                            color: AppColors.borderSubtle),
                        const SizedBox(height: 12),

                        // ─── Author ───
                        Row(children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors
                                .brandRed
                                .withOpacity(0.1),
                            backgroundImage:
                                authorAvatar != null
                                    ? NetworkImage(
                                        authorAvatar)
                                    : null,
                            child: authorAvatar == null
                                ? Text(
                                    authorName.isNotEmpty
                                        ? authorName[0]
                                            .toUpperCase()
                                        : '?',
                                    style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: AppColors
                                            .brandRed,
                                        fontWeight:
                                            FontWeight.w700))
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(authorName,
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight:
                                          FontWeight.w600,
                                      color:
                                          AppColors.darkText)),
                              if (authorBatch.isNotEmpty ||
                                  authorCourse.isNotEmpty)
                                Text(
                                  [
                                    if (authorCourse
                                        .isNotEmpty)
                                      authorCourse,
                                    if (authorBatch
                                        .isNotEmpty)
                                      'Batch $authorBatch',
                                  ].join(' · '),
                                  style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color:
                                          AppColors.mutedText),
                                ),
                            ],
                          ),
                          const Spacer(),

                          // ─── Like post ───
                          StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore
                                .instance
                                .collection('discussions')
                                .doc(widget.discussionId)
                                .collection('likes')
                                .doc(widget.currentUid)
                                .snapshots(),
                            builder: (context, snap) {
                              final liked =
                                  snap.data?.exists ??
                                      false;
                              return GestureDetector(
                                onTap: () async {
                                  final ref = FirebaseFirestore
                                      .instance
                                      .collection(
                                          'discussions')
                                      .doc(widget
                                          .discussionId);
                                  final likeRef = ref
                                      .collection('likes')
                                      .doc(widget
                                          .currentUid);
                                  if (liked) {
                                    await likeRef.delete();
                                    await ref.update({
                                      'likesCount':
                                          FieldValue
                                              .increment(-1)
                                    });
                                  } else {
                                    await likeRef.set({
                                      'likedAt': FieldValue
                                          .serverTimestamp()
                                    });
                                    await ref.update({
                                      'likesCount':
                                          FieldValue
                                              .increment(1)
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets
                                      .symmetric(
                                      horizontal: 12,
                                      vertical: 6),
                                  decoration: BoxDecoration(
                                    color: liked
                                        ? AppColors.brandRed
                                            .withOpacity(0.1)
                                        : AppColors.softWhite,
                                    borderRadius:
                                        BorderRadius.circular(
                                            20),
                                    border: Border.all(
                                        color: liked
                                            ? AppColors
                                                .brandRed
                                                .withOpacity(
                                                    0.3)
                                            : AppColors
                                                .borderSubtle),
                                  ),
                                  child: Row(children: [
                                    Icon(
                                      liked
                                          ? Icons.favorite
                                          : Icons
                                              .favorite_border,
                                      size: 15,
                                      color: liked
                                          ? AppColors.brandRed
                                          : AppColors
                                              .mutedText,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      '$likesCount',
                                      style: GoogleFonts
                                          .inter(
                                              fontSize: 12,
                                              color: liked
                                                  ? AppColors
                                                      .brandRed
                                                  : AppColors
                                                      .mutedText,
                                              fontWeight:
                                                  FontWeight
                                                      .w600),
                                    ),
                                  ]),
                                ),
                              );
                            },
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),

                // ─── Replies header ───
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        20, 4, 20, 12),
                    child: Row(children: [
                      Container(
                          width: 16,
                          height: 1,
                          color: AppColors.brandRed),
                      const SizedBox(width: 8),
                      Text('REPLIES',
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brandRed)),
                    ]),
                  ),
                ),

                // ─── Replies list ───
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('discussions')
                      .doc(widget.discussionId)
                      .collection('replies')
                      .orderBy('createdAt')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const SliverToBoxAdapter(
                        child: Center(
                            child:
                                CircularProgressIndicator(
                                    color:
                                        AppColors.brandRed)),
                      );
                    }

                    final docs =
                        snapshot.data?.docs ?? [];

                    if (docs.isEmpty) {
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets
                              .symmetric(vertical: 32),
                          child: Center(
                            child: Column(children: [
                              const Icon(
                                  Icons
                                      .chat_bubble_outline,
                                  size: 36,
                                  color: AppColors
                                      .borderSubtle),
                              const SizedBox(height: 8),
                              Text(
                                'No replies yet.',
                                style: GoogleFonts.inter(
                                    color:
                                        AppColors.mutedText,
                                    fontSize: 13),
                              ),
                              if (!_isLocked)
                                Text(
                                  'Be the first to reply!',
                                  style: GoogleFonts.inter(
                                      color:
                                          AppColors.mutedText,
                                      fontSize: 12),
                                ),
                            ]),
                          ),
                        ),
                      );
                    }

                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final doc = docs[i];
                          final d = doc.data()
                              as Map<String, dynamic>;
                          return _replyCard(
                              doc.id, d);
                        },
                        childCount: docs.length,
                      ),
                    );
                  },
                ),

                const SliverToBoxAdapter(
                    child: SizedBox(height: 16)),
              ],
            ),
          ),

          // ─── Reply input ───
          if (!_isLocked)
            Container(
              color: Colors.white,
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(context)
                        .viewInsets
                        .bottom +
                    16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  if (_editingReplyId != null)
                    Padding(
                      padding: const EdgeInsets.only(
                          bottom: 6),
                      child: Row(children: [
                        Text('Editing reply',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.brandRed,
                                fontWeight:
                                    FontWeight.w600)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _editingReplyId = null;
                              _replyCtrl.clear();
                            });
                          },
                          child: Text('Cancel',
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color:
                                      AppColors.mutedText)),
                        ),
                      ]),
                    ),
                  Row(children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.brandRed
                          .withOpacity(0.1),
                      backgroundImage:
                          widget.currentAvatar != null
                              ? NetworkImage(
                                  widget.currentAvatar!)
                              : null,
                      child: widget.currentAvatar == null
                          ? Text(
                              widget.currentName.isNotEmpty
                                  ? widget
                                      .currentName[0]
                                      .toUpperCase()
                                  : '?',
                              style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: AppColors.brandRed,
                                  fontWeight:
                                      FontWeight.w700))
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _replyCtrl,
                        maxLines: 3,
                        minLines: 1,
                        style: GoogleFonts.inter(
                            fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Write a reply...',
                          hintStyle: GoogleFonts.inter(
                              color: AppColors.mutedText,
                              fontSize: 13),
                          filled: true,
                          fillColor: AppColors.softWhite,
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap:
                          _isReplying ? null : _postReply,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.brandRed,
                          shape: BoxShape.circle,
                        ),
                        child: _isReplying
                            ? const Padding(
                                padding:
                                    EdgeInsets.all(10),
                                child:
                                    CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2))
                            : const Icon(Icons.send,
                                color: Colors.white,
                                size: 18),
                      ),
                    ),
                  ]),
                ],
              ),
            )
          else
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock,
                      size: 14,
                      color: AppColors.mutedText),
                  const SizedBox(width: 6),
                  Text(
                    'This thread is locked. No more replies.',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.mutedText),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _replyCard(
      String replyId, Map<String, dynamic> d) {
    final body = d['body']?.toString() ?? '';
    final authorName =
        d['authorName']?.toString() ?? 'Alumni';
    final authorAvatar =
        d['authorAvatar']?.toString();
    final authorId = d['authorId']?.toString() ?? '';
    final likesCount = d['likesCount'] as int? ?? 0;
    final isEdited = d['isEdited'] as bool? ?? false;
    final createdAt = d['createdAt'] as Timestamp?;
    final isOwner = authorId == widget.currentUid;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Author row ───
          Row(children: [
            CircleAvatar(
              radius: 14,
              backgroundColor:
                  AppColors.brandRed.withOpacity(0.1),
              backgroundImage: authorAvatar != null
                  ? NetworkImage(authorAvatar)
                  : null,
              child: authorAvatar == null
                  ? Text(
                      authorName.isNotEmpty
                          ? authorName[0].toUpperCase()
                          : '?',
                      style: GoogleFonts.inter(
                          fontSize: 9,
                          color: AppColors.brandRed,
                          fontWeight: FontWeight.w700))
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(authorName,
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkText)),
                  Row(children: [
                    Text(_timeAgo(createdAt),
                        style: GoogleFonts.inter(
                            fontSize: 9,
                            color: AppColors.mutedText)),
                    if (isEdited) ...[
                      const SizedBox(width: 4),
                      Text('· edited',
                          style: GoogleFonts.inter(
                              fontSize: 9,
                              color: AppColors.mutedText,
                              fontStyle:
                                  FontStyle.italic)),
                    ],
                  ]),
                ],
              ),
            ),

            // ─── Like reply ───
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('discussions')
                  .doc(widget.discussionId)
                  .collection('replies')
                  .doc(replyId)
                  .collection('likes')
                  .doc(widget.currentUid)
                  .snapshots(),
              builder: (context, snap) {
                final liked = snap.data?.exists ?? false;
                return GestureDetector(
                  onTap: () =>
                      _toggleReplyLike(replyId, likesCount),
                  child: Row(children: [
                    Icon(
                      liked
                          ? Icons.favorite
                          : Icons.favorite_border,
                      size: 14,
                      color: liked
                          ? AppColors.brandRed
                          : AppColors.mutedText,
                    ),
                    const SizedBox(width: 3),
                    Text('$likesCount',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.mutedText)),
                  ]),
                );
              },
            ),

            // ─── Actions ───
            if (isOwner || _isStaff) ...[
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz,
                    size: 16, color: AppColors.mutedText),
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(12)),
                onSelected: (v) {
                  if (v == 'edit') {
                    setState(() {
                      _editingReplyId = replyId;
                      _replyCtrl.text = body;
                    });
                  } else if (v == 'delete') {
                    _deleteReply(replyId);
                  }
                },
                itemBuilder: (_) => [
                  if (isOwner)
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        const Icon(Icons.edit_outlined,
                            size: 15,
                            color: AppColors.mutedText),
                        const SizedBox(width: 8),
                        Text('Edit',
                            style: GoogleFonts.inter(
                                fontSize: 13)),
                      ]),
                    ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      const Icon(Icons.delete_outline,
                          size: 15, color: Colors.red),
                      const SizedBox(width: 8),
                      Text('Delete',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.red)),
                    ]),
                  ),
                ],
              ),
            ],
          ]),

          const SizedBox(height: 8),

          // ─── Body ───
          Text(body,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.darkText,
                  height: 1.5)),
        ],
      ),
    );
  }
}