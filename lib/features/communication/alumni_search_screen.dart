import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:alumni/core/constants/app_colors.dart';
import 'package:alumni/features/notification/notification_service.dart';
import 'chat_screen.dart';

// ─────────────────────────────────────────────
// Alumni Search Screen
// ─────────────────────────────────────────────
class AlumniSearchScreen extends StatefulWidget {
  const AlumniSearchScreen({super.key});

  @override
  State<AlumniSearchScreen> createState() => _AlumniSearchScreenState();
}

class _AlumniSearchScreenState extends State<AlumniSearchScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isSearching = false;
  String? _startingChatFor;
  final currentUid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final q = query.trim().toLowerCase();
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .limit(500)
          .get();
      final filtered = snapshot.docs
          .where((d) => d.id != currentUid)
          .where((d) {
            final name =
                d.data()['name']?.toString().toLowerCase() ?? '';
            return name.contains(q);
          })
          .map((d) => {'uid': d.id, ...d.data()})
          .toList();
      if (mounted) {
        setState(() {
          _results = filtered;
          _isSearching = false;
        });
      }
    } catch (e) {
      debugPrint('Search error: $e');
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<String> _getOrCreateChat(String otherUid) async {
    final existing = await FirebaseFirestore.instance
        .collection('chats')
        .where('memberIds', arrayContains: currentUid)
        .get();
    for (final doc in existing.docs) {
      final members = List<String>.from(doc['memberIds'] ?? []);
      if (members.contains(otherUid)) return doc.id;
    }
    final ref =
        await FirebaseFirestore.instance.collection('chats').add({
      'memberIds': [currentUid, otherUid],
      'lastMessage': '',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'unreadCount': {currentUid: 0, otherUid: 0},
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> _startChat(
      String otherUid, String otherName, String otherAvatarUrl) async {
    setState(() => _startingChatFor = otherUid);
    try {
      final chatId = await _getOrCreateChat(otherUid);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: chatId,
              otherUid: otherUid,
              otherName: otherName,
              otherAvatarUrl: otherAvatarUrl,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Could not open chat: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _startingChatFor = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softWhite,
      appBar: AppBar(
        backgroundColor: AppColors.cardWhite,
        elevation: 0,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search alumni by name...',
            hintStyle: GoogleFonts.inter(
                color: AppColors.mutedText, fontSize: 15),
            border: InputBorder.none,
          ),
          style: GoogleFonts.inter(fontSize: 15),
          onChanged: _search,
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                setState(() => _results = []);
              },
            ),
        ],
      ),
      body: _isSearching
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.brandRed))
          : _results.isEmpty
              ? _emptyState()
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => Divider(
                      height: 1, color: AppColors.borderSubtle),
                  itemBuilder: (context, index) {
                    final user = _results[index];
                    final uid = user['uid']?.toString() ?? '';
                    final name =
                        user['name']?.toString() ?? 'Unknown';
                    final avatarUrl =
                        user['profilePictureUrl']?.toString() ?? '';
                    final headline =
                        user['headline']?.toString().isNotEmpty ==
                                true
                            ? user['headline'].toString()
                            : user['role']?.toString() ?? '';
                    final hasAvatar = avatarUrl.isNotEmpty;
                    final isStarting = _startingChatFor == uid;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      leading: GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                AlumniPublicProfileScreen(uid: uid),
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 26,
                          backgroundColor: AppColors.borderSubtle,
                          child: hasAvatar
                              ? ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: avatarUrl,
                                    fit: BoxFit.cover,
                                    width: 52,
                                    height: 52,
                                    errorWidget: (_, __, ___) =>
                                        const Icon(Icons.person,
                                            color:
                                                AppColors.brandRed),
                                  ),
                                )
                              : const Icon(Icons.person,
                                  color: AppColors.brandRed),
                        ),
                      ),
                      title: Text(name,
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      subtitle: headline.isNotEmpty
                          ? Text(headline,
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.mutedText),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis)
                          : null,
                      trailing: isStarting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.brandRed))
                          : IconButton(
                              icon: const Icon(
                                  Icons.chat_bubble_outline,
                                  color: AppColors.brandRed),
                              onPressed: () =>
                                  _startChat(uid, name, avatarUrl)),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AlumniPublicProfileScreen(uid: uid),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _emptyState() {
    final hasQuery = _searchController.text.isNotEmpty;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(hasQuery ? Icons.search_off : Icons.people_outline,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            hasQuery ? 'No alumni found' : 'Search for alumni',
            style: GoogleFonts.cormorantGaramond(
                fontSize: 24, color: AppColors.darkText),
          ),
          const SizedBox(height: 8),
          Text(
            hasQuery
                ? 'Try a different name'
                : 'Type a name to find and message alumni',
            style: GoogleFonts.inter(
                fontSize: 14, color: AppColors.mutedText),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Alumni Public Profile Screen
// ─────────────────────────────────────────────
class AlumniPublicProfileScreen extends StatefulWidget {
  final String uid;
  const AlumniPublicProfileScreen({super.key, required this.uid});

  @override
  State<AlumniPublicProfileScreen> createState() =>
      _AlumniPublicProfileScreenState();
}

class _AlumniPublicProfileScreenState
    extends State<AlumniPublicProfileScreen> {
  Map<String, dynamic>? userData;
  String _myRole = '';
  bool isLoading = true;
  bool isFollowing = false;
  bool isFollowLoading = false;
  bool isChatLoading = false;
  bool _isFriend = false;
  bool _requestSent = false;
  bool _requestReceived = false;
  bool _isFriendLoading = false;

  final currentUid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => isLoading = true);
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('users')
            .doc(widget.uid)
            .get(),
        FirebaseFirestore.instance
            .collection('users')
            .doc(currentUid)
            .get(),
        FirebaseFirestore.instance
            .collection('users')
            .doc(widget.uid)
            .collection('followers')
            .doc(currentUid)
            .get(),
        FirebaseFirestore.instance
            .collection('users')
            .doc(currentUid)
            .collection('connections')
            .doc(widget.uid)
            .get(),
        FirebaseFirestore.instance
            .collection('friend_requests')
            .doc('${currentUid}_${widget.uid}')
            .get(),
        FirebaseFirestore.instance
            .collection('friend_requests')
            .doc('${widget.uid}_$currentUid')
            .get(),
      ]);

      final userDoc = results[0];
      final myDoc = results[1];
      final followDoc = results[2];
      final connectionDoc = results[3];
      final sentDoc = results[4];
      final receivedDoc = results[5];

      if (userDoc.exists && mounted) {
        setState(() {
          userData = userDoc.data();
          _myRole =
              myDoc.data()?['role']?.toString().toLowerCase() ?? '';
          isFollowing = followDoc.exists;
          _isFriend = connectionDoc.exists;
          _requestSent = sentDoc.exists;
          _requestReceived = receivedDoc.exists;
          isLoading = false;
        });
      } else if (mounted) {
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint('Load error: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ─── Role helpers ───
  bool get _isAlumni => _myRole == 'alumni';
  bool get _targetIsAlumni =>
      userData?['role']?.toString().toLowerCase() == 'alumni';
  bool get _canFollow => _myRole == 'alumni';

  // ─── Follow / Unfollow ───
  Future<void> _toggleFollow() async {
    if (!_canFollow) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('You are not allowed to follow alumni'),
            backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() => isFollowLoading = true);
    try {
      final followerRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('followers')
          .doc(currentUid);
      final followingRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('following')
          .doc(widget.uid);
      final batch = FirebaseFirestore.instance.batch();
      if (isFollowing) {
        batch.delete(followerRef);
        batch.delete(followingRef);
        batch.set(
            FirebaseFirestore.instance
                .collection('users')
                .doc(widget.uid),
            {'followersCount': FieldValue.increment(-1)},
            SetOptions(merge: true));
        batch.set(
            FirebaseFirestore.instance
                .collection('users')
                .doc(currentUid),
            {'followingCount': FieldValue.increment(-1)},
            SetOptions(merge: true));
      } else {
        batch.set(followerRef,
            {'followedAt': FieldValue.serverTimestamp()});
        batch.set(followingRef,
            {'followedAt': FieldValue.serverTimestamp()});
        batch.set(
            FirebaseFirestore.instance
                .collection('users')
                .doc(widget.uid),
            {'followersCount': FieldValue.increment(1)},
            SetOptions(merge: true));
        batch.set(
            FirebaseFirestore.instance
                .collection('users')
                .doc(currentUid),
            {'followingCount': FieldValue.increment(1)},
            SetOptions(merge: true));
      }
      await batch.commit();
      if (mounted) {
        setState(() => isFollowing = !isFollowing);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isFollowing
              ? 'You are now following ${_safe('name')}'
              : 'Unfollowed ${_safe('name')}'),
          backgroundColor:
              isFollowing ? Colors.green : AppColors.mutedText,
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => isFollowLoading = false);
    }
  }

  // ─── Send friend request ───
  Future<void> _sendFriendRequest() async {
    if (!_isAlumni || !_targetIsAlumni) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Friend requests are only between alumni'),
            backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() => _isFriendLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('friend_requests')
          .doc('${currentUid}_${widget.uid}')
          .set({
        'fromUid': currentUid,
        'toUid': widget.uid,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      final myDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .get();
      final senderName =
          myDoc.data()?['name']?.toString() ?? 'Someone';
      await NotificationService.sendFriendRequestNotification(
        toUid: widget.uid,
        fromName: senderName,
        fromUid: currentUid,
      );
      if (mounted) {
        setState(() => _requestSent = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Friend request sent!'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('Send request error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isFriendLoading = false);
    }
  }

  // ─── Cancel sent request ───
  Future<void> _cancelFriendRequest() async {
    setState(() => _isFriendLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('friend_requests')
          .doc('${currentUid}_${widget.uid}')
          .delete();
      if (mounted) setState(() => _requestSent = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isFriendLoading = false);
    }
  }

  // ─── Accept incoming request ───
  Future<void> _acceptFriendRequest() async {
    setState(() => _isFriendLoading = true);
    try {
      debugPrint('Accepting from profile: widget.uid=${widget.uid} currentUid=$currentUid');

      // ─── Try both doc ID formats ───
      final docId1 = '${widget.uid}_$currentUid';
      final docId2 = '${currentUid}_${widget.uid}';
      DocumentSnapshot? requestDoc;

      final doc1 = await FirebaseFirestore.instance
          .collection('friend_requests')
          .doc(docId1)
          .get();
      if (doc1.exists) {
        requestDoc = doc1;
        debugPrint('Found at: $docId1');
      } else {
        final doc2 = await FirebaseFirestore.instance
            .collection('friend_requests')
            .doc(docId2)
            .get();
        if (doc2.exists) {
          requestDoc = doc2;
          debugPrint('Found at: $docId2');
        }
      }

      if (requestDoc == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Friend request not found'),
                backgroundColor: Colors.red),
          );
        }
        return;
      }

      final requestDocId = requestDoc.id;
      final now = FieldValue.serverTimestamp();

      // ─── Step 1: Add my connection ───
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('connections')
          .doc(widget.uid)
          .set({'connectedAt': now});

      // ─── Step 2: Add their connection ───
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('connections')
          .doc(currentUid)
          .set({'connectedAt': now});

      // ─── Step 3: Delete the request ───
      await FirebaseFirestore.instance
          .collection('friend_requests')
          .doc(requestDocId)
          .delete();

      // ─── Step 4: Update my count ───
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .set({'connectionsCount': FieldValue.increment(1)},
              SetOptions(merge: true));

      // ─── Step 5: Update their count ───
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .set({'connectionsCount': FieldValue.increment(1)},
              SetOptions(merge: true));

      // ─── Step 6: Notify sender ───
      final myDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .get();
      final acceptorName =
          myDoc.data()?['name']?.toString() ?? 'Someone';
      await NotificationService.sendFriendAcceptedNotification(
        toUid: widget.uid,
        acceptorName: acceptorName,
        acceptorUid: currentUid,
      );

      if (mounted) {
        setState(() {
          _isFriend = true;
          _requestReceived = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('You are now connected with ${_safe('name')}!'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      debugPrint('Accept error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isFriendLoading = false);
    }
  }

  // ─── Unfriend ───
  Future<void> _unfriend() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Unfriend',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text('Remove ${_safe('name')} from your connections?',
            style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style:
                    GoogleFonts.inter(color: AppColors.mutedText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Unfriend',
                style:
                    GoogleFonts.inter(color: AppColors.brandRed)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _isFriendLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('connections')
          .doc(widget.uid)
          .delete();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('connections')
          .doc(currentUid)
          .delete();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .set({'connectionsCount': FieldValue.increment(-1)},
              SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .set({'connectionsCount': FieldValue.increment(-1)},
              SetOptions(merge: true));

      if (mounted) {
        setState(() => _isFriend = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Connection removed'),
              backgroundColor: Colors.grey),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isFriendLoading = false);
    }
  }

  // ─── Start chat ───
  Future<void> _startChat() async {
    setState(() => isChatLoading = true);
    try {
      final name = _safe('name');
      final avatarUrl = _safe('profilePictureUrl', fallback: '');
      final existing = await FirebaseFirestore.instance
          .collection('chats')
          .where('memberIds', arrayContains: currentUid)
          .get();
      String? chatId;
      for (final doc in existing.docs) {
        final members =
            List<String>.from(doc['memberIds'] ?? []);
        if (members.contains(widget.uid)) {
          chatId = doc.id;
          break;
        }
      }
      chatId ??= (await FirebaseFirestore.instance
              .collection('chats')
              .add({
        'memberIds': [currentUid, widget.uid],
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unreadCount': {currentUid: 0, widget.uid: 0},
        'createdAt': FieldValue.serverTimestamp(),
      }))
          .id;
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: chatId!,
              otherUid: widget.uid,
              otherName: name,
              otherAvatarUrl: avatarUrl == '—' ? '' : avatarUrl,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Could not open chat: $e'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => isChatLoading = false);
    }
  }

  // ─── Helpers ───
  String _safe(String key, {String fallback = '—'}) {
    final val = userData?[key]?.toString().trim();
    return (val != null && val.isNotEmpty) ? val : fallback;
  }

  List<Map<String, dynamic>> _safeList(String key) {
    final list = userData?[key];
    if (list == null || list is! List) return [];
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  String _formatDate(dynamic value) {
    if (value == null) return '—';
    DateTime? date = value is Timestamp
        ? value.toDate()
        : DateTime.tryParse(value.toString());
    return date != null ? DateFormat('MMMM yyyy').format(date) : '—';
  }

  String _formatPeriod(dynamic start, dynamic end) {
    final s = _formatDate(start);
    final e = _formatDate(end);
    return end == null ? '$s – Present' : '$s – $e';
  }

  String _safeMap(Map<String, dynamic>? map, String key,
      {String fallback = '—'}) {
    final val = map?[key]?.toString().trim();
    return (val != null && val.isNotEmpty) ? val : fallback;
  }

  // ─── Friend button ───
  Widget _buildFriendButton() {
    if (!_isAlumni || !_targetIsAlumni) return const SizedBox.shrink();
    if (_isFriendLoading) {
      return const SizedBox(
        height: 44,
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: AppColors.brandRed),
          ),
        ),
      );
    }
    if (_isFriend) {
      return OutlinedButton.icon(
        onPressed: _unfriend,
        icon: const Icon(Icons.people, size: 16),
        label: const Text('Connected'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.green.shade700,
          side: BorderSide(color: Colors.green.shade400),
          minimumSize: const Size(double.infinity, 44),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
    if (_requestSent) {
      return OutlinedButton.icon(
        onPressed: _cancelFriendRequest,
        icon: const Icon(Icons.hourglass_top, size: 16),
        label: const Text('Request Sent · Cancel'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.mutedText,
          side: const BorderSide(color: AppColors.borderSubtle),
          minimumSize: const Size(double.infinity, 44),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
    if (_requestReceived) {
      return ElevatedButton.icon(
        onPressed: _acceptFriendRequest,
        icon: const Icon(Icons.person_add, size: 16),
        label: Text("Accept ${_safe('name').split(' ').first}'s Request"),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 44),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: _sendFriendRequest,
      icon: const Icon(Icons.person_add_outlined, size: 16),
      label: const Text('Add Friend'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.brandRed.withOpacity(0.08),
        foregroundColor: AppColors.brandRed,
        elevation: 0,
        minimumSize: const Size(double.infinity, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.brandRed),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
            child: CircularProgressIndicator(
                color: AppColors.brandRed)),
      );
    }
    if (userData == null) {
      return Scaffold(
        appBar:
            AppBar(backgroundColor: AppColors.cardWhite, elevation: 0),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_off_outlined,
                  size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text('Profile not found',
                  style: GoogleFonts.inter(
                      fontSize: 16, color: AppColors.mutedText)),
            ],
          ),
        ),
      );
    }

    final coverUrl = _safe('coverPhotoUrl');
    final avatarUrl = _safe('profilePictureUrl');
    final hasCover = coverUrl != '—' && coverUrl.isNotEmpty;
    final hasAvatar = avatarUrl != '—' && avatarUrl.isNotEmpty;
    final experiences = _safeList('experience');
    final education = _safeList('education');
    final followersCount = _safe('followersCount', fallback: '0');
    final connectionsCount =
        _safe('connectionsCount', fallback: '0');

    return Scaffold(
      backgroundColor: AppColors.softWhite,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.cardWhite,
            elevation: 0,
            title: Text(_safe('name'),
                style: GoogleFonts.cormorantGaramond(fontSize: 22)),
          ),

          SliverToBoxAdapter(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 180,
                  width: double.infinity,
                  child: hasCover
                      ? CachedNetworkImage(
                          imageUrl: coverUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: AppColors.softWhite),
                          errorWidget: (_, __, ___) => _defaultCover(),
                        )
                      : _defaultCover(),
                ),
                Positioned(
                  bottom: -50,
                  left: 20,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.softWhite, width: 4),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 3)),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: AppColors.borderSubtle,
                      child: hasAvatar
                          ? ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: avatarUrl,
                                fit: BoxFit.cover,
                                width: 100,
                                height: 100,
                                errorWidget: (_, __, ___) =>
                                    const Icon(Icons.person,
                                        color: AppColors.brandRed,
                                        size: 50),
                              ),
                            )
                          : const Icon(Icons.person,
                              color: AppColors.brandRed, size: 50),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 62)),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_safe('name'),
                      style: GoogleFonts.cormorantGaramond(
                          fontSize: 28,
                          fontWeight: FontWeight.w600)),
                  if (_safe('headline') != '—') ...[
                    const SizedBox(height: 2),
                    Text(_safe('headline', fallback: _safe('role')),
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500)),
                  ],
                  if (_safe('location') != '—') ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      Icon(Icons.location_on_outlined,
                          size: 14, color: AppColors.mutedText),
                      const SizedBox(width: 4),
                      Text(_safe('location'),
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.mutedText)),
                    ]),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    '$followersCount followers  •  $connectionsCount connections',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: AppColors.mutedText),
                  ),
                  const SizedBox(height: 16),

                  // ─── Message + Follow ───
                  Row(children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isChatLoading ? null : _startChat,
                        icon: isChatLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white))
                            : const Icon(Icons.chat_bubble_outline,
                                size: 16),
                        label: Text(
                            isChatLoading ? 'Opening...' : 'Message'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brandRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    if (_canFollow) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: isFollowLoading
                            ? const Center(
                                child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: AppColors.brandRed)))
                            : OutlinedButton.icon(
                                onPressed: _toggleFollow,
                                icon: Icon(
                                    isFollowing
                                        ? Icons.person_remove_outlined
                                        : Icons.person_add_outlined,
                                    size: 16),
                                label: Text(isFollowing
                                    ? 'Unfollow'
                                    : 'Follow'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: isFollowing
                                      ? AppColors.mutedText
                                      : AppColors.brandRed,
                                  side: BorderSide(
                                      color: isFollowing
                                          ? AppColors.mutedText
                                          : AppColors.brandRed),
                                  padding:
                                      const EdgeInsets.symmetric(
                                          vertical: 10),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(8)),
                                ),
                              ),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 10),
                  _buildFriendButton(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          if (_safe('about') != '—') ...[
            SliverToBoxAdapter(
              child: _sectionCard(
                title: 'About',
                child: Text(_safe('about'),
                    style:
                        GoogleFonts.inter(fontSize: 14, height: 1.6)),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
          ],

          SliverToBoxAdapter(
            child: _sectionCard(
              title: 'Experience',
              child: experiences.isNotEmpty
                  ? Column(
                      children: experiences.map((exp) {
                        return Padding(
                          padding:
                              const EdgeInsets.only(bottom: 16),
                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.brandRed
                                      .withOpacity(0.08),
                                  borderRadius:
                                      BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.work_outline,
                                    color: AppColors.brandRed,
                                    size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(_safeMap(exp, 'title'),
                                        style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight:
                                                FontWeight.w700)),
                                    Text(_safeMap(exp, 'company'),
                                        style: GoogleFonts.inter(
                                            fontSize: 13,
                                            color: AppColors.brandRed,
                                            fontWeight:
                                                FontWeight.w600)),
                                    Text(
                                        _formatPeriod(
                                            exp['start'], exp['end']),
                                        style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color:
                                                AppColors.mutedText)),
                                    if (_safeMap(exp, 'location') !=
                                        '—') ...[
                                      const SizedBox(height: 2),
                                      Row(children: [
                                        Icon(
                                            Icons.location_on_outlined,
                                            size: 12,
                                            color: AppColors.mutedText),
                                        const SizedBox(width: 3),
                                        Text(_safeMap(exp, 'location'),
                                            style: GoogleFonts.inter(
                                                fontSize: 12,
                                                color: AppColors
                                                    .mutedText)),
                                      ]),
                                    ],
                                    if (_safeMap(exp, 'description') !=
                                        '—') ...[
                                      const SizedBox(height: 6),
                                      Text(
                                          _safeMap(exp, 'description'),
                                          style: GoogleFonts.inter(
                                              fontSize: 13,
                                              height: 1.5)),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    )
                  : Text('No experience added.',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.mutedText)),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          SliverToBoxAdapter(
            child: _sectionCard(
              title: 'Education',
              child: education.isNotEmpty
                  ? Column(
                      children: education.map((edu) {
                        return Padding(
                          padding:
                              const EdgeInsets.only(bottom: 16),
                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.brandRed
                                      .withOpacity(0.08),
                                  borderRadius:
                                      BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                    Icons.school_outlined,
                                    color: AppColors.brandRed,
                                    size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(_safeMap(edu, 'degree'),
                                        style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight:
                                                FontWeight.w700)),
                                    Text(_safeMap(edu, 'school'),
                                        style: GoogleFonts.inter(
                                            fontSize: 13,
                                            color: AppColors.brandRed,
                                            fontWeight:
                                                FontWeight.w600)),
                                    Text(
                                        _formatPeriod(
                                            edu['start'], edu['end']),
                                        style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color:
                                                AppColors.mutedText)),
                                    if (_safeMap(
                                            edu, 'fieldOfStudy') !=
                                        '—') ...[
                                      const SizedBox(height: 2),
                                      Text(
                                          _safeMap(
                                              edu, 'fieldOfStudy'),
                                          style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color:
                                                  AppColors.mutedText)),
                                    ],
                                    if (_safeMap(edu, 'grade') !=
                                        '—') ...[
                                      const SizedBox(height: 2),
                                      Row(children: [
                                        Icon(
                                            Icons
                                                .military_tech_outlined,
                                            size: 12,
                                            color: AppColors.mutedText),
                                        const SizedBox(width: 3),
                                        Text(
                                            'Grade: ${_safeMap(edu, 'grade')}',
                                            style: GoogleFonts.inter(
                                                fontSize: 12,
                                                color: AppColors
                                                    .mutedText)),
                                      ]),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    )
                  : Text('No education added.',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.mutedText)),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _defaultCover() => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.brandRed.withOpacity(0.4),
              AppColors.softWhite,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      );

  Widget _sectionCard(
      {required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: GoogleFonts.cormorantGaramond(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkText)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}