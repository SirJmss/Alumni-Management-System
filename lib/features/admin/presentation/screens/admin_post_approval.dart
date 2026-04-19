import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:alumni/core/constants/app_colors.dart';

// ═══════════════════════════════════════════════════════════════
//  POST APPROVAL SYSTEM  — drop-in for AdminDashboardWeb
//
//  1. PostApprovalPanel       — standalone scrollable panel
//  2. PostApprovalBadge       — live counter badge for sidebar
//  3. _PostDetailDialog       — full-screen review modal
//  4. PostApprovalService     — all Firestore write logic
//
//  Firestore schema expected (collection: `alumni_posts`):
//  {
//    authorId       : String
//    authorName     : String
//    authorPhotoUrl : String?
//    authorRole     : String          // alumni | faculty | admin
//    content        : String
//    mediaUrls      : List<String>?
//    postType       : String          // update | milestone | event | job | question
//    tags           : List<String>?
//    status         : String          // pending | approved | rejected | flagged
//    createdAt      : Timestamp
//    updatedAt      : Timestamp?
//    approvedAt     : Timestamp?
//    approvedBy     : String?
//    rejectedAt     : Timestamp?
//    rejectedBy     : String?
//    rejectionReason: String?
//    flagReason     : String?
//    reportCount    : int             // auto-incremented by alumni
//  }
// ═══════════════════════════════════════════════════════════════

// ─── Colors ─────────────────────────────────────────────────────
const _kPending  = Color(0xFFF59E0B);
const _kApproved = Color(0xFF10B981);
const _kRejected = Color(0xFFEF4444);
const _kFlagged  = Color(0xFF8B5CF6);

// ─── Status badge chip ───────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'approved' => _kApproved,
      'rejected' => _kRejected,
      'flagged'  => _kFlagged,
      _          => _kPending,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 9, fontWeight: FontWeight.w700,
          color: color, letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ─── Post type chip ──────────────────────────────────────────────
class _TypeChip extends StatelessWidget {
  final String type;
  const _TypeChip(this.type);

  IconData get _icon => switch (type) {
    'milestone' => Icons.emoji_events_outlined,
    'event'     => Icons.event_outlined,
    'job'       => Icons.work_outline,
    'question'  => Icons.help_outline,
    _           => Icons.article_outlined,
  };

