// =============================================================================
// FILE: lib/features/milestones/presentation/screens/career_milestones_screen.dart
//
// Replaces the old GalleryScreen + dual-tab system.
// Single source of truth: achievement_posts collection.
//
// FLOW:
//   Alumni → "Share Achievement" → upload photo + form → status=pending
//   Admin   → reviews in AdminAchievementQueue → approve/reject
//   Approved posts appear in this feed for all authenticated users.
//
// ROUTE: /career_milestones  (update your router)
// =============================================================================

import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:alumni/core/constants/app_colors.dart';

// ─── Cloudinary config ───────────────────────────────────────────────────────
const _kCloudName    = 'dok63li34';
const _kUploadPreset = 'alumni_uploads';

// =============================================================================
// MODEL
// =============================================================================

enum PostStatus { pending, approved, rejected }

class AchievementPost {
  final String id;
  final String userId, userName, userPhotoUrl;
  final String imageUrl, publicId;
  final String title, caption, category;
  final List<String> tags;
  final PostStatus status;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime? approvedAt;

  const AchievementPost({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhotoUrl,
    required this.imageUrl,
    required this.publicId,
    required this.title,
    required this.caption,
    required this.category,
    required this.tags,
    required this.status,
    required this.createdAt,
    this.rejectionReason,
    this.approvedAt,
  });

  factory AchievementPost.fromMap(String id, Map<String, dynamic> d) {
    return AchievementPost(
      id:              id,
      userId:          d['userId']       ?? '',
      userName:        d['userName']     ?? 'Alumni',
      userPhotoUrl:    d['userPhotoUrl'] ?? '',
      imageUrl:        d['imageUrl']     ?? '',
      publicId:        d['publicId']     ?? '',
      title:           d['title']        ?? '',
      caption:         d['caption']      ?? '',
      category:        d['category']     ?? 'Milestone',
      tags:            List<String>.from(d['tags'] ?? []),
      status:          _parseStatus(d['status']),
      rejectionReason: d['rejectionReason']?.toString(),
      createdAt:       (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      approvedAt:      (d['approvedAt'] as Timestamp?)?.toDate(),
    );
  }

  static PostStatus _parseStatus(dynamic v) {
    switch (v?.toString()) {
      case 'approved': return PostStatus.approved;
      case 'rejected': return PostStatus.rejected;
      default:         return PostStatus.pending;
    }
  }

  bool get isOwnPost =>
      userId == FirebaseAuth.instance.currentUser?.uid;
}

// =============================================================================
// CAREER MILESTONES SCREEN  (user-facing)
// =============================================================================

class CareerMilestonesScreen extends StatefulWidget {
  const CareerMilestonesScreen({super.key});

  @override
  State<CareerMilestonesScreen> createState() =>
      _CareerMilestonesScreenState();
}

class _CareerMilestonesScreenState extends State<CareerMilestonesScreen> {
  // ── Filter state ─────────────────────────────────────────────────────────
  String _activeCategory = 'All';
  bool   _showMyOnly     = false;

  static const _categories = [
    'All', 'Career', 'Awards', 'Education', 'Community', 'Milestone',
  ];

  final _db   = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // ── Streams ───────────────────────────────────────────────────────────────

  Stream<List<AchievementPost>> get _approvedStream => _db
      .collection('achievement_posts')
      .where('status', isEqualTo: 'approved')
      .orderBy('approvedAt', descending: true)
      .snapshots()
      .map((s) => s.docs
          .map((d) => AchievementPost.fromMap(d.id, d.data()))
          .toList());

  Stream<List<AchievementPost>> get _myPostsStream {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _db
        .collection('achievement_posts')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => AchievementPost.fromMap(d.id, d.data()))
            .toList());
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  void _openShare() {
    if (_auth.currentUser == null) {
      _snack('Sign in to share achievements', isError: true);
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareAchievementSheet(
        onSaved: () {
          if (mounted) setState(() => _showMyOnly = true);
        },
      ),
    );
  }

