import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:alumni/core/constants/app_colors.dart';
import 'chat_screen.dart';
import 'alumni_search_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final currentUid = FirebaseAuth.instance.currentUser?.uid;

  void _goToSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AlumniSearchScreen()),
    );
  }

  int _getUnreadCount(Map<String, dynamic> chat, String uid) {
    final unread = chat['unreadCount'] as Map?;
    if (unread == null) return 0;
    return (unread[uid] as int?) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    if (currentUid == null) {
      return const Scaffold(
        body: Center(child: Text('Not logged in')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.softWhite,
      appBar: AppBar(
        backgroundColor: AppColors.cardWhite,
        elevation: 0,
        title: Text(
          'Messages',
          style: GoogleFonts.cormorantGaramond(fontSize: 26),
        ),
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
            .where('memberIds', arrayContains: currentUid)
            .orderBy('lastMessageAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {

          // ─── Error state ───
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(
                    'Failed to load messages',
                    style: GoogleFonts.inter(
                        fontSize: 14, color: AppColors.mutedText),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: GoogleFonts.inter(
                        fontSize: 11, color: AppColors.mutedText),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          // ─── Loading state ───
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.brandRed),
            );
          }

          // ─── Empty state ───
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

          // ─── Chat list ───
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
              final chat = chats[index].data() as Map<String, dynamic>;
              final chatId = chats[index].id;

              final List memberIds = chat['memberIds'] ?? [];
              final otherUid = memberIds.firstWhere(
                (id) => id != currentUid,
                orElse: () => '',
              );

              if (otherUid.isEmpty) return const SizedBox.shrink();

              return _ChatTile(
                chatId: chatId,
                otherUid: otherUid.toString(),
                lastMessage: chat['lastMessage']?.toString() ?? '',
                lastMessageAt: chat['lastMessageAt'] as Timestamp?,
                unreadCount: _getUnreadCount(chat, currentUid!),
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Chat tile ───
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
    final dt = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return DateFormat('hh:mm a').format(dt);
    if (diff.inDays < 7) return DateFormat('EEE').format(dt);
    return DateFormat('MM/dd/yy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(otherUid)
          .get(),
      builder: (context, snapshot) {

        // ─── Loading skeleton ───
        if (!snapshot.hasData) {
          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: const CircleAvatar(
              radius: 28,
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, color: Colors.white),
            ),
            title: Container(
              height: 14,
              width: 100,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            subtitle: Container(
              height: 12,
              width: 160,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        }

        // ─── Error loading user ───
        if (snapshot.hasError) {
          return const ListTile(
            leading: CircleAvatar(
              radius: 28,
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, color: Colors.white),
            ),
            title: Text('Unknown user'),
          );
        }

        final user = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final name = user['name']?.toString() ?? 'Unknown';
        final avatarUrl = user['profilePictureUrl']?.toString() ?? '';
        final hasAvatar = avatarUrl.isNotEmpty;
        final timeStr = _formatTime(lastMessageAt);
        final hasUnread = unreadCount > 0;

        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),

          // ─── Avatar ───
          leading: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AlumniPublicProfileScreen(uid: otherUid),
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.borderSubtle,
                  child: hasAvatar
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: avatarUrl,
                            fit: BoxFit.cover,
                            width: 56,
                            height: 56,
                            errorWidget: (_, __, ___) => const Icon(
                                Icons.person,
                                color: AppColors.brandRed),
                          ),
                        )
                      : const Icon(Icons.person,
                          color: AppColors.brandRed),
                ),
              ],
            ),
          ),

          // ─── Name + time ───
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
                  fontWeight:
                      hasUnread ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),

          // ─── Last message + unread badge ───
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    lastMessage.isEmpty ? 'Tap to chat' : lastMessage,
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