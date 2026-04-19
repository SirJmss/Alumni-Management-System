// ─────────────────────────────────────────────────────────────────────────────
// GalleryScreen + Achievement Posts
// FILE: lib/features/gallery/presentation/screens/gallery_screen.dart
//
// CLOUDINARY CONFIG (matches project settings):
//   Cloud name : dok63li34
//   Upload preset: alumni_uploads  (unsigned)
//
// FIRESTORE COLLECTIONS:
//   gallery_posts/{id}          — approved official posts + user posts
//   achievement_posts/{id}      — user achievement submissions
//     fields: userId, userName, userPhotoUrl, imageUrl, publicId,
//             title, caption, category, tags[], status (pending/approved/rejected),
//             rejectionReason, createdAt, updatedAt, approvedAt
//
// FLOW:
//   1. Alumni taps "Share Achievement" → bottom sheet → fills form → upload to Cloudinary
//   2. Post saved to achievement_posts with status='pending'
//   3. Admin sees pending posts in User Verification / Admin Dashboard
//   4. Admin approves → status='approved' → post appears in gallery
//   5. Alumni can edit (text only, not image) or delete their pending/approved posts
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';


import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:alumni/core/constants/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CLOUDINARY CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────
const _cloudName    = 'dok63li34';
const _uploadPreset = 'alumni_uploads';

// ─────────────────────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────────────────────

