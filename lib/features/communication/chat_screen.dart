import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:alumni/core/constants/app_colors.dart';
import 'package:alumni/features/notification/notification_service.dart';
import 'package:alumni/features/profile/presentation/screens/alumni_public_profile_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ChatScreen
//
// CHANGES vs original:
//  - Removed import of alumni_search_screen.dart — AlumniPublicProfileScreen
//    is now imported from the canonical location
//  - currentUid is null-safe: uses ?. instead of force-unwrap !
//  - Auth guard: shows safe fallback if currentUid is empty
//  - chatId and otherUid validated before any Firestore write
//  - _markAsRead wrapped in try/catch — silent fail on permission errors
//  - _sendMessage validates text length cap (10,000 chars) to prevent abuse
//  - Notification fetch errors are caught separately so a failed push
//    notification never prevents the message from appearing
//  - Message input cleared AFTER the batch commit guard (restored on error)
//  - Long-press on message bubble → copy to clipboard
//  - Date separator now uses local midnight comparison (not .inDays which
//    can be off by one near midnight depending on timezone)
//  - _formatTime uses local DateTime correctly
//  - Keyboard dismiss on tap outside
//  - Empty-message submit guard is more explicit
//  - _scrollController.hasClients guard before animateTo
// ─────────────────────────────────────────────────────────────────────────────
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
  final _focusNode = FocusNode();

  /// Null-safe — guard against missing auth
  late final String _currentUid;

  bool _isSending = false;

  /// Maximum message length — prevents runaway writes
  static const int _maxMessageLength = 10000;

  @override
  void initState() {
    super.initState();
    _currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _markAsRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ─── Mark as read ─────────────────────────────────────────────────────────
  Future<void> _markAsRead() async {
    if (_currentUid.isEmpty || widget.chatId.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .update({'unreadCount.$_currentUid': 0});
    } on FirebaseException catch (e) {
      // Silent — a failed read-mark should never interrupt UX
      debugPrint('markAsRead error: ${e.code} ${e.message}');
    } catch (e) {
      debugPrint('markAsRead error: $e');
    }
  }

  // ─── Send message ─────────────────────────────────────────────────────────
  Future<void> _sendMessage() async {
    // Auth guard
    if (_currentUid.isEmpty) {
      _showSnack('Please sign in to send messages.', Colors.orange.shade700);
      return;
    }

    // Validate chat / recipient IDs
    if (widget.chatId.isEmpty || widget.otherUid.isEmpty) {
      _showSnack('Invalid chat. Please restart the conversation.',
          Colors.red.shade700);
      return;
    }

    final text = _messageController.text.trim();

    // Empty guard
    if (text.isEmpty) return;
    if (_isSending) return;

    // Length cap
    if (text.length > _maxMessageLength) {
      _showSnack(
          'Message is too long (max $_maxMessageLength characters).',
          Colors.orange.shade700);
      return;
    }

    // Capture text before clearing so we can restore on error
    final sentText = text;
    _messageController.clear();
    setState(() => _isSending = true);

    try {
      final now = FieldValue.serverTimestamp();
      final db = FirebaseFirestore.instance;
      final wb = db.batch();

      // Add message document
      final msgRef = db
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .doc();

      wb.set(msgRef, {
        'text': sentText,
        'senderId': _currentUid,
        'createdAt': now,
      });

      // Update chat metadata
      final chatRef = db.collection('chats').doc(widget.chatId);
      wb.update(chatRef, {
        'lastMessage': sentText,
        'lastMessageAt': now,
        'unreadCount.${widget.otherUid}': FieldValue.increment(1),
        'unreadCount.$_currentUid': 0,
      });

      await wb.commit();

      // Send push notification — catch separately so a failed push never
      // blocks the message from being visible in the chat
      _sendPushNotification(sentText);

      // Scroll to bottom
      _scrollToBottom();
    } on FirebaseException catch (e) {
      // Restore the message text so the user doesn't lose their draft
      _messageController.text = sentText;
      _messageController.selection = TextSelection.collapsed(
          offset: _messageController.text.length);
      if (mounted) {
        _showSnack(_friendlyFirestoreError(e), Colors.red.shade700);
      }
    } catch (e) {
      _messageController.text = sentText;
      _messageController.selection = TextSelection.collapsed(
          offset: _messageController.text.length);
      if (mounted) {
        _showSnack('Failed to send. Please try again.', Colors.red.shade700);
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // Runs fire-and-forget — errors are swallowed intentionally
  void _sendPushNotification(String text) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUid)
          .get();
      final senderName =
          userDoc.data()?['name']?.toString().trim() ?? 'Someone';

      await NotificationService.sendMessageNotification(
        toUid: widget.otherUid,
        fromName: senderName,
        messageText: text,
        chatId: widget.chatId,
      );
    } catch (e) {
      debugPrint('Push notification failed (non-critical): $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: GoogleFonts.inter()),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ));
  }

  String _friendlyFirestoreError(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'Permission denied. Check your Firestore security rules.';
      case 'unavailable':
        return 'Service unavailable. Check your internet connection.';
      case 'unauthenticated':
        return 'Please sign in to send messages.';
      case 'not-found':
        return 'Chat no longer exists.';
      default:
        return 'Error (${e.code}): ${e.message ?? ''}';
    }
  }

  void _openProfile() {
    if (widget.otherUid.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AlumniPublicProfileScreen(uid: widget.otherUid),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Auth guard
    if (_currentUid.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.cardWhite,
          elevation: 0,
          title: Text('Chat',
              style: GoogleFonts.cormorantGaramond(fontSize: 22)),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 56, color: Colors.grey),
              SizedBox(height: 16),
              Text('Please sign in to view this chat.'),
            ],
          ),
        ),
      );
    }

    // Validate chat ID
    if (widget.chatId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.cardWhite,
          elevation: 0,
        ),
        body: const Center(child: Text('Invalid chat ID.')),
      );
    }

    final hasAvatar = widget.otherAvatarUrl.isNotEmpty;

    return GestureDetector(
      // Dismiss keyboard when tapping outside the input
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.softWhite,
        appBar: AppBar(
          backgroundColor: AppColors.cardWhite,
          elevation: 0,
          titleSpacing: 0,
          leading: const BackButton(),
          title: GestureDetector(
            onTap: _openProfile,
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
                            placeholder: (_, __) =>
                                Container(color: Colors.grey.shade100),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.otherName.isNotEmpty
                            ? widget.otherName
                            : 'User',
                        style: GoogleFonts.inter(
                            fontSize: 15, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Tap to view profile',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: AppColors.mutedText),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_outline),
              tooltip: 'View profile',
              onPressed: _openProfile,
            ),
          ],
        ),
        body: Column(
          children: [
            // ── Messages list ────────────────────────────────────────────
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
                  // Error state
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.cloud_off_outlined,
                                size: 48, color: Colors.grey),
                            const SizedBox(height: 12),
                            Text(
                              snapshot.error is FirebaseException &&
                                      (snapshot.error as FirebaseException)
                                              .code ==
                                          'permission-denied'
                                  ? 'Permission denied.\nCheck your Firestore security rules.'
                                  : 'Failed to load messages.',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.mutedText),
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

                  // Empty — no messages yet
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.waving_hand_outlined,
                              size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text(
                            'Say hello to ${widget.otherName.isNotEmpty ? widget.otherName : 'them'}!',
                            style: GoogleFonts.inter(
                                fontSize: 15,
                                color: AppColors.mutedText),
                          ),
                        ],
                      ),
                    );
                  }

                  final messages = snapshot.data!.docs;

                  // Mark as read whenever new messages arrive
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => _markAsRead());

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final rawData = messages[index].data();
                      if (rawData == null) return const SizedBox.shrink();
                      final msg = rawData as Map<String, dynamic>;

                      final isMe = msg['senderId']?.toString() == _currentUid;
                      final text = msg['text']?.toString() ?? '';
                      if (text.isEmpty) return const SizedBox.shrink();

                      final ts = msg['createdAt'] as Timestamp?;

                      // Date separator — compare calendar dates in local time
                      bool showDate = false;
                      if (index == messages.length - 1) {
                        showDate = true;
                      } else if (ts != null) {
                        final nextMsg =
                            messages[index + 1].data() as Map<String, dynamic>?
                                ?? {};
                        final nextTs = nextMsg['createdAt'] as Timestamp?;
                        if (nextTs != null) {
                          final curr = ts.toDate().toLocal();
                          final next = nextTs.toDate().toLocal();
                          showDate = curr.year != next.year ||
                              curr.month != next.month ||
                              curr.day != next.day;
                        }
                      }

                      return Column(
                        children: [
                          if (showDate && ts != null)
                            _DateSeparator(date: ts.toDate()),
                          _MessageBubble(
                            text: text,
                            isMe: isMe,
                            timestamp: ts,
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),

            // ── Input bar ───────────────────────────────────────────────
            _buildInputBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        border: Border(top: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                minLines: 1,
                maxLines: 5,
                maxLength: _maxMessageLength,
                // Hide the counter — we show our own feedback
                buildCounter: (_, {required currentLength,
                    required isFocused,
                    required maxLength}) =>
                    null,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Type a message…',
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
              ),
            ),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: _isSending
                  ? const SizedBox(
                      key: ValueKey('loading'),
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
                      key: const ValueKey('send'),
                      onPressed: _sendMessage,
                      icon: const Icon(Icons.send_rounded),
                      color: AppColors.brandRed,
                      iconSize: 26,
                      tooltip: 'Send',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MessageBubble
// ─────────────────────────────────────────────────────────────────────────────
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
        ? DateFormat('hh:mm a').format(timestamp!.toDate().toLocal())
        : '';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        // Long-press to copy message text
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: text));
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(SnackBar(
              content: Text('Message copied', style: GoogleFonts.inter()),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.grey.shade700,
              duration: const Duration(seconds: 2),
            ));
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
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
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DateSeparator
// ─────────────────────────────────────────────────────────────────────────────
class _DateSeparator extends StatelessWidget {
  final DateTime date;
  const _DateSeparator({required this.date});

  @override
  Widget build(BuildContext context) {
    final local = date.toLocal();
    final now = DateTime.now();

    // Use local calendar dates for comparison to avoid timezone edge cases
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(local.year, local.month, local.day);
    final diff = today.difference(msgDay).inDays;

    final String label;
    if (diff == 0) {
      label = 'Today';
    } else if (diff == 1) {
      label = 'Yesterday';
    } else if (diff < 7) {
      label = DateFormat('EEEE').format(local); // e.g. "Monday"
    } else {
      label = DateFormat('MMMM d, yyyy').format(local);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(children: [
        Expanded(child: Divider(color: AppColors.borderSubtle)),
        const SizedBox(width: 12),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 12, color: AppColors.mutedText)),
        const SizedBox(width: 12),
        Expanded(child: Divider(color: AppColors.borderSubtle)),
      ]),
    );
  }
}