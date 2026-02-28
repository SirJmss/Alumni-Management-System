import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'edit_event_screen.dart'; // Make sure this import is correct

class EventScreen extends StatefulWidget {
  final Map<String, dynamic> event;

  const EventScreen({super.key, required this.event});

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  final _commentController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  bool _isPostingComment = false;

  String get eventId => widget.event['id'] as String;

  // Load current user's role
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _userRole = doc.data()?['role'] as String? ?? 'alumni';
        });
      }
    } catch (_) {
      // Silent fail - treat as alumni
      if (mounted) setState(() => _userRole = 'alumni');
    }
  }

  // Permission: creator OR admin/moderator can edit/delete
  bool get _canEditOrDelete {
    final currentUid = _auth.currentUser?.uid;
    final creatorUid = widget.event['createdBy'] as String?;

    if (currentUid == null) return false;

    // Admin or moderator can edit ANY event
    if (_userRole == 'admin' || _userRole == 'moderator') {
      return true;
    }

    // Otherwise, only the creator can edit their own
    return currentUid == creatorUid;
  }

Future<void> _toggleLike() async {
  final user = _auth.currentUser;
  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please sign in to like events')),
    );
    return;
  }

  final likeRef = _firestore.collection('events').doc(eventId).collection('likes').doc(user.uid);

  try {
    final doc = await likeRef.get();
    if (doc.exists) {
      await likeRef.delete();
    } else {
      await likeRef.set({'likedAt': FieldValue.serverTimestamp()});
    }
  } on FirebaseException catch (e) {
    if (e.code == 'permission-denied') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only alumni can like this event'),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.message}')),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Unexpected error: $e')),
    );
  }
}

  Future<void> _addComment() async {
    final user = _auth.currentUser;
    final text = _commentController.text.trim();
    if (user == null || text.isEmpty) return;

    setState(() => _isPostingComment = true);

    try {
      // Try to get user's display name / photo from auth first, then Firestore `users` doc
      String userName = user.displayName ?? 'Anonymous';
      String? userPhoto = user.photoURL;

      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data();
          userName = userName == 'Anonymous'
              ? (data?['name'] as String? ?? data?['fullName'] as String? ?? userName)
              : userName;
          userPhoto = userPhoto ?? (data?['photoUrl'] as String? ?? data?['photoURL'] as String?);
        }
      } catch (_) {
        // ignore - fall back to auth values
      }

      await _firestore.collection('events').doc(eventId).collection('comments').add({
        'text': text,
        'userId': user.uid,
        'userName': userName,
        'userPhoto': userPhoto,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _commentController.clear();
      FocusScope.of(context).unfocus();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Comment posted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error posting comment: $e')));
      }
    } finally {
      if (mounted) setState(() => _isPostingComment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final startDate = event['startDate'] as Timestamp?;
    final dateStr = startDate != null
        ? DateFormat('MMM dd, yyyy • hh:mm a').format(startDate.toDate())
        : 'Date not set';
    final location = event['location'] as String? ?? 'Location not set';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFFE64646).withOpacity(0.15),
                    child: const Icon(Icons.school, color: Color(0xFFE64646), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'St. Cecilia’s Alumni',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                        Text(
                          dateStr,
                          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.black54),
                    onPressed: () {},
                  ),
                ],
              ),
            ),

            // Main content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Gradient hero section
                    Container(
                      height: MediaQuery.of(context).size.width,
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFFFF6B6B),
                            Color(0xFFFF8E53),
                            Color(0xFFF9D423),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            event['title'] ?? 'Event Title',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [Shadow(blurRadius: 12, color: Colors.black38)],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),

                    // Description / info
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event['description'] ?? 'No description available.',
                            style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.black87),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 18, color: Colors.grey[700]),
                              const SizedBox(width: 8),
                              Text(location, style: TextStyle(fontSize: 14, color: Colors.grey[800])),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.calendar_today, size: 18, color: Colors.grey[700]),
                              const SizedBox(width: 8),
                              Text(dateStr, style: TextStyle(fontSize: 14, color: Colors.grey[800])),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Action bar with Edit & Delete buttons
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Left side: Like, Comment, Share
                          Row(
                            children: [
                              StreamBuilder<QuerySnapshot>(
                                stream: _firestore.collection('events').doc(eventId).collection('likes').snapshots(),
                                builder: (context, snapshot) {
                                  final likeCount = snapshot.data?.docs.length ?? 0;
                                  final isLiked = snapshot.data?.docs.any((doc) => doc.id == _auth.currentUser?.uid) ?? false;

                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      GestureDetector(
                                        onTap: _toggleLike,
                                        child: Icon(
                                          isLiked ? Icons.favorite : Icons.favorite_border,
                                          color: isLiked ? Colors.red : Colors.grey[800],
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      if (likeCount > 0)
                                        Text(
                                          '$likeCount',
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                        ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(width: 32),
                              GestureDetector(
                                onTap: () => FocusScope.of(context).requestFocus(FocusNode()),
                                child: Icon(Icons.chat_bubble_outline, color: Colors.grey[800], size: 28),
                              ),
                              const SizedBox(width: 32),
                              Icon(Icons.share_outlined, color: Colors.grey[800], size: 28),
                            ],
                          ),

                          // Right side: Edit, Delete (only for creator OR admin/moderator)
                          Row(
                            children: [
                              if (_canEditOrDelete)
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Color(0xFFE64646), size: 28),
                                  tooltip: 'Edit Event',
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => EditEventScreen(
                                          eventId: eventId,
                                          event: widget.event,
                                        ),
                                      ),
                                    );
                                  },
                                ),

                              if (_canEditOrDelete)
                                IconButton(
                                  icon: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 28),
                                  tooltip: 'Delete Event',
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        title: const Text('Delete Event', style: TextStyle(color: Colors.red)),
                                        content: const Text('This action cannot be undone. Are you sure?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm != true || !mounted) return;

                                    try {
                                      await _firestore.collection('events').doc(eventId).delete();
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Event deleted'), backgroundColor: Colors.green),
                                        );
                                        Navigator.pop(context); // back to list
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Error deleting: $e'), backgroundColor: Colors.red),
                                        );
                                      }
                                    }
                                  },
                                ),

                              Icon(Icons.bookmark_border, color: Colors.grey[800], size: 28),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Likes count
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _firestore.collection('events').doc(eventId).collection('likes').snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Text('0 likes', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15));
                          }
                          final likeCount = snapshot.data?.docs.length ?? 0;
                          final label = likeCount == 1 ? 'like' : 'likes';
                          return Text(
                            '$likeCount $label',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                          );
                        },
                      ),
                    ),

                    const Divider(height: 1, color: Color(0xFFEEEEEE)),

                    // Comments section
