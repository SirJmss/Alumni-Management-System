import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:alumni/core/constants/app_colors.dart';
import 'package:alumni/features/notification/notification_service.dart';
import 'package:alumni/features/notification/notification_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// InAppNotificationOverlay
//
// Wrap any screen (typically DashboardScreen's Scaffold) with this widget.
// It listens for new Firestore notifications and slides in a banner at the
// top of the screen for each new one. Banners auto-dismiss after 4 s and
// support tap-to-navigate + swipe-to-dismiss.
//
// Usage:
//   InAppNotificationOverlay(
//     child: Scaffold(...),
//   )
// ─────────────────────────────────────────────────────────────────────────────
class InAppNotificationOverlay extends StatefulWidget {
  final Widget child;

  const InAppNotificationOverlay({super.key, required this.child});

  @override
  State<InAppNotificationOverlay> createState() =>
      _InAppNotificationOverlayState();
}

class _InAppNotificationOverlayState
    extends State<InAppNotificationOverlay> {
  // Queue so rapid bursts don't stack more than 3 banners
  final List<_PendingBanner> _queue = [];
  bool _isShowing = false;

  StreamSubscription<QuerySnapshot>? _sub;
  // Tracks the most-recent doc we've already shown, to prevent re-showing
  // on widget rebuild / stream re-attach.
  DateTime? _sessionStart;

  @override
  void initState() {
    super.initState();
    // Only show notifications that arrive AFTER the widget mounts
    _sessionStart = DateTime.now();
    _attachStream();
  }

  void _attachStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    _sub = FirebaseFirestore.instance
        .collection('notifications')
        .where('toUid', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots()
        .listen(_onSnapshot);
  }

  void _onSnapshot(QuerySnapshot snap) {
    if (!mounted) return;

    for (final change in snap.docChanges) {
      if (change.type != DocumentChangeType.added) continue;

      final data = change.doc.data() as Map<String, dynamic>?;
      if (data == null) continue;

      // Filter: only show docs created after this session started
      final ts = data['createdAt'];
      if (ts is Timestamp) {
        final createdAt = ts.toDate();
        if (createdAt.isBefore(_sessionStart!)) continue;
      }

      final type =
          NotifTypeX.fromString(data['type']?.toString() ?? '');
      final title = data['title']?.toString() ?? '';
      final body  = data['body']?.toString()  ?? '';
      final refId = data['refId']?.toString() ?? '';
      final badge = (data['badgeCount'] as int?) ?? 1;

      if (title.isEmpty) continue;

      _enqueue(_PendingBanner(
        id:         change.doc.id,
        type:       type,
        title:      title,
        body:       body,
        refId:      refId,
        badgeCount: badge,
      ));
    }
  }

  void _enqueue(_PendingBanner banner) {
    if (_queue.length >= 3) return; // cap burst
    _queue.add(banner);
    if (!_isShowing) _showNext();
  }

  void _showNext() {
    if (_queue.isEmpty || !mounted) {
      _isShowing = false;
      return;
    }
    _isShowing = true;
    final banner = _queue.removeAt(0);

    _BannerManager.show(context, banner, onDismissed: _showNext);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ─────────────────────────────────────────────────────────────────────────────
// _BannerManager — uses an OverlayEntry to show the animated banner
// ─────────────────────────────────────────────────────────────────────────────
class _BannerManager {
  static void show(
    BuildContext context,
    _PendingBanner banner, {
    required VoidCallback onDismissed,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _BannerWidget(
        banner: banner,
        onDismiss: () {
          entry.remove();
          onDismissed();
        },
        onTap: () {
          entry.remove();
          onDismissed();
          NotificationService.markRead(banner.id);
          _navigate(context, banner.type, banner.refId);
        },
      ),
    );

    overlay.insert(entry);
  }

  static void _navigate(
      BuildContext context, NotifType type, String refId) {
    switch (type) {
      case NotifType.message:
        Navigator.pushNamed(context, '/messages',
            arguments: refId.isNotEmpty ? refId : null);
        break;
      case NotifType.event:
        Navigator.pushNamed(context, '/events',
            arguments: refId.isNotEmpty ? refId : null);
        break;
      case NotifType.announcement:
        Navigator.pushNamed(context, '/announcements',
            arguments: refId.isNotEmpty ? refId : null);
        break;
      case NotifType.jobOpportunity:
        Navigator.pushNamed(context, '/jobs',
            arguments: refId.isNotEmpty ? refId : null);
        break;
      case NotifType.gallery:
        Navigator.pushNamed(context, '/gallery',
            arguments: refId.isNotEmpty ? refId : null);
        break;
      case NotifType.friendRequest:
      case NotifType.friendAccepted:
        Navigator.pushNamed(context, '/friends');
        break;
      case NotifType.system:
        Navigator.push(context,
            MaterialPageRoute(
                builder: (_) => const NotificationsScreen()));
        break;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _BannerWidget — the animated sliding banner
// ─────────────────────────────────────────────────────────────────────────────
class _BannerWidget extends StatefulWidget {
  final _PendingBanner banner;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  const _BannerWidget({
    required this.banner,
    required this.onDismiss,
    required this.onTap,
  });

  @override
  State<_BannerWidget> createState() => _BannerWidgetState();
}

class _BannerWidgetState extends State<_BannerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset>   _slide;
  late final Animation<double>   _fade;
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));

    _fade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _ctrl.forward();

    // Auto-dismiss after 4 s
    _autoTimer = Timer(const Duration(seconds: 4), _dismiss);
  }

  Future<void> _dismiss() async {
    _autoTimer?.cancel();
    if (!mounted) return;
    await _ctrl.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Color _colorForType(NotifType t) {
    switch (t) {
      case NotifType.message:       return AppColors.brandRed;
      case NotifType.event:         return Colors.blue.shade600;
      case NotifType.announcement:  return Colors.orange.shade600;
      case NotifType.jobOpportunity:return Colors.teal.shade600;
      case NotifType.gallery:       return Colors.pink.shade500;
      case NotifType.friendRequest: return Colors.purple.shade600;
      case NotifType.friendAccepted:return Colors.green.shade600;
      case NotifType.system:        return Colors.grey.shade600;
    }
  }

  IconData _iconForType(NotifType t) {
    switch (t) {
      case NotifType.message:       return Icons.chat_bubble_rounded;
      case NotifType.event:         return Icons.event_rounded;
      case NotifType.announcement:  return Icons.campaign_rounded;
      case NotifType.jobOpportunity:return Icons.work_rounded;
      case NotifType.gallery:       return Icons.photo_library_rounded;
      case NotifType.friendRequest: return Icons.person_add_rounded;
      case NotifType.friendAccepted:return Icons.people_rounded;
      case NotifType.system:        return Icons.info_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForType(widget.banner.type);
    final safeTop = MediaQuery.of(context).padding.top;
    final badge   = widget.banner.badgeCount;
    final showBadge = badge > 1;

    return Positioned(
      top: safeTop + 8,
      left: 12,
      right: 12,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Dismissible(
            key: ValueKey(widget.banner.id),
            direction: DismissDirection.up,
            onDismissed: (_) => widget.onDismiss(),
            child: GestureDetector(
              onTap: widget.onTap,
              child: Material(
                elevation: 12,
                borderRadius: BorderRadius.circular(16),
                shadowColor: Colors.black.withOpacity(0.18),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: color.withOpacity(0.25), width: 1.5),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Colored accent bar
                      Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Icon + optional badge
                            Stack(clipBehavior: Clip.none, children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(_iconForType(widget.banner.type),
                                    color: color, size: 20),
                              ),
                              if (showBadge)
                                Positioned(
                                  top: -5, right: -5,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.brandRed,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: Colors.white, width: 1.5),
                                    ),
                                    child: Text(
                                      badge > 99 ? '99+' : '$badge',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                            ]),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Expanded(
                                      child: Text(
                                        widget.banner.title,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF1A1A1A),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('now',
                                        style: GoogleFonts.inter(
                                            fontSize: 10,
                                            color: Colors.grey.shade400)),
                                  ]),
                                  if (widget.banner.body.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      (widget.banner.type ==
                                                  NotifType.message &&
                                              badge > 1)
                                          ? '$badge new messages · ${widget.banner.body}'
                                          : widget.banner.body,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                        height: 1.35,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Dismiss X
                            GestureDetector(
                              onTap: _dismiss,
                              child: Icon(Icons.close_rounded,
                                  size: 16, color: Colors.grey.shade400),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data model for a pending banner
// ─────────────────────────────────────────────────────────────────────────────
class _PendingBanner {
  final String    id;
  final NotifType type;
  final String    title;
  final String    body;
  final String    refId;
  final int       badgeCount;

  const _PendingBanner({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.refId,
    required this.badgeCount,
  });
}