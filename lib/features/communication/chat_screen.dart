import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:alumni/core/constants/app_colors.dart';
import 'alumni_search_screen.dart';
import 'package:alumni/features/notification/notification_service.dart';



class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUid;
  final String otherName;
  final String otherAvatarUrl;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.otherUid,
    required this.otherName,
    required this.otherAvatarUrl,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final currentUid = FirebaseAuth.instance.currentUser!.uid;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _markAsRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _markAsRead() async {
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .update({'unreadCount.$currentUid': 0});
  }

Future<void> _sendMessage() async {
  final text = _messageController.text.trim();
  if (text.isEmpty || _isSending) return;

  setState(() => _isSending = true);
  _messageController.clear();

  try {
    final now = FieldValue.serverTimestamp();
    final batch = FirebaseFirestore.instance.batch();

    // ─── Add message ───
    final msgRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .doc();

    batch.set(msgRef, {
      'text': text,
      'senderId': currentUid,
      'createdAt': now,
    });

    // ─── Update chat metadata ───
    final chatRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId);

    batch.update(chatRef, {
      'lastMessage': text,
      'lastMessageAt': now,
      'unreadCount.${widget.otherUid}': FieldValue.increment(1),
      'unreadCount.$currentUid': 0,
    });

    await batch.commit();

    // ─── Send notification ───
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final senderName =
          userDoc.data()?['name']?.toString() ?? 'Someone';

      await NotificationService.sendMessageNotification(
        toUid: widget.otherUid,
        fromName: senderName,
        messageText: text,
        chatId: widget.chatId,
      );
    }

    // ─── Scroll to bottom ───
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to send: $e'),
            backgroundColor: Colors.red),
      );
    }
  } finally {
    if (mounted) setState(() => _isSending = false);
  }
}

  @override
  Widget build(BuildContext context) {
    final hasAvatar = widget.otherAvatarUrl.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.softWhite,
      appBar: AppBar(
        backgroundColor: AppColors.cardWhite,
        elevation: 0,
        titleSpacing: 0,
        leading: const BackButton(),
        title: GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  AlumniPublicProfileScreen(uid: widget.otherUid),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.borderSubtle,
                child: hasAvatar
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: widget.otherAvatarUrl,
                          fit: BoxFit.cover,
                          width: 36,
                          height: 36,
                          errorWidget: (_, __, ___) => const Icon(
                              Icons.person,
                              color: AppColors.brandRed),
                        ),
                      )
                    : const Icon(Icons.person,
                        color: AppColors.brandRed, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.otherName,
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'View profile',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    AlumniPublicProfileScreen(uid: widget.otherUid),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Messages list ───
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .limit(100)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.brandRed),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.waving_hand_outlined,
                            size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'Say hello to ${widget.otherName}!',
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              color: AppColors.mutedText),
                        ),
                      ],
                    ),
                  );
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg =
                        messages[index].data() as Map<String, dynamic>;
                    final isMe = msg['senderId'] == currentUid;
                    final text = msg['text']?.toString() ?? '';
                    final ts = msg['createdAt'] as Timestamp?;

                    // Show date separator
                    bool showDate = false;
                    if (index == messages.length - 1) {
                      showDate = true;
                    } else {
                      final nextMsg = messages[index + 1].data()
                          as Map<String, dynamic>;
                      final nextTs =
                          nextMsg['createdAt'] as Timestamp?;
                      if (ts != null && nextTs != null) {
                        final curr = ts.toDate();
                        final next = nextTs.toDate();
                        showDate = curr.day != next.day ||
                            curr.month != next.month ||
                            curr.year != next.year;
                      }
                    }

                    return Column(
                      children: [
                        if (showDate && ts != null)
                          _DateSeparator(date: ts.toDate()),
                        _MessageBubble(
                            text: text, isMe: isMe, timestamp: ts),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // ─── Input bar ───
          Container(
            padding: EdgeInsets.only(
              left: 12,
              right: 8,
              top: 10,
              bottom: MediaQuery.of(context).viewInsets.bottom + 10,
            ),
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              border: Border(
                  top: BorderSide(color: AppColors.borderSubtle)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: GoogleFonts.inter(
                          color: AppColors.mutedText, fontSize: 14),
                      filled: true,
                      fillColor: AppColors.softWhite,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: GoogleFonts.inter(fontSize: 14),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                _isSending
                    ? const SizedBox(
                        width: 44,
                        height: 44,
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.brandRed),
                        ),
                      )
                    : IconButton(
                        onPressed: _sendMessage,
                        icon: const Icon(Icons.send_rounded),
                        color: AppColors.brandRed,
                        iconSize: 26,
                        tooltip: 'Send',
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Message bubble ───
class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final Timestamp? timestamp;

  const _MessageBubble({
    required this.text,
    required this.isMe,
    this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = timestamp != null
        ? DateFormat('hh:mm a').format(timestamp!.toDate())
        : '';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppColors.brandRed : AppColors.cardWhite,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: isMe ? Colors.white : AppColors.darkText,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              timeStr,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: isMe
                    ? Colors.white.withOpacity(0.7)
                    : AppColors.mutedText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Date separator ───
class _DateSeparator extends StatelessWidget {
  final DateTime date;

  const _DateSeparator({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    String label;
    if (now.difference(date).inDays == 0) {
      label = 'Today';
    } else if (now.difference(date).inDays == 1) {
      label = 'Yesterday';
    } else {
      label = DateFormat('MMMM d, yyyy').format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: AppColors.borderSubtle)),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.inter(
                fontSize: 12, color: AppColors.mutedText),
          ),
          const SizedBox(width: 12),
          Expanded(child: Divider(color: AppColors.borderSubtle)),
        ],
      ),
    );
  }
}