  void _openEdit(AchievementPost post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareAchievementSheet(
        postToEdit: post,
        onSaved: () {},
      ),
    );
  }

  Future<void> _confirmDelete(AchievementPost post) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        contentPadding: EdgeInsets.zero,
        content: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.12),
                  shape: BoxShape.circle),
              child: const Icon(Icons.delete_outline,
                  color: Colors.red, size: 24),
            ),
            const SizedBox(height: 16),
            Text('Delete Post?',
                style: GoogleFonts.cormorantGaramond(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
            const SizedBox(height: 8),
            Text(
              post.status == PostStatus.approved
                  ? 'This removes your post from the milestones feed permanently.'
                  : 'This deletes your pending submission.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.5),
                  height: 1.5),
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: Colors.white.withOpacity(0.2)),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Cancel',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Delete',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );

    if (ok == true) {
      try {
        await _db.collection('achievement_posts').doc(post.id).delete();
        _snack('Post deleted', isError: false);
      } catch (_) {
        _snack('Failed to delete post', isError: true);
      }
    }
  }

  void _snack(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: GoogleFonts.inter()),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 640;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0C),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          // ── Hero sliver ──────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: isMobile ? 240 : 320,
            pinned: true,
            backgroundColor: const Color(0xFF0C0C0C),
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: GestureDetector(
                  onTap: _openShare,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.brandRed,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(children: [
                      const Icon(Icons.add_photo_alternate_outlined,
                          color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text('Share',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ]),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Stack(fit: StackFit.expand, children: [
                // Background gradient — no hardcoded image asset
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1A0A0A), Color(0xFF0C0C0C)],
                    ),
                  ),
                ),
                // Decorative circles
                Positioned(
                  top: -40, right: -40,
                  child: Container(
                    width: 200, height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.brandRed.withOpacity(0.06),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 60, left: -60,
                  child: Container(
                    width: 160, height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.brandRed.withOpacity(0.04),
                    ),
                  ),
                ),
                // Hero text
                Positioned(
                  bottom: 60,
                  left: isMobile ? 24 : 48,
                  right: isMobile ? 24 : 48,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                            width: 20, height: 1,
                            color: AppColors.brandRed),
                        const SizedBox(width: 10),
                        Text('ST. CECILIA\'S  ·  ALUMNI',
                            style: GoogleFonts.inter(
                                fontSize: 9,
                                letterSpacing: 3,
                                color: AppColors.brandRed,
                                fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: 10),
                      Text('Career Milestones.',
                          style: GoogleFonts.cormorantGaramond(
                              fontSize: isMobile ? 38 : 52,
                              fontWeight: FontWeight.w300,
                              color: Colors.white,
                              height: 1.0)),
                      const SizedBox(height: 6),
                      Text('Achievements, recognition, and shared success.',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.4),
                              fontWeight: FontWeight.w300)),
                    ],
                  ),
                ),
              ]),
            ),
          ),

          // ── Sticky filter bar ─────────────────────────────────────────────
          SliverPersistentHeader(
            pinned: true,
            delegate: _FilterHeaderDelegate(
              categories:  _categories,
              active:      _activeCategory,
              showMyOnly:  _showMyOnly,
              onCategory:  (c) => setState(() => _activeCategory = c),
              onToggleMy:  () => setState(() => _showMyOnly = !_showMyOnly),
            ),
          ),
        ],

        // ── Feed ─────────────────────────────────────────────────────────────
        body: StreamBuilder<List<AchievementPost>>(
          stream: _showMyOnly ? _myPostsStream : _approvedStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.brandRed, strokeWidth: 2));
            }

            if (snapshot.hasError) {
              return _ErrorState(
                  message: 'Could not load milestones.\n${snapshot.error}');
            }

            var posts = snapshot.data ?? [];

            if (_activeCategory != 'All') {
              posts = posts
                  .where((p) => p.category == _activeCategory)
                  .toList();
            }

            if (posts.isEmpty) {
              return _EmptyState(
                showMyOnly: _showMyOnly,
                onShare: _openShare,
              );
            }

            return RefreshIndicator(
              color: AppColors.brandRed,
              backgroundColor: const Color(0xFF1A1A1A),
              onRefresh: () async {
                setState(() {});
              },
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(
                    isMobile ? 12 : 40, 16,
                    isMobile ? 12 : 40, 100),
                itemCount: posts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 3),
                itemBuilder: (_, i) => MilestoneCard(
                  post:     posts[i],
                  onEdit:   () => _openEdit(posts[i]),
                  onDelete: () => _confirmDelete(posts[i]),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// =============================================================================
// STICKY FILTER HEADER
// =============================================================================

class _FilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  final List<String> categories;
  final String active;
  final bool showMyOnly;
  final ValueChanged<String> onCategory;
  final VoidCallback onToggleMy;

  const _FilterHeaderDelegate({
    required this.categories,
    required this.active,
    required this.showMyOnly,
    required this.onCategory,
    required this.onToggleMy,
  });

  @override double get minExtent => 88;
  @override double get maxExtent => 88;

  @override
  bool shouldRebuild(_FilterHeaderDelegate old) =>
      old.active != active || old.showMyOnly != showMyOnly;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool _) {
    return Container(
      color: const Color(0xFF0C0C0C),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Category chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: categories.map((cat) {
              final isActive = active == cat;
              return GestureDetector(
                onTap: () => onCategory(cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.brandRed
                        : Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isActive
                          ? AppColors.brandRed
                          : Colors.white.withOpacity(0.1),
                      width: 0.5,
                    ),
                  ),
                  child: Text(cat.toUpperCase(),
                      style: GoogleFonts.inter(
                          fontSize: 9,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w700,
                          color: isActive
                              ? Colors.white
                              : Colors.white.withOpacity(0.5))),
                ),
              );
            }).toList(),
          ),
        ),

        // My posts toggle
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: GestureDetector(
            onTap: onToggleMy,
            child: Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 28, height: 15,
                decoration: BoxDecoration(
                  color: showMyOnly
                      ? AppColors.brandRed
                      : Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  alignment: showMyOnly
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    width: 11, height: 11,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('My posts only',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      color: showMyOnly
                          ? Colors.white
                          : Colors.white.withOpacity(0.4),
                      fontWeight: showMyOnly
                          ? FontWeight.w600
                          : FontWeight.w400)),
            ]),
          ),
        ),
      ]),
    );
  }
}

