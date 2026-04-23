import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Supported notification types.
enum NotifType {
  message,
  event,
  announcement,
  jobOpportunity,
  gallery,
  friendRequest,
  friendAccepted,
  system,
}

extension NotifTypeX on NotifType {
  String get value {
    switch (this) {
      case NotifType.message:
        return 'message';
      case NotifType.event:
        return 'event';
      case NotifType.announcement:
        return 'announcement';
      case NotifType.jobOpportunity:
        return 'job_opportunity';
      case NotifType.gallery:
        return 'gallery';
      case NotifType.friendRequest:
        return 'friend_request';
      case NotifType.friendAccepted:
        return 'friend_accepted';
      case NotifType.system:
        return 'system';
    }
  }

  static NotifType fromString(String v) {
    return NotifType.values.firstWhere(
      (e) => e.value == v,
      orElse: () => NotifType.system,
    );
  }
}

class NotificationService {
  static final _db = FirebaseFirestore.instance;
  static const int _broadcastPageSize = 400; // stay under 500-write batch limit

  // ───────────────────────────────────────────
  // Core send — never throws, never self-notifies
  // ───────────────────────────────────────────
  static Future<void> send({
    required String toUid,
    required NotifType type,
    required String title,
    required String body,
    String? refId,
    int? badgeCount, // for grouped message notifications
  }) async {
    // Validation
    if (toUid.trim().isEmpty) return;
    if (title.trim().isEmpty || body.trim().isEmpty) return;

    final fromUid = FirebaseAuth.instance.currentUser?.uid;
    if (fromUid == null || fromUid == toUid) return; // no self-notify

    try {
      await _db.collection('notifications').add({
        'toUid': toUid,
        'fromUid': fromUid,
        'type': type.value,
        'title': title.trim(),
        'body': body.trim(),
        'refId': refId ?? '',
        'read': false,
        'badgeCount': badgeCount ?? 1,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Silently fail — never block the calling action
    }
  }

  // ───────────────────────────────────────────
  // MESSAGE — grouped badge per sender
  //
  // Instead of one notification per message, we upsert a single
  // notification document per (fromUid → toUid) chat pair and
  // increment its badgeCount. This gives the "3 new messages" UX.
  // ───────────────────────────────────────────
  static Future<void> sendMessageNotification({
    required String toUid,
    required String fromName,
    required String messageText,
    required String chatId,
  }) async {
    if (toUid.trim().isEmpty || fromName.trim().isEmpty) return;
    final fromUid = FirebaseAuth.instance.currentUser?.uid;
    if (fromUid == null || fromUid == toUid) return;

    final truncated = messageText.length > 80
        ? '${messageText.substring(0, 80)}…'
        : messageText;

    try {
      // Look for an existing unread message notification from this sender
      final existing = await _db
          .collection('notifications')
          .where('toUid', isEqualTo: toUid)
          .where('fromUid', isEqualTo: fromUid)
          .where('type', isEqualTo: NotifType.message.value)
          .where('read', isEqualTo: false)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        // Update existing — increment badge and update preview
        final doc = existing.docs.first;
        final currentCount =
            (doc.data()['badgeCount'] as int?) ?? 1;
        await doc.reference.update({
          'badgeCount': currentCount + 1,
          'body': truncated,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new notification
        await _db.collection('notifications').add({
          'toUid': toUid,
          'fromUid': fromUid,
          'type': NotifType.message.value,
          'title': fromName.trim(),
          'body': truncated,
          'refId': chatId,
          'read': false,
          'badgeCount': 1,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}
  }

  // ───────────────────────────────────────────
  // FRIEND REQUEST — idempotent (no duplicates)
  // ───────────────────────────────────────────
  static Future<void> sendFriendRequestNotification({
    required String toUid,
    required String fromName,
    required String fromUid,
  }) async {
    if (toUid.trim().isEmpty || fromName.trim().isEmpty) return;
    if (fromUid == toUid) return;

    try {
      // Check if an unread friend_request from this user already exists
      final existing = await _db
          .collection('notifications')
          .where('toUid', isEqualTo: toUid)
          .where('fromUid', isEqualTo: fromUid)
          .where('type', isEqualTo: NotifType.friendRequest.value)
          .where('read', isEqualTo: false)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) return; // already pending

      await _db.collection('notifications').add({
        'toUid': toUid,
        'fromUid': fromUid,
        'type': NotifType.friendRequest.value,
        'title': 'New Friend Request',
        'body': '$fromName sent you a friend request',
        'refId': fromUid,
        'read': false,
        'badgeCount': 1,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // ───────────────────────────────────────────
  // FRIEND ACCEPTED
  // ───────────────────────────────────────────
  static Future<void> sendFriendAcceptedNotification({
    required String toUid,
    required String acceptorName,
    required String acceptorUid,
  }) async {
    if (toUid.trim().isEmpty || acceptorName.trim().isEmpty) return;

    try {
      await _db.collection('notifications').add({
        'toUid': toUid,
        'fromUid': acceptorUid,
        'type': NotifType.friendAccepted.value,
        'title': 'Connection Accepted',
        'body': '$acceptorName accepted your friend request!',
        'refId': acceptorUid,
        'read': false,
        'badgeCount': 1,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // ───────────────────────────────────────────
  // BROADCAST helper — handles > 400 users safely
  // ───────────────────────────────────────────
  static Future<void> _broadcast({
    required NotifType type,
    required String title,
    required String body,
    required String refId,
  }) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;
    if (title.trim().isEmpty) return;

    try {
      DocumentSnapshot? lastDoc;
      bool hasMore = true;

      while (hasMore) {
        Query query = _db
            .collection('users')
            .limit(_broadcastPageSize);

        if (lastDoc != null) {
          query = query.startAfterDocument(lastDoc);
        }

        final users = await query.get();
        if (users.docs.isEmpty) break;

        final batch = _db.batch();
        for (final doc in users.docs) {
          if (doc.id == currentUid) continue;
          final ref = _db.collection('notifications').doc();
          batch.set(ref, {
            'toUid': doc.id,
            'fromUid': currentUid,
            'type': type.value,
            'title': title.trim(),
            'body': body.trim(),
            'refId': refId,
            'read': false,
            'badgeCount': 1,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();

        lastDoc = users.docs.last;
        hasMore = users.docs.length == _broadcastPageSize;
      }
    } catch (_) {}
  }

  // ───────────────────────────────────────────
  // EVENT
  // ───────────────────────────────────────────
  static Future<void> sendEventNotificationToAll({
    required String eventTitle,
    required String eventId,
    String? eventDescription,
  }) async {
    if (eventTitle.trim().isEmpty || eventId.trim().isEmpty) return;
    final body = eventDescription != null && eventDescription.trim().isNotEmpty
        ? eventDescription.trim()
        : eventTitle.trim();

    await _broadcast(
      type: NotifType.event,
      title: '📅 New Event: ${eventTitle.trim()}',
      body: body.length > 100 ? '${body.substring(0, 100)}…' : body,
      refId: eventId,
    );
  }

  // ───────────────────────────────────────────
  // ANNOUNCEMENT
  // ───────────────────────────────────────────
  static Future<void> sendAnnouncementNotificationToAll({
    required String announcementTitle,
    required String announcementId,
    String? announcementBody,
  }) async {
    if (announcementTitle.trim().isEmpty || announcementId.trim().isEmpty) return;
    final body = announcementBody != null && announcementBody.trim().isNotEmpty
        ? announcementBody.trim()
        : announcementTitle.trim();

    await _broadcast(
      type: NotifType.announcement,
      title: '📢 ${announcementTitle.trim()}',
      body: body.length > 100 ? '${body.substring(0, 100)}…' : body,
      refId: announcementId,
    );
  }

  // ───────────────────────────────────────────
  // JOB OPPORTUNITY
  // ───────────────────────────────────────────
  static Future<void> sendJobNotificationToAll({
    required String jobTitle,
    required String jobId,
    String? companyName,
  }) async {
    if (jobTitle.trim().isEmpty || jobId.trim().isEmpty) return;
    final body = companyName != null && companyName.trim().isNotEmpty
        ? '${companyName.trim()} is hiring for this role'
        : 'A new job opportunity has been posted';

    await _broadcast(
      type: NotifType.jobOpportunity,
      title: '💼 Job: ${jobTitle.trim()}',
      body: body,
      refId: jobId,
    );
  }

  // ───────────────────────────────────────────
  // GALLERY
  // ───────────────────────────────────────────
  static Future<void> sendGalleryNotificationToAll({
    required String galleryTitle,
    required String galleryId,
    String? uploaderName,
  }) async {
    if (galleryTitle.trim().isEmpty || galleryId.trim().isEmpty) return;
    final body = uploaderName != null && uploaderName.trim().isNotEmpty
        ? '${uploaderName.trim()} added new photos'
        : 'New photos have been added';

    await _broadcast(
      type: NotifType.gallery,
      title: '🖼️ Gallery: ${galleryTitle.trim()}',
      body: body,
      refId: galleryId,
    );
  }

  // ───────────────────────────────────────────
  // SYSTEM (admin or app-level messages)
  // ───────────────────────────────────────────
  static Future<void> sendSystemNotification({
    required String toUid,
    required String title,
    required String body,
    String? refId,
  }) async {
    if (toUid.trim().isEmpty || title.trim().isEmpty) return;
    try {
      await _db.collection('notifications').add({
        'toUid': toUid,
        'fromUid': 'system',
        'type': NotifType.system.value,
        'title': title.trim(),
        'body': body.trim(),
        'refId': refId ?? '',
        'read': false,
        'badgeCount': 1,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // ───────────────────────────────────────────
  // Mark read / mark all read
  // ───────────────────────────────────────────
  static Future<void> markRead(String notificationId) async {
    if (notificationId.trim().isEmpty) return;
    try {
      await _db
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true, 'badgeCount': 0});
    } catch (_) {}
  }

  static Future<void> markAllRead() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final unread = await _db
          .collection('notifications')
          .where('toUid', isEqualTo: uid)
          .where('read', isEqualTo: false)
          .get();

      if (unread.docs.isEmpty) return;

      final batch = _db.batch();
      for (final doc in unread.docs) {
        batch.update(doc.reference, {'read': true, 'badgeCount': 0});
      }
      await batch.commit();
    } catch (_) {}
  }

  // ───────────────────────────────────────────
  // Streams
  // ───────────────────────────────────────────

  /// Total unread notification count (for nav badge).
  static Stream<int> unreadCountStream(String uid) {
    if (uid.trim().isEmpty) return Stream.value(0);
    return _db
        .collection('notifications')
        .where('toUid', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length)
        .handleError((_) => 0);
  }

  /// Sum of all badgeCounts — useful for message-style unread totals.
  static Stream<int> totalBadgeCountStream(String uid) {
    if (uid.trim().isEmpty) return Stream.value(0);
    return _db
        .collection('notifications')
        .where('toUid', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.fold<int>(
              0,
              (sum, doc) =>
                  sum + ((doc.data()['badgeCount'] as int?) ?? 1),
            ))
        .handleError((_) => 0);
  }

  /// Unread count for a specific type only (e.g. messages badge).
  static Stream<int> unreadCountByTypeStream(String uid, NotifType type) {
    if (uid.trim().isEmpty) return Stream.value(0);
    return _db
        .collection('notifications')
        .where('toUid', isEqualTo: uid)
        .where('type', isEqualTo: type.value)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.fold<int>(
              0,
              (sum, doc) =>
                  sum + ((doc.data()['badgeCount'] as int?) ?? 1),
            ))
        .handleError((_) => 0);
  }

  // ───────────────────────────────────────────
  // Delete old read notifications (house-keeping, call periodically)
  // ───────────────────────────────────────────
  static Future<void> deleteOldReadNotifications({
    int olderThanDays = 30,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final cutoff = DateTime.now().subtract(Duration(days: olderThanDays));
      final old = await _db
          .collection('notifications')
          .where('toUid', isEqualTo: uid)
          .where('read', isEqualTo: true)
          .where('createdAt', isLessThan: Timestamp.fromDate(cutoff))
          .limit(100)
          .get();

      if (old.docs.isEmpty) return;
      final batch = _db.batch();
      for (final doc in old.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (_) {}
  }
}