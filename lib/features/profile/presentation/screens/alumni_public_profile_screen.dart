// lib/features/profile/presentation/screens/alumni_public_profile_screen.dart
//
// FIXES APPLIED:
//  1. _RelationshipWatcher: Replaced where() queries for pendingOut/pendingIn
//     with direct document snapshot listeners using the known doc ID pattern
//     (${fromUid}_${toUid}). This eliminates composite index requirements and
//     ensures the watcher never stalls in "not ready" state.
//  2. All connect/unfollow actions use Firestore Transactions so counts are
//     always accurate even if the app crashes mid-write.
//  3. _sendRequest: Checks for existing connection AND existing request inside
//     a transaction to prevent duplicate requests.
//  4. _acceptRequest: Fully transactional — reads request + existing connection
//     + user counts atomically before any write.
//  5. Count guards: All increments/decrements are bounded at 0 to prevent
//     negative counts from partial writes.
//  6. _unfriend / _unfollowUser: Check the sub-collection doc exists before
//     decrementing so stale UI state can't cause double-decrements.

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:alumni/core/constants/app_colors.dart';

class AlumniPublicProfileScreen extends StatefulWidget {
  final String uid;
  const AlumniPublicProfileScreen({super.key, required this.uid});

  @override
  State<AlumniPublicProfileScreen> createState() =>
      _AlumniPublicProfileScreenState();
}