// =============================================================================
// MILESTONE CARD  (user-facing)
// =============================================================================

class MilestoneCard extends StatelessWidget {
  final AchievementPost post;
  final VoidCallback onEdit, onDelete;

  const MilestoneCard({
    super.key,
    required this.post,
    required this.onEdit,
    required this.onDelete,
  });

  Color get _statusColor {
    switch (post.status) {
      case PostStatus.approved: return Colors.green;
      case PostStatus.rejected: return Colors.red;
      default:                  return Colors.orange;
    }
  }

  String get _statusLabel {
    switch (post.status) {
      case PostStatus.approved: return 'Published';
      case PostStatus.rejected: return 'Rejected';
      default:                  return 'Pending Review';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: post.isOwnPost
              ? _statusColor.withOpacity(0.25)
              : Colors.white.withOpacity(0.06),
          width: post.isOwnPost ? 1.5 : 0.5,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Image ────────────────────────────────────────────────────────
        if (post.imageUrl.isNotEmpty)
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(9)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: CachedNetworkImage(
                imageUrl: post.imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: const Color(0xFF1E1E1E),
                  child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.brandRed.withOpacity(0.5),
                        strokeWidth: 1.5),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: const Color(0xFF1E1E1E),
                  child: Icon(Icons.image_not_supported_outlined,
                      color: Colors.white.withOpacity(0.15), size: 36),
                ),
              ),
            ),
          ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Header row ──────────────────────────────────────────────
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // User avatar
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white.withOpacity(0.06),
                backgroundImage: post.userPhotoUrl.isNotEmpty
                    ? NetworkImage(post.userPhotoUrl)
                    : null,
                child: post.userPhotoUrl.isEmpty
                    ? Text(
                        post.userName.isNotEmpty
                            ? post.userName[0].toUpperCase()
                            : '?',
                        style: GoogleFonts.cormorantGaramond(
                            fontSize: 15,
                            color: Colors.white,
                            fontWeight: FontWeight.w600))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(post.userName,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(
                    _timeAgo(post.createdAt),
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.35)),
                  ),
                ]),
              ),

              // Category badge
              _CategoryChip(label: post.category),

              // Own-post menu
              if (post.isOwnPost) ...[
                const SizedBox(width: 6),
                _PostMenu(
                  onEdit:   post.status != PostStatus.approved ? onEdit : null,
                  onDelete: onDelete,
                  status:   post.status,
                ),
              ],
            ]),

            const SizedBox(height: 12),

            // ── Title ────────────────────────────────────────────────────
            Text(post.title,
                style: GoogleFonts.cormorantGaramond(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 1.2)),

            // ── Caption ──────────────────────────────────────────────────
            if (post.caption.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(post.caption,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.6),
                      height: 1.55),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis),
            ],

            // ── Tags ──────────────────────────────────────────────────────
            if (post.tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: post.tags.map((t) =>
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.brandRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: AppColors.brandRed.withOpacity(0.25),
                        width: 0.5),
                  ),
                  child: Text('#$t',
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          color: AppColors.brandRed,
                          fontWeight: FontWeight.w600)),
                ),
              ).toList()),
            ],

            // ── Own-post status banner ────────────────────────────────────
            if (post.isOwnPost) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: _statusColor.withOpacity(0.25),
                      width: 0.5),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Icon(
                      post.status == PostStatus.approved
                          ? Icons.check_circle_outline
                          : post.status == PostStatus.rejected
                              ? Icons.cancel_outlined
                              : Icons.hourglass_top_rounded,
                      color: _statusColor, size: 13),
                    const SizedBox(width: 6),
                    Text(_statusLabel,
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _statusColor)),
                  ]),
                  if (post.status == PostStatus.pending)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        'Awaiting admin review. Typically reviewed within 24 hours.',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.4),
                            height: 1.4),
                      ),
                    ),
                  if (post.status == PostStatus.rejected &&
                      (post.rejectionReason ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        'Reason: ${post.rejectionReason}',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.red.withOpacity(0.7),
                            height: 1.4),
                      ),
                    ),
                ]),
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60)  return 'Just now';
    if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)    return '${diff.inHours}h ago';
    if (diff.inDays < 7)      return '${diff.inDays}d ago';
    final months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

// =============================================================================
// SHARE / EDIT ACHIEVEMENT BOTTOM SHEET
// =============================================================================

class ShareAchievementSheet extends StatefulWidget {
  final AchievementPost? postToEdit;
  final VoidCallback onSaved;

  const ShareAchievementSheet({
    this.postToEdit,
    required this.onSaved,
    super.key,
  });

  @override
  State<ShareAchievementSheet> createState() =>
      _ShareAchievementSheetState();
}

class _ShareAchievementSheetState extends State<ShareAchievementSheet> {
  final _titleCtrl   = TextEditingController();
  final _captionCtrl = TextEditingController();
  final _tagCtrl     = TextEditingController();

