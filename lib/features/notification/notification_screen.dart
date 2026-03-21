import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:alumni/core/constants/app_colors.dart';
import 'notification_service.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
          body: Center(child: Text('Not logged in')));
    }

    return Scaffold(
      backgroundColor: AppColors.softWhite,
      appBar: AppBar(
        backgroundColor: AppColors.cardWhite,
        elevation: 0,
        title: Text(
          'Notifications',
          style: GoogleFonts.cormorantGaramond(fontSize: 26),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () => NotificationService.markAllRead(),
            child: Text(
              'Mark all read',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.brandRed,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('toUid', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          // ─── Error state ───
          if (snapshot.hasError) {
            final error = snapshot.error.toString();
            final needsIndex =
                error.contains('FAILED_PRECONDITION') ||
                    error.contains('requires an index');

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      needsIndex
                          ? Icons.storage_outlined
                          : Icons.error_outline,
                      size: 56,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      needsIndex
                          ? 'Database index required'
                          : 'Failed to load notifications',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      needsIndex
                          ? 'Go to Firebase Console → Firestore → Indexes and create a composite index:\n\nCollection: notifications\ntoUid → Ascending\ncreatedAt → Descending'
                          : error,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.mutedText,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          // ─── Loading ───
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                  color: AppColors.brandRed),
            );
          }

          // ─── Empty ───
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none_outlined,
                      size: 72, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: GoogleFonts.cormorantGaramond(
                        fontSize: 24, color: AppColors.darkText),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You\'ll be notified about messages,\nevents, announcements and friend requests here.',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: AppColors.mutedText),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final notifications = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: notifications.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: AppColors.borderSubtle),
            itemBuilder: (context, index) {
              final doc = notifications[index];
              final data = doc.data() as Map<String, dynamic>;
              return _NotificationTile(id: doc.id, data: data);
            },
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;

  const _NotificationTile({required this.id, required this.data});

  IconData _iconForType(String type) {
    switch (type) {
      case 'message':
        return Icons.chat_bubble_outline_rounded;
      case 'event':
        return Icons.event_outlined;
      case 'announcement':
        return Icons.campaign_outlined;
      case 'friend_request':
        return Icons.person_add_outlined;
      case 'friend_accepted':
        return Icons.people_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'message':
        return AppColors.brandRed;
      case 'event':
        return Colors.blue.shade600;
      case 'announcement':
        return Colors.orange.shade600;
      case 'friend_request':
        return Colors.purple.shade600;
      case 'friend_accepted':
        return Colors.green.shade600;
      default:
        return AppColors.mutedText;
    }
  }

  String _formatTime(dynamic value) {
    if (value == null) return '';
    final dt =
        value is Timestamp ? value.toDate() : DateTime.now();
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final type = data['type']?.toString() ?? '';
    final title = data['title']?.toString() ?? '';
    final body = data['body']?.toString() ?? '';
    final isRead = data['read'] == true;
    final createdAt = data['createdAt'];
    final color = _colorForType(type);

    return InkWell(
      onTap: () {
        if (!isRead) NotificationService.markRead(id);
        _handleTap(context, type);
      },
      child: Container(
        color: isRead
            ? Colors.transparent
            : AppColors.brandRed.withOpacity(0.04),
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Icon ───
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_iconForType(type),
                  color: color, size: 22),
            ),
            const SizedBox(width: 14),

            // ─── Content ───
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: isRead
                                ? FontWeight.w500
                                : FontWeight.w700,
                            color: AppColors.darkText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(createdAt),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    body,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: isRead
                          ? AppColors.mutedText
                          : AppColors.darkText,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // ─── Friend request inline actions ───
                  if (type == 'friend_request' && !isRead) ...[
                    const SizedBox(height: 10),
                    _FriendRequestActions(
                      notificationId: id,
                      fromUid: data['refId']?.toString() ?? '',
                    ),
                  ],

                  // ─── Unread dot ───
                  if (isRead == false &&
                      type != 'friend_request') ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'New',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleTap(BuildContext context, String type) {
    switch (type) {
      case 'message':
        Navigator.pushNamed(context, '/messages');
        break;
      case 'event':
        Navigator.pushNamed(context, '/events');
        break;
      case 'announcement':
        Navigator.pushNamed(context, '/announcements');
        break;
      case 'friend_request':
        Navigator.pushNamed(context, '/friends');
        break;
      case 'friend_accepted':
        Navigator.pushNamed(context, '/friends');
        break;
    }
  }
}

// ─────────────────────────────────────────────
// Inline accept / decline for friend_request notifications
// ─────────────────────────────────────────────
class _FriendRequestActions extends StatefulWidget {
  final String notificationId;
  final String fromUid;

  const _FriendRequestActions({
    required this.notificationId,
    required this.fromUid,
  });

  @override
  State<_FriendRequestActions> createState() =>
      _FriendRequestActionsState();
}

class _FriendRequestActionsState
    extends State<_FriendRequestActions> {
  bool _isLoading = false;
  bool _isDone = false;
  String _doneMessage = '';
  final currentUid = FirebaseAuth.instance.currentUser!.uid;

  Future<void> _accept() async {
    setState(() => _isLoading = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      final now = FieldValue.serverTimestamp();

      batch.set(
          FirebaseFirestore.instance
              .collection('users')
              .doc(currentUid)
              .collection('connections')
              .doc(widget.fromUid),
          {'connectedAt': now});

      batch.set(
          FirebaseFirestore.instance
              .collection('users')
              .doc(widget.fromUid)
              .collection('connections')
              .doc(currentUid),
          {'connectedAt': now});

      batch.delete(FirebaseFirestore.instance
          .collection('friend_requests')
          .doc('${widget.fromUid}_$currentUid'));

      batch.update(
          FirebaseFirestore.instance
              .collection('users')
              .doc(currentUid),
          {'connectionsCount': FieldValue.increment(1)});

      batch.update(
          FirebaseFirestore.instance
              .collection('users')
              .doc(widget.fromUid),
          {'connectionsCount': FieldValue.increment(1)});

      await batch.commit();

      // Mark the notification as read
      await NotificationService.markRead(widget.notificationId);

      // Notify the sender
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .get();
      final acceptorName =
          currentUserDoc.data()?['name']?.toString() ?? 'Someone';

      await NotificationService.sendFriendAcceptedNotification(
        toUid: widget.fromUid,
        acceptorName: acceptorName,
        acceptorUid: currentUid,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isDone = true;
          _doneMessage = 'Connected!';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _decline() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('friend_requests')
          .doc('${widget.fromUid}_$currentUid')
          .delete();

      await NotificationService.markRead(widget.notificationId);

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isDone = true;
          _doneMessage = 'Request declined';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isDone) {
      return Text(
        _doneMessage,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _doneMessage == 'Connected!'
              ? Colors.green.shade700
              : AppColors.mutedText,
        ),
      );
    }

    if (_isLoading) {
      return const SizedBox(
        height: 24,
        width: 24,
        child: CircularProgressIndicator(
            strokeWidth: 2.5, color: AppColors.brandRed),
      );
    }

    return Row(
      children: [
        ElevatedButton(
          onPressed: _accept,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brandRed,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: Text('Accept',
              style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: _decline,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.mutedText,
            side:
                const BorderSide(color: AppColors.borderSubtle),
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: Text('Decline',
              style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}