class OfficialGalleryItem {
  final String image, title, category, year, description;
  OfficialGalleryItem.fromMap(Map<String, dynamic> m)
      : image       = m['image'] ?? '',
        title       = m['title'] ?? '',
        category    = m['category'] ?? '',
        year        = m['year'] ?? '',
        description = m['description'] ?? '';
}

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

  AchievementPost.fromMap(String id, Map<String, dynamic> d)
      : id              = id,
        userId          = d['userId']       ?? '',
        userName        = d['userName']     ?? 'Alumni',
        userPhotoUrl    = d['userPhotoUrl'] ?? '',
        imageUrl        = d['imageUrl']     ?? '',
        publicId        = d['publicId']     ?? '',
        title           = d['title']        ?? '',
        caption         = d['caption']      ?? '',
        category        = d['category']     ?? 'Milestone',
        tags            = List<String>.from(d['tags'] ?? []),
        status          = _parseStatus(d['status']),
        rejectionReason = d['rejectionReason'],
        createdAt       = (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        approvedAt      = (d['approvedAt'] as Timestamp?)?.toDate();

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

// ─────────────────────────────────────────────────────────────────────────────
// MAIN GALLERY SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen>
    with SingleTickerProviderStateMixin {
  // tabs: 0 = The Archive (official), 1 = Achievements (community)
  late final TabController _tab;
  String _activeCategory = 'All';
  bool _showMyPostsOnly  = false;

  final _db   = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  static const _archiveCategories = [
    'All', 'Campus', 'Events', 'Reunions', 'Milestones'
  ];
  static const _achievementCategories = [
    'All', 'Career', 'Awards', 'Education', 'Community', 'Milestone'
  ];

  static const _officialItems = [
    {'image': 'assets/images/gallery/pic1.png',    'title': 'Golden Horizon',    'category': 'Campus',     'year': '2024', 'description': 'A breathtaking sunset over the serene campus grounds.'},
    {'image': 'assets/images/gallery/pic2.jpg',    'title': 'Urban Elegance',    'category': 'Campus',     'year': '2023', 'description': 'Modern architecture illuminated by twilight.'},
    {'image': 'assets/images/gallery/pic3.jpg',    'title': 'Forest Whisper',    'category': 'Events',     'year': '2023', 'description': 'Ancient trees standing tall amidst morning mist.'},
    {'image': 'assets/images/gallery/building.jpg','title': 'The Grand Hall',    'category': 'Campus',     'year': '2022', 'description': "The iconic St. Cecilia's main building."},
    {'image': 'assets/images/gallery/pic1.png',    'title': 'Homecoming 2024',   'category': 'Reunions',   'year': '2024', 'description': 'Alumni gathered for the annual grand homecoming.'},
    {'image': 'assets/images/gallery/pic2.jpg',    'title': 'Recognition Night', 'category': 'Milestones', 'year': '2023', 'description': 'Honoring outstanding alumni achievements.'},
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() => _activeCategory = 'All'));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  List<String> get _currentCategories =>
      _tab.index == 0 ? _archiveCategories : _achievementCategories;

  Stream<List<AchievementPost>> get _approvedPostsStream => _db
      .collection('achievement_posts')
      .where('status', isEqualTo: 'approved')
      .orderBy('approvedAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => AchievementPost.fromMap(d.id, d.data())).toList());

  Stream<List<AchievementPost>> get _myPostsStream {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _db
        .collection('achievement_posts')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => AchievementPost.fromMap(d.id, d.data())).toList());
  }

  // ══════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final w        = MediaQuery.of(context).size.width;
    final isMobile = w < 640;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0C),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxScrolled) => [
          // ── Hero AppBar ─────────────────────────────────
          SliverAppBar(
            expandedHeight: isMobile ? 260 : 380,
            pinned: true,
            backgroundColor: const Color(0xFF0C0C0C),
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 16),
                ),
              ),
            ),
            actions: [
              // Share Achievement button
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: GestureDetector(
                  onTap: _openShareAchievement,
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
                Image.asset('assets/images/gallery/building.jpg',
                    fit: BoxFit.cover,
                    opacity: const AlwaysStoppedAnimation(0.35)),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        const Color(0xFF0C0C0C).withOpacity(0.5),
                        const Color(0xFF0C0C0C),
                      ],
                      stops: const [0.3, 0.7, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 60,
                  left: isMobile ? 24 : 48,
                  right: isMobile ? 24 : 48,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(width: 20, height: 1, color: AppColors.brandRed),
                        const SizedBox(width: 10),
                        Text('ST. CECILIA\'S  ·  GALLERY',
                            style: GoogleFonts.inter(
                                fontSize: 9,
                                letterSpacing: 3,
                                color: AppColors.brandRed,
                                fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: 10),
                      Text('The Archive.',
                          style: GoogleFonts.cormorantGaramond(
                              fontSize: isMobile ? 40 : 58,
                              fontWeight: FontWeight.w300,
                              color: Colors.white,
                              height: 1.0)),
                      const SizedBox(height: 6),
                      Text('Memories, milestones, and legacy.',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.45),
                              fontWeight: FontWeight.w300)),
                    ],
                  ),
                ),
              ]),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF0C0C0C),
                  border: Border(
                      bottom: BorderSide(
                          color: Color(0xFF1E1E1E), width: 1)),
                ),
                child: TabBar(
                  controller: _tab,
                  indicatorColor: AppColors.brandRed,
                  indicatorWeight: 2,
                  labelColor: Colors.white,
                  unselectedLabelColor:
                      Colors.white.withOpacity(0.4),
                  labelStyle: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5),
                  unselectedLabelStyle: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w400),
                  tabs: const [
                    Tab(text: 'THE ARCHIVE'),
                    Tab(text: 'ACHIEVEMENTS'),
                  ],
                ),
              ),
            ),
          ),

          // ── Category + filter bar ───────────────────────
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyFilterDelegate(
              categories:  _currentCategories,
              active:      _activeCategory,
              showMyOnly:  _showMyPostsOnly,
              isAchievementTab: _tab.index == 1,
              onCategoryTap: (cat) =>
                  setState(() => _activeCategory = cat),
              onToggleMyPosts: () =>
                  setState(() => _showMyPostsOnly = !_showMyPostsOnly),
            ),
          ),
        ],

        body: TabBarView(
          controller: _tab,
          children: [
            _ArchiveTab(
              officialItems: _officialItems,
              activeCategory: _activeCategory,
              isMobile: isMobile,
            ),
            _AchievementsTab(
              activeCategory: _activeCategory,
              showMyOnly:     _showMyPostsOnly,
              isMobile:       isMobile,
              approvedStream: _approvedPostsStream,
              myPostsStream:  _myPostsStream,
              onEdit:   _openEditAchievement,
              onDelete: _confirmDeletePost,
            ),
          ],
        ),
      ),
    );
  }

  // ── Open share sheet ──────────────────────────────────
  void _openShareAchievement() {
    final user = _auth.currentUser;
    if (user == null) {
      _showSnack('Sign in to share achievements', isError: true);
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareAchievementSheet(onSaved: () {
        if (mounted) {
          _tab.animateTo(1);
          setState(() => _showMyPostsOnly = true);
        }
      }),
    );
  }

  void _openEditAchievement(AchievementPost post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          ShareAchievementSheet(postToEdit: post, onSaved: () {}),
    );
  }

  Future<void> _confirmDeletePost(AchievementPost post) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        contentPadding: EdgeInsets.zero,
        content: Container(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
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
                  ? 'This will remove your post from the gallery permanently. This cannot be undone.'
                  : 'This will delete your pending submission. This cannot be undone.',
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

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('achievement_posts')
            .doc(post.id)
            .delete();
        _showSnack('Post deleted', isError: false);
      } catch (e) {
        _showSnack('Failed to delete post', isError: true);
      }
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: GoogleFonts.inter()),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STICKY FILTER HEADER DELEGATE
// ─────────────────────────────────────────────────────────────────────────────