  String     _category        = 'Career';
  Uint8List? _pickedBytes;
  String     _existingImageUrl = '';
  String     _existingPublicId = '';

  final _tags = <String>[];
  bool   _isUploading    = false;
  double _uploadProgress = 0;
  String _uploadStage    = '';

  bool get _isEdit     => widget.postToEdit != null;
  bool get _isApproved => widget.postToEdit?.status == PostStatus.approved;

  static const _categories = [
    'Career', 'Awards', 'Education', 'Community', 'Milestone',
  ];
  static const _tagSuggestions = [
    'promotion', 'graduate', 'award', 'certification',
    'license', 'board exam', 'new job', 'published',
    'volunteer', 'leadership',
  ];

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _titleCtrl.text    = widget.postToEdit!.title;
      _captionCtrl.text  = widget.postToEdit!.caption;
      _category          = widget.postToEdit!.category;
      _existingImageUrl  = widget.postToEdit!.imageUrl;
      _existingPublicId  = widget.postToEdit!.publicId;
      _tags.addAll(widget.postToEdit!.tags);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _captionCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  // ── Pick image ────────────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    if (_isApproved) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setState(() => _pickedBytes = bytes);
    } catch (e) {
      _snack('Could not pick image: $e', isError: true);
    }
  }

  // ── Upload to Cloudinary ──────────────────────────────────────────────────
  Future<Map<String, String>?> _uploadToCloudinary(Uint8List bytes) async {
    try {
      setState(() {
        _uploadProgress = 0.15;
        _uploadStage    = 'Preparing upload…';
      });

      final uri = Uri.parse(
          'https://api.cloudinary.com/v1_1/$_kCloudName/image/upload');

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _kUploadPreset
        ..fields['folder']        = 'achievements'
        ..files.add(http.MultipartFile.fromBytes(
          'file', bytes,
          filename:
              'milestone_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ));

      setState(() {
        _uploadProgress = 0.45;
        _uploadStage    = 'Uploading to cloud…';
      });

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      setState(() {
        _uploadProgress = 0.85;
        _uploadStage    = 'Finalising…';
      });

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'url':      json['secure_url'] as String,
          'publicId': json['public_id']  as String,
        };
      }
      debugPrint('Cloudinary error: ${response.body}');
      return null;
    } catch (e) {
      debugPrint('Cloudinary exception: $e');
      return null;
    }
  }

  // ── Validation ────────────────────────────────────────────────────────────
  String? _validate() {
    if (_titleCtrl.text.trim().isEmpty) {
      return 'Please enter a title for your milestone.';
    }
    if (_titleCtrl.text.trim().length < 5) {
      return 'Title must be at least 5 characters.';
    }
    if (!_isEdit && _pickedBytes == null) {
      return 'Please select a photo for your milestone.';
    }
    if (_captionCtrl.text.trim().length > 1000) {
      return 'Caption cannot exceed 1000 characters.';
    }
    return null;
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    final error = _validate();
    if (error != null) { _snack(error, isError: true); return; }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { _snack('Sign in to post', isError: true); return; }

    setState(() { _isUploading = true; _uploadProgress = 0; });

    try {
      String imageUrl = _existingImageUrl;
      String publicId = _existingPublicId;

      if (_pickedBytes != null) {
        setState(() {
          _uploadStage    = 'Uploading photo…';
          _uploadProgress = 0.1;
        });
        final result = await _uploadToCloudinary(_pickedBytes!);
        if (result == null) {
          _snack('Image upload failed. Check your connection and try again.',
              isError: true);
          setState(() => _isUploading = false);
          return;
        }
        imageUrl = result['url']!;
        publicId = result['publicId']!;
      }

      setState(() {
        _uploadStage    = 'Saving…';
        _uploadProgress = 0.95;
      });

      // Fetch user display name + avatar
      String userName     = user.displayName ?? 'Alumni';
      String userPhotoUrl = user.photoURL    ?? '';
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users').doc(user.uid).get();
        if (doc.exists) {
          userName = doc.data()?['name']?.toString() ??
                     doc.data()?['fullName']?.toString() ??
                     userName;
          userPhotoUrl =
              doc.data()?['profilePictureUrl']?.toString() ??
              userPhotoUrl;
        }
      } catch (_) {}

      final db   = FirebaseFirestore.instance;
      final data = <String, dynamic>{
        'userId':       user.uid,
        'userName':     userName,
        'userPhotoUrl': userPhotoUrl,
        'imageUrl':     imageUrl,
        'publicId':     publicId,
        'title':        _titleCtrl.text.trim(),
        'caption':      _captionCtrl.text.trim(),
        'category':     _category,
        'tags':         List<String>.from(_tags),
        'updatedAt':    FieldValue.serverTimestamp(),
      };

      if (_isEdit) {
        if (!_isApproved) data['status'] = 'pending';
        await db.collection('achievement_posts')
            .doc(widget.postToEdit!.id)
            .update(data);
        _snack('Post updated! Awaiting review.', isError: false);
      } else {
        data['status']    = 'pending';
        data['createdAt'] = FieldValue.serverTimestamp();
        await db.collection('achievement_posts').add(data);
        _snack(
            'Milestone submitted! It will appear after admin review.',
            isError: false);
      }

      setState(() => _uploadProgress = 1.0);
      await Future.delayed(const Duration(milliseconds: 300));

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      debugPrint('Submit error: $e');
      _snack('Something went wrong. Please try again.', isError: true);
      setState(() => _isUploading = false);
    }
  }

  // ── Tag helpers ───────────────────────────────────────────────────────────
  void _addTag(String raw) {
    final tag = raw.trim().replaceAll('#', '').toLowerCase();
    if (tag.isEmpty || tag.length > 30) return;
    if (_tags.contains(tag)) {
      _snack('"#$tag" already added', isError: false);
      return;
    }
    if (_tags.length >= 8) {
      _snack('Maximum 8 tags allowed', isError: true);
      return;
    }
    setState(() => _tags.add(tag));
    _tagCtrl.clear();
  }

  void _snack(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: GoogleFonts.inter()),
        backgroundColor:
            isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.93,
      maxChildSize:     0.97,
      minChildSize:     0.5,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF141414),
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                    _isEdit ? 'Edit Milestone' : 'Share Milestone',
                    style: GoogleFonts.cormorantGaramond(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                  Text(
                    _isEdit && _isApproved
                        ? 'Caption and tags only — image locked'
                        : 'Submitted for admin review before publishing',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.4)),
                  ),
                ]),
              ),
              if (!_isUploading)
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close,
                        color: Colors.white.withOpacity(0.6), size: 16),
                  ),
                ),
            ]),
          ),

          const Divider(height: 1, color: Color(0xFF242424)),

          // Upload progress bar
          if (_isUploading)
            Container(
              margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.brandRed.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.brandRed.withOpacity(0.3)),
              ),
              child: Column(children: [
                Row(children: [
                  SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                        value: _uploadProgress,
                        strokeWidth: 2,
                        color: AppColors.brandRed),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_uploadStage,
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.7))),
                  ),
                  Text('${(_uploadProgress * 100).toInt()}%',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.brandRed,
                          fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: _uploadProgress,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    valueColor: const AlwaysStoppedAnimation(
                        AppColors.brandRed),
                    minHeight: 3,
                  ),
                ),
              ]),
            ),

          // Form
          Expanded(
            child: AbsorbPointer(
              absorbing: _isUploading,
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.all(20),
                children: [

                  // ── Image picker ─────────────────────────────────────
                  GestureDetector(
                    onTap: _isApproved ? null : _pickImage,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 210,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _pickedBytes != null
                              ? AppColors.brandRed.withOpacity(0.5)
                              : Colors.white.withOpacity(0.1),
                          width: _pickedBytes != null ? 1.5 : 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: _buildImagePickerContent(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Info notice
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.blue.withOpacity(0.15),
                          width: 0.5),
                    ),
                    child: Row(children: [
                      const Icon(Icons.info_outline,
                          size: 14, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isEdit && _isApproved
                              ? 'This post is approved. Only caption and tags can be updated.'
                              : 'Posts are reviewed by admins before appearing publicly. Typical wait is 24 hours.',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.blue.withOpacity(0.8),
                              height: 1.4),
                        ),
                      ),
                    ]),
                  ),

                  const SizedBox(height: 20),

                  // Title
                  _DarkField(
                    controller: _titleCtrl,
                    label: 'Milestone Title *',
                    hint: 'e.g. Passed the Philippine Board Exam',
                    maxLength: 100,
                  ),
                  const SizedBox(height: 14),

                  // Caption
                  _DarkField(
                    controller: _captionCtrl,
                    label: 'Caption (optional)',
                    hint:
                        'Tell your story — what happened, how you got here…',
                    maxLines: 5,
                    maxLength: 1000,
                  ),
                  const SizedBox(height: 16),

                  // Category picker
                  _DarkLabel('Category *'),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8,
                    children: _categories.map((cat) {
                      final sel = _category == cat;
                      return GestureDetector(
                        onTap: () => setState(() => _category = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: sel
                                ? AppColors.brandRed
                                : Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: sel
                                  ? AppColors.brandRed
                                  : Colors.white.withOpacity(0.1),
                              width: 0.5,
                            ),
                          ),
                          child: Text(cat,
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: sel
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.5))),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // Tags
                  _DarkLabel('Tags (optional, max 8)'),
                  const SizedBox(height: 8),
                  if (_tags.isNotEmpty)
                    Wrap(spacing: 6, runSpacing: 6,
                      children: _tags.map((tag) => GestureDetector(
                        onTap: () => setState(() => _tags.remove(tag)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.brandRed.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: AppColors.brandRed.withOpacity(0.3),
                                width: 0.5),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text('#$tag',
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppColors.brandRed,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(width: 5),
                            Icon(Icons.close, size: 11,
                                color: AppColors.brandRed.withOpacity(0.6)),
                          ]),
                        ),
                      )).toList(),
                    ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: _DarkField(
                        controller: _tagCtrl,
                        label: '',
                        hint: 'Add a tag and press Enter…',
                        onSubmitted: _addTag,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _addTag(_tagCtrl.text),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.brandRed.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.add,
                            color: AppColors.brandRed, size: 18),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  // Suggestions
                  Wrap(spacing: 6, runSpacing: 6,
                    children: _tagSuggestions
                        .where((s) => !_tags.contains(s))
                        .take(6)
                        .map((s) => GestureDetector(
                          onTap: () => _addTag(s),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.08),
                                  width: 0.5),
                            ),
                            child: Text('+ $s',
                                style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: Colors.white.withOpacity(0.35))),
                          ),
                        )).toList(),
                  ),

                  const SizedBox(height: 32),

                  // Submit button
                  SizedBox(
                    width: double.infinity, height: 52,
                    child: ElevatedButton(
                      onPressed: _isUploading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandRed,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            AppColors.brandRed.withOpacity(0.4),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isUploading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                    width: 16, height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white)),
                                const SizedBox(width: 10),
                                Text(
                                    _uploadStage.isEmpty
                                        ? 'Uploading…'
                                        : _uploadStage,
                                    style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                              ],
                            )
                          : Text(
                              _isEdit ? 'SAVE CHANGES' : 'SUBMIT FOR REVIEW',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildImagePickerContent() {
    if (_pickedBytes != null) {
      return Stack(fit: StackFit.expand, children: [
        Image.memory(_pickedBytes!, fit: BoxFit.cover),
        Positioned(
          top: 8, right: 8,
          child: GestureDetector(
            onTap: _pickImage,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.edit_outlined,
                  color: Colors.white, size: 14),
            ),
          ),
        ),
      ]);
    }

    if (_existingImageUrl.isNotEmpty) {
      return Stack(fit: StackFit.expand, children: [
        CachedNetworkImage(
          imageUrl: _existingImageUrl, fit: BoxFit.cover),
        if (!_isApproved)
          Positioned(
            top: 8, right: 8,
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.edit_outlined,
                    color: Colors.white, size: 14),
              ),
            ),
          ),
        if (_isApproved)
          Positioned(
            bottom: 8, left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.65),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('Image locked after approval',
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      color: Colors.white.withOpacity(0.6))),
            ),
          ),
      ]);
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: AppColors.brandRed.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.add_photo_alternate_outlined,
              color: AppColors.brandRed, size: 26),
        ),
        const SizedBox(height: 12),
        Text('Tap to select photo',
            style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.white.withOpacity(0.4),
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text('JPG or PNG · Max 10 MB',
            style: GoogleFonts.inter(
                fontSize: 10,
                color: Colors.white.withOpacity(0.2))),
      ],
    );
  }
}

