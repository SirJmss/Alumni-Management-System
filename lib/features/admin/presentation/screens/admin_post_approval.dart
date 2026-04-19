// =============================================================================
// UPDATED: PostApprovalPanel — supports alumni_posts AND achievement_posts
// Drop-in replacement: only PostApprovalPanel + its state are changed.
// Requires cached_network_image in pubspec.yaml.
// =============================================================================

// ignore_for_file: library_private_types_in_public_api

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:alumni/core/constants/app_colors.dart';

// ─── Color tokens (unchanged) ──────────────────────────────────────────────────
const _kPending  = Color(0xFFF59E0B);
const _kApproved = Color(0xFF10B981);
const _kRejected = Color(0xFFEF4444);
const _kFlagged  = Color(0xFF8B5CF6);

// =============================================================================
// PostApprovalService (unchanged)
// =============================================================================
class PostApprovalService {
  static final _fs   = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static Future<void> approve(String postId,
      {String collection = 'alumni_posts'}) async {
    await _fs.collection(collection).doc(postId).update({
      'status'          : 'approved',
      'approvedAt'      : FieldValue.serverTimestamp(),
      'approvedBy'      : _auth.currentUser?.uid,
      'updatedAt'       : FieldValue.serverTimestamp(),
      'rejectionReason' : FieldValue.delete(),
      'rejectedAt'      : FieldValue.delete(),
      'rejectedBy'      : FieldValue.delete(),
    });
  }

  static Future<void> reject(String postId, String reason,
      {String collection = 'alumni_posts'}) async {
    if (reason.trim().isEmpty) {
      throw ArgumentError('Rejection reason is required');
    }
    await _fs.collection(collection).doc(postId).update({
      'status'          : 'rejected',
      'rejectedAt'      : FieldValue.serverTimestamp(),
      'rejectedBy'      : _auth.currentUser?.uid,
      'rejectionReason' : reason.trim(),
      'updatedAt'       : FieldValue.serverTimestamp(),
    });
  }

  static Future<void> flag(String postId, String reason,
      {String collection = 'alumni_posts'}) async {
    if (reason.trim().isEmpty) throw ArgumentError('Flag reason is required');
    await _fs.collection(collection).doc(postId).update({
      'status'     : 'flagged',
      'flagReason' : reason.trim(),
      'flaggedAt'  : FieldValue.serverTimestamp(),
      'flaggedBy'  : _auth.currentUser?.uid,
      'updatedAt'  : FieldValue.serverTimestamp(),
    });
  }

  static Future<void> bulkApprove(List<String> ids,
      {String collection = 'alumni_posts'}) async {
    final batch = _fs.batch();
    for (final id in ids) {
      batch.update(_fs.collection(collection).doc(id), {
        'status'     : 'approved',
        'approvedAt' : FieldValue.serverTimestamp(),
        'approvedBy' : _auth.currentUser?.uid,
        'updatedAt'  : FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}

// =============================================================================
// CombinedPendingBadge (unchanged)
// =============================================================================
class CombinedPendingBadge extends StatelessWidget {
  const CombinedPendingBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('alumni_posts')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (_, feedSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('achievement_posts')
              .where('status', isEqualTo: 'pending')
              .snapshots(),
          builder: (_, achSnap) {
            final total = (feedSnap.data?.docs.length ?? 0) +
                (achSnap.data?.docs.length ?? 0);
            if (total == 0) return const SizedBox.shrink();
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.brandRed,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$total',
                  style: GoogleFonts.inter(
                      fontSize: 9, fontWeight: FontWeight.w800,
                      color: Colors.white)),
            );
          },
        );
      },
    );
  }
}

// =============================================================================
// PostApprovalBadge (unchanged)
// =============================================================================
class PostApprovalBadge extends StatelessWidget {
  const PostApprovalBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('alumni_posts')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (_, snap) {
        final count = snap.data?.docs.length ?? 0;
        if (count == 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.brandRed,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count',
              style: GoogleFonts.inter(
                  fontSize: 9, fontWeight: FontWeight.w800,
                  color: Colors.white)),
        );
      },
    );
  }
}

