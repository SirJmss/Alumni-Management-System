import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:alumni/core/constants/app_colors.dart';
import 'edit_event_screen.dart';

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
  String? _userRole;

  String get eventId => widget.event['id'] as String;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _userRole =
              doc.data()?['role'] as String? ?? 'alumni';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _userRole = 'alumni');
    }
  }

  bool get _canEditOrDelete {
    final currentUid = _auth.currentUser?.uid;
    final creatorUid =
        widget.event['createdBy'] as String?;
    if (currentUid == null) return false;
    if (_userRole == 'admin' ||
        _userRole == 'moderator' ||
        _userRole == 'staff' ||
        _userRole == 'registrar') return true;
    return currentUid == creatorUid;
  }

  Future<void> _toggleLike() async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please sign in to like events')),
      );
      return;
    }

    final likeRef = _firestore
        .collection('events')
        .doc(eventId)
        .collection('likes')
        .doc(user.uid);

    try {
      final doc = await likeRef.get();
      if (doc.exists) {
        await likeRef.delete();
      } else {
        await likeRef
            .set({'likedAt': FieldValue.serverTimestamp()});
      }
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error: ${e.message}'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteEvent() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Event',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: AppColors.brandRed)),
        content: Text(
            'This event will be permanently deleted.',
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

    try {
      await _firestore
          .collection('events')
          .doc(eventId)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Event deleted'),
              backgroundColor: Colors.grey),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _addComment() async {
    final user = _auth.currentUser;
    final text = _commentController.text.trim();
    if (user == null || text.isEmpty) return;

    setState(() => _isPostingComment = true);

    try {
      String userName =
          user.displayName ?? 'Anonymous';
      String? userPhoto = user.photoURL;

      try {
        final doc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists) {
          final data = doc.data();
          userName = data?['name']?.toString() ??
              data?['fullName']?.toString() ??
              userName;
          userPhoto = userPhoto ??
              data?['profilePictureUrl']?.toString();
        }
      } catch (_) {}

      await _firestore
          .collection('events')
          .doc(eventId)
          .collection('comments')
          .add({
        'text': text,
        'userId': user.uid,
        'userName': userName,
        'userPhoto': userPhoto,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _commentController.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isPostingComment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final startTs = event['startDate'] as Timestamp?;
    final dt = startTs?.toDate();
    final dateFormatted = dt != null
        ? DateFormat('EEEE, MMM dd yyyy').format(dt)
        : 'TBD';
    final timeFormatted =
        dt != null ? DateFormat('hh:mm a').format(dt) : 'TBD';
    final endTs = event['endDate'] as Timestamp?;
    final endFormatted = endTs != null
        ? DateFormat('hh:mm a').format(endTs.toDate())
        : null;

    final location =
        event['location']?.toString() ?? 'Location TBD';
    final title =
        event['title']?.toString() ?? 'Event';
    final description =
        event['description']?.toString() ??
            'No description available.';
    final heroImageUrl =
        event['heroImageUrl']?.toString() ?? '';
    final isVirtual =
        event['isVirtual'] as bool? ?? false;
    final isImportant =
        event['isImportant'] as bool? ?? false;
    final type =
        event['type']?.toString() ?? 'Campus Event';
    final maxAttendees = event['maxAttendees'];

    return Scaffold(
      backgroundColor: AppColors.softWhite,
      body: CustomScrollView(
        slivers: [
          // ─── SliverAppBar with image ───
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppColors.cardWhite,
            iconTheme:
                const IconThemeData(color: Colors.white),
            actions: [
              if (_canEditOrDelete) ...[
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      color: Colors.white),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditEventScreen(
                          eventId: eventId,
                          event: widget.event),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.white),
                  onPressed: _deleteEvent,
                ),
              ],
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  heroImageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: heroImageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                              color: AppColors.borderSubtle),
                          errorWidget: (_, __, ___) =>
                              Container(
                            color: AppColors.borderSubtle,
                            child: const Icon(
                                Icons.event_outlined,
                                size: 64,
                                color: AppColors.mutedText),
                          ),
                        )
                      : Container(
                          color: AppColors.brandRed
                              .withOpacity(0.2),
                          child: const Icon(
                              Icons.event_outlined,
                              size: 80,
                              color: AppColors.mutedText),
                        ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.2),
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          _heroBadge(type.toUpperCase(),
                              AppColors.brandRed),
                          if (isVirtual) ...[
                            const SizedBox(width: 6),
                            _heroBadge('VIRTUAL',
                                Colors.blue.shade600),
                          ],
                          if (isImportant) ...[
                            const SizedBox(width: 6),
                            _heroBadge('★ IMPORTANT',
                                Colors.orange.shade700),
                          ],
                        ]),
                        const SizedBox(height: 8),
                        Text(
                          title,
                          style:
                              GoogleFonts.cormorantGaramond(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Info chips ───
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _infoChip(
                              Icons.calendar_today_outlined,
                              dateFormatted),
                          _infoChip(
                              Icons.access_time_outlined,
                              endFormatted != null
                                  ? '$timeFormatted – $endFormatted'
                                  : timeFormatted),
                          _infoChip(
                              Icons.location_on_outlined,
                              location),
                          if (maxAttendees != null)
                            _infoChip(Icons.people_outline,
                                '$maxAttendees max attendees'),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ─── Like / Comment actions ───
                      Row(children: [
                        StreamBuilder<QuerySnapshot>(
                          stream: _firestore
                              .collection('events')
                              .doc(eventId)
                              .collection('likes')
                              .snapshots(),
                          builder: (context, snap) {
                            final count =
                                snap.data?.docs.length ?? 0;
                            final liked = snap.data?.docs.any(
                                    (d) =>
                                        d.id ==
                                        _auth
                                            .currentUser
                                            ?.uid) ??
                                false;
                            return GestureDetector(
                              onTap: _toggleLike,
                              child: Row(children: [
                                Icon(
                                  liked
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: liked
                                      ? AppColors.brandRed
                                      : AppColors.mutedText,
                                  size: 22,
                                ),
                                const SizedBox(width: 6),
                                Text('$count',
                                    style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color:
                                            AppColors.mutedText)),
                              ]),
                            );
                          },
                        ),
                        const SizedBox(width: 20),
                        StreamBuilder<QuerySnapshot>(
                          stream: _firestore
                              .collection('events')
                              .doc(eventId)
                              .collection('comments')
                              .snapshots(),
                          builder: (context, snap) {
                            final count =
                                snap.data?.docs.length ?? 0;
                            return Row(children: [
                              const Icon(
                                  Icons.chat_bubble_outline,
                                  color: AppColors.mutedText,
                                  size: 22),
                              const SizedBox(width: 6),
                              Text('$count',
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color:
                                          AppColors.mutedText)),
                            ]);
                          },
                        ),
                      ]),

                      const SizedBox(height: 24),
                      const Divider(
                          color: AppColors.borderSubtle),
                      const SizedBox(height: 20),

                      // ─── About ───
                      Text('About',
                          style: GoogleFonts.cormorantGaramond(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: AppColors.darkText)),
                      const SizedBox(height: 12),
                      Text(description,
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              height: 1.7,
                              color: AppColors.darkText)),

                      const SizedBox(height: 24),

                      // ─── RSVP card ───
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.cardWhite,
                          borderRadius:
                              BorderRadius.circular(16),
                          border: Border.all(
                              color: AppColors.borderSubtle),
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text('Registration / RSVP',
                                style:
                                    GoogleFonts.cormorantGaramond(
                                        fontSize: 20,
                                        fontWeight:
                                            FontWeight.w600)),
                            const SizedBox(height: 8),
                            Text(
                              'Secure your spot for this event.',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.mutedText),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'RSVP coming soon')),
                                  );
                                },
                                style:
                                    ElevatedButton.styleFrom(
                                  backgroundColor:
                                      AppColors.brandRed,
                                  foregroundColor:
                                      Colors.white,
                                  shape:
                                      RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(
                                            10),
                                  ),
                                ),
                                child: Text('RSVP Now',
                                    style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight:
                                            FontWeight.w600)),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),
                      const Divider(
                          color: AppColors.borderSubtle),
                      const SizedBox(height: 16),

                      // ─── Comments ───
                      Text('Comments',
                          style: GoogleFonts.cormorantGaramond(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: AppColors.darkText)),
                      const SizedBox(height: 16),
                      _buildComments(),
                    ],
                  ),
                ),

                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),

      // ─── Comment input ───
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            MediaQuery.of(context).viewInsets.bottom + 12),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          border: const Border(
              top: BorderSide(color: AppColors.borderSubtle)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor:
                  AppColors.brandRed.withOpacity(0.1),
              child: const Icon(Icons.person,
                  color: AppColors.brandRed, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _commentController,
                style: GoogleFonts.inter(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Write a comment...',
                  hintStyle: GoogleFonts.inter(
                      color: AppColors.mutedText,
                      fontSize: 14),
                  filled: true,
                  fillColor: AppColors.softWhite,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _isPostingComment ? null : _addComment,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.brandRed,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: _isPostingComment
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2),
                      )
                    : const Icon(Icons.send,
                        color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComments() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('events')
          .doc(eventId)
          .collection('comments')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: AppColors.brandRed));
        }
        if (!snapshot.hasData ||
            snapshot.data!.docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('No comments yet. Be the first!',
                  style: GoogleFonts.inter(
                      color: AppColors.mutedText,
                      fontSize: 14)),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          separatorBuilder: (_, __) =>
              const Divider(color: AppColors.borderSubtle),
          itemBuilder: (context, i) {
            final c = snapshot.data!.docs[i].data()
                as Map<String, dynamic>;
            final commentId = snapshot.data!.docs[i].id;
            final ts = c['createdAt'] as Timestamp?;
            final time = ts != null
                ? DateFormat('MMM dd • HH:mm')
                    .format(ts.toDate())
                : '';
            final name =
                c['userName']?.toString() ?? 'Anonymous';
            final photo = c['userPhoto']?.toString();
            final isOwner =
                c['userId'] == _auth.currentUser?.uid;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.borderSubtle,
                    backgroundImage: photo != null
                        ? NetworkImage(photo)
                        : null,
                    child: photo == null
                        ? Text(name[0].toUpperCase(),
                            style: GoogleFonts.inter(
                                color: AppColors.brandRed,
                                fontWeight: FontWeight.w600))
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(name,
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: AppColors.darkText)),
                          const SizedBox(width: 8),
                          Text(time,
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.mutedText)),
                          if (isOwner) ...[
                            const Spacer(),
                            GestureDetector(
                              onTap: () async {
                                await _firestore
                                    .collection('events')
                                    .doc(eventId)
                                    .collection('comments')
                                    .doc(commentId)
                                    .delete();
                              },
                              child: const Icon(
                                  Icons.delete_outline,
                                  size: 16,
                                  color: AppColors.mutedText),
                            ),
                          ],
                        ]),
                        const SizedBox(height: 4),
                        Text(c['text']?.toString() ?? '',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.darkText,
                                height: 1.5)),
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
  }

  Widget _heroBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(text, style: GoogleFonts.inter(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: AppColors.brandRed),
        const SizedBox(width: 6),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.darkText,
                fontWeight: FontWeight.w500)),
      ]),
    );
  }
}