// =============================================================================
// ADMIN ACHIEVEMENT QUEUE
// Embed in any admin screen. Prominently shows submitted photo for review.
// =============================================================================

class AdminAchievementQueue extends StatelessWidget {
  /// If [showAll] is true, shows all statuses (for management view).
  /// Default: shows only pending posts.
  final bool showAll;

  const AdminAchievementQueue({super.key, this.showAll = false});

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('achievement_posts')
        .orderBy('createdAt', descending: false);

    if (!showAll) {
      query = query.where('status', isEqualTo: 'pending');
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator(
                color: AppColors.brandRed, strokeWidth: 2)),
          );
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                const Icon(Icons.check_circle_outline,
                    size: 52, color: AppColors.borderSubtle),
                const SizedBox(height: 12),
                Text(
                  showAll
                      ? 'No posts yet'
                      : 'All caught up — no pending posts',
                  style: GoogleFonts.inter(
                      fontSize: 14, color: AppColors.mutedText),
                ),
              ]),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final post = AchievementPost.fromMap(
                docs[i].id, docs[i].data());
            return _AdminPostCard(post: post);
          },
        );
      },
    );
  }
}

// =============================================================================
// ADMIN POST CARD  — image prominently shown for visual review
// =============================================================================

class _AdminPostCard extends StatefulWidget {
  final AchievementPost post;
  const _AdminPostCard({required this.post});