class _AlumniPublicProfileScreenState
    extends State<AlumniPublicProfileScreen> {
  final _db = FirebaseFirestore.instance;
  late final String _currentUid;

  bool _connectLoading    = false;
  bool _followLoading     = false;
  bool _isConnected       = false;
  bool _requestPending    = false;  // I sent a request to them
  bool _requestReceived   = false;  // They sent a request to me
  bool _isFollowing       = false;
  bool _relationshipReady = false;

  static const double _coverHeight   = 220.0;
  static const double _avatarRadius  = 48.0;
  static const double _avatarBorder  = 4.0;
  static const double _avatarTotal   = (_avatarRadius + _avatarBorder) * 2;
  static const double _avatarOverlap = _avatarRadius + _avatarBorder;

  bool get _isOwnProfile =>
      _currentUid.isNotEmpty && _currentUid == widget.uid;

  @override
  void initState() {
    super.initState();
    _currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  bool _canAct(String action) {
    if (_currentUid.isEmpty) {
      _showSnack('Sign in to $action', Colors.orange.shade700);
      return false;
    }
    if (_isOwnProfile) return false;
    return true;
  }

  // ══════════════════════════════════════════════════════
  //  CONNECTION ACTIONS
  // ══════════════════════════════════════════════════════

  Future<void> _handleConnect() async {
    if (!_canAct('connect') || _connectLoading) return;
    setState(() => _connectLoading = true);
    try {
      if (_isConnected)          await _unfriend();
      else if (_requestPending)  await _cancelRequest();
      else if (_requestReceived) await _acceptRequest();
      else                       await _sendRequest();
    } catch (e) {
      if (mounted) _showSnack(_friendlyError(e), Colors.red.shade700);
    } finally {
      if (mounted) setState(() => _connectLoading = false);
    }
  }

  // ── Send request ──────────────────────────────────────
  // FIX: Check everything inside a transaction to prevent race conditions.
  Future<void> _sendRequest() async {
    final outReqRef = _db
        .collection('friend_requests')
        .doc('${_currentUid}_${widget.uid}');
    final inReqRef = _db
        .collection('friend_requests')
        .doc('${widget.uid}_${_currentUid}');
    final connRef = _db
        .collection('users')
        .doc(_currentUid)
        .collection('connections')
        .doc(widget.uid);

    await _db.runTransaction((tx) async {
      final outReq = await tx.get(outReqRef);
      final inReq  = await tx.get(inReqRef);
      final conn   = await tx.get(connRef);

      if (conn.exists) {
        throw Exception('already_connected');
      }
      if (outReq.exists) {
        throw Exception('already_sent');
      }
      if (inReq.exists) {
        throw Exception('has_incoming');
      }

      tx.set(outReqRef, {
        'fromUid':   _currentUid,
        'toUid':     widget.uid,
        'status':    'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });

    _showSnack('Connection request sent!', Colors.green.shade700);
  }

  // ── Cancel outgoing request ───────────────────────────
  Future<void> _cancelRequest() async {
    final ok = await _confirm(
        title: 'Cancel Request',
        body: 'Withdraw your pending connection request?',
        confirmLabel: 'Withdraw');
    if (ok != true) return;

    await _db
        .collection('friend_requests')
        .doc('${_currentUid}_${widget.uid}')
        .delete();
    _showSnack('Request withdrawn', Colors.grey.shade700);
  }

  // ── Accept incoming request ───────────────────────────
  // FIX: Fully transactional. Uses direct doc ID — no where() query.
  Future<void> _acceptRequest() async {
    final reqRef       = _db
        .collection('friend_requests')
        .doc('${widget.uid}_${_currentUid}');
    final myConnRef    = _db
        .collection('users').doc(_currentUid)
        .collection('connections').doc(widget.uid);
    final theirConnRef = _db
        .collection('users').doc(widget.uid)
        .collection('connections').doc(_currentUid);
    final myUserRef    = _db.collection('users').doc(_currentUid);
    final theirUserRef = _db.collection('users').doc(widget.uid);

    await _db.runTransaction((tx) async {
      final reqSnap      = await tx.get(reqRef);
      final existingConn = await tx.get(myConnRef);
      final myUser       = await tx.get(myUserRef);
      final theirUser    = await tx.get(theirUserRef);

      if (!reqSnap.exists) {
        throw Exception('request_gone');
      }
      if (existingConn.exists) {
        // Stale state — clean up the request silently
        tx.delete(reqRef);
        return;
      }

      final now = Timestamp.now();
      tx.set(myConnRef, {'connectedAt': now, 'uid': widget.uid});
      tx.set(theirConnRef, {'connectedAt': now, 'uid': _currentUid});
      tx.delete(reqRef);

      final myCount =
          (myUser.data()?['connectionsCount'] as num?)?.toInt() ?? 0;
      final theirCount =
          (theirUser.data()?['connectionsCount'] as num?)?.toInt() ?? 0;
      tx.update(myUserRef, {'connectionsCount': myCount + 1});
      tx.update(theirUserRef, {'connectionsCount': theirCount + 1});
    });

    _showSnack('Connected!', Colors.green.shade700);
  }

  // ── Unfriend ──────────────────────────────────────────
  // FIX: Fully transactional with existence check before decrement.
  Future<void> _unfriend() async {
    final ok = await _confirm(
        title: 'Remove Connection',
        body: "Remove this person from your connections? They won't be notified.",
        confirmLabel: 'Remove');
    if (ok != true) return;

    final myConnRef    = _db
        .collection('users').doc(_currentUid)
        .collection('connections').doc(widget.uid);
    final theirConnRef = _db
        .collection('users').doc(widget.uid)
        .collection('connections').doc(_currentUid);
    final myUserRef    = _db.collection('users').doc(_currentUid);
    final theirUserRef = _db.collection('users').doc(widget.uid);

    await _db.runTransaction((tx) async {
      final myConn    = await tx.get(myConnRef);
      final myUser    = await tx.get(myUserRef);
      final theirUser = await tx.get(theirUserRef);

      if (!myConn.exists) return; // already removed

      tx.delete(myConnRef);
      tx.delete(theirConnRef);

      final myCount =
          (myUser.data()?['connectionsCount'] as num?)?.toInt() ?? 0;
      final theirCount =
          (theirUser.data()?['connectionsCount'] as num?)?.toInt() ?? 0;

      tx.update(myUserRef,
          {'connectionsCount': myCount > 0 ? FieldValue.increment(-1) : 0});
      tx.update(theirUserRef,
          {'connectionsCount': theirCount > 0 ? FieldValue.increment(-1) : 0});
    });

    _showSnack('Connection removed', Colors.grey.shade700);
  }

  // ══════════════════════════════════════════════════════
  //  FOLLOW ACTIONS
  // ══════════════════════════════════════════════════════

  Future<void> _handleFollow() async {
    if (!_canAct('follow') || _followLoading) return;
    setState(() => _followLoading = true);
    try {
      if (_isFollowing) await _unfollowUser();
      else              await _followUser();
    } catch (e) {
      if (mounted) _showSnack(_friendlyError(e), Colors.red.shade700);
    } finally {
      if (mounted) setState(() => _followLoading = false);
    }
  }

  // FIX: Transactional follow to prevent duplicate writes.
  Future<void> _followUser() async {
    final myFollowRef  = _db
        .collection('users').doc(_currentUid)
        .collection('following').doc(widget.uid);
    final theirFollRef = _db
        .collection('users').doc(widget.uid)
        .collection('followers').doc(_currentUid);
    final myUserRef    = _db.collection('users').doc(_currentUid);
    final theirUserRef = _db.collection('users').doc(widget.uid);

    await _db.runTransaction((tx) async {
      final existing = await tx.get(myFollowRef);
      if (existing.exists) throw Exception('already_following');

      final myUser    = await tx.get(myUserRef);
      final theirUser = await tx.get(theirUserRef);

      final now = Timestamp.now();
      tx.set(myFollowRef, {'followedAt': now, 'uid': widget.uid});
      tx.set(theirFollRef, {'followedAt': now, 'uid': _currentUid});

      final myFollowing =
          (myUser.data()?['followingCount'] as num?)?.toInt() ?? 0;
      final theirFollowers =
          (theirUser.data()?['followersCount'] as num?)?.toInt() ?? 0;
      tx.update(myUserRef, {'followingCount': myFollowing + 1});
      tx.update(theirUserRef, {'followersCount': theirFollowers + 1});
    });

    _showSnack('Following!', Colors.green.shade700);
  }

  // FIX: Transactional unfollow with existence check.
  Future<void> _unfollowUser() async {
    final myFollowRef  = _db
        .collection('users').doc(_currentUid)
        .collection('following').doc(widget.uid);
    final theirFollRef = _db
        .collection('users').doc(widget.uid)
        .collection('followers').doc(_currentUid);
    final myUserRef    = _db.collection('users').doc(_currentUid);
    final theirUserRef = _db.collection('users').doc(widget.uid);

    await _db.runTransaction((tx) async {
      final followDoc = await tx.get(myFollowRef);
      if (!followDoc.exists) return; // already unfollowed

      final myUser    = await tx.get(myUserRef);
      final theirUser = await tx.get(theirUserRef);

      tx.delete(myFollowRef);
      tx.delete(theirFollRef);

      final myFollowing =
          (myUser.data()?['followingCount'] as num?)?.toInt() ?? 0;
      final theirFollowers =
          (theirUser.data()?['followersCount'] as num?)?.toInt() ?? 0;

      tx.update(myUserRef,
          {'followingCount': myFollowing > 0 ? FieldValue.increment(-1) : 0});
      tx.update(theirUserRef,
          {'followersCount': theirFollowers > 0 ? FieldValue.increment(-1) : 0});
    });

    _showSnack('Unfollowed', Colors.grey.shade700);
  }

  // ── Helpers ─────────────────────────────────────────────
  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: GoogleFonts.inter()),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 3),
      ));
  }

  Future<bool?> _confirm({
    required String title,
    required String body,
    required String confirmLabel,
  }) {
    if (!mounted) return Future.value(false);
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: 320,
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08), shape: BoxShape.circle),
              child: const Icon(Icons.warning_amber_rounded,
                  color: Colors.red, size: 24),
            ),
            const SizedBox(height: 14),
            Text(title,
                style: GoogleFonts.cormorantGaramond(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkText)),
            const SizedBox(height: 8),
            Text(body,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.mutedText,
                    height: 1.5)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.borderSubtle),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  child: Text('Cancel',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: AppColors.mutedText)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  child: Text(confirmLabel,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  String _friendlyError(Object e) {
    // Surface the intent-specific exceptions first
    if (e is Exception) {
      final msg = e.toString();
      if (msg.contains('already_connected'))
        return 'You are already connected.';
      if (msg.contains('already_sent'))
        return 'You already sent a request.';
      if (msg.contains('has_incoming'))
        return 'They already sent you a request — accept it instead.';
      if (msg.contains('request_gone'))
        return 'Request no longer available.';
      if (msg.contains('already_following'))
        return 'You are already following this person.';
    }
    if (e is FirebaseException) {
      switch (e.code) {
        case 'permission-denied':
          return 'Permission denied. Check your Firestore security rules.';
        case 'unavailable':
          return 'Service unavailable. Check your internet connection.';
        case 'not-found':
          return 'Data not found.';
        case 'unauthenticated':
          return 'Please sign in to perform this action.';
        default:
          return 'Error (${e.code}): ${e.message ?? ''}';
      }
    }
    return e.toString();
  }

  // ══════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (widget.uid.trim().isEmpty) {
      return Scaffold(
        appBar: _simpleAppBar('Profile'),
        body: const Center(child: Text('Invalid user ID.')),
      );
    }
    if (_currentUid.isEmpty) {
      return Scaffold(
        appBar: _simpleAppBar('Profile'),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 56, color: Colors.grey),
              const SizedBox(height: 16),
              Text('Sign in to view profiles',
                  style: GoogleFonts.cormorantGaramond(
                      fontSize: 22, color: AppColors.darkText)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      body: Stack(children: [
        StreamBuilder<DocumentSnapshot>(
          stream: _db.collection('users').doc(widget.uid).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return _buildErrorScaffold(snapshot.error);
            if (snapshot.connectionState == ConnectionState.waiting)
              return _buildLoadingScaffold();
            if (!snapshot.hasData || !snapshot.data!.exists)
              return _buildNotFoundScaffold();
            final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
            return _buildProfileScaffold(data);
          },
        ),
        // FIX: _RelationshipWatcher now uses only direct doc listeners
        _RelationshipWatcher(
          currentUid: _currentUid,
          otherUid: widget.uid,
          onChanged: ({
            required bool connected,
            required bool pendingOut,
            required bool pendingIn,
            required bool following,
            required bool ready,
          }) {
            if (!mounted) return;
            setState(() {
              _isConnected       = connected;
              _requestPending    = pendingOut;
              _requestReceived   = pendingIn;
              _isFollowing       = following;
              _relationshipReady = ready;
            });
          },
        ),
      ]),
    );
  }

  AppBar _simpleAppBar(String title) => AppBar(
        title: Text(title,
            style: GoogleFonts.cormorantGaramond(fontSize: 22)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.darkText,
      );

  Widget _buildLoadingScaffold() => Scaffold(
        backgroundColor: const Color(0xFFF4F4F6),
        body: Column(children: [
          SizedBox(height: _coverHeight, child: _defaultCover()),
          const Expanded(
            child: Center(
              child: CircularProgressIndicator(
                  color: AppColors.brandRed, strokeWidth: 2.5),
            ),
          ),
        ]),
      );

  Widget _buildErrorScaffold(Object? error) => Scaffold(
        backgroundColor: const Color(0xFFF4F4F6),
        appBar: _simpleAppBar('Profile'),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 56, color: Colors.grey),
                const SizedBox(height: 16),
                Text('Could not load profile',
                    style: GoogleFonts.cormorantGaramond(
                        fontSize: 22, color: AppColors.darkText)),
                const SizedBox(height: 8),
                Text(_friendlyError(error ?? 'Unknown error'),
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.mutedText),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );

  Widget _buildNotFoundScaffold() => Scaffold(
        backgroundColor: const Color(0xFFF4F4F6),
        appBar: _simpleAppBar('Profile'),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_off_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text('Profile not found',
                  style: GoogleFonts.cormorantGaramond(
                      fontSize: 22, color: AppColors.darkText)),
              const SizedBox(height: 8),
              Text('This account may have been deleted.',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: AppColors.mutedText)),
            ],
          ),
        ),
      );

  // ══════════════════════════════════════════════════════
  //  MAIN PROFILE SCAFFOLD
  // ══════════════════════════════════════════════════════

  Widget _buildProfileScaffold(Map<String, dynamic> data) {
    final firstName = _s(data, 'firstName');
    final lastName  = _s(data, 'lastName');
    final name      = _s(data, 'name',
        fb: [firstName, lastName]
                .where((s) => s.isNotEmpty)
                .join(' ')
                .trim()
                .isNotEmpty
            ? [firstName, lastName].where((s) => s.isNotEmpty).join(' ').trim()
            : 'Unknown User');

    String resolveUrl(List<String> keys) {
      for (final k in keys) {
        final raw = data[k]?.toString().trim() ?? '';
        if (raw.isNotEmpty && raw != 'null' && raw != 'undefined') return raw;
      }
      return '';
    }

    final avatarUrl  = resolveUrl(['profilePictureUrl', 'photoURL', 'avatarUrl']);
    final coverUrl   = resolveUrl(['coverPhotoUrl', 'coverPictureUrl', 'cover']);
    final headline   = _s(data, 'headline', fb: _s(data, 'role'));
    final about      = _s(data, 'about', fb: _s(data, 'bio', fb: ''));
    final location   = _s(data, 'location', fb: '');
    final batch      = _s(data, 'batch', fb: _s(data, 'batchYear', fb: ''));
    final course     = _s(data, 'course', fb: _s(data, 'program', fb: ''));
    final occupation = _s(data, 'occupation', fb: '');
    final company    = _s(data, 'company', fb: '');
    final role       = _s(data, 'role', fb: '');
    final status     = _s(data, 'status', fb: '');
    final phone      = _s(data, 'phone_number', fb: _s(data, 'phone', fb: ''));
    final isVerified = status == 'active' ||
        _s(data, 'verificationStatus', fb: '') == 'verified';

    final experience = _safeList(data, 'experience');
    final education  = _safeList(data, 'education');

    final connectionsCount = _safeInt(data['connectionsCount']);
    final followersCount   = _safeInt(data['followersCount']);
    final followingCount   = _safeInt(data['followingCount']);

    // ── Connect button state ──────────────────────────
    final String connectLabel;
    final Color connectBg;
    final IconData connectIcon;
    final bool connectOutlined;

    if (_isConnected) {
      connectLabel    = 'Connected';
      connectBg       = Colors.green.shade600;
      connectIcon     = Icons.how_to_reg_rounded;
      connectOutlined = true;
    } else if (_requestPending) {
      connectLabel    = 'Pending';
      connectBg       = Colors.orange.shade600;
      connectIcon     = Icons.schedule_rounded;
      connectOutlined = true;
    } else if (_requestReceived) {
      connectLabel    = 'Accept';
      connectBg       = Colors.blue.shade600;
      connectIcon     = Icons.person_add_alt_1_rounded;
      connectOutlined = false;
    } else {
      connectLabel    = 'Connect';
      connectBg       = AppColors.brandRed;
      connectIcon     = Icons.person_add_alt_1_rounded;
      connectOutlined = false;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Pinned AppBar ──────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.white,
            foregroundColor: AppColors.darkText,
            elevation: 0.5,
            title: Text(name,
                style: GoogleFonts.cormorantGaramond(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkText),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),

          // ── Cover + Avatar ────────────────────────
          SliverToBoxAdapter(
            child: SizedBox(
              height: _coverHeight + _avatarOverlap,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Cover
                  Positioned(
                    top: 0, left: 0, right: 0,
                    height: _coverHeight,
                    child: coverUrl.isNotEmpty
                        ? Stack(fit: StackFit.expand, children: [
                            CachedNetworkImage(
                              imageUrl: coverUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => _defaultCover(),
                            ),
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                height: 90,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.4),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ])
                        : _defaultCover(),
                  ),

                  // Avatar + action buttons row
                  Positioned(
                    top: _coverHeight - _avatarTotal / 2,
                    left: 20,
                    right: 20,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Avatar
                        Hero(
                          tag: 'alumni_avatar_${widget.uid}',
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: const Color(0xFFF4F4F6),
                                  width: _avatarBorder),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.18),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                              color: Colors.white,
                            ),
                            child: CircleAvatar(
                              radius: _avatarRadius,
                              backgroundColor: AppColors.borderSubtle,
                              child: avatarUrl.isNotEmpty
                                  ? ClipOval(
                                      child: CachedNetworkImage(
                                        imageUrl: avatarUrl,
                                        width: _avatarRadius * 2,
                                        height: _avatarRadius * 2,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) => Container(
                                            color: Colors.grey.shade100),
                                        errorWidget: (_, __, ___) =>
                                            const Icon(Icons.person,
                                                size: 44,
                                                color: AppColors.brandRed),
                                      ),
                                    )
                                  : const Icon(Icons.person,
                                      size: 44, color: AppColors.brandRed),
                            ),
                          ),
                        ),

                        const Spacer(),

                        // Action buttons
                        if (!_isOwnProfile)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: !_relationshipReady
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.brandRed))
                                : Row(children: [
                                    _ActionBtn(
                                      label: _isFollowing ? 'Following' : 'Follow',
                                      icon: _isFollowing
                                          ? Icons.notifications_active_rounded
                                          : Icons.notifications_none_rounded,
                                      color: _isFollowing
                                          ? Colors.blue.shade700
                                          : AppColors.mutedText,
                                      outlined: true,
                                      loading: _followLoading,
                                      onPressed: _handleFollow,
                                    ),
                                    const SizedBox(width: 8),
                                    _ActionBtn(
                                      label: connectLabel,
                                      icon: connectIcon,
                                      color: connectBg,
                                      outlined: connectOutlined,
                                      loading: _connectLoading,
                                      onPressed: _handleConnect,
                                    ),
                                  ]),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Content ───────────────────────────────
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),

                // Name + badge
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(
                          child: Text(name,
                              style: GoogleFonts.cormorantGaramond(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.darkText,
                                  height: 1.1)),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.brandRed.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: AppColors.brandRed.withOpacity(0.3)),
                            ),
                            child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.verified_rounded,
                                      size: 11, color: AppColors.brandRed),
                                  const SizedBox(width: 3),
                                  Text('Verified',
                                      style: GoogleFonts.inter(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.brandRed)),
                                ]),
                          ),
                        ],
                      ]),

                      if (headline.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(headline,
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.darkText.withOpacity(0.75))),
                      ],

                      if (company.isNotEmpty || occupation.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(children: [
                          const Icon(Icons.business_outlined,
                              size: 12, color: AppColors.mutedText),
                          const SizedBox(width: 4),
                          Text(
                            [
                              if (occupation.isNotEmpty) occupation,
                              if (company.isNotEmpty) company,
                            ].join(' · '),
                            style: GoogleFonts.inter(
                                fontSize: 12, color: AppColors.mutedText),
                          ),
                        ]),
                      ],

                      const SizedBox(height: 10),

                      Wrap(spacing: 14, runSpacing: 6, children: [
                        if (location.isNotEmpty)
                          _MetaBit(icon: Icons.location_on_outlined, text: location),
                        if (batch.isNotEmpty)
                          _MetaBit(icon: Icons.school_outlined, text: 'Batch $batch'),
                        if (course.isNotEmpty)
                          _MetaBit(icon: Icons.auto_stories_outlined, text: course),
                        if (role.isNotEmpty)
                          _MetaBit(
                              icon: Icons.badge_outlined,
                              text: role[0].toUpperCase() + role.substring(1)),
                        if (phone.isNotEmpty)
                          _MetaBit(icon: Icons.phone_outlined, text: phone),
                      ]),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Stats
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.borderSubtle),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Row(children: [
                      _StatCell(count: connectionsCount, label: 'Connections'),
                      _StatDivider(),
                      _StatCell(count: followersCount, label: 'Followers'),
                      _StatDivider(),
                      _StatCell(count: followingCount, label: 'Following'),
                    ]),
                  ),
                ),

                const SizedBox(height: 20),

                // About
                if (about.isNotEmpty) ...[
                  _SectionCard(
                    title: 'About',
                    icon: Icons.person_outline_rounded,
                    child: Text(about,
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.darkText.withOpacity(0.85),
                            height: 1.65)),
                  ),
                  const SizedBox(height: 12),
                ],

                // Experience
                if (experience.isNotEmpty) ...[
                  _SectionCard(
                    title: 'Experience',
                    icon: Icons.work_outline_rounded,
                    child: Column(
                      children: experience.asMap().entries.map((e) {
                        return Column(children: [
                          if (e.key > 0)
                            Divider(
                                height: 24,
                                color: AppColors.borderSubtle.withOpacity(0.6)),
                          _ExpItem(exp: e.value),
                        ]);
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Education
                if (education.isNotEmpty) ...[
                  _SectionCard(
                    title: 'Education',
                    icon: Icons.school_outlined,
                    child: Column(
                      children: education.asMap().entries.map((e) {
                        return Column(children: [
                          if (e.key > 0)
                            Divider(
                                height: 24,
                                color: AppColors.borderSubtle.withOpacity(0.6)),
                          _EduItem(edu: e.value),
                        ]);
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Career Milestones
                _CareerSection(uid: widget.uid),

                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _s(Map<String, dynamic> data, String key, {String fb = ''}) {
    final v = data[key]?.toString().trim();
    return (v != null && v.isNotEmpty) ? v : fb;
  }

  static int _safeInt(dynamic value) {
    if (value == null)   return 0;
    if (value is int)    return value;
    if (value is num)    return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static List<Map<String, dynamic>> _safeList(
      Map<String, dynamic> data, String key) {
    final raw = data[key];
    if (raw == null || raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Widget _defaultCover() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6B0000), Color(0xFFB22222), Color(0xFFCC4444)],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// _RelationshipWatcher
//
// FIX: Replaced the two where() queries for pending requests with direct
// document snapshot listeners. The doc IDs follow the established pattern:
//   outgoing: '${currentUid}_${otherUid}'
//   incoming: '${otherUid}_${currentUid}'
//
// This means:
//  • No composite indexes required — works immediately after deploy.
//  • Listeners fire as soon as the doc exists/is deleted, so the UI updates
//    in real time with zero extra reads.
//  • _relationshipReady = true as soon as all 4 listeners emit once.
// ─────────────────────────────────────────────────────────────────────────────
class _RelationshipWatcher extends StatefulWidget {
  final String currentUid, otherUid;
  final void Function({
    required bool connected,
    required bool pendingOut,
    required bool pendingIn,
    required bool following,
    required bool ready,
  }) onChanged;

  const _RelationshipWatcher({
    required this.currentUid,
    required this.otherUid,
    required this.onChanged,
  });

  @override
  State<_RelationshipWatcher> createState() => _RelationshipWatcherState();
}

class _RelationshipWatcherState extends State<_RelationshipWatcher> {
  final _db = FirebaseFirestore.instance;
  StreamSubscription? _connSub, _outSub, _inSub, _followSub;

  bool _connReady    = false, _outReady    = false,
       _inReady      = false, _followReady = false;
  bool _connected    = false, _pendingOut  = false,
       _pendingIn    = false, _following   = false;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(_RelationshipWatcher old) {
    super.didUpdateWidget(old);
    if (old.currentUid != widget.currentUid ||
        old.otherUid != widget.otherUid) {
      _unsubscribe();
      _resetState();
      _subscribe();
    }
  }

  void _resetState() {
    _connReady = _outReady = _inReady = _followReady = false;
    _connected = _pendingOut = _pendingIn = _following = false;
  }

  void _subscribe() {
    if (widget.currentUid.isEmpty || widget.otherUid.isEmpty) {
      // Still mark ready so UI doesn't spin forever
      widget.onChanged(
        connected: false, pendingOut: false, pendingIn: false,
        following: false, ready: true,
      );
      return;
    }

    // 1. Connection sub-collection doc
    _connSub = _db
        .collection('users')
        .doc(widget.currentUid)
        .collection('connections')
        .doc(widget.otherUid)
        .snapshots()
        .listen(
          (s) { _connected = s.exists; _connReady = true; _notify(); },
          onError: (_) { _connReady = true; _notify(); },
        );

    // FIX 2. Outgoing request — direct doc read, no where() query
    _outSub = _db
        .collection('friend_requests')
        .doc('${widget.currentUid}_${widget.otherUid}')
        .snapshots()
        .listen(
          (s) {
            // Only count it as pending if status field says 'pending'
            final data = s.data() as Map<String, dynamic>?;
            _pendingOut = s.exists &&
                data?['status']?.toString() == 'pending';
            _outReady = true;
            _notify();
          },
          onError: (_) { _outReady = true; _notify(); },
        );

    // FIX 3. Incoming request — direct doc read, no where() query
    _inSub = _db
        .collection('friend_requests')
        .doc('${widget.otherUid}_${widget.currentUid}')
        .snapshots()
        .listen(
          (s) {
            final data = s.data() as Map<String, dynamic>?;
            _pendingIn = s.exists &&
                data?['status']?.toString() == 'pending';
            _inReady = true;
            _notify();
          },
          onError: (_) { _inReady = true; _notify(); },
        );

    // 4. Following sub-collection doc
    _followSub = _db
        .collection('users')
        .doc(widget.currentUid)
        .collection('following')
        .doc(widget.otherUid)
        .snapshots()
        .listen(
          (s) { _following = s.exists; _followReady = true; _notify(); },
          onError: (_) { _followReady = true; _notify(); },
        );
  }

  void _notify() {
    if (!mounted) return;
    widget.onChanged(
      connected:  _connected,
      pendingOut: _pendingOut,
      pendingIn:  _pendingIn,
      following:  _following,
      ready: _connReady && _outReady && _inReady && _followReady,
    );
  }

  void _unsubscribe() {
    _connSub?.cancel();
    _outSub?.cancel();
    _inSub?.cancel();
    _followSub?.cancel();
    _connSub = _outSub = _inSub = _followSub = null;
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ─────────────────────────────────────────────────────────────────────────────
// _CareerSection
// ─────────────────────────────────────────────────────────────────────────────
class _CareerSection extends StatelessWidget {
  final String uid;
  const _CareerSection({required this.uid});

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('career_milestones')
          .where('userId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError ||
            !snapshot.hasData ||
            snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
        final docs = snapshot.data!.docs;
        return Column(children: [
          _SectionCard(
            title: 'Career Milestones',
            icon: Icons.emoji_events_outlined,
            child: Column(
              children: docs.asMap().entries.map((entry) {
                final d = entry.value.data() as Map<String, dynamic>? ?? {};
                final title   = d['title']?.toString()   ?? '';
                final company = d['company']?.toString() ?? '';
                final year    = d['year']?.toString()    ?? '';
                if (title.isEmpty && company.isEmpty) return const SizedBox.shrink();
                return Column(children: [
                  if (entry.key > 0)
                    Divider(height: 24, color: AppColors.borderSubtle.withOpacity(0.6)),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const _IconBox(icon: Icons.work_outline),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title.isNotEmpty)
                          Text(title,
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.darkText)),
                        if (company.isNotEmpty)
                          Text(company,
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.brandRed,
                                  fontWeight: FontWeight.w500)),
                        if (year.isNotEmpty)
                          Text(year,
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: AppColors.mutedText)),
                      ],
                    )),
                  ]),
                ]);
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
        ]);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small reusable widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ExpItem extends StatelessWidget {
  final Map<String, dynamic> exp;
  const _ExpItem({required this.exp});

  @override
  Widget build(BuildContext context) {
    final title       = exp['title']?.toString()       ?? '';
    final company     = exp['company']?.toString()     ?? '';
    final location    = exp['location']?.toString()    ?? '';
    final description = exp['description']?.toString() ?? '';

    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _IconBox(icon: Icons.work_outline_rounded),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Text(title,
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText)),
          if (company.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(company,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.brandRed,
                    fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 3),
          Text(_formatPeriod(exp['start'], exp['end']),
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedText)),
          if (location.isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.location_on_outlined, size: 12, color: AppColors.mutedText),
              const SizedBox(width: 3),
              Flexible(child: Text(location,
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedText))),
            ]),
          ],
          if (description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(description,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.darkText.withOpacity(0.8),
                    height: 1.5)),
          ],
        ],
      )),
    ]);
  }

  String _formatPeriod(dynamic start, dynamic end) {
    final s = _d(start);
    if (end == null) return s.isNotEmpty ? '$s – Present' : 'Present';
    final e = _d(end);
    return s.isNotEmpty ? '$s – $e' : e;
  }

  String _d(dynamic v) {
    if (v == null) return '';
    final dt = v is Timestamp ? v.toDate() : DateTime.tryParse(v.toString());
    return dt != null ? DateFormat('MMM yyyy').format(dt) : '';
  }
}