  Color get _color => switch (type) {
    'milestone' => Colors.amber,
    'event'     => Colors.blue,
    'job'       => Colors.teal,
    'question'  => Colors.indigo,
    _           => Colors.grey,
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
        Text(
          type.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 9, fontWeight: FontWeight.w700,
            color: _color, letterSpacing: 0.5,
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PostApprovalService
// ═══════════════════════════════════════════════════════════════
class PostApprovalService {
  static final _fs   = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;
  static const _col  = 'alumni_posts';

  static Future<void> approve(String postId) async {
    await _fs.collection(_col).doc(postId).update({
      'status'          : 'approved',
      'approvedAt'      : FieldValue.serverTimestamp(),
      'approvedBy'      : _auth.currentUser?.uid,
      'updatedAt'       : FieldValue.serverTimestamp(),
      'rejectionReason' : FieldValue.delete(),
      'rejectedAt'      : FieldValue.delete(),
      'rejectedBy'      : FieldValue.delete(),
    });
  }

  static Future<void> reject(String postId, String reason) async {
    if (reason.trim().isEmpty) throw ArgumentError('Rejection reason is required');
    await _fs.collection(_col).doc(postId).update({
      'status'          : 'rejected',
      'rejectedAt'      : FieldValue.serverTimestamp(),
      'rejectedBy'      : _auth.currentUser?.uid,
      'rejectionReason' : reason.trim(),
      'updatedAt'       : FieldValue.serverTimestamp(),
    });
  }

  static Future<void> flag(String postId, String reason) async {
    if (reason.trim().isEmpty) throw ArgumentError('Flag reason is required');
    await _fs.collection(_col).doc(postId).update({
      'status'     : 'flagged',
      'flagReason' : reason.trim(),
      'flaggedAt'  : FieldValue.serverTimestamp(),
      'flaggedBy'  : _auth.currentUser?.uid,
      'updatedAt'  : FieldValue.serverTimestamp(),
    });
  }

  static Future<void> bulkApprove(List<String> ids) async {
    final batch = _fs.batch();
    for (final id in ids) {
      batch.update(_fs.collection(_col).doc(id), {
        'status'     : 'approved',
        'approvedAt' : FieldValue.serverTimestamp(),
        'approvedBy' : _auth.currentUser?.uid,
        'updatedAt'  : FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}

// ═══════════════════════════════════════════════════════════════
//  PostApprovalBadge  — live pending count (feed posts only)
// ═══════════════════════════════════════════════════════════════
class PostApprovalBadge extends StatelessWidget {
  const PostApprovalBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('alumni_posts')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snap) {
        final count = snap.data?.docs.length ?? 0;
        if (count == 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.brandRed,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: GoogleFonts.inter(
              fontSize: 9, fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  CombinedPendingBadge — feed posts + achievement posts
// ═══════════════════════════════════════════════════════════════
class CombinedPendingBadge extends StatelessWidget {
  const CombinedPendingBadge({super.key});

  @override
  Widget build(BuildContext context) {
    // Combine both streams by watching each independently
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('alumni_posts')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, feedSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('achievement_posts')
              .where('status', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, achSnap) {
            final total = (feedSnap.data?.docs.length ?? 0) +
                (achSnap.data?.docs.length ?? 0);
            if (total == 0) return const SizedBox.shrink();
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.brandRed,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$total',
                style: GoogleFonts.inter(
                  fontSize: 9, fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  _PostDetailDialog  — full review modal
// ═══════════════════════════════════════════════════════════════
class _PostDetailDialog extends StatefulWidget {
  final Map<String, dynamic> post;
  final String postId;
  final VoidCallback onActionComplete;

  const _PostDetailDialog({
    required this.post,
    required this.postId,
    required this.onActionComplete,
  });

  @override
  State<_PostDetailDialog> createState() => _PostDetailDialogState();
}

class _PostDetailDialogState extends State<_PostDetailDialog> {
  final _reasonCtrl = TextEditingController();
  bool _isSubmitting = false;
  String? _actionInProgress;

  String _fmt(Timestamp? ts) {
    if (ts == null) return '—';
    return DateFormat('MMM d, yyyy · h:mm a').format(ts.toDate());
  }

  Future<void> _doAction(String action) async {
    if ((action == 'reject' || action == 'flag') &&
        _reasonCtrl.text.trim().isEmpty) {
      _showSnack(
        action == 'reject' ? 'Rejection reason required' : 'Flag reason required',
        isError: true,
      );
      return;
    }

    setState(() { _isSubmitting = true; _actionInProgress = action; });

    try {
      switch (action) {
        case 'approve': await PostApprovalService.approve(widget.postId);
        case 'reject':  await PostApprovalService.reject(widget.postId, _reasonCtrl.text);
        case 'flag':    await PostApprovalService.flag(widget.postId, _reasonCtrl.text);
      }
      if (mounted) {
        Navigator.of(context).pop();
        widget.onActionComplete();
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Error: $e', isError: true);
        setState(() { _isSubmitting = false; _actionInProgress = null; });
      }
    }
  }

  void _showSnack(String msg, {required bool isError}) {
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
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p           = widget.post;
    final content     = p['content']?.toString()      ?? '';
    final authorName  = p['authorName']?.toString()   ?? 'Unknown';
    final authorPhoto = p['authorPhotoUrl']?.toString();
    final authorRole  = p['authorRole']?.toString()   ?? 'alumni';
    final postType    = p['postType']?.toString()     ?? 'update';
    final status      = p['status']?.toString()       ?? 'pending';
    final createdAt   = p['createdAt'] as Timestamp?;
    final mediaUrls   = (p['mediaUrls'] as List<dynamic>?)
            ?.map((e) => e.toString()).toList() ?? [];
    final tags        = (p['tags'] as List<dynamic>?)
            ?.map((e) => e.toString()).toList() ?? [];
    final reportCount = (p['reportCount'] as num?)?.toInt() ?? 0;
    final isPending   = status == 'pending' || status == 'flagged';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Container(
        width: 680,
        constraints: const BoxConstraints(maxHeight: 780),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 40, spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─── Header ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.softWhite,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
              ),
              child: Row(children: [
                const Icon(Icons.rate_review_outlined,
                    color: AppColors.brandRed, size: 20),
                const SizedBox(width: 10),
                Text('Post Review',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 22, fontWeight: FontWeight.w600,
                      color: AppColors.darkText,
                    )),
                const SizedBox(width: 12),
                _StatusChip(status),
                if (reportCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _kRejected.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.flag_outlined, size: 10, color: _kRejected),
                      const SizedBox(width: 4),
                      Text('$reportCount report${reportCount > 1 ? 's' : ''}',
                          style: GoogleFonts.inter(
                            fontSize: 9, fontWeight: FontWeight.w700,
                            color: _kRejected,
                          )),
                    ]),
                  ),
                ],
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: AppColors.mutedText, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ]),
            ),

            // ─── Body ─────────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.brandRed.withOpacity(0.1),
                        backgroundImage: authorPhoto != null
                            ? NetworkImage(authorPhoto) : null,
                        child: authorPhoto == null
                            ? Text(authorName[0].toUpperCase(),
                                style: GoogleFonts.inter(
                                  color: AppColors.brandRed,
                                  fontWeight: FontWeight.w700, fontSize: 14,
                                ))
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(authorName,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700, fontSize: 14,
                                color: AppColors.darkText,
                              )),
                          Row(children: [
                            Text(authorRole.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 10, letterSpacing: 0.5,
                                  color: AppColors.mutedText,
                                )),
                            const SizedBox(width: 8),
                            _TypeChip(postType),
                          ]),
                        ],
                      )),
                      Text(_fmt(createdAt),
                          style: GoogleFonts.inter(
                            fontSize: 11, color: AppColors.mutedText,
                          )),
                    ]),

                    const SizedBox(height: 20),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.softWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Text(content,
                          style: GoogleFonts.inter(
                            fontSize: 14, height: 1.6,
                            color: AppColors.darkText,
                          )),
                    ),

                    if (mediaUrls.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 80,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: mediaUrls.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) => ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              mediaUrls[i],
                              width: 80, height: 80, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 80, height: 80,
                                color: AppColors.borderSubtle,
                                child: const Icon(Icons.broken_image_outlined,
                                    color: AppColors.mutedText),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],

                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6, runSpacing: 6,
                        children: tags.map((t) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('#$t',
                              style: GoogleFonts.inter(
                                fontSize: 11, color: Colors.blue.shade700,
                              )),
                        )).toList(),
                      ),
                    ],

                    if (isPending) ...[
                      const SizedBox(height: 20),
                      Text(
                        'Rejection / Flag Reason (required for reject or flag)',
                        style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: AppColors.mutedText, letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _reasonCtrl,
                        maxLines: 3,
                        style: GoogleFonts.inter(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'e.g. Content violates community guidelines',
                          hintStyle: GoogleFonts.inter(
                            color: AppColors.mutedText, fontSize: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.borderSubtle),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.borderSubtle),
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
            ),

            // ─── Action bar ──────────────────────────────────────
            if (isPending)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.softWhite,
                  borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(20)),
                  border: Border(top: BorderSide(color: AppColors.borderSubtle)),
                ),
                child: Row(children: [
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
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Reusable action button ──────────────────────────────────────
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
                color: filled ? Colors.white : color,
              ),
            )
          else
            Icon(icon, size: 15, color: filled ? Colors.white : color),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: filled ? Colors.white : color,
              )),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PostApprovalPanel  — main widget