  @override
  State<_AdminPostCard> createState() => _AdminPostCardState();
}

class _AdminPostCardState extends State<_AdminPostCard> {
  bool _isActing = false;
  final _reasonCtrl = TextEditingController();

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Color get _statusColor {
    switch (widget.post.status) {
      case PostStatus.approved: return Colors.green;
      case PostStatus.rejected: return Colors.red;
      default:                  return Colors.orange;
    }
  }

  Future<void> _approve() async {
    setState(() => _isActing = true);
    try {
      await FirebaseFirestore.instance
          .collection('achievement_posts')
          .doc(widget.post.id)
          .update({
        'status':          'approved',
        'approvedAt':      FieldValue.serverTimestamp(),
        'rejectionReason': FieldValue.delete(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Approved: ${widget.post.title}',
              style: GoogleFonts.inter()),
          backgroundColor: Colors.green.shade700,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e', style: GoogleFonts.inter()),
          backgroundColor: Colors.red.shade700,
        ));
      }
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _reject() async {
    _reasonCtrl.clear();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        title: Text('Reject Post',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Provide a rejection reason (shown to the user):',
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.mutedText)),
          const SizedBox(height: 10),
          TextField(
            controller: _reasonCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText:
                  'e.g. Image quality too low, or content unrelated to career milestones',
              hintStyle: GoogleFonts.inter(fontSize: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: AppColors.brandRed),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text('Cancel',
                style: GoogleFonts.inter(
                    color: AppColors.mutedText)),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, _reasonCtrl.text.trim()),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            child: Text('Reject',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (reason == null) return;

    setState(() => _isActing = true);
    try {
      await FirebaseFirestore.instance
          .collection('achievement_posts')
          .doc(widget.post.id)
          .update({
        'status':          'rejected',
        'rejectionReason': reason.isEmpty
            ? 'Does not meet posting guidelines.'
            : reason,
        'rejectedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e', style: GoogleFonts.inter()),
          backgroundColor: Colors.red.shade700,
        ));
      }
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        title: Text('Delete Post',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: AppColors.brandRed)),
        content: Text(
          'Permanently delete "${widget.post.title}"? This cannot be undone.',
          style: GoogleFonts.inter(),
        ),
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
                    color: Colors.red,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (ok != true) return;
    try {
      await FirebaseFirestore.instance
          .collection('achievement_posts')
          .doc(widget.post.id)
          .delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _statusColor.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Status header bar ─────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _statusColor.withOpacity(0.07),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(13)),
          ),
          child: Row(children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                  color: _statusColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              post.status == PostStatus.pending
                  ? 'PENDING REVIEW'
                  : post.status == PostStatus.approved
                      ? 'APPROVED'
                      : 'REJECTED',
              style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: _statusColor,
                  letterSpacing: 1),
            ),
            const Spacer(),
            Text(
              _timeAgo(post.createdAt),
              style: GoogleFonts.inter(
                  fontSize: 10, color: AppColors.mutedText),
            ),
          ]),
        ),

        // ── SUBMITTED PHOTO — prominent for admin review ───────────────────
        if (post.imageUrl.isNotEmpty)
          Stack(children: [
            ClipRRect(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: post.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: const Color(0xFFF5F5F5),
                    child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.brandRed.withOpacity(0.5),
                            strokeWidth: 1.5)),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: AppColors.borderSubtle,
                    height: 180,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image_outlined,
                            color: AppColors.mutedText, size: 36),
                        const SizedBox(height: 8),
                        Text('Image unavailable',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.mutedText)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Overlay label: "SUBMITTED PHOTO"
            Positioned(
              top: 10, left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(children: [
                  const Icon(Icons.image_outlined,
                      color: Colors.white, size: 11),
                  const SizedBox(width: 5),
                  Text('SUBMITTED PHOTO',
                      style: GoogleFonts.inter(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.8)),
                ]),
              ),
            ),
          ])
        else
          Container(
            height: 100,
            color: AppColors.softWhite,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image_not_supported_outlined,
                      color: AppColors.borderSubtle, size: 32),
                  const SizedBox(height: 6),
                  Text('No image submitted',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.mutedText)),
                ],
              ),
            ),
          ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // ── Submitter info ─────────────────────────────────────────
            Row(children: [
              CircleAvatar(
                radius: 20,
                backgroundColor:
                    AppColors.brandRed.withOpacity(0.08),
                backgroundImage: post.userPhotoUrl.isNotEmpty
                    ? NetworkImage(post.userPhotoUrl)
                    : null,
                child: post.userPhotoUrl.isEmpty
                    ? Text(
                        post.userName.isNotEmpty
                            ? post.userName[0].toUpperCase()
                            : '?',
                        style: GoogleFonts.inter(
                            color: AppColors.brandRed,
                            fontSize: 14,
                            fontWeight: FontWeight.w700))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(post.userName,
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkText)),
                  Text('Submitted ${_timeAgo(post.createdAt)}',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.mutedText)),
                ]),
              ),
              _CategoryChip(label: post.category, dark: false),
            ]),

            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.borderSubtle),
            const SizedBox(height: 12),

            // ── Post content ───────────────────────────────────────────
            Text(post.title,
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText)),
            if (post.caption.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(post.caption,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.mutedText,
                      height: 1.5),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis),
            ],

            if (post.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 5, runSpacing: 5,
                children: post.tags.map((t) => Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.brandRed.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: AppColors.brandRed.withOpacity(0.2),
                        width: 0.5),
                  ),
                  child: Text('#$t',
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          color: AppColors.brandRed,
                          fontWeight: FontWeight.w600)),
                )).toList(),
              ),
            ],

            // Rejection reason if present
            if (post.status == PostStatus.rejected &&
                (post.rejectionReason ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.red.withOpacity(0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline,
                      color: Colors.red, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Rejection reason: ${post.rejectionReason}',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.red.shade700,
                          height: 1.4),
                    ),
                  ),
                ]),
              ),
            ],

            const SizedBox(height: 16),

            // ── Action buttons ─────────────────────────────────────────
            if (post.status == PostStatus.pending) ...[
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isActing ? null : _reject,
                    icon: const Icon(Icons.cancel_outlined,
                        size: 14, color: Colors.red),
                    label: Text('Reject',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _isActing ? null : _approve,
                    icon: _isActing
                        ? const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                        : const Icon(Icons.check_circle_outline,
                            size: 14, color: Colors.white),
                    label: Text('Approve & Publish',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ]),
            ] else ...[
              // Approved / rejected — only delete available
              Row(children: [
                if (post.status == PostStatus.approved)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isActing ? null : _reject,
                      icon: const Icon(Icons.unpublished_outlined,
                          size: 14),
                      label: Text('Revoke Approval',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(
                            color: Colors.orange),
                        padding: const EdgeInsets.symmetric(
                            vertical: 11),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                if (post.status == PostStatus.rejected)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isActing ? null : _approve,
                      icon: const Icon(
                          Icons.check_circle_outline,
                          size: 14, color: Colors.white),
                      label: Text('Re-approve',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            vertical: 11),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _isActing ? null : _delete,
                  icon: const Icon(Icons.delete_outline,
                      size: 14, color: Colors.red),
                  label: Text('Delete',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60)  return 'Just now';
    if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)    return '${diff.inHours}h ago';
    if (diff.inDays < 7)      return '${diff.inDays}d ago';
    const m = ['Jan','Feb','Mar','Apr','May','Jun',
                'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[dt.month-1]} ${dt.day}, ${dt.year}';
  }
}

// =============================================================================
// SHARED SMALL WIDGETS
// =============================================================================

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool dark;
  const _CategoryChip({required this.label, this.dark = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.brandRed.withOpacity(dark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
            color: AppColors.brandRed.withOpacity(dark ? 0.3 : 0.2),
            width: 0.5),
      ),
      child: Text(label.toUpperCase(),
          style: GoogleFonts.inter(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: AppColors.brandRed,
              letterSpacing: 0.8)),
    );
  }
}