class _StickyFilterDelegate extends SliverPersistentHeaderDelegate {
  final List<String> categories;
  final String active;
  final bool showMyOnly;
  final bool isAchievementTab;
  final ValueChanged<String> onCategoryTap;
  final VoidCallback onToggleMyPosts;

  const _StickyFilterDelegate({
    required this.categories,
    required this.active,
    required this.showMyOnly,
    required this.isAchievementTab,
    required this.onCategoryTap,
    required this.onToggleMyPosts,
  });

  @override
  double get minExtent => isAchievementTab ? 88 : 52;
  @override
  double get maxExtent => isAchievementTab ? 88 : 52;

  @override
  bool shouldRebuild(_StickyFilterDelegate old) =>
      old.active != active ||
      old.showMyOnly != showMyOnly ||
      old.isAchievementTab != isAchievementTab ||
      old.categories != categories;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFF0C0C0C),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories.map((cat) {
                final isActive = active == cat;
                return GestureDetector(
                  onTap: () => onCategoryTap(cat),
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

          // "My Posts" toggle (achievements tab only)
          if (isAchievementTab)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: GestureDetector(
                onTap: onToggleMyPosts,
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
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ARCHIVE TAB (official items only)
// ─────────────────────────────────────────────────────────────────────────────

class _ArchiveTab extends StatelessWidget {
  final List<Map<String, dynamic>> officialItems;
  final String activeCategory;
  final bool isMobile;

  const _ArchiveTab({
    required this.officialItems,
    required this.activeCategory,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = activeCategory == 'All'
        ? officialItems
        : officialItems
            .where((e) => e['category'] == activeCategory)
            .toList();

    if (filtered.isEmpty) {
      return _EmptyState(
        icon: Icons.photo_library_outlined,
        message: 'No photos in this category yet.',
        dark: true,
      );
    }

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
          isMobile ? 12 : 40, 16, isMobile ? 12 : 40, 100),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 1 : 2,
        crossAxisSpacing: 3,
        mainAxisSpacing: 3,
        childAspectRatio: isMobile ? 1.3 : 1.15,
      ),
      itemCount: filtered.length,
      itemBuilder: (_, i) {
        final item = OfficialGalleryItem.fromMap(filtered[i]);
        return _OfficialCard(item: item);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACHIEVEMENTS TAB
// ─────────────────────────────────────────────────────────────────────────────

class _AchievementsTab extends StatelessWidget {
  final String activeCategory;
  final bool showMyOnly, isMobile;
  final Stream<List<AchievementPost>> approvedStream;
  final Stream<List<AchievementPost>> myPostsStream;
  final void Function(AchievementPost) onEdit;
  final void Function(AchievementPost) onDelete;

  const _AchievementsTab({
    required this.activeCategory,
    required this.showMyOnly,
    required this.isMobile,
    required this.approvedStream,
    required this.myPostsStream,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final stream = showMyOnly ? myPostsStream : approvedStream;

    return StreamBuilder<List<AchievementPost>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
                color: AppColors.brandRed, strokeWidth: 2),
          );
        }

        var posts = snapshot.data ?? [];

        if (activeCategory != 'All') {
          posts = posts
              .where((p) => p.category == activeCategory)
              .toList();
        }

        if (posts.isEmpty) {
          return _EmptyState(
            icon: Icons.emoji_events_outlined,
            message: showMyOnly
                ? 'You haven\'t shared any achievements yet.'
                : 'No achievements posted yet. Be the first!',
            dark: true,
          );
        }

        return ListView.separated(
          padding: EdgeInsets.fromLTRB(
              isMobile ? 12 : 40, 16, isMobile ? 12 : 40, 100),
          itemCount: posts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 3),
          itemBuilder: (_, i) => _AchievementCard(
            post:     posts[i],
            onEdit:   () => onEdit(posts[i]),
            onDelete: () => onDelete(posts[i]),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OFFICIAL CARD (archive tab)
// ─────────────────────────────────────────────────────────────────────────────

class _OfficialCard extends StatelessWidget {
  final OfficialGalleryItem item;
  const _OfficialCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Stack(fit: StackFit.expand, children: [
        Image.asset(item.image, fit: BoxFit.cover),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.4),
                Colors.black.withOpacity(0.85),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CategoryBadge(label: item.category),
                const SizedBox(height: 6),
                Text(item.title,
                    style: GoogleFonts.cormorantGaramond(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.1),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                if (item.year.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(item.year,
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.5),
                          letterSpacing: 1)),
                ],
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACHIEVEMENT CARD (community posts)
// ─────────────────────────────────────────────────────────────────────────────

class _AchievementCard extends StatelessWidget {
  final AchievementPost post;
  final VoidCallback onEdit, onDelete;

  const _AchievementCard({
    required this.post,
    required this.onEdit,
    required this.onDelete,
  });

  Color get _statusColor {
    switch (post.status) {
      case PostStatus.approved:  return Colors.green;
      case PostStatus.rejected:  return Colors.red;
      default:                   return Colors.orange;
    }
  }

  String get _statusLabel {
    switch (post.status) {
      case PostStatus.approved:  return 'Approved';
      case PostStatus.rejected:  return 'Rejected';
      default:                   return 'Pending Review';
    }
  }

  IconData get _statusIcon {
    switch (post.status) {
      case PostStatus.approved:  return Icons.check_circle_outline;
      case PostStatus.rejected:  return Icons.cancel_outlined;
      default:                   return Icons.hourglass_top_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: post.isOwnPost
              ? _statusColor.withOpacity(0.25)
              : Colors.white.withOpacity(0.06),
          width: post.isOwnPost ? 1.5 : 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Image ────────────────────────────────────
          if (post.imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(7)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: post.imageUrl.startsWith('http')
                    ? CachedNetworkImage(
                        imageUrl: post.imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _ImagePlaceholder(),
                      )
                    : _ImagePlaceholder(),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Header row ─────────────────────────
                Row(children: [
                  // User avatar
                  CircleAvatar(
                    radius: 16,
                    backgroundColor:
                        Colors.white.withOpacity(0.08),
                    backgroundImage:
                        post.userPhotoUrl.isNotEmpty
                            ? NetworkImage(post.userPhotoUrl)
                            : null,
                    child: post.userPhotoUrl.isEmpty
                        ? Text(
                            post.userName.isNotEmpty
                                ? post.userName[0].toUpperCase()
                                : '?',
                            style: GoogleFonts.cormorantGaramond(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.w600))
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(post.userName,
                            style: GoogleFonts.inter(
                                fontSize: 12,
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
                      ],
                    ),
                  ),

                  // Category badge
                  _CategoryBadge(label: post.category),

                  // Own post: edit/delete menu
                  if (post.isOwnPost) ...[
                    const SizedBox(width: 6),
                    _PostMenu(
                      onEdit: post.status != PostStatus.approved
                          ? onEdit
                          : null,
                      onDelete: onDelete,
                      status:  post.status,
                    ),
                  ],
                ]),

                const SizedBox(height: 12),

                // ─── Title ──────────────────────────────
                Text(post.title,
                    style: GoogleFonts.cormorantGaramond(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.2)),

                // ─── Caption ────────────────────────────
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

                // ─── Tags ────────────────────────────────
                if (post.tags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(spacing: 6, runSpacing: 6,
                    children: post.tags.map((tag) =>
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
                        child: Text('#$tag',
                            style: GoogleFonts.inter(
                                fontSize: 10,
                                color: AppColors.brandRed,
                                fontWeight: FontWeight.w600)),
                      ),
                    ).toList(),
                  ),
                ],

                // ─── Status banner (own posts only) ──────
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
                          Icon(_statusIcon,
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
                              'Your post is awaiting admin review. It will appear publicly once approved.',
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
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60)  return 'Just now';
    if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)    return '${diff.inHours}h ago';
    if (diff.inDays < 7)      return '${diff.inDays}d ago';
    return DateFormatter.format(dt);
  }
}

class DateFormatter {
  static String format(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// POST MENU (three-dot for own posts)
// ─────────────────────────────────────────────────────────────────────────────

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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

// ─────────────────────────────────────────────────────────────────────────────
// SHARE / EDIT ACHIEVEMENT BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────

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

class _ShareAchievementSheetState
    extends State<ShareAchievementSheet> {
  final _titleCtrl   = TextEditingController();
  final _captionCtrl = TextEditingController();
  final _tagCtrl     = TextEditingController();

  String _category    = 'Career';
  File?  _pickedFile;
  Uint8List? _pickedBytes;
  String _existingImageUrl = '';

  final _tags = <String>[];
  bool _isUploading = false;
  double _uploadProgress = 0;
  String _uploadStage = '';
  
  bool get _isEdit => widget.postToEdit != null;
  bool get _isApproved =>
      widget.postToEdit?.status == PostStatus.approved;

  static const _categories = [
    'Career', 'Awards', 'Education', 'Community', 'Milestone'
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
      _titleCtrl.text   = widget.postToEdit!.title;
      _captionCtrl.text = widget.postToEdit!.caption;
      _category         = widget.postToEdit!.category;
      _existingImageUrl = widget.postToEdit!.imageUrl;
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

  // ── Pick image ───────────────────────────────────────
  Future<void> _pickImage() async {
    if (_isApproved) return; // can't change image of approved post
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setState(() {
        _pickedFile  = File(picked.path);
        _pickedBytes = bytes;
      });
    } catch (e) {
      _showSnack('Could not pick image: $e', isError: true);
    }
  }

  // ── Upload to Cloudinary ─────────────────────────────
  Future<Map<String, String>?> _uploadToCloudinary(
      Uint8List bytes) async {
    try {
      setState(() {
        _uploadProgress = 0.1;
        _uploadStage    = 'Preparing upload…';
      });

      final uri = Uri.parse(
          'https://api.cloudinary.com/v1_1/$_cloudName/image/upload');

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset
        ..fields['folder']        = 'achievements'
        ..files.add(http.MultipartFile.fromBytes(
          'file', bytes,
          filename: 'achievement_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ));

      setState(() {
        _uploadProgress = 0.4;
        _uploadStage    = 'Uploading to cloud…';
      });

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      setState(() {
        _uploadProgress = 0.85;
        _uploadStage    = 'Finalising…';
      });

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return {
          'url':      json['secure_url'] as String,
          'publicId': json['public_id']  as String,
        };
      } else {
        debugPrint('Cloudinary error: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Cloudinary upload exception: $e');
      return null;
    }
  }

  // ── Validate ────────────────────────────────────────
  String? _validate() {
    if (_titleCtrl.text.trim().isEmpty) {
      return 'Please enter a title for your achievement.';
    }
    if (_titleCtrl.text.trim().length < 5) {
      return 'Title must be at least 5 characters.';
    }
    if (!_isEdit && _pickedBytes == null) {
      return 'Please select a photo for your achievement.';
    }
    if (_isEdit && _isApproved && _pickedBytes == null &&
        _existingImageUrl.isEmpty) {
      return 'No image found. Please select a photo.';
    }
    if (_captionCtrl.text.trim().length > 1000) {
      return 'Caption cannot exceed 1000 characters.';
    }
    return null;
  }

  // ── Submit ──────────────────────────────────────────
  Future<void> _submit() async {
    final error = _validate();
    if (error != null) { _showSnack(error, isError: true); return; }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { _showSnack('Sign in to post', isError: true); return; }

    setState(() { _isUploading = true; _uploadProgress = 0; });

    try {
      String imageUrl = _existingImageUrl;
      String publicId = widget.postToEdit?.publicId ?? '';

      // Upload new image if picked
      if (_pickedBytes != null) {
        setState(() { _uploadStage = 'Uploading photo…'; _uploadProgress = 0.1; });
        final result = await _uploadToCloudinary(_pickedBytes!);
        if (result == null) {
          _showSnack('Image upload failed. Please check your connection and try again.', isError: true);
          setState(() => _isUploading = false);
          return;
        }
        imageUrl = result['url']!;
        publicId = result['publicId']!;
      }

      setState(() { _uploadStage = 'Saving…'; _uploadProgress = 0.95; });

      // Fetch user profile for name + photo
      String userName    = user.displayName ?? 'Alumni';
      String userPhotoUrl = user.photoURL ?? '';
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          userName     = userDoc.data()?['name']?.toString() ??
                         userDoc.data()?['fullName']?.toString() ??
                         userName;
          userPhotoUrl = userDoc.data()?['profilePictureUrl']
                             ?.toString() ?? userPhotoUrl;
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
        'tags':         _tags,
        'updatedAt':    FieldValue.serverTimestamp(),
      };

      if (_isEdit) {
        // Can only edit text, not image (can't change approved)
        // Status stays the same — admin re-reviews on edit
        if (!_isApproved) {
          data['status'] = 'pending'; // re-submit for review if editing pending
        }
        await db.collection('achievement_posts')
            .doc(widget.postToEdit!.id)
            .update(data);
        _showSnack('Post updated! Awaiting admin review.', isError: false);
      } else {
        data['status']    = 'pending';
        data['createdAt'] = FieldValue.serverTimestamp();
        await db.collection('achievement_posts').add(data);
        _showSnack(
            'Achievement submitted! It will appear after admin review.',
            isError: false);
      }

      setState(() { _uploadProgress = 1.0; });
      await Future.delayed(const Duration(milliseconds: 300));

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      debugPrint('Submit error: $e');
      _showSnack(
          'Something went wrong. Please check your connection and try again.',
          isError: true);
      setState(() => _isUploading = false);
    }
  }

  // ── Add tag ──────────────────────────────────────────
  void _addTag(String raw) {
    final tag = raw.trim().replaceAll('#', '').toLowerCase();
    if (tag.isEmpty || tag.length > 30) return;
    if (_tags.contains(tag)) {
      _showSnack('"#$tag" already added', isError: false);
      return;
    }
    if (_tags.length >= 8) {
      _showSnack('Maximum 8 tags allowed', isError: true);
      return;
    }
    setState(() => _tags.add(tag));
    _tagCtrl.clear();
  }

  void _showSnack(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: GoogleFonts.inter()),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ));
  }

  // ══════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.97,
      minChildSize: 0.5,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF141414),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          // ── Handle ──────────────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── Header ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_isEdit ? 'Edit Achievement' : 'Share Achievement',
                    style: GoogleFonts.cormorantGaramond(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
                Text(
                  _isEdit
                      ? (_isApproved
                          ? 'Caption and tags can be updated'
                          : 'Update your pending post')
                      : 'Submit for admin review before publishing',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.4)),
                ),
              ]),
              const Spacer(),
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

          // ── Upload progress overlay ─────────────────
          if (_isUploading)
            Container(
              margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.brandRed.withOpacity(0.1),
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
                      color: AppColors.brandRed,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(_uploadStage,
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.7))),
                  const Spacer(),
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
                    backgroundColor: Colors.white.withOpacity(0.1),
                    valueColor: const AlwaysStoppedAnimation(AppColors.brandRed),
                    minHeight: 3,
                  ),
                ),
              ]),
            ),

          // ── Scrollable form ─────────────────────────
          Expanded(
            child: AbsorbPointer(
              absorbing: _isUploading,
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.all(20),
                children: [

                  // ─── Image picker ─────────────────────
                  GestureDetector(
                    onTap: _isApproved ? null : _pickImage,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
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
                        child: _pickedBytes != null
                            ? Stack(fit: StackFit.expand, children: [
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
                                      child: const Icon(
                                          Icons.edit_outlined,
                                          color: Colors.white, size: 14),
                                    ),
                                  ),
                                ),
                              ])
                            : _existingImageUrl.isNotEmpty
                                ? Stack(fit: StackFit.expand, children: [
                                    CachedNetworkImage(
                                      imageUrl: _existingImageUrl,
                                      fit: BoxFit.cover,
                                    ),
                                    if (!_isApproved)
                                      Positioned(
                                        top: 8, right: 8,
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.6),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Icon(
                                              Icons.edit_outlined,
                                              color: Colors.white, size: 14),
                                        ),
                                      ),
                                    if (_isApproved)
                                      Positioned(
                                        bottom: 8, left: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.7),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'Image locked after approval',
                                            style: GoogleFonts.inter(
                                                fontSize: 10,
                                                color: Colors.white.withOpacity(0.6)),
                                          ),
                                        ),
                                      ),
                                  ])
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_photo_alternate_outlined,
                                          size: 40,
                                          color: Colors.white.withOpacity(0.25)),
                                      const SizedBox(height: 10),
                                      Text('Tap to select photo',
                                          style: GoogleFonts.inter(
                                              fontSize: 13,
                                              color: Colors.white.withOpacity(0.3))),
                                      const SizedBox(height: 4),
                                      Text('JPG or PNG · Max 10 MB',
                                          style: GoogleFonts.inter(
                                              fontSize: 10,
                                              color: Colors.white.withOpacity(0.2))),
                                    ],
                                  ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ─── Info notice ─────────────────────
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.blue.withOpacity(0.2), width: 0.5),
                    ),
                    child: Row(children: [
                      const Icon(Icons.info_outline,
                          size: 14, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isEdit && _isApproved
                              ? 'This post is approved. Only caption and tags can be updated.'
                              : 'Your post will be reviewed by an admin before appearing in the gallery. Typical review time is 24 hours.',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.blue.withOpacity(0.8),
                              height: 1.4),
                        ),
                      ),
                    ]),
                  ),

                  const SizedBox(height: 20),

                  // ─── Title ───────────────────────────
                  _DarkField(
                    controller: _titleCtrl,
                    label: 'Achievement Title *',
                    hint: 'e.g. Passed the Board Exam',
                    maxLength: 100,
                  ),
                  const SizedBox(height: 14),

                  // ─── Caption ─────────────────────────
                  _DarkField(
                    controller: _captionCtrl,
                    label: 'Caption',
                    hint: 'Tell your story — what happened, how it felt, who helped you get here…',
                    maxLines: 5,
                    maxLength: 1000,
                  ),
                  const SizedBox(height: 14),

                  // ─── Category ────────────────────────
                  _DarkLabel('Category *'),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8,
                    children: _categories.map((cat) {
                      final isSel = _category == cat;
                      return GestureDetector(
                        onTap: () => setState(() => _category = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSel
                                ? AppColors.brandRed
                                : Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSel
                                  ? AppColors.brandRed
                                  : Colors.white.withOpacity(0.1),
                              width: 0.5,
                            ),
                          ),
                          child: Text(cat,
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isSel
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.5))),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // ─── Tags ────────────────────────────
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
                            Icon(Icons.close,
                                size: 11,
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

                  // ─── Submit button ───────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 50,
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
                          ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              const SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white)),
                              const SizedBox(width: 10),
                              Text(_uploadStage.isEmpty ? 'Uploading…' : _uploadStage,
                                  style: GoogleFonts.inter(
                                      fontSize: 13, fontWeight: FontWeight.w600)),
                            ])
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
}