class _EduItem extends StatelessWidget {
  final Map<String, dynamic> edu;
  const _EduItem({required this.edu});

  @override
  Widget build(BuildContext context) {
    final degree       = edu['degree']?.toString()       ?? '';
    final school       = edu['school']?.toString()       ?? '';
    final fieldOfStudy = edu['fieldOfStudy']?.toString() ?? '';
    final grade        = edu['grade']?.toString()        ?? '';

    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _IconBox(icon: Icons.school_outlined),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (degree.isNotEmpty)
            Text(degree,
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText)),
          if (school.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(school,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.brandRed,
                    fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 3),
          Text(_formatPeriod(edu['start'], edu['end']),
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedText)),
          if (fieldOfStudy.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(fieldOfStudy,
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedText)),
          ],
          if (grade.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.military_tech_outlined, size: 12, color: Colors.amber.shade700),
                const SizedBox(width: 4),
                Text(grade,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber.shade800)),
              ]),
            ),
          ],
        ],
      )),
    ]);
  }

  String _formatPeriod(dynamic start, dynamic end) {
    final s = _d(start);
    final e = _d(end);
    if (e.isEmpty) return s.isNotEmpty ? '$s – Present' : '';
    return s.isNotEmpty ? '$s – $e' : e;
  }

  String _d(dynamic v) {
    if (v == null) return '';
    final dt = v is Timestamp ? v.toDate() : DateTime.tryParse(v.toString());
    return dt != null ? DateFormat('MMM yyyy').format(dt) : '';
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _SectionCard(
      {required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.brandRed.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 17, color: AppColors.brandRed),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: GoogleFonts.cormorantGaramond(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkText)),
            ]),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _MetaBit extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MetaBit({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.mutedText),
          const SizedBox(width: 4),
          Text(text,
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedText)),
        ],
      );
}

class _StatCell extends StatelessWidget {
  final int count;
  final String label;
  const _StatCell({required this.count, required this.label});

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(children: [
            Text(_fmt(count),
                style: GoogleFonts.cormorantGaramond(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText)),
            const SizedBox(height: 2),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 10,
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.w500)),
          ]),
        ),
      );
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(height: 32, width: 1, color: AppColors.borderSubtle);
}

class _IconBox extends StatelessWidget {
  final IconData icon;
  const _IconBox({required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.brandRed.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.brandRed, size: 18),
      );
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool outlined, loading;
  final VoidCallback onPressed;
  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.outlined,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final shape   = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
    const padding = EdgeInsets.symmetric(horizontal: 14, vertical: 9);
    final content = loading
        ? SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: outlined ? color : Colors.white))
        : Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14),
            const SizedBox(width: 5),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w600)),
          ]);

    return outlined
        ? OutlinedButton(
            style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color),
                padding: padding, shape: shape),
            onPressed: loading ? null : onPressed,
            child: content,
          )
        : ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: padding, shape: shape),
            onPressed: loading ? null : onPressed,
            child: content,
          );
  }
}