// ═══════════════════════════════════════════════════════════════
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
  bool _bulkMode = false;
  bool _isBulkApproving = false;

  static const _filters = ['pending', 'approved', 'rejected', 'flagged'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _filters.length, vsync: this);
    _tabs.addListener(() => setState(() => _selected.clear()));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String get _currentFilter => _filters[_tabs.index];

  // ── No unnecessary cast: typed directly as CollectionReference<Map<String,dynamic>>
  Stream<QuerySnapshot<Map<String, dynamic>>> get _postStream =>
      FirebaseFirestore.instance
          .collection('alumni_posts')
          .where('status', isEqualTo: _currentFilter)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots();

  Future<void> _bulkApprove() async {
    if (_selected.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Bulk Approve',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text('Approve ${_selected.length} selected post(s)?',
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
                  color: _kApproved, fontWeight: FontWeight.w700,
                )),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _isBulkApproving = true);
    try {
      await PostApprovalService.bulkApprove(_selected.toList());
      _showSnack('${_selected.length} posts approved', isError: false);
      setState(() { _selected.clear(); _bulkMode = false; _isBulkApproving = false; });
      widget.onRefreshStats?.call();
    } catch (e) {
      _showSnack('Bulk approve failed: $e', isError: true);
      setState(() => _isBulkApproving = false);
    }
  }

  void _showSnack(String msg, {required bool isError}) {
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
        onActionComplete: () {
          _showSnack('Action completed', isError: false);
          widget.onRefreshStats?.call();
        },
      ),
    );
  }

  String _fmt(Timestamp? ts) {
    if (ts == null) return '—';
    final date = ts.toDate();
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    if (diff.inDays < 7)     return '${diff.inDays}d ago';
    return DateFormat('MMM d, yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Panel header ──────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('Post Approval Queue',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 22, fontWeight: FontWeight.w600,
                      color: AppColors.darkText,
                    )),
                const SizedBox(width: 10),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('alumni_posts')
                      .where('status', isEqualTo: 'pending')
                      .snapshots(),
                  builder: (_, snap) {
                    final n = snap.data?.docs.length ?? 0;
                    if (n == 0) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _kPending,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('$n pending',
                          style: GoogleFonts.inter(
                            fontSize: 10, fontWeight: FontWeight.w800,
                            color: Colors.white,
                          )),
                    );
                  },
                ),
              ]),
              Text('Review alumni posts before publishing',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.mutedText)),
            ]),
            if (_currentFilter == 'pending') Row(children: [
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
                    _bulkMode ? 'CANCEL BULK' : 'BULK SELECT',
                    style: GoogleFonts.inter(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: _bulkMode
                          ? AppColors.brandRed
                          : AppColors.mutedText,
                    ),
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
                        : Text(
                            'APPROVE ${_selected.length}',
                            style: GoogleFonts.inter(
                              fontSize: 10, fontWeight: FontWeight.w700,
                              letterSpacing: 1, color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ]),
          ],
        ),

        const SizedBox(height: 16),

        // ─── Tabs ─────────────────────────────────────────────
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

        // ─── Post list ───────────────────────────────────────
        // No cast needed — _postStream is already typed
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _postStream,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(
                    color: AppColors.brandRed, strokeWidth: 2)),
              );
            }

            if (snap.hasError) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(child: Text('Error: ${snap.error}',
                    style: GoogleFonts.inter(color: Colors.red, fontSize: 13))),
              );
            }

            final docs = snap.data?.docs ?? [];

            if (docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    _currentFilter == 'pending'
                        ? Icons.check_circle_outline
                        : Icons.inbox_outlined,
                    size: 40,
                    color: _currentFilter == 'pending'
                        ? Colors.green : AppColors.mutedText,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentFilter == 'pending'
                        ? 'Queue is clear!'
                        : 'No $_currentFilter posts',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: _currentFilter == 'pending'
                          ? Colors.green : AppColors.mutedText,
                    ),
                  ),
                ])),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              separatorBuilder: (_, __) =>
                  const Divider(color: AppColors.borderSubtle, height: 1),
              itemBuilder: (context, i) {
                final doc  = docs[i];
                final data = doc.data();
                final id   = doc.id;

                final authorName  = data['authorName']?.toString()   ?? 'Unknown';
                final authorPhoto = data['authorPhotoUrl']?.toString();
                final content     = data['content']?.toString()       ?? '';
                final postType    = data['postType']?.toString()      ?? 'update';
                final status      = data['status']?.toString()        ?? 'pending';
                final createdAt   = data['createdAt'] as Timestamp?;
                final reportCount = (data['reportCount'] as num?)?.toInt() ?? 0;
                final isSelected  = _selected.contains(id);

                return InkWell(
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
                        horizontal: 8, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _kApproved.withOpacity(0.06)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_bulkMode && status == 'pending')
                          Padding(
                            padding: const EdgeInsets.only(right: 10, top: 2),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 18, height: 18,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? _kApproved : Colors.transparent,
                                border: Border.all(
                                  color: isSelected
                                      ? _kApproved : AppColors.borderSubtle,
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check,
                                      size: 12, color: Colors.white)
                                  : null,
                            ),
                          ),

                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.brandRed.withOpacity(0.1),
                          backgroundImage: authorPhoto != null
                              ? NetworkImage(authorPhoto) : null,
                          child: authorPhoto == null
                              ? Text(
                                  authorName.isNotEmpty
                                      ? authorName[0].toUpperCase() : '?',
                                  style: GoogleFonts.inter(
                                    color: AppColors.brandRed,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ))
                              : null,
                        ),
                        const SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Text(authorName,
                                    style: GoogleFonts.inter(
                                      fontSize: 13, fontWeight: FontWeight.w600,
                                      color: AppColors.darkText,
                                    )),
                                const SizedBox(width: 8),
                                _TypeChip(postType),
                                if (reportCount > 0) ...[
                                  const SizedBox(width: 6),
                                  Icon(Icons.flag_outlined,
                                      size: 12, color: _kRejected),
                                  Text('$reportCount',
                                      style: GoogleFonts.inter(
                                        fontSize: 10, color: _kRejected,
                                        fontWeight: FontWeight.w700,
                                      )),
                                ],
                                const Spacer(),
                                _StatusChip(status),
                                const SizedBox(width: 8),
                                Text(_fmt(createdAt),
                                    style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: AppColors.mutedText)),
                              ]),
                              const SizedBox(height: 4),
                              Text(content,
                                  style: GoogleFonts.inter(
                                    fontSize: 12, color: AppColors.mutedText,
                                    height: 1.4,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),

                        if (!_bulkMode && status == 'pending')
                          Padding(
                            padding: const EdgeInsets.only(left: 10),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              _QuickBtn(
                                icon: Icons.check,
                                color: _kApproved,
                                tooltip: 'Quick approve',
                                onTap: () async {
                                  await PostApprovalService.approve(id);
                                  _showSnack('Post approved', isError: false);
                                  widget.onRefreshStats?.call();
                                },
                              ),
                              const SizedBox(width: 4),
                              _QuickBtn(
                                icon: Icons.close,
                                color: _kRejected,
                                tooltip: 'Review & reject',
                                onTap: () => _openDetail(id, data),
                              ),
                            ]),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

// ─── Small quick-action button ───────────────────────────────────
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