// Comments section
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Comments',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 12),

      StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('events')
            .doc(eventId)
            .collection('comments')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading comments',
                style: TextStyle(color: Colors.red[700]),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No comments yet. Be the first to share your thoughts!',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final comments = snapshot.data!.docs;

          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: comments.length,
            itemBuilder: (context, index) {
              final comment = comments[index].data() as Map<String, dynamic>;
              final timestamp = comment['createdAt'] as Timestamp?;
              final dateStr = timestamp != null
                  ? DateFormat('MMM dd • hh:mm').format(timestamp.toDate())
                  : 'Just now';

              final userName = comment['userName'] as String? ?? 'Anonymous';
              final userPhoto = comment['userPhoto'] as String?;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar with fallback
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFFE64646).withOpacity(0.2),
                      backgroundImage: userPhoto != null && userPhoto.isNotEmpty
                          ? NetworkImage(userPhoto)
                          : null,
                      child: userPhoto == null || userPhoto.isEmpty
                          ? Text(
                              userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                              style: const TextStyle(
                                color: Color(0xFFE64646),
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                userName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                dateStr,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            comment['text'] ?? '',
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.4,
                              color: Colors.black87,
                            ),
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
      ),
    ],
  ),
),
                  ],
                ),
              ),
            ),

            // Bottom comment input bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFFE64646).withOpacity(0.2),
                    child: const Icon(Icons.person, color: Color(0xFFE64646), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: _isPostingComment
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send, color: Color(0xFFE64646)),
                    onPressed: _isPostingComment ? null : _addComment,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}