class _PostMenu extends StatelessWidget {
  final VoidCallback? onEdit;
  final VoidCallback onDelete;
  final PostStatus status;

  const _PostMenu({
    required this.onEdit,
    required this.onDelete,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_horiz,
          color: Colors.white.withOpacity(0.4), size: 18),
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
      onSelected: (v) {
        if (v == 'edit')   onEdit?.call();
        if (v == 'delete') onDelete();
      },
      itemBuilder: (_) => [
        if (onEdit != null)
          PopupMenuItem(
            value: 'edit',
            child: Row(children: [
              const Icon(Icons.edit_outlined,
                  color: Colors.white, size: 16),
              const SizedBox(width: 10),
              Text('Edit Post',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: Colors.white)),
            ]),
          ),
        if (status == PostStatus.approved)
          PopupMenuItem(
            enabled: false,
            child: Row(children: [
              Icon(Icons.edit_off_outlined,
                  color: Colors.white.withOpacity(0.3), size: 16),
              const SizedBox(width: 10),
              Text('Cannot edit approved post',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.3))),
            ]),
          ),
        PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            const Icon(Icons.delete_outline,
                color: Colors.red, size: 16),
            const SizedBox(width: 10),
            Text('Delete',
                style: GoogleFonts.inter(
                    fontSize: 13, color: Colors.red)),
          ]),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool showMyOnly;
  final VoidCallback onShare;
  const _EmptyState({required this.showMyOnly, required this.onShare});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: AppColors.brandRed.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.emoji_events_outlined,
                  size: 36, color: AppColors.brandRed),
            ),
            const SizedBox(height: 16),
            Text(
              showMyOnly ? 'No posts yet' : 'No milestones here yet',
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 22, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              showMyOnly
                  ? 'Share your first career milestone with the alumni community.'
                  : 'Be the first to share a career milestone.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.4),
                  height: 1.5),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onShare,
              icon: const Icon(Icons.add_photo_alternate_outlined,
                  size: 16),
              label: Text('Share Achievement',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandRed,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_outlined,
                size: 48, color: Colors.white.withOpacity(0.15)),
            const SizedBox(height: 14),
            Text(message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.35),
                    height: 1.5)),
          ],
        ),
      ),
    );
  }
}

class _DarkLabel extends StatelessWidget {
  final String text;
  const _DarkLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.white.withOpacity(0.4),
            letterSpacing: 1));
  }
}

class _DarkField extends StatelessWidget {
  final TextEditingController controller;
  final String label, hint;
  final int maxLines;
  final int? maxLength;
  final ValueChanged<String>? onSubmitted;

  const _DarkField({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
    this.maxLength,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (label.isNotEmpty) ...[
        _DarkLabel(label),
        const SizedBox(height: 6),
      ],
      TextField(
        controller:   controller,
        maxLines:     maxLines,
        maxLength:    maxLength,
        onSubmitted:  onSubmitted,
        style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white.withOpacity(0.2)),
          counterStyle: GoogleFonts.inter(
              fontSize: 10,
              color: Colors.white.withOpacity(0.25)),
          filled:       true,
          fillColor:    Colors.white.withOpacity(0.04),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
                color: Colors.white.withOpacity(0.1), width: 0.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
                color: Colors.white.withOpacity(0.1), width: 0.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
                color: AppColors.brandRed.withOpacity(0.6), width: 1),
          ),
        ),
      ),
    ]);
  }
}