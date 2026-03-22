import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:alumni/core/constants/app_colors.dart';

class ChapterManagementScreen extends StatefulWidget {
  const ChapterManagementScreen({super.key});

  @override
  State<ChapterManagementScreen> createState() =>
      _ChapterManagementScreenState();
}

class _ChapterManagementScreenState
    extends State<ChapterManagementScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _typeFilter;
  String _adminName = 'Admin';
  String _adminRole = 'ADMIN';

  // ─── Live stats from Firestore ───
  int _totalChapters = 0;
  int _activeChapters = 0;
  int _totalMembers = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(
        () => _searchQuery =
            _searchController.text.trim().toLowerCase()));
    _loadAdminProfile();
    _loadStats();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _adminName = data['name']?.toString() ??
              data['fullName']?.toString() ??
              user.displayName ??
              'Admin';
          _adminRole =
              data['role']?.toString().toUpperCase() ??
                  'ADMIN';
        });
      }
    } catch (_) {}
  }

  Future<void> _loadStats() async {
    try {
      final all = await FirebaseFirestore.instance
          .collection('chapters')
          .count()
          .get();
      final active = await FirebaseFirestore.instance
          .collection('chapters')
          .where('status', isEqualTo: 'active')
          .count()
          .get();

      // Count total members across all chapters
      final chapters = await FirebaseFirestore.instance
          .collection('chapters')
          .get();
      int memberCount = 0;
      for (final ch in chapters.docs) {
        final mc = await FirebaseFirestore.instance
            .collection('chapters')
            .doc(ch.id)
            .collection('members')
            .count()
            .get();
        memberCount += mc.count ?? 0;
      }

      if (mounted) {
        setState(() {
          _totalChapters = all.count ?? 0;
          _activeChapters = active.count ?? 0;
          _totalMembers = memberCount;
        });
      }
    } catch (e) {
      debugPrint('Stats error: $e');
    }
  }

  void _showSnackBar(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter()),
        backgroundColor:
            isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  Future<bool?> _confirmDialog({
    required String title,
    required String message,
    required String confirmText,
    Color confirmColor = AppColors.brandRed,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700)),
        content:
            Text(message, style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(
                    color: AppColors.mutedText)),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, true),
            child: Text(confirmText,
                style: GoogleFonts.inter(
                    color: confirmColor,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ─── Create / Edit Chapter ───
  void _showChapterForm({
    String? chapterId,
    Map<String, dynamic>? initialData,
  }) {
    final isEdit = chapterId != null;
    String type =
        initialData?['type']?.toString() ?? 'regional';
    String status =
        initialData?['status']?.toString() ?? 'active';
    final nameCtrl = TextEditingController(
        text: initialData?['name']?.toString() ?? '');
    final descCtrl = TextEditingController(
        text: initialData?['description']?.toString() ??
            '');
    final regionCtrl = TextEditingController(
        text:
            initialData?['region']?.toString() ?? '');
    final locationCtrl = TextEditingController(
        text:
            initialData?['location']?.toString() ?? '');
    final batchYearCtrl = TextEditingController(
        text: (initialData?['batchYear'] as num?)
                ?.toStringAsFixed(0) ??
            '');
    final programCtrl = TextEditingController(
        text:
            initialData?['program']?.toString() ?? '');
    final contactCtrl = TextEditingController(
        text:
            initialData?['contactEmail']?.toString() ??
                '');
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) =>
            DraggableScrollableSheet(
          initialChildSize: 0.9,
          maxChildSize: 0.97,
          minChildSize: 0.5,
          builder: (_, controller) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                  top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(
                      vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderSubtle,
                    borderRadius:
                        BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        isEdit
                            ? 'Edit Chapter'
                            : 'New Chapter',
                        style:
                            GoogleFonts.cormorantGaramond(
                                fontSize: 22,
                                fontWeight:
                                    FontWeight.w600),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final name =
                                    nameCtrl.text.trim();
                                if (name.isEmpty) {
                                  _showSnackBar(
                                      'Chapter name is required',
                                      isError: true);
                                  return;
                                }
                                if (type == 'batch') {
                                  final y =
                                      batchYearCtrl.text
                                          .trim();
                                  if (y.isEmpty ||
                                      int.tryParse(y) ==
                                          null) {
                                    _showSnackBar(
                                        'Valid batch year required',
                                        isError: true);
                                    return;
                                  }
                                }
                                setSheet(() =>
                                    isSubmitting = true);

                                final data =
                                    <String, dynamic>{
                                  'name': name,
                                  'type': type,
                                  'status': status,
                                  'description':
                                      descCtrl.text.trim(),
                                  'region':
                                      regionCtrl.text.trim(),
                                  'location': locationCtrl
                                      .text
                                      .trim(),
                                  'contactEmail':
                                      contactCtrl.text.trim(),
                                  'updatedAt': FieldValue
                                      .serverTimestamp(),
                                };

                                if (type == 'batch') {
                                  data['batchYear'] =
                                      int.parse(batchYearCtrl
                                          .text
                                          .trim());
                                }
                                if (type == 'course') {
                                  data['program'] =
                                      programCtrl.text.trim();
                                }

                                if (!isEdit) {
                                  data.addAll({
                                    'createdAt': FieldValue
                                        .serverTimestamp(),
                                    'createdBy': FirebaseAuth
                                        .instance
                                        .currentUser
                                        ?.uid,
                                    'memberCount': 0,
                                    'eventCount': 0,
                                  });
                                }

                                try {
                                  if (isEdit) {
                                    await FirebaseFirestore
                                        .instance
                                        .collection(
                                            'chapters')
                                        .doc(chapterId)
                                        .update(data);
                                  } else {
                                    await FirebaseFirestore
                                        .instance
                                        .collection(
                                            'chapters')
                                        .add(data);
                                  }
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                    _showSnackBar(
                                        isEdit
                                            ? 'Chapter updated!'
                                            : 'Chapter created!',
                                        isError: false);
                                    _loadStats();
                                  }
                                } catch (e) {
                                  setSheet(() =>
                                      isSubmitting = false);
                                  _showSnackBar('Error: $e',
                                      isError: true);
                                }
                              },
                        child: Text(
                          isSubmitting
                              ? 'Saving...'
                              : isEdit
                                  ? 'Save'
                                  : 'Create',
                          style: GoogleFonts.inter(
                              color: AppColors.brandRed,
                              fontWeight: FontWeight.w700,
                              fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    controller: controller,
                    padding: const EdgeInsets.all(20),
                    children: [
                      // ─── Type dropdown ───
                      _dropdownField(
                        label: 'Chapter Type',
                        value: type,
                        items: const {
                          'regional': 'Regional / Geographic',
                          'batch': 'Batch / Graduation Year',
                          'course': 'Course / Program-Based',
                          'professional':
                              'Professional / Career Field',
                          'international': 'International',
                          'other': 'Other',
                        },
                        onChanged: (v) =>
                            setSheet(() => type = v!),
                      ),
                      const SizedBox(height: 16),

                      _formField(nameCtrl, 'Chapter Name *',
                          'e.g. Cebu City Chapter'),
                      const SizedBox(height: 16),

                      if (type == 'batch') ...[
                        _formField(
                            batchYearCtrl,
                            'Batch Year *',
                            'e.g. 2015',
                            keyboardType:
                                TextInputType.number),
                        const SizedBox(height: 16),
                      ],

                      if (type == 'course') ...[
                        _formField(programCtrl,
                            'Course / Program *',
                            'e.g. BS Nursing'),
                        const SizedBox(height: 16),
                      ],

                      _formField(regionCtrl,
                          'Region / Province',
                          'e.g. Region VII',
                          prefixIcon:
                              Icons.map_outlined),
                      const SizedBox(height: 16),

                      _formField(
                          locationCtrl,
                          'Specific Location',
                          'e.g. Cebu City, Cebu',
                          prefixIcon:
                              Icons.location_on_outlined),
                      const SizedBox(height: 16),

                      _formField(
                          contactCtrl,
                          'Contact Email',
                          'chapter@stcecilia.edu.ph',
                          prefixIcon: Icons.email_outlined,
                          keyboardType:
                              TextInputType.emailAddress),
                      const SizedBox(height: 16),

                      _formField(descCtrl, 'Description',
                          'What is this chapter about?',
                          maxLines: 3),
                      const SizedBox(height: 16),

                      // ─── Status ───
                      _dropdownField(
                        label: 'Status',
                        value: status,
                        items: const {
                          'active': 'Active',
                          'inactive': 'Inactive',
                          'dissolved': 'Dissolved',
                        },
                        onChanged: (v) =>
                            setSheet(() => status = v!),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Delete chapter ───
  Future<void> _deleteChapter(
      String id, String name) async {
    final confirm = await _confirmDialog(
      title: 'Delete Chapter',
      message:
          'Delete "$name" and all its members? This cannot be undone.',
      confirmText: 'Delete',
    );
    if (confirm != true) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      final members = await FirebaseFirestore.instance
          .collection('chapters')
          .doc(id)
          .collection('members')
          .get();
      for (final doc in members.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(FirebaseFirestore.instance
          .collection('chapters')
          .doc(id));
      await batch.commit();
      _showSnackBar('Chapter deleted', isError: false);
      _loadStats();
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  // ─── Members panel ───
  void _showMembers(String chapterId, String name) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.97,
        minChildSize: 0.4,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
                top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(
                    vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style:
                                  GoogleFonts.cormorantGaramond(
                                      fontSize: 20,
                                      fontWeight:
                                          FontWeight.w600)),
                          Text('Chapter Members',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color:
                                      AppColors.mutedText)),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () =>
                          _showAddMember(chapterId, ctx),
                      icon: const Icon(Icons.person_add,
                          size: 16),
                      label: Text('Add Member',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandRed,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('chapters')
                      .doc(chapterId)
                      .collection('members')
                      .orderBy('joinedAt',
                          descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                          child:
                              CircularProgressIndicator(
                                  color:
                                      AppColors.brandRed));
                    }
                    final docs =
                        snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            const Icon(
                                Icons.group_outlined,
                                size: 48,
                                color:
                                    AppColors.borderSubtle),
                            const SizedBox(height: 12),
                            Text('No members yet',
                                style: GoogleFonts.inter(
                                    color:
                                        AppColors.mutedText)),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () =>
                                  _showAddMember(
                                      chapterId, ctx),
                              child: Text('Add first member',
                                  style: GoogleFonts.inter(
                                      color: AppColors
                                          .brandRed)),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.separated(
                      controller: controller,
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) =>
                          const Divider(
                              color: AppColors.borderSubtle,
                              height: 1),
                      itemBuilder: (context, i) {
                        final doc = docs[i];
                        final mData = doc.data()
                            as Map<String, dynamic>;
                        final uid = doc.id;
                        final role =
                            mData['role']?.toString() ??
                                'member';
                        final joinedAt = (mData['joinedAt']
                                as Timestamp?)
                            ?.toDate();
                        final isPresident =
                            role == 'president';
return FutureBuilder<Map<String, dynamic>>(
                          future: _fetchUser(uid),
                          builder: (context, snap) {
                            final user = snap.data ??
                                {
                                  'name': 'Loading...',
                                  'email': '',
                                  'avatarUrl': null,
                                };
                            final uName =
                                user['name'].toString();
                            final uEmail =
                                user['email'].toString();
                            final avatarUrl =
                                user['avatarUrl']
                                    ?.toString();

                            return ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 4),
                              leading: CircleAvatar(
                                radius: 20,
                                backgroundColor: isPresident
                                    ? AppColors.brandRed
                                    : AppColors.brandRed
                                        .withOpacity(0.1),
                                backgroundImage:
                                    avatarUrl != null
                                        ? NetworkImage(
                                            avatarUrl)
                                        : null,
                                child: avatarUrl == null
                                    ? Text(
                                        uName.isNotEmpty
                                            ? uName[0]
                                                .toUpperCase()
                                            : '?',
                                        style: GoogleFonts.inter(
                                            color: isPresident
                                                ? Colors.white
                                                : AppColors
                                                    .brandRed,
                                            fontWeight:
                                                FontWeight
                                                    .w700,
                                            fontSize: 13))
                                    : null,
                              ),
                              title: Row(children: [
                                Text(uName,
                                    style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight:
                                            FontWeight.w600)),
                                if (isPresident) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding:
                                        const EdgeInsets
                                            .symmetric(
                                            horizontal: 6,
                                            vertical: 2),
                                    decoration:
                                        BoxDecoration(
                                      color:
                                          AppColors.brandRed,
                                      borderRadius:
                                          BorderRadius
                                              .circular(4),
                                    ),
                                    child: Text('PRESIDENT',
                                        style:
                                            GoogleFonts.inter(
                                                fontSize: 8,
                                                color: Colors
                                                    .white,
                                                fontWeight:
                                                    FontWeight
                                                        .w700)),
                                  ),
                                ],
                              ]),
                              subtitle: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(uEmail,
                                      style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: AppColors
                                              .mutedText)),
                                  if (joinedAt != null)
                                    Text(
                                      'Joined ${DateFormat('MMM dd, yyyy').format(joinedAt)}',
                                      style: GoogleFonts.inter(
                                          fontSize: 10,
                                          color: AppColors
                                              .mutedText),
                                    ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize:
                                    MainAxisSize.min,
                                children: [
                                  if (!isPresident)
                                    Tooltip(
                                      message:
                                          'Set as President',
                                      child: GestureDetector(
                                        onTap: () =>
                                            _setPresident(
                                                chapterId,
                                                uid,
                                                uName),
                                        child: Container(
                                          padding:
                                              const EdgeInsets
                                                  .all(6),
                                          decoration:
                                              BoxDecoration(
                                            color: AppColors
                                                .brandRed
                                                .withOpacity(
                                                    0.08),
                                            borderRadius:
                                                BorderRadius
                                                    .circular(
                                                        6),
                                          ),
                                          child: const Icon(
                                              Icons.star_outline,
                                              color: AppColors
                                                  .brandRed,
                                              size: 16),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: 6),
                                  Tooltip(
                                    message:
                                        'Remove Member',
                                    child: GestureDetector(
                                      onTap: () =>
                                          _removeMember(
                                              chapterId,
                                              uid,
                                              uName,
                                              ctx),
                                      child: Container(
                                        padding:
                                            const EdgeInsets
                                                .all(6),
                                        decoration:
                                            BoxDecoration(
                                          color: Colors.red
                                              .withOpacity(
                                                  0.08),
                                          borderRadius:
                                              BorderRadius
                                                  .circular(6),
                                        ),
                                        child: const Icon(
                                            Icons
                                                .remove_circle_outline,
                                            color: Colors.red,
                                            size: 16),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Add member search ───
  void _showAddMember(
      String chapterId, BuildContext parentCtx) {
    final searchCtrl = TextEditingController();
    List<Map<String, dynamic>> results = [];
    bool isSearching = false;

    showModalBottomSheet(
      context: parentCtx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          builder: (_, controller) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                  top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(
                      vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderSubtle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 4),
                  child: Row(children: [
                    Text('Add Member',
                        style:
                            GoogleFonts.cormorantGaramond(
                                fontSize: 20,
                                fontWeight:
                                    FontWeight.w600)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: AppColors.mutedText),
                      onPressed: () =>
                          Navigator.pop(ctx),
                    ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      20, 4, 20, 12),
                  child: TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    style: GoogleFonts.inter(fontSize: 14),
                    onChanged: (v) async {
                      if (v.trim().length < 2) {
                        setSheet(() => results = []);
                        return;
                      }
                      setSheet(() => isSearching = true);
                      final q = v.trim().toLowerCase();
                      final snap = await FirebaseFirestore
                          .instance
                          .collection('users')
                          .limit(100)
                          .get();
                      final filtered = snap.docs
                          .where((d) {
                            final name = d
                                    .data()['name']
                                    ?.toString()
                                    .toLowerCase() ??
                                '';
                            final email = d
                                    .data()['email']
                                    ?.toString()
                                    .toLowerCase() ??
                                '';
                            return name.contains(q) ||
                                email.contains(q);
                          })
                          .map((d) => {
                                'uid': d.id,
                                'name': d.data()['name']
                                        ?.toString() ??
                                    'Unknown',
                                'email': d.data()['email']
                                        ?.toString() ??
                                    '—',
                                'avatarUrl': d
                                    .data()[
                                        'profilePictureUrl']
                                    ?.toString(),
                                'role': d.data()['role']
                                        ?.toString() ??
                                    'alumni',
                              })
                          .toList();
                      setSheet(() {
                        results = filtered;
                        isSearching = false;
                      });
                    },
                    decoration: InputDecoration(
                      hintText:
                          'Search alumni by name or email...',
                      hintStyle: GoogleFonts.inter(
                          color: AppColors.mutedText,
                          fontSize: 13),
                      prefixIcon: const Icon(Icons.search,
                          color: AppColors.mutedText,
                          size: 20),
                      filled: true,
                      fillColor: AppColors.softWhite,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: isSearching
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.brandRed))
                      : results.isEmpty
                          ? Center(
                              child: Text(
                                'Type to search alumni',
                                style: GoogleFonts.inter(
                                    color:
                                        AppColors.mutedText),
                              ),
                            )
                          : ListView.separated(
                              controller: controller,
                              padding: const EdgeInsets.all(
                                  12),
                              itemCount: results.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(
                                      color: AppColors
                                          .borderSubtle,
                                      height: 1),
                              itemBuilder: (context, i) {
                                final u = results[i];
                                final avatarUrl =
                                    u['avatarUrl']
                                        ?.toString();
                                return ListTile(
                                  leading: CircleAvatar(
                                    radius: 18,
                                    backgroundColor:
                                        AppColors.brandRed
                                            .withOpacity(0.1),
                                    backgroundImage:
                                        avatarUrl != null
                                            ? NetworkImage(
                                                avatarUrl)
                                            : null,
                                    child: avatarUrl == null
                                        ? Text(
                                            u['name']
                                                    .toString()
                                                    .isNotEmpty
                                                ? u['name']
                                                    .toString()[0]
                                                    .toUpperCase()
                                                : '?',
                                            style: GoogleFonts.inter(
                                                color: AppColors
                                                    .brandRed,
                                                fontSize: 11,
                                                fontWeight:
                                                    FontWeight
                                                        .w700))
                                        : null,
                                  ),
                                  title: Text(
                                      u['name'].toString(),
                                      style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight:
                                              FontWeight
                                                  .w600)),
                                  subtitle: Text(
                                      u['email'].toString(),
                                      style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: AppColors
                                              .mutedText)),
                                  trailing: GestureDetector(
                                    onTap: () =>
                                        _addMember(
                                            chapterId,
                                            u['uid']
                                                .toString(),
                                            u['name']
                                                .toString(),
                                            ctx),
                                    child: Container(
                                      padding:
                                          const EdgeInsets
                                              .symmetric(
                                              horizontal: 10,
                                              vertical: 6),
                                      decoration:
                                          BoxDecoration(
                                        color: Colors.green
                                            .withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius
                                                .circular(8),
                                      ),
                                      child: Text('Add',
                                          style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color:
                                                  Colors.green,
                                              fontWeight:
                                                  FontWeight
                                                      .w600)),
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addMember(String chapterId, String uid,
      String name, BuildContext ctx) async {
    try {
      final ref = FirebaseFirestore.instance
          .collection('chapters')
          .doc(chapterId)
          .collection('members')
          .doc(uid);
      final exists = await ref.get();
      if (exists.exists) {
        _showSnackBar('$name is already a member',
            isError: true);
        return;
      }
      await ref.set({
        'joinedAt': FieldValue.serverTimestamp(),
        'role': 'member',
        'status': 'active',
        'addedBy':
            FirebaseAuth.instance.currentUser?.uid,
      });

      // ─── Update member count ───
      await FirebaseFirestore.instance
          .collection('chapters')
          .doc(chapterId)
          .set({'memberCount': FieldValue.increment(1)},
              SetOptions(merge: true));

      _showSnackBar('$name added to chapter',
          isError: false);
      _loadStats();
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  Future<void> _removeMember(String chapterId,
      String uid, String name, BuildContext ctx) async {
    final confirm = await _confirmDialog(
      title: 'Remove Member',
      message: 'Remove $name from this chapter?',
      confirmText: 'Remove',
    );
    if (confirm != true) return;
    try {
      await FirebaseFirestore.instance
          .collection('chapters')
          .doc(chapterId)
          .collection('members')
          .doc(uid)
          .delete();
      await FirebaseFirestore.instance
          .collection('chapters')
          .doc(chapterId)
          .set(
              {'memberCount': FieldValue.increment(-1)},
              SetOptions(merge: true));
      _showSnackBar('$name removed', isError: false);
      _loadStats();
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  Future<void> _setPresident(
      String chapterId, String uid, String name) async {
    final confirm = await _confirmDialog(
      title: 'Set as President',
      message:
          'Make $name the chapter president? This will replace the current president.',
      confirmText: 'Confirm',
      confirmColor: Colors.green,
    );
    if (confirm != true) return;

    try {
      final chapterRef = FirebaseFirestore.instance
          .collection('chapters')
          .doc(chapterId);
      final chapter = await chapterRef.get();
      final currentPresidentUid =
          chapter.data()?['presidentUid'] as String?;

      final batch = FirebaseFirestore.instance.batch();

      if (currentPresidentUid != null &&
          currentPresidentUid != uid) {
        batch.update(
          chapterRef
              .collection('members')
              .doc(currentPresidentUid),
          {'role': 'member'},
        );
      }

      batch.update(
        chapterRef.collection('members').doc(uid),
        {'role': 'president'},
      );

      batch.update(chapterRef, {
        'presidentUid': uid,
        'presidentName': name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      _showSnackBar('$name is now chapter president',
          isError: false);
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  Future<Map<String, dynamic>> _fetchUser(
      String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = doc.data() ?? {};
      return {
        'name': data['name']?.toString() ??
            data['fullName']?.toString() ??
            'Unknown',
        'email': data['email']?.toString() ?? '—',
        'avatarUrl':
            data['profilePictureUrl']?.toString(),
      };
    } catch (_) {
      return {
        'name': 'Unknown',
        'email': '—',
        'avatarUrl': null
      };
    }
  }

  Future<int> _getMemberCount(String chapterId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('chapters')
          .doc(chapterId)
          .collection('members')
          .count()
          .get();
      return snap.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<String> _getPresidentName(String? uid) async {
    if (uid == null || uid.isEmpty) return 'None';
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = doc.data() ?? {};
      return data['name']?.toString() ??
          data['fullName']?.toString() ??
          'Unknown';
    } catch (_) {
      return 'None';
    }
  }

  Color _typeColor(String type) {
    switch (type.toLowerCase()) {
      case 'regional':
        return Colors.blue;
      case 'batch':
        return Colors.purple;
      case 'course':
        return Colors.teal;
      case 'professional':
        return Colors.orange;
      case 'international':
        return Colors.green;
      default:
        return AppColors.mutedText;
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.orange;
      case 'dissolved':
        return Colors.red;
      default:
        return AppColors.mutedText;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softWhite,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Sidebar ───
          Container(
            width: 280,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                  right: BorderSide(
                      color: AppColors.borderSubtle,
                      width: 0.5)),
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text('ALUMNI',
                          style:
                              GoogleFonts.cormorantGaramond(
                                  fontSize: 22,
                                  letterSpacing: 6,
                                  color: AppColors.brandRed,
                                  fontWeight:
                                      FontWeight.w300)),
                      const SizedBox(height: 6),
                      Text('ARCHIVE PORTAL',
                          style: GoogleFonts.inter(
                              fontSize: 9,
                              letterSpacing: 2,
                              color: AppColors.mutedText,
                              fontWeight:
                                  FontWeight.bold)),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        _sidebarSection('NETWORK', [
                          _sidebarItem('Overview',
                              route: '/admin_dashboard'),
                          _sidebarItem(
                              'Chapter Management',
                              route: '/chapter_management',
                              isActive: true),
                        ]),
                        const SizedBox(height: 32),
                        _sidebarSection('ENGAGEMENT', [
                          _sidebarItem(
                              'Reunions & Events',
                              route: '/reunions_events'),
                          _sidebarItem(
                              'Career Milestones',
                              route: '/career_milestones'),
                        ]),
                        const SizedBox(height: 32),
                        _sidebarSection(
                            'ADMIN FEATURES', [
                          _sidebarItem(
                              'User Verification & Moderation',
                              route:
                                  '/user_verification_moderation'),
                          _sidebarItem('Event Planning',
                              route: '/event_planning'),
                          _sidebarItem(
                              'Job Board Management',
                              route:
                                  '/job_board_management'),
                          _sidebarItem('Growth Metrics',
                              route: '/growth_metrics'),
                          _sidebarItem(
                              'Announcement Management',
                              route:
                                  '/announcement_management'),
                        ]),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    border: Border(
                        top: BorderSide(
                            color: AppColors.borderSubtle
                                .withOpacity(0.3))),
                  ),
                  child: Column(children: [
                    Row(children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors
                            .brandRed
                            .withOpacity(0.1),
                        child: Text(
                          _adminName[0].toUpperCase(),
                          style:
                              GoogleFonts.cormorantGaramond(
                                  color: AppColors.brandRed,
                                  fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(_adminName,
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight:
                                        FontWeight.bold),
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis),
                            Text(_adminRole,
                                style: GoogleFonts.inter(
                                    fontSize: 9,
                                    color:
                                        AppColors.mutedText)),
                          ],
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () async {
                          await FirebaseAuth.instance
                              .signOut();
                          if (mounted) {
                            Navigator
                                .pushNamedAndRemoveUntil(
                                    context,
                                    '/login',
                                    (r) => false);
                          }
                        },
                        icon: const Icon(Icons.logout,
                            size: 13,
                            color: AppColors.mutedText),
                        label: Text('DISCONNECT',
                            style: GoogleFonts.inter(
                                fontSize: 10,
                                letterSpacing: 2,
                                color: AppColors.mutedText,
                                fontWeight:
                                    FontWeight.bold)),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),

          // ─── Main content ───
          Expanded(
            child: Column(
              children: [
                // ─── Top bar ───
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 16),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text('Chapter Management',
                              style: GoogleFonts
                                  .cormorantGaramond(
                                      fontSize: 32,
                                      fontWeight:
                                          FontWeight.w400,
                                      color:
                                          AppColors.darkText)),
                          Text(
                              'Manage alumni chapters, batches and regional groups.',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color:
                                      AppColors.mutedText)),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () =>
                            _showChapterForm(),
                        icon: const Icon(Icons.add,
                            size: 18),
                        label: Text('New Chapter',
                            style: GoogleFonts.inter(
                                fontWeight:
                                    FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              AppColors.brandRed,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                      8)),
                        ),
                      ),
                    ],
                  ),
                ),

                // ─── Stats row ───
                Container(
                  color: AppColors.cardWhite,
                  padding: const EdgeInsets.fromLTRB(
                      32, 12, 32, 12),
                  child: Row(children: [
                    _statChip('Total Chapters',
                        _totalChapters.toString(),
                        AppColors.mutedText),
                    const SizedBox(width: 12),
                    _statChip('Active',
                        _activeChapters.toString(),
                        Colors.green),
                    const SizedBox(width: 12),
                    _statChip('Total Members',
                        _totalMembers.toString(),
                        AppColors.brandRed),
                  ]),
                ),

                // ─── Search + filter ───
                Container(
                  color: AppColors.cardWhite,
                  padding: const EdgeInsets.fromLTRB(
                      32, 0, 32, 12),
                  child: Column(children: [
                    TextField(
                      controller: _searchController,
                      style: GoogleFonts.inter(
                          fontSize: 14),
                      decoration: InputDecoration(
                        hintText:
                            'Search chapters by name, region, batch...',
                        hintStyle: GoogleFonts.inter(
                            color: AppColors.mutedText,
                            fontSize: 13),
                        prefixIcon: const Icon(
                            Icons.search,
                            color: AppColors.mutedText,
                            size: 20),
                        filled: true,
                        fillColor: AppColors.softWhite,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        _filterChip('All', null),
                        const SizedBox(width: 8),
                        _filterChip(
                            'Regional', 'regional'),
                        const SizedBox(width: 8),
                        _filterChip('Batch', 'batch'),
                        const SizedBox(width: 8),
                        _filterChip('Course', 'course'),
                        const SizedBox(width: 8),
                        _filterChip(
                            'Professional', 'professional'),
                        const SizedBox(width: 8),
                        _filterChip(
                            'International',
                            'international'),
                      ]),
                    ),
                  ]),
                ),

                // ─── Chapter list ───
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('chapters')
                        .orderBy('createdAt',
                            descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                            child:
                                CircularProgressIndicator(
                                    color:
                                        AppColors.brandRed));
                      }
                      if (snapshot.hasError) {
                        return Center(
                            child: Text(
                                'Error: ${snapshot.error}',
                                style: GoogleFonts.inter(
                                    color: Colors.red)));
                      }

                      var docs =
                          snapshot.data?.docs ?? [];

                      // ─── Filter by type ───
                      if (_typeFilter != null) {
                        docs = docs.where((d) {
                          final data = d.data()
                              as Map<String, dynamic>;
                          return data['type']
                                  ?.toString() ==
                              _typeFilter;
                        }).toList();
                      }

                      // ─── Filter by search ───
                      if (_searchQuery.isNotEmpty) {
                        docs = docs.where((d) {
                          final data = d.data()
                              as Map<String, dynamic>;
                          final name = data['name']
                                  ?.toString()
                                  .toLowerCase() ??
                              '';
                          final region = data['region']
                                  ?.toString()
                                  .toLowerCase() ??
                              '';
                          final batch = data['batchYear']
                                  ?.toString() ??
                              '';
                          final program = data['program']
                                  ?.toString()
                                  .toLowerCase() ??
                              '';
                          return name.contains(
                                  _searchQuery) ||
                              region.contains(
                                  _searchQuery) ||
                              batch.contains(
                                  _searchQuery) ||
                              program
                                  .contains(_searchQuery);
                        }).toList();
                      }

                      if (docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              const Icon(
                                  Icons.apartment_outlined,
                                  size: 72,
                                  color: AppColors
                                      .borderSubtle),
                              const SizedBox(height: 16),
                              Text('No chapters found',
                                  style: GoogleFonts
                                      .cormorantGaramond(
                                          fontSize: 22,
                                          color: AppColors
                                              .darkText)),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: () =>
                                    _showChapterForm(),
                                icon: const Icon(Icons.add,
                                    color:
                                        AppColors.brandRed),
                                label: Text(
                                    'Create first chapter',
                                    style: GoogleFonts.inter(
                                        color: AppColors
                                            .brandRed)),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.all(32),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data()
                              as Map<String, dynamic>;
                          return _chapterCard(
                              doc.id, data);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chapterCard(
      String id, Map<String, dynamic> data) {
    final name =
        data['name']?.toString() ?? 'Unnamed Chapter';
    final type =
        data['type']?.toString() ?? 'regional';
    final status =
        data['status']?.toString() ?? 'active';
    final region =
        data['region']?.toString() ?? '';
    final location =
        data['location']?.toString() ?? '';
    final description =
        data['description']?.toString() ?? '';
    final batchYear = data['batchYear']?.toString() ?? '';
    final program =
        data['program']?.toString() ?? '';
    final contactEmail =
        data['contactEmail']?.toString() ?? '';
    final presidentUid =
        data['presidentUid']?.toString();
    final memberCount =
        data['memberCount'] as int? ?? 0;
    final createdAt =
        (data['createdAt'] as Timestamp?)?.toDate();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status == 'active'
              ? AppColors.borderSubtle
              : Colors.orange.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              // ─── Icon ───
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _typeColor(type)
                      .withOpacity(0.08),
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: Icon(_typeIcon(type),
                    color: _typeColor(type), size: 24),
              ),
              const SizedBox(width: 14),

              // ─── Name + location ───
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkText)),
                    const SizedBox(height: 2),
                    Row(children: [
                      if (region.isNotEmpty ||
                          location.isNotEmpty) ...[
                        const Icon(
                            Icons.location_on_outlined,
                            size: 12,
                            color: AppColors.mutedText),
                        const SizedBox(width: 3),
                        Text(
                          [region, location]
                              .where((s) => s.isNotEmpty)
                              .join(', '),
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.mutedText),
                        ),
                      ],
                    ]),
                  ],
                ),
              ),

              // ─── Badges ───
              Column(
                crossAxisAlignment:
                    CrossAxisAlignment.end,
                children: [
                  _badge(type.toUpperCase(),
                      _typeColor(type)),
                  const SizedBox(height: 4),
                  _badge(status.toUpperCase(),
                      _statusColor(status)),
                ],
              ),
            ],
          ),

          if (description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(description,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.mutedText,
                    height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],

          const SizedBox(height: 10),

          // ─── Info chips ───
          Wrap(spacing: 6, runSpacing: 6, children: [
           FutureBuilder<int>(
  future: _getMemberCount(id),
  builder: (context, snap) {
    final count = snap.data ?? memberCount;
    return _infoChip(
      Icons.people_outline,
      '$count members',
      color: count > 0 ? Colors.green : AppColors.mutedText,
    );
  },
),
            if (batchYear.isNotEmpty)
              _infoChip(Icons.school_outlined,
                  'Batch $batchYear'),
            if (program.isNotEmpty)
              _infoChip(
                  Icons.book_outlined, program),
            if (contactEmail.isNotEmpty)
              _infoChip(
                  Icons.email_outlined, contactEmail),
            if (createdAt != null)
              _infoChip(
                  Icons.calendar_today_outlined,
                  'Est. ${DateFormat('MMM yyyy').format(createdAt)}'),
          ]),

          // ─── President ───
          if (presidentUid != null &&
              presidentUid.isNotEmpty) ...[
            const SizedBox(height: 8),
            FutureBuilder<String>(
              future: _getPresidentName(presidentUid),
              builder: (context, snap) {
                if (!snap.hasData) return const SizedBox();
                return Row(children: [
                  const Icon(Icons.star,
                      size: 12,
                      color: AppColors.brandRed),
                  const SizedBox(width: 4),
                  Text(
                    'President: ${snap.data}',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.brandRed,
                        fontWeight: FontWeight.w600),
                  ),
                ]);
              },
            ),
          ],

          const SizedBox(height: 12),
          const Divider(color: AppColors.borderSubtle),
          const SizedBox(height: 4),

          // ─── Actions ───
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _actionBtn(
                icon: Icons.group_outlined,
                label: 'Members',
                color: Colors.blue,
                onTap: () =>
                    _showMembers(id, name),
              ),
              const SizedBox(width: 8),
              _actionBtn(
                icon: Icons.edit_outlined,
                label: 'Edit',
                color: AppColors.mutedText,
                onTap: () => _showChapterForm(
                    chapterId: id, initialData: data),
              ),
              const SizedBox(width: 8),
              _actionBtn(
                icon: Icons.delete_outline,
                label: 'Delete',
                color: Colors.red,
                onTap: () =>
                    _deleteChapter(id, name),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _typeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'regional':
        return Icons.map_outlined;
      case 'batch':
        return Icons.school_outlined;
      case 'course':
        return Icons.book_outlined;
      case 'professional':
        return Icons.work_outline;
      case 'international':
        return Icons.public_outlined;
      default:
        return Icons.apartment_outlined;
    }
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.4)),
    );
  }

  Widget _infoChip(IconData icon, String label,
      {Color? color}) {
    final c = color ?? AppColors.mutedText;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(0.07),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withOpacity(0.15)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: c),
        const SizedBox(width: 4),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 10, color: c)),
      ]),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w600)),
            ]),
      ),
    );
  }

  Widget _statChip(
      String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(value,
            style: GoogleFonts.cormorantGaramond(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: color)),
        const SizedBox(width: 6),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _filterChip(String label, String? value) {
    final isSelected = _typeFilter == value;
    return GestureDetector(
      onTap: () =>
          setState(() => _typeFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brandRed
              : AppColors.softWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isSelected
                  ? AppColors.brandRed
                  : AppColors.borderSubtle),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : AppColors.mutedText)),
      ),
    );
  }

  Widget _formField(
    TextEditingController ctrl,
    String label,
    String hint, {
    int maxLines = 1,
    IconData? prefixIcon,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.inter(
            color: AppColors.brandRed,
            fontWeight: FontWeight.w500),
        hintStyle: GoogleFonts.inter(
            color: AppColors.mutedText, fontSize: 13),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon,
                color: AppColors.mutedText, size: 20)
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: AppColors.brandRed, width: 1.5),
        ),
        filled: true,
        fillColor: AppColors.softWhite,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _dropdownField({
    required String label,
    required String value,
    required Map<String, String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.softWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 4),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(
              color: AppColors.brandRed,
              fontWeight: FontWeight.w500),
          border: InputBorder.none,
        ),
        items: items.entries
            .map((e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value,
                      style: GoogleFonts.inter(
                          fontSize: 14)),
                ))
            .toList(),
        onChanged: onChanged,
        style: GoogleFonts.inter(
            fontSize: 14, color: AppColors.darkText),
      ),
    );
  }

  Widget _sidebarSection(
      String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: GoogleFonts.inter(
                fontSize: 10,
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
                color: AppColors.mutedText
                    .withOpacity(0.7))),
        const SizedBox(height: 16),
        ...items,
      ],
    );
  }

  Widget _sidebarItem(String label,
      {String? route, bool isActive = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: route != null && !isActive
            ? () => Navigator.pushNamed(context, route)
            : null,
        child: MouseRegion(
          cursor: route != null && !isActive
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          child: Text(label,
              style: GoogleFonts.inter(
                  fontSize: 13.5,
                  color: isActive
                      ? AppColors.brandRed
                      : AppColors.darkText,
                  fontWeight: isActive
                      ? FontWeight.w600
                      : FontWeight.w400)),
        ),
      ),
    );
  }
}