// =============================================================================
// Shared micro-widgets (unchanged)
// =============================================================================
class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip(this.status);

  Color get _color => switch (status) {
    'approved' => _kApproved,
    'rejected' => _kRejected,
    'flagged'  => _kFlagged,
    _          => _kPending,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withOpacity(0.4)),
      ),
      child: Text(status.toUpperCase(),
          style: GoogleFonts.inter(
              fontSize: 9, fontWeight: FontWeight.w700,
              color: _color, letterSpacing: 0.8)),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String type;
  const _TypeChip(this.type);

  IconData get _icon => switch (type) {
    'milestone'    => Icons.emoji_events_outlined,
    'event'        => Icons.event_outlined,
    'job'          => Icons.work_outline,
    'question'     => Icons.help_outline,
    'achievement'  => Icons.workspace_premium_outlined,
    _              => Icons.article_outlined,
  };

  Color get _color => switch (type) {
    'milestone'    => Colors.amber,
    'event'        => Colors.blue,
    'job'          => Colors.teal,
    'question'     => Colors.indigo,
    'achievement'  => Colors.deepPurple,
    _              => Colors.grey,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(_icon, size: 10, color: _color),
        const SizedBox(width: 4),
        Text(type.toUpperCase(),
            style: GoogleFonts.inter(
                fontSize: 9, fontWeight: FontWeight.w700,
                color: _color, letterSpacing: 0.5)),
      ]),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool filled;
  final bool isLoading;
  final VoidCallback? onTap;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    this.filled = false,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: filled ? color : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: filled ? null : Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (isLoading)
            SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: filled ? Colors.white : color),
            )
          else
            Icon(icon, size: 15,
                color: filled ? Colors.white : color),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: filled ? Colors.white : color)),
        ]),
      ),
    );
  }
}

class _QuickBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _QuickBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 26, height: 26,
          decoration: BoxDecoration(
            color: AppColors.borderSubtle.withOpacity(0.6),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(icon, size: 13, color: AppColors.mutedText),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 9, fontWeight: FontWeight.w700,
                    color: AppColors.mutedText, letterSpacing: 0.6)),
            const SizedBox(height: 1),
            Text(value,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    color: valueColor ?? AppColors.darkText,
                    fontWeight: FontWeight.w500,
                    height: 1.3)),
          ]),
        ),
      ]),
    );
  }
}

// =============================================================================
// _MetaCard + _InfoBanner (unchanged)
// =============================================================================
class _MetaCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _MetaCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.softWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: GoogleFonts.inter(
                fontSize: 9, fontWeight: FontWeight.w800,
                color: AppColors.mutedText, letterSpacing: 1.2)),
        const SizedBox(height: 10),
        ...children,
      ]),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String label;
  final String text;
  final Color color;
  const _InfoBanner({
    required this.icon,
    required this.label,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 9, fontWeight: FontWeight.w800,
                    color: color, letterSpacing: 1)),
            const SizedBox(height: 3),
            Text(text,
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.darkText)),
          ]),
        ),
      ]),
    );
  }
}

// =============================================================================
// _PostDetailDialog — updated to show imageUrl via CachedNetworkImage
// =============================================================================
class _PostDetailDialog extends StatefulWidget {
  final Map<String, dynamic> post;
  final String postId;
  final String collection;           // ← new: pass 'alumni_posts' or 'achievement_posts'
  final VoidCallback onActionComplete;

  const _PostDetailDialog({
    required this.post,
    required this.postId,
    required this.collection,
    required this.onActionComplete,
  });

  @override
  State<_PostDetailDialog> createState() => _PostDetailDialogState();
}