// ─────────────────────────────────────────────────────────────────────────────
// ADMIN APPROVAL — add this to your admin screens
// Call: AdminAchievementApproval widget (separate section below)
// ─────────────────────────────────────────────────────────────────────────────

/// Compact widget to embed in any admin screen to
/// show pending achievement posts with Approve/Reject.
class AdminAchievementQueue extends StatelessWidget {
  const AdminAchievementQueue({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('achievement_posts')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(
                  color: AppColors.brandRed, strokeWidth: 2));
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: Text(
              'No pending achievement posts',
              style: GoogleFonts.inter(
                  fontSize: 14, color: AppColors.mutedText),
            )),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final post = AchievementPost.fromMap(
                docs[i].id, docs[i].data() as Map<String, dynamic>);
            return _AdminPostCard(post: post);
          },
        );
      },
    );
  }
}

class _AdminPostCard extends StatefulWidget {
  final AchievementPost post;
  const _AdminPostCard({required this.post});

  @override
  State<_AdminPostCard> createState() => _AdminPostCardState();
}

class _AdminPostCardState extends State<_AdminPostCard> {
  bool _isActing = false;
  final _rejectReasonCtrl = TextEditingController();

  Future<void> _approve() async {
    setState(() => _isActing = true);
    try {
      await FirebaseFirestore.instance
          .collection('achievement_posts')
          .doc(widget.post.id)
          .update({
        'status':     'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'rejectionReason': null,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Approved: ${widget.post.title}'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _reject() async {
    _rejectReasonCtrl.clear();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        title: Text('Reject Post',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Provide a reason for rejection (shown to user):',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.mutedText)),
          const SizedBox(height: 10),
          TextField(
            controller: _rejectReasonCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'e.g. Image quality too low, or unrelated content',
              hintStyle: GoogleFonts.inter(fontSize: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppColors.mutedText)),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, _rejectReasonCtrl.text.trim()),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            child: Text('Reject',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (reason == null) return; // cancelled

    setState(() => _isActing = true);
    try {
      await FirebaseFirestore.instance
          .collection('achievement_posts')
          .doc(widget.post.id)
          .update({
        'status':          'rejected',
        'rejectionReason': reason.isEmpty ? 'Does not meet posting guidelines.' : reason,
        'rejectedAt':      FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'),
                backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            // User info
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.borderSubtle,
              backgroundImage: widget.post.userPhotoUrl.isNotEmpty
                  ? NetworkImage(widget.post.userPhotoUrl) : null,
              child: widget.post.userPhotoUrl.isEmpty
                  ? Text(widget.post.userName.isNotEmpty
                        ? widget.post.userName[0].toUpperCase() : '?',
                      style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: AppColors.brandRed))
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.post.userName,
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: AppColors.darkText)),
                Text(widget.post.category,
                    style: GoogleFonts.inter(
                        fontSize: 11, color: AppColors.mutedText)),
              ],
            )),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: Colors.orange.withOpacity(0.3)),
              ),
              child: Text('PENDING',
                  style: GoogleFonts.inter(
                      fontSize: 9, fontWeight: FontWeight.w800,
                      color: Colors.orange, letterSpacing: 0.5)),
            ),
          ]),

          const SizedBox(height: 10),

          // Image preview
          if (widget.post.imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: widget.post.imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    color: AppColors.borderSubtle,
                    child: const Icon(Icons.broken_image_outlined,
                        color: AppColors.mutedText),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 10),

          Text(widget.post.title,
              style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: AppColors.darkText)),
          if (widget.post.caption.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(widget.post.caption,
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.mutedText,
                    height: 1.4),
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
          ],

          const SizedBox(height: 12),

          // Approve / Reject buttons
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isActing ? null : _reject,
                icon: const Icon(Icons.cancel_outlined,
                    size: 14, color: Colors.red),
                label: Text('Reject',
                    style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isActing ? null : _approve,
                icon: _isActing
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_outline,
                        size: 14, color: Colors.white),
                label: Text('Approve',
                    style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UI HELPERS
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryBadge extends StatelessWidget {
  final String label;
  const _CategoryBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.brandRed.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
            color: AppColors.brandRed.withOpacity(0.3), width: 0.5),
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

class _ImagePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E1E1E),
      child: Icon(Icons.image_outlined,
          color: Colors.white.withOpacity(0.15), size: 40),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final bool dark;
  const _EmptyState({required this.icon, required this.message, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Center(child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 56,
            color: dark
                ? Colors.white.withOpacity(0.1)
                : AppColors.borderSubtle),
        const SizedBox(height: 14),
        Text(message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 13,
                color: dark
                    ? Colors.white.withOpacity(0.3)
                    : AppColors.mutedText,
                height: 1.5)),
      ]),
    ));
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          _DarkLabel(label),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          onSubmitted: onSubmitted,
          style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
                fontSize: 13, color: Colors.white.withOpacity(0.2)),
            counterStyle: GoogleFonts.inter(
                fontSize: 10, color: Colors.white.withOpacity(0.25)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.04),
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
      ],
    );
  }
}