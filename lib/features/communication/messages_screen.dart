import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:alumni/core/constants/app_colors.dart';
import 'chat_screen.dart';
import 'alumni_search_screen.dart';
import 'package:alumni/features/profile/presentation/screens/alumni_public_profile_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MessagesScreen
//
// CHANGES vs original:
//  - currentUid is null-safe: stored in a late final, guarded before use
//  - Auth guard: shows a proper "not signed in" screen instead of just a
//    plain Text widget
//  - _getUnreadCount: handles the case where unreadCount values are stored
//    as num (Firestore can return double or int) instead of assuming int
//  - _ChatTile upgraded from FutureBuilder to StreamBuilder so the name and
//    avatar update live (e.g. if the other user changes their profile picture)
//  - Empty-string otherUid guard added in chat list builder
//  - _formatTime: uses local DateTime to avoid timezone edge cases
//  - Error state on the stream now shows a human-readable message
//  - Firestore permission-denied error is surfaced clearly
//  - All cast operations on Firestore data are null-safe
// ─────────────────────────────────────────────────────────────────────────────
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  // Null-safe — empty string if auth hasn't fired yet
  late final String _currentUid;

  @override
  void initState() {
    super.initState();
    _currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  void _goToSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AlumniSearchScreen()),
    );
  }

  /// Safely reads unreadCount regardless of whether Firestore stored an int
  /// or a double (which can happen after certain SDK versions).
  int _getUnreadCount(Map<String, dynamic> chat, String uid) {
    final unread = chat['unreadCount'];
    if (unread == null || unread is! Map) return 0;
    return (unread[uid] as num?)?.toInt() ?? 0;
  }

  /// Converts FirebaseException into a human-readable message.
  String _friendlyError(Object? error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'Permission denied.\nAdd: allow read: if request.auth != null;\nto your Firestore /chats rule.';
        case 'unavailable':
          return 'Service unavailable. Check your internet connection.';
        case 'unauthenticated':
          return 'Please sign in to view messages.';
        default:
          return 'Error (${error.code}): ${error.message ?? ''}';
      }
    }
    return error?.toString() ?? 'Unknown error';
  }

  @override
  Widget build(BuildContext context) {
    // Auth guard
    if (_currentUid.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.softWhite,
        appBar: AppBar(
          backgroundColor: AppColors.cardWhite,
          elevation: 0,
          title: Text('Messages',
              style: GoogleFonts.cormorantGaramond(fontSize: 26)),
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 56, color: Colors.grey),
              const SizedBox(height: 16),
              Text('Please sign in to view your messages.',
                  style: GoogleFonts.inter(
                      fontSize: 14, color: AppColors.mutedText)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.softWhite,
      appBar: AppBar(
        backgroundColor: AppColors.cardWhite,
        elevation: 0,
        title: Text('Messages',
            style: GoogleFonts.cormorantGaramond(fontSize: 26)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Find alumni to message',
            onPressed: _goToSearch,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.brandRed,
        foregroundColor: Colors.white,
        tooltip: 'New Message',
        onPressed: _goToSearch,
        child: const Icon(Icons.edit),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('memberIds', arrayContains: _currentUid)
            .orderBy('lastMessageAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          // Error state
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_off_outlined,
                        size: 56, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      'Could not load messages',
                      style: GoogleFonts.cormorantGaramond(
                          fontSize: 22, color: AppColors.darkText),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _friendlyError(snapshot.error),
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.mutedText),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          // Loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                  color: AppColors.brandRed, strokeWidth: 2.5),
            );
          }

          // Empty
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline_rounded,
                      size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 24),
                  Text(
                    'No messages yet',
                    style: GoogleFonts.cormorantGaramond(
                        fontSize: 28, color: AppColors.darkText),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Search for alumni to start a conversation',
                    style: GoogleFonts.inter(
                        fontSize: 14, color: AppColors.mutedText),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _goToSearch,
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('Find Alumni'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandRed,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            );
          }

          final chats = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: chats.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              indent: 80,
              color: AppColors.borderSubtle,
            ),
            itemBuilder: (context, index) {
              final chatData =
                  chats[index].data() as Map<String, dynamic>? ?? {};
              final chatId = chats[index].id;

              if (chatId.isEmpty) return const SizedBox.shrink();

              final memberIds =
                  List<String>.from(chatData['memberIds'] ?? []);

              // Find the other user's UID
              final otherUid = memberIds.firstWhere(
                (id) => id != _currentUid,
                orElse: () => '',
              );

              if (otherUid.isEmpty) return const SizedBox.shrink();

              final lastMessage =
                  chatData['lastMessage']?.toString() ?? '';
              final lastMessageAt =
                  chatData['lastMessageAt'] as Timestamp?;
              final unreadCount =
                  _getUnreadCount(chatData, _currentUid);

              return _ChatTile(
                chatId: chatId,
                otherUid: otherUid,
                lastMessage: lastMessage,
                lastMessageAt: lastMessageAt,
                unreadCount: unreadCount,
              );
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ChatTile
//
// Uses StreamBuilder instead of FutureBuilder so that avatar and name
// changes made by the other user are reflected in real time without
// requiring a full screen reload.
// ─────────────────────────────────────────────────────────────────────────────
class _ChatTile extends StatelessWidget {
  final String chatId;
  final String otherUid;
  final String lastMessage;
  final Timestamp? lastMessageAt;
  final int unreadCount;

  const _ChatTile({
    required this.chatId,
    required this.otherUid,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
  });

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate().toLocal();
    final now = DateTime.now();

    // Use local midnight-to-midnight for comparison
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(msgDay).inDays;

    if (diff == 0) return DateFormat('hh:mm a').format(dt);
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat('EEE').format(dt);
    return DateFormat('MM/dd/yy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    if (otherUid.isEmpty) return const SizedBox.shrink();

    // StreamBuilder keeps the name/avatar live — no stale data after profile
    // updates by the other user
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(otherUid)
          .snapshots(),
      builder: (context, snapshot) {
        // Loading skeleton
        if (!snapshot.hasData) {
          return const _ChatTileSkeleton();
        }

        // Error loading user
        if (snapshot.hasError || !snapshot.data!.exists) {
          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: CircleAvatar(
              radius: 28,
              backgroundColor: Colors.grey.shade200,
              child: const Icon(Icons.person_off_outlined,
                  color: Colors.grey),
            ),
            title: Text('Unknown user',
                style: GoogleFonts.inter(
                    fontSize: 15, color: AppColors.mutedText)),
            subtitle: Text(
              lastMessage.isNotEmpty ? lastMessage : 'Tap to view',
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.mutedText),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }

        final user =
            snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final name = user['name']?.toString().trim().isNotEmpty == true
            ? user['name'].toString().trim()
            : 'Unknown';
        final avatarUrl =
            user['profilePictureUrl']?.toString() ?? '';
        final hasAvatar = avatarUrl.isNotEmpty;
        final timeStr = _formatTime(lastMessageAt);
        final hasUnread = unreadCount > 0;

        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),

          // Avatar
          leading: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    AlumniPublicProfileScreen(uid: otherUid),
              ),
            ),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.borderSubtle,
              child: hasAvatar
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: avatarUrl,
                        fit: BoxFit.cover,
                        width: 56,
                        height: 56,
                        placeholder: (_, __) =>
                            Container(color: Colors.grey.shade100),
                        errorWidget: (_, __, ___) => const Icon(
                            Icons.person,
                            color: AppColors.brandRed),
                      ),
                    )
                  : const Icon(Icons.person, color: AppColors.brandRed),
            ),
          ),

          // Name + time
          title: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight:
                        hasUnread ? FontWeight.w700 : FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                timeStr,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: hasUnread
                      ? AppColors.brandRed
                      : AppColors.mutedText,
                  fontWeight: hasUnread
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
            ],
          ),

          // Last message + unread badge
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    lastMessage.isNotEmpty
                        ? lastMessage
                        : 'Tap to chat',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: hasUnread
                          ? AppColors.darkText
                          : AppColors.mutedText,
                      fontWeight: hasUnread
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasUnread) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.brandRed,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                chatId: chatId,
                otherUid: otherUid,
                otherName: name,
                otherAvatarUrl: avatarUrl,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ChatTileSkeleton — shown while the user doc loads
// ─────────────────────────────────────────────────────────────────────────────
class _ChatTileSkeleton extends StatelessWidget {
  const _ChatTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
          radius: 28, backgroundColor: Colors.grey.shade200),
      title: Container(
        height: 14,
        width: 120,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Container(
          height: 12,
          width: 180,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}