class _PostDetailDialogState extends State<_PostDetailDialog> {
  final _reasonCtrl   = TextEditingController();
  bool  _isSubmitting = false;
  String? _actionInProgress;
  Map<String, dynamic>? _authorProfile;
  bool _loadingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadAuthorProfile();
  }

  @override
  void dispose() { _reasonCtrl.dispose(); super.dispose(); }

  Future<void> _loadAuthorProfile() async {
    // Support both 'authorId' (alumni_posts) and 'userId' (achievement_posts)
    final authorId = (widget.post['authorId'] ?? widget.post['userId'])?.toString();
    if (authorId == null || authorId.isEmpty) {
      setState(() => _loadingProfile = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(authorId).get();
      if (mounted) {
        setState(() {
          _authorProfile  = doc.exists ? doc.data() : null;
          _loadingProfile = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  String _fmtFull(Timestamp? ts) {
    if (ts == null) return '—';
    return DateFormat('MMMM d, yyyy  h:mm a').format(ts.toDate());
  }

  String _fmtShort(Timestamp? ts) {
    if (ts == null) return '—';
    return DateFormat('MMM d, yyyy').format(ts.toDate());
  }

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '—';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1)  return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24) return '${diff.inHours}h ago';
    if (diff.inDays    < 7)  return '${diff.inDays}d ago';
    return _fmtShort(ts);
  }

  Future<void> _doAction(String action) async {
    if ((action == 'reject' || action == 'flag') &&
        _reasonCtrl.text.trim().isEmpty) {
      _snack(action == 'reject'
          ? 'Rejection reason is required'
          : 'Flag reason is required', isError: true);
      return;
    }
    setState(() { _isSubmitting = true; _actionInProgress = action; });
    try {
      switch (action) {
        case 'approve':
          await PostApprovalService.approve(widget.postId,
              collection: widget.collection);
        case 'reject':
          await PostApprovalService.reject(
              widget.postId, _reasonCtrl.text,
              collection: widget.collection);
        case 'flag':
          await PostApprovalService.flag(
              widget.postId, _reasonCtrl.text,
              collection: widget.collection);
      }
      if (mounted) {
        Navigator.of(context).pop();
        widget.onActionComplete();
      }
    } catch (e) {
      if (mounted) {
        _snack('Error: $e', isError: true);
        setState(() { _isSubmitting = false; _actionInProgress = null; });
      }
    }
  }

  void _snack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: GoogleFonts.inter()),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(12),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;

    // ── Field resolution: handles both alumni_posts and achievement_posts ──
    final bool isAchievement = widget.collection == 'achievement_posts';

    final content         = (p['content'] ?? p['description'])?.toString() ?? '';
    final title           = p['title']?.toString();                    // achievement_posts has a title
    final authorName      = (p['authorName'] ?? p['userName'])?.toString() ?? 'Unknown';
    final authorPhoto     = (p['authorPhotoUrl'] ?? p['userPhotoUrl'])?.toString();
    final authorRole      = p['authorRole']?.toString() ?? (isAchievement ? 'alumni' : 'alumni');
    final postType        = p['postType']?.toString() ?? (isAchievement ? 'achievement' : 'update');
    final status          = p['status']?.toString()    ?? 'pending';
    final imageUrl        = p['imageUrl']?.toString();                 // Cloudinary image (achievement_posts)
    final createdAt       = p['createdAt']   as Timestamp?;
    final updatedAt       = p['updatedAt']   as Timestamp?;
    final approvedAt      = p['approvedAt']  as Timestamp?;
    final rejectedAt      = p['rejectedAt']  as Timestamp?;
    final rejectionReason = p['rejectionReason']?.toString();
    final flagReason      = p['flagReason']?.toString();
    final mediaUrls       = (p['mediaUrls'] as List<dynamic>?)
            ?.map((e) => e.toString()).toList() ?? [];
    final tags            = (p['tags'] as List<dynamic>?)
            ?.map((e) => e.toString()).toList() ?? [];
    final reportCount     = (p['reportCount'] as num?)?.toInt() ?? 0;
    final isPending       = status == 'pending' || status == 'flagged';

    final ap              = _authorProfile;
    final profileEmail    = ap?['email']?.toString()     ?? '—';
    final profileBatch    = ap?['batchYear']?.toString() ?? ap?['batch']?.toString() ?? '—';
    final profileCourse   = ap?['course']?.toString()   ?? ap?['program']?.toString() ?? '—';
    final profilePhone    = ap?['phone']?.toString()     ?? '—';
    final profileStatus   = ap?['status']?.toString()    ?? '—';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 820,
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 48, spreadRadius: 4,
              ),
            ],
          ),
          child: Column(children: [

            // ── HEADER ────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 14, 14),
              decoration: const BoxDecoration(
                color: AppColors.softWhite,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
              ),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.brandRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isAchievement
                        ? Icons.workspace_premium_outlined
                        : Icons.rate_review_outlined,
                    color: AppColors.brandRed, size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAchievement ? 'Achievement Review' : 'Post Review',
                        style: GoogleFonts.cormorantGaramond(
                            fontSize: 22, fontWeight: FontWeight.w600,
                            color: AppColors.darkText),
                      ),
                      Text('ID: ${widget.postId}',
                          style: GoogleFonts.inter(
                              fontSize: 10, color: AppColors.mutedText)),
                    ],
                  ),
                ),
                _StatusChip(status),
                if (reportCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _kRejected.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.flag_rounded, size: 10, color: _kRejected),
                      const SizedBox(width: 4),
                      Text('$reportCount report${reportCount > 1 ? 's' : ''}',
                          style: GoogleFonts.inter(
                              fontSize: 9, fontWeight: FontWeight.w700,
                              color: _kRejected)),
                    ]),
                  ),
                ],
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: AppColors.mutedText, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ]),
            ),

            // ── SCROLLABLE BODY ───────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // LEFT column ──────────────────────────────────────────
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          // Author card
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.softWhite,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.borderSubtle),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 26,
                                  backgroundColor: AppColors.brandRed.withOpacity(0.1),
                                  backgroundImage: authorPhoto != null
                                      ? NetworkImage(authorPhoto)
                                      : null,
                                  child: authorPhoto == null
                                      ? Text(
                                          authorName.isNotEmpty
                                              ? authorName[0].toUpperCase()
                                              : '?',
                                          style: GoogleFonts.inter(
                                              color: AppColors.brandRed,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 17))
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(authorName,
                                          style: GoogleFonts.inter(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                              color: AppColors.darkText)),
                                      const SizedBox(height: 4),
                                      Row(children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(authorRole.toUpperCase(),
                                              style: GoogleFonts.inter(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.blue,
                                                  letterSpacing: 0.5)),
                                        ),
                                        const SizedBox(width: 6),
                                        _TypeChip(postType),
                                      ]),
                                      const SizedBox(height: 4),
                                      if (_loadingProfile)
                                        Row(children: [
                                          const SizedBox(
                                              width: 10, height: 10,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 1.5,
                                                  color: AppColors.mutedText)),
                                          const SizedBox(width: 6),
                                          Text('Loading profile…',
                                              style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  color: AppColors.mutedText)),
                                        ])
                                      else ...[
                                        if (profileEmail != '—')
                                          Text(profileEmail,
                                              style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  color: AppColors.mutedText)),
                                        if (profileBatch != '—' || profileCourse != '—')
                                          Text(
                                            [
                                              if (profileCourse != '—') profileCourse,
                                              if (profileBatch != '—') 'Batch $profileBatch',
                                            ].join(' · '),
                                            style: GoogleFonts.inter(
                                                fontSize: 11,
                                                color: AppColors.mutedText),
                                          ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Achievement image (Cloudinary via CachedNetworkImage)
                          if (imageUrl != null && imageUrl.isNotEmpty) ...[
                            Row(children: [
                              const Icon(Icons.image_outlined,
                                  size: 12, color: AppColors.mutedText),
                              const SizedBox(width: 5),
                              Text('ACHIEVEMENT IMAGE',
                                  style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.mutedText,
                                      letterSpacing: 1)),
                            ]),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: imageUrl,
                                width: double.infinity,
                                height: 220,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  height: 220,
                                  color: AppColors.borderSubtle,
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.brandRed),
                                  ),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  height: 220,
                                  color: AppColors.borderSubtle,
                                  child: const Center(
                                    child: Icon(Icons.broken_image_outlined,
                                        color: AppColors.mutedText, size: 32),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          // Post title (achievement_posts)
                          if (title != null && title.isNotEmpty) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: Colors.deepPurple.withOpacity(0.15)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('TITLE',
                                      style: GoogleFonts.inter(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.deepPurple,
                                          letterSpacing: 1)),
                                  const SizedBox(height: 4),
                                  Text(title,
                                      style: GoogleFonts.inter(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.darkText)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],

                          // Post content / description
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.softWhite,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.borderSubtle),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  const Icon(Icons.article_outlined,
                                      size: 12, color: AppColors.mutedText),
                                  const SizedBox(width: 5),
                                  Text(
                                    isAchievement ? 'DESCRIPTION' : 'POST CONTENT',
                                    style: GoogleFonts.inter(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.mutedText,
                                        letterSpacing: 1),
                                  ),
                                ]),
                                const SizedBox(height: 10),
                                SelectableText(
                                  content.isNotEmpty ? content : '(no text content)',
                                  style: GoogleFonts.inter(
                                      fontSize: 14,
                                      height: 1.65,
                                      color: content.isNotEmpty
                                          ? AppColors.darkText
                                          : AppColors.mutedText,
                                      fontStyle: content.isEmpty
                                          ? FontStyle.italic
                                          : null),
                                ),
                              ],
                            ),
                          ),

                          // Extra mediaUrls (alumni_posts)
                          if (mediaUrls.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Row(children: [
                              const Icon(Icons.photo_library_outlined,
                                  size: 12, color: AppColors.mutedText),
                              const SizedBox(width: 5),
                              Text(
                                  '${mediaUrls.length} MEDIA FILE${mediaUrls.length > 1 ? 'S' : ''}',
                                  style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.mutedText,
                                      letterSpacing: 1)),
                            ]),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 110,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: mediaUrls.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 8),
                                itemBuilder: (_, i) => ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: mediaUrls[i],
                                    width: 175, height: 110,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Container(
                                      width: 175, height: 110,
                                      color: AppColors.borderSubtle,
                                      child: const Icon(Icons.broken_image_outlined,
                                          color: AppColors.mutedText),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],

                          // Tags
                          if (tags.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 6, runSpacing: 6,
                              children: tags.map((t) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: Colors.blue.withOpacity(0.2)),
                                ),
                                child: Text('#$t',
                                    style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: Colors.blue.shade700)),
                              )).toList(),
                            ),
                          ],

                          // Banners
                          if (status == 'flagged' &&
                              (flagReason ?? '').isNotEmpty) ...[
                            const SizedBox(height: 14),
                            _InfoBanner(
                              icon: Icons.flag_outlined,
                              label: 'FLAGGED',
                              text: flagReason!,
                              color: _kFlagged,
                            ),
                          ],
                          if (status == 'rejected' &&
                              (rejectionReason ?? '').isNotEmpty) ...[
                            const SizedBox(height: 14),
                            _InfoBanner(
                              icon: Icons.cancel_outlined,
                              label: 'REJECTION REASON',
                              text: rejectionReason!,
                              color: _kRejected,
                            ),
                          ],

                          // Reason input
                          if (isPending) ...[
                            const SizedBox(height: 20),
                            const Divider(color: AppColors.borderSubtle),
                            const SizedBox(height: 14),
                            Row(children: [
                              const Icon(Icons.edit_note_outlined,
                                  size: 15, color: AppColors.mutedText),
                              const SizedBox(width: 6),
                              Text(
                                'Rejection / Flag Reason'
                                ' (required for Reject or Flag)',
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.mutedText),
                              ),
                            ]),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _reasonCtrl,
                              maxLines: 3,
                              style: GoogleFonts.inter(fontSize: 13),
                              decoration: InputDecoration(
                                hintText:
                                    'e.g. Off-topic, spam, or violates community guidelines',
                                hintStyle: GoogleFonts.inter(
                                    color: AppColors.mutedText, fontSize: 12),
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
                                filled: true,
                                fillColor: AppColors.softWhite,
                                contentPadding: const EdgeInsets.all(14),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(width: 16),

                    // RIGHT sidebar ─────────────────────────────────────────
                    SizedBox(
                      width: 210,
                      child: Column(
                        children: [
                          _MetaCard(
                            title: 'POST DETAILS',
                            children: [
                              _DetailRow(
                                icon: Icons.calendar_today_outlined,
                                label: 'SUBMITTED',
                                value: _fmtFull(createdAt),
                              ),
                              _DetailRow(
                                icon: Icons.access_time_outlined,
                                label: 'TIME AGO',
                                value: _timeAgo(createdAt),
                              ),
                              if (updatedAt != null)
                                _DetailRow(
                                  icon: Icons.edit_calendar_outlined,
                                  label: 'LAST UPDATED',
                                  value: _fmtShort(updatedAt),
                                ),
                              if (approvedAt != null)
                                _DetailRow(
                                  icon: Icons.check_circle_outline,
                                  label: 'APPROVED',
                                  value: _fmtFull(approvedAt),
                                  valueColor: _kApproved,
                                ),
                              if (rejectedAt != null)
                                _DetailRow(
                                  icon: Icons.cancel_outlined,
                                  label: 'REJECTED',
                                  value: _fmtFull(rejectedAt),
                                  valueColor: _kRejected,
                                ),
                              _DetailRow(
                                icon: Icons.label_outline,
                                label: 'TYPE',
                                value: postType.toUpperCase(),
                              ),
                              _DetailRow(
                                icon: Icons.storage_outlined,
                                label: 'COLLECTION',
                                value: widget.collection,
                              ),
                              if (reportCount > 0)
                                _DetailRow(
                                  icon: Icons.flag_outlined,
                                  label: 'REPORTS',
                                  value: '$reportCount report${reportCount > 1 ? 's' : ''}',
                                  valueColor: _kRejected,
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _MetaCard(
                            title: 'AUTHOR PROFILE',
                            children: [
                              _DetailRow(
                                icon: Icons.person_outline,
                                label: 'NAME',
                                value: authorName,
                              ),
                              _DetailRow(
                                icon: Icons.badge_outlined,
                                label: 'ROLE',
                                value: authorRole.toUpperCase(),
                              ),
                              if (profileEmail != '—')
                                _DetailRow(
                                  icon: Icons.email_outlined,
                                  label: 'EMAIL',
                                  value: profileEmail,
                                ),
                              if (profilePhone != '—')
                                _DetailRow(
                                  icon: Icons.phone_outlined,
                                  label: 'PHONE',
                                  value: profilePhone,
                                ),
                              if (profileBatch != '—')
                                _DetailRow(
                                  icon: Icons.school_outlined,
                                  label: 'BATCH',
                                  value: profileBatch,
                                ),
                              if (profileCourse != '—')
                                _DetailRow(
                                  icon: Icons.menu_book_outlined,
                                  label: 'COURSE',
                                  value: profileCourse,
                                ),
                              _DetailRow(
                                icon: Icons.verified_outlined,
                                label: 'ACCOUNT STATUS',
                                value: profileStatus.toUpperCase(),
                                valueColor: profileStatus == 'active'
                                    ? _kApproved
                                    : null,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── ACTION BAR ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: AppColors.softWhite,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(top: BorderSide(color: AppColors.borderSubtle)),
              ),
              child: isPending
                  ? Row(children: [
                      _ActionBtn(
                        label: 'Flag',
                        icon: Icons.flag_outlined,
                        color: _kFlagged,
                        isLoading: _isSubmitting && _actionInProgress == 'flag',
                        onTap: _isSubmitting ? null : () => _doAction('flag'),
                      ),
                      const Spacer(),
                      _ActionBtn(
                        label: 'Reject',
                        icon: Icons.close_rounded,
                        color: _kRejected,
                        isLoading: _isSubmitting && _actionInProgress == 'reject',
                        onTap: _isSubmitting ? null : () => _doAction('reject'),
                      ),
                      const SizedBox(width: 12),
                      _ActionBtn(
                        label: 'Approve',
                        icon: Icons.check_rounded,
                        color: _kApproved,
                        filled: true,
                        isLoading: _isSubmitting && _actionInProgress == 'approve',
                        onTap: _isSubmitting ? null : () => _doAction('approve'),
                      ),
                    ])
                  : Row(children: [
                      Icon(
                        status == 'approved'
                            ? Icons.check_circle_outline
                            : Icons.info_outline,
                        size: 14,
                        color: status == 'approved' ? _kApproved : AppColors.mutedText,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        switch (status) {
                          'approved' => 'Post approved — visible to all alumni',
                          'rejected' => 'Post rejected — hidden from feed',
                          'flagged'  => 'Post flagged — under review',
                          _          => 'Read-only view',
                        },
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: status == 'approved'
                                ? _kApproved
                                : AppColors.mutedText),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Close',
                            style: GoogleFonts.inter(
                                color: AppColors.mutedText,
                                fontWeight: FontWeight.w600)),
                      ),
                    ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// =============================================================================
// PostApprovalPanel — UPDATED to support alumni_posts + achievement_posts
// =============================================================================

/// Which Firestore collection is currently selected.
enum _PostSource { alumniPosts, achievementPosts }

extension _PostSourceExt on _PostSource {
  String get collection => switch (this) {
    _PostSource.alumniPosts      => 'alumni_posts',
    _PostSource.achievementPosts => 'achievement_posts',
  };

  String get label => switch (this) {
    _PostSource.alumniPosts      => 'Alumni Posts',
    _PostSource.achievementPosts => 'Achievements',
  };

  IconData get icon => switch (this) {
    _PostSource.alumniPosts      => Icons.article_outlined,
    _PostSource.achievementPosts => Icons.workspace_premium_outlined,
  };
}

class PostApprovalPanel extends StatefulWidget {
  final VoidCallback? onRefreshStats;
  const PostApprovalPanel({super.key, this.onRefreshStats});

  @override
  State<PostApprovalPanel> createState() => _PostApprovalPanelState();
}

class _PostApprovalPanelState extends State<PostApprovalPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final Set<String> _selected = {};
  bool _bulkMode         = false;
  bool _isBulkApproving  = false;
  _PostSource _source    = _PostSource.alumniPosts;

  static const _filters  = ['pending', 'approved', 'rejected', 'flagged'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _filters.length, vsync: this);
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) {
        setState(() { _selected.clear(); _bulkMode = false; });
      }
    });
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  String get _currentFilter  => _filters[_tabs.index];
  String get _collection     => _source.collection;

  void _snack(String msg, {required bool isError}) {
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

  void _openDetail(String id, Map<String, dynamic> data) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PostDetailDialog(
        postId: id,
        post: data,
        collection: _collection,
        onActionComplete: () {
          _snack('Action completed', isError: false);
          widget.onRefreshStats?.call();
        },
      ),
    );
  }

  Future<void> _bulkApprove() async {
    if (_selected.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Bulk Approve',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text('Approve ${_selected.length} selected posts?',
            style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppColors.mutedText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Approve All',
                style: GoogleFonts.inter(
                    color: _kApproved, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _isBulkApproving = true);
    try {
      await PostApprovalService.bulkApprove(
          _selected.toList(), collection: _collection);
      _snack('${_selected.length} posts approved', isError: false);
      setState(() {
        _selected.clear();
        _bulkMode        = false;
        _isBulkApproving = false;
      });
      widget.onRefreshStats?.call();
    } catch (e) {
      _snack('Bulk approve failed: $e', isError: true);
      setState(() => _isBulkApproving = false);
    }
  }

  String _fmt(Timestamp? ts) {
    if (ts == null) return '—';
    final date = ts.toDate();
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24) return '${diff.inHours}h ago';
    if (diff.inDays    < 7)  return '${diff.inDays}d ago';
    return DateFormat('MMM d, yyyy').format(date);
  }

  // ─── Field helpers: normalise differences between collections ─────────────
  String _authorName(Map<String, dynamic> d) =>
      (d['authorName'] ?? d['userName'])?.toString() ?? 'Unknown';

  String? _authorPhoto(Map<String, dynamic> d) =>
      (d['authorPhotoUrl'] ?? d['userPhotoUrl'])?.toString();

  String _postType(Map<String, dynamic> d) =>
      d['postType']?.toString() ??
      (_source == _PostSource.achievementPosts ? 'achievement' : 'update');

  String _previewText(Map<String, dynamic> d) {
    // achievement_posts: show title first, fall back to description
    if (_source == _PostSource.achievementPosts) {
      final title = d['title']?.toString() ?? '';
      final desc  = d['description']?.toString() ?? '';
      return title.isNotEmpty ? title : desc;
    }
    return d['content']?.toString() ?? '';
  }

  // ─── Small thumbnail for achievement images ────────────────────────────────
  Widget _buildThumbnail(Map<String, dynamic> d) {
    if (_source != _PostSource.achievementPosts) return const SizedBox.shrink();
    final url = d['imageUrl']?.toString();
    if (url == null || url.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: url,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            width: 52, height: 52,
            color: AppColors.borderSubtle,
            child: const Center(
              child: SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 1.5, color: AppColors.brandRed),
              ),
            ),
          ),
          errorWidget: (_, __, ___) => Container(
            width: 52, height: 52,
            color: AppColors.borderSubtle,
            child: const Icon(Icons.broken_image_outlined,
                size: 18, color: AppColors.mutedText),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ── Source toggle (Alumni Posts / Achievements) ────────────────────
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.softWhite,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: _PostSource.values.map((src) {
              final isActive = _source == src;
              return GestureDetector(
                onTap: () {
                  if (_source != src) {
                    setState(() {
                      _source   = src;
                      _selected.clear();
                      _bulkMode = false;
                    });
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.brandRed
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(src.icon,
                        size: 13,
                        color: isActive ? Colors.white : AppColors.mutedText),
                    const SizedBox(width: 6),
                    Text(src.label,
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                            color: isActive ? Colors.white : AppColors.mutedText)),
                  ]),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 12),

        // ── Toolbar row ───────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Live pending badge for the active collection
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection(_collection)
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
              builder: (_, snap) {
                final n = snap.data?.docs.length ?? 0;
                if (n == 0) {
                  return Text('No pending posts',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.green,
                          fontWeight: FontWeight.w600));
                }
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kPending,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$n pending review',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                );
              },
            ),

            // Bulk controls (pending tab only)
            if (_currentFilter == 'pending')
              Row(children: [
                GestureDetector(
                  onTap: () => setState(() {
                    _bulkMode = !_bulkMode;
                    _selected.clear();
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: _bulkMode
                          ? AppColors.brandRed.withOpacity(0.08)
                          : AppColors.softWhite,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _bulkMode
                            ? AppColors.brandRed
                            : AppColors.borderSubtle,
                      ),
                    ),
                    child: Text(
                      _bulkMode ? 'CANCEL' : 'BULK SELECT',
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: _bulkMode
                              ? AppColors.brandRed
                              : AppColors.mutedText),
                    ),
                  ),
                ),
                if (_bulkMode && _selected.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isBulkApproving ? null : _bulkApprove,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: _kApproved,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _isBulkApproving
                          ? const SizedBox(
                              width: 12, height: 12,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text('APPROVE ${_selected.length}',
                              style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                  color: Colors.white)),
                    ),
                  ),
                ],
              ]),
          ],
        ),

        const SizedBox(height: 12),

        // ── Status tabs ───────────────────────────────────────────────────
        TabBar(
          controller: _tabs,
          labelStyle: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8),
          unselectedLabelStyle: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w500),
          labelColor: AppColors.brandRed,
          unselectedLabelColor: AppColors.mutedText,
          indicatorColor: AppColors.brandRed,
          indicatorWeight: 2,
          tabs: _filters.map((f) => Tab(text: f.toUpperCase())).toList(),
        ),

        const SizedBox(height: 12),

        // ── Post list ─────────────────────────────────────────────────────
        // Using AnimatedBuilder + StreamBuilder with Column children avoids
        // the unbounded-height / RenderFlex conflict inside a parent scroll view.
        AnimatedBuilder(
          animation: _tabs,
          builder: (_, __) =>
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            key: ValueKey('$_collection-$_currentFilter'),
            stream: FirebaseFirestore.instance
                .collection(_collection)
                .where('status', isEqualTo: _currentFilter)
                .orderBy('createdAt', descending: true)
                .limit(50)
                .snapshots(),
            builder: (context, snap) {
              // Loading
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.brandRed, strokeWidth: 2),
                  ),
                );
              }

              // Error
              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 40),
                        const SizedBox(height: 8),
                        Text('Could not load posts',
                            style: GoogleFonts.inter(
                                color: Colors.red,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        const SizedBox(height: 4),
                        Text('${snap.error}',
                            style: GoogleFonts.inter(
                                color: AppColors.mutedText, fontSize: 11)),
                      ],
                    ),
                  ),
                );
              }

              final docs = snap.data?.docs ?? [];

              // Empty state
              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _currentFilter == 'pending'
                              ? Icons.check_circle_outline
                              : Icons.inbox_outlined,
                          size: 52,
                          color: _currentFilter == 'pending'
                              ? Colors.green
                              : AppColors.borderSubtle,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _currentFilter == 'pending'
                              ? 'Queue is clear!'
                              : 'No ${_currentFilter} posts',
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _currentFilter == 'pending'
                                  ? Colors.green
                                  : AppColors.mutedText),
                        ),
                        if (_currentFilter == 'pending') ...[
                          const SizedBox(height: 4),
                          Text(
                            'All posts have been reviewed',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: AppColors.mutedText),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }

              // ── Post rows ───────────────────────────────────────────────
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(docs.length, (i) {
                  final doc  = docs[i];
                  final data = doc.data();
                  final id   = doc.id;

                  final authorName  = _authorName(data);
                  final authorPhoto = _authorPhoto(data);
                  final postType    = _postType(data);
                  final status      = data['status']?.toString() ?? 'pending';
                  final createdAt   = data['createdAt'] as Timestamp?;
                  final reportCount = (data['reportCount'] as num?)?.toInt() ?? 0;
                  final preview     = _previewText(data);
                  final isSelected  = _selected.contains(id);

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (i > 0)
                        const Divider(
                            color: AppColors.borderSubtle, height: 1),
                      InkWell(
                        onTap: () {
                          if (_bulkMode && status == 'pending') {
                            setState(() => isSelected
                                ? _selected.remove(id)
                                : _selected.add(id));
                          } else {
                            _openDetail(id, data);
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? _kApproved.withOpacity(0.06)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [

                              // Bulk checkbox
                              if (_bulkMode && status == 'pending')
                                Padding(
                                  padding: const EdgeInsets.only(
                                      right: 10, top: 4),
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 150),
                                    width: 18, height: 18,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? _kApproved
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: isSelected
                                            ? _kApproved
                                            : AppColors.borderSubtle,
                                        width: 1.5,
                                      ),
                                      borderRadius:
                                          BorderRadius.circular(4),
                                    ),
                                    child: isSelected
                                        ? const Icon(Icons.check,
                                            size: 12, color: Colors.white)
                                        : null,
                                  ),
                                ),

                              // Author avatar
                              CircleAvatar(
                                radius: 22,
                                backgroundColor:
                                    AppColors.brandRed.withOpacity(0.1),
                                backgroundImage: authorPhoto != null
                                    ? NetworkImage(authorPhoto)
                                    : null,
                                child: authorPhoto == null
                                    ? Text(
                                        authorName.isNotEmpty
                                            ? authorName[0].toUpperCase()
                                            : '?',
                                        style: GoogleFonts.inter(
                                            color: AppColors.brandRed,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14))
                                    : null,
                              ),
                              const SizedBox(width: 12),

                              // Achievement image thumbnail
                              _buildThumbnail(data),

                              // Content preview
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Flexible(
                                        child: Text(
                                          authorName,
                                          style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.darkText),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _TypeChip(postType),
                                      if (reportCount > 0) ...[
                                        const SizedBox(width: 5),
                                        Icon(Icons.flag_rounded,
                                            size: 11, color: _kRejected),
                                        Text('$reportCount',
                                            style: GoogleFonts.inter(
                                                fontSize: 10,
                                                color: _kRejected,
                                                fontWeight:
                                                    FontWeight.w700)),
                                      ],
                                    ]),
                                    const SizedBox(height: 3),
                                    Row(children: [
                                      _StatusChip(status),
                                      const SizedBox(width: 8),
                                      Text(_fmt(createdAt),
                                          style: GoogleFonts.inter(
                                              fontSize: 10,
                                              color: AppColors.mutedText)),
                                    ]),
                                    const SizedBox(height: 5),
                                    Text(
                                      preview,
                                      style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: AppColors.darkText,
                                          height: 1.45),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Quick actions (pending, non-bulk)
                              if (!_bulkMode && status == 'pending')
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _QuickBtn(
                                      icon: Icons.check,
                                      color: _kApproved,
                                      tooltip: 'Quick approve',
                                      onTap: () async {
                                        await PostApprovalService.approve(
                                            id, collection: _collection);
                                        _snack('Post approved',
                                            isError: false);
                                        widget.onRefreshStats?.call();
                                      },
                                    ),
                                    const SizedBox(height: 6),
                                    _QuickBtn(
                                      icon: Icons.open_in_new_rounded,
                                      color: AppColors.brandRed,
                                      tooltip: 'View & review',
                                      onTap: () => _openDetail(id, data),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              );
            },
          ),
        ),
      ],
    );
  }
}