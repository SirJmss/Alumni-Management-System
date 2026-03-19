import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final _db = FirebaseFirestore.instance;

  // ─── Send a notification to a specific user ───
  static Future<void> send({
    required String toUid,
    required String type,
    required String title,
    required String body,
    String? refId,
  }) async {
    final fromUid = FirebaseAuth.instance.currentUser?.uid;
    if (fromUid == null || toUid == fromUid) return;

    try {
      await _db.collection('notifications').add({
        'toUid': toUid,
        'fromUid': fromUid,
        'type': type,
        'title': title,
        'body': body,
        'refId': refId ?? '',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Silently fail — never block the main action
    }
  }

  // ─── Send message notification ───
  static Future<void> sendMessageNotification({
    required String toUid,
    required String fromName,
    required String messageText,
    required String chatId,
  }) async {
    await send(
      toUid: toUid,
      type: 'message',
      title: fromName,
      body: messageText.length > 80
          ? '${messageText.substring(0, 80)}...'
          : messageText,
      refId: chatId,
    );
  }

  // ─── Send friend request notification ───
  static Future<void> sendFriendRequestNotification({
    required String toUid,
    required String fromName,
    required String fromUid,
  }) async {
    await send(
      toUid: toUid,
      type: 'friend_request',
      title: 'New Friend Request',
      body: '$fromName sent you a friend request',
      refId: fromUid,
    );
  }

  // ─── Send friend accepted notification ───
  static Future<void> sendFriendAcceptedNotification({
    required String toUid,
    required String acceptorName,
    required String acceptorUid,
  }) async {
    await send(
      toUid: toUid,
      type: 'friend_accepted',
      title: 'Connection Accepted',
      body: '$acceptorName accepted your friend request!',
      refId: acceptorUid,
    );
  }

  // ─── Send event notification to all users ───
  static Future<void> sendEventNotificationToAll({
    required String eventTitle,
    required String eventId,
  }) async {
    try {
      final users = await FirebaseFirestore.instance
          .collection('users')
          .limit(500)
          .get();

      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final batch = FirebaseFirestore.instance.batch();

      for (final doc in users.docs) {
        if (doc.id == currentUid) continue;
        final ref =
            FirebaseFirestore.instance.collection('notifications').doc();
        batch.set(ref, {
          'toUid': doc.id,
          'fromUid': currentUid ?? '',
          'type': 'event',
          'title': 'New Event',
          'body': eventTitle,
          'refId': eventId,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      // Silently fail
    }
  }

  // ─── Send announcement notification to all users ───
  static Future<void> sendAnnouncementNotificationToAll({
    required String announcementTitle,
    required String announcementId,
  }) async {
    try {
      final users = await FirebaseFirestore.instance
          .collection('users')
          .limit(500)
          .get();

      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final batch = FirebaseFirestore.instance.batch();

      for (final doc in users.docs) {
        if (doc.id == currentUid) continue;
        final ref =
            FirebaseFirestore.instance.collection('notifications').doc();
        batch.set(ref, {
          'toUid': doc.id,
          'fromUid': currentUid ?? '',
          'type': 'announcement',
          'title': 'New Announcement',
          'body': announcementTitle,
          'refId': announcementId,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      // Silently fail
    }
  }

  // ─── Mark a notification as read ───
  static Future<void> markRead(String notificationId) async {
    try {
      await _db
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      // Silently fail
    }
  }

  // ─── Mark all as read for current user ───
  static Future<void> markAllRead() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final unread = await _db
          .collection('notifications')
          .where('toUid', isEqualTo: uid)
          .where('read', isEqualTo: false)
          .get();

      final batch = _db.batch();
      for (final doc in unread.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (e) {
      // Silently fail
    }
  }

  // ─── Stream unread count ───
  static Stream<int> unreadCountStream(String uid) {
    if (uid.isEmpty) return Stream.value(0);
    return _db
        .collection('notifications')
        .where('toUid', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length)
        .handleError((_) => 0);
  }
}