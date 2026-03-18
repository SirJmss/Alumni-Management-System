import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:alumni/core/constants/app_colors.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  bool isLoading = true;
  bool isSaving = false;
  Map<String, dynamic>? userData;

  // Cloudinary config
  static const String _cloudName = 'dok63li34';
  static const String _uploadPreset = 'alumni_uploads';

  // Controllers
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _headlineController = TextEditingController();
  final _aboutController = TextEditingController();
  final _locationController = TextEditingController();
  final _phoneController = TextEditingController();

  // Image handling
  File? _profileImageFile;
  File? _coverImageFile;
  String? _currentProfileUrl;
  String? _currentCoverUrl;
  bool _isUploadingProfile = false;
  bool _isUploadingCover = false;

  // Dynamic lists
  List<Map<String, dynamic>> _experiences = [];
  List<Map<String, dynamic>> _educations = [];

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _headlineController.dispose();
    _aboutController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No user logged in');

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) throw Exception('User document not found');

      if (mounted) {
        setState(() {
          userData = doc.data();
          isLoading = false;

          _nameController.text = _safe('name');
          _headlineController.text = _safe('headline');
          _aboutController.text = _safe('about');
          _locationController.text = _safe('location');
          _phoneController.text = _safe('phone_number');
          _currentProfileUrl = _safe('profilePictureUrl');
          _currentCoverUrl = _safe('coverPhotoUrl');

          _experiences = _safeList('experience');
          _educations = _safeList('education');
        });
      }
    } catch (e) {
      debugPrint('Load error: $e');
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ─── Cloudinary Upload ───
  Future<String?> _uploadToCloudinary(File imageFile, String folder) async {
    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
      );

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset
        ..fields['folder'] = folder
        ..files.add(
          await http.MultipartFile.fromPath('file', imageFile.path),
        );

      final response = await request.send();
      final responseData = await response.stream.toBytes();
      final jsonResponse = json.decode(String.fromCharCodes(responseData));

      debugPrint('Cloudinary response [$folder]: ${response.statusCode} → $jsonResponse');

      if (response.statusCode == 200) {
        return jsonResponse['secure_url'] as String;
      } else {
        debugPrint('Cloudinary error: ${jsonResponse['error']['message']}');
        return null;
      }
    } catch (e) {
      debugPrint('Upload error: $e');
      return null;
    }
  }

  // ─── Profile Image ───
  Future<void> _pickAndUploadProfileImage() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (file == null) return;

    setState(() {
      _profileImageFile = File(file.path);
      _isUploadingProfile = true;
    });

    final url = await _uploadToCloudinary(_profileImageFile!, 'profile_pictures');

    if (mounted) {
      setState(() {
        if (url != null) _currentProfileUrl = url;
        _isUploadingProfile = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        url != null
            ? const SnackBar(
                content: Text('Profile picture uploaded'),
                backgroundColor: Colors.green,
              )
            : const SnackBar(
                content: Text('Failed to upload profile picture'),
                backgroundColor: Colors.red,
              ),
      );
    }
  }

  // ─── Cover Image ───
  Future<void> _pickAndUploadCoverImage() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
      maxHeight: 600,
    );
    if (file == null) return;

    setState(() {
      _coverImageFile = File(file.path);
      _isUploadingCover = true;
    });

    final url = await _uploadToCloudinary(_coverImageFile!, 'cover_photos');

    if (mounted) {
      setState(() {
        if (url != null) _currentCoverUrl = url;
        _isUploadingCover = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        url != null
            ? const SnackBar(
                content: Text('Cover photo uploaded'),
                backgroundColor: Colors.green,
              )
            : const SnackBar(
                content: Text('Failed to upload cover photo'),
                backgroundColor: Colors.red,
              ),
      );
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    // Block save if either image is still uploading
    if (_isUploadingProfile || _isUploadingCover) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for images to finish uploading'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No user logged in');

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'name': _nameController.text.trim(),
        'headline': _headlineController.text.trim(),
        'about': _aboutController.text.trim(),
        'location': _locationController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'profilePictureUrl': _currentProfileUrl ?? _safe('profilePictureUrl'),
        'coverPhotoUrl': _currentCoverUrl ?? _safe('coverPhotoUrl'),
        'experience': _experiences,
        'education': _educations,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  // ─── Helpers ───
  String _safe(String key, {String fallback = ''}) {
    final val = userData?[key]?.toString().trim();
    return (val != null && val.isNotEmpty) ? val : fallback;
  }

  List<Map<String, dynamic>> _safeList(String key) {
    final list = userData?[key];
    if (list == null || list is! List) return [];
    return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  // ─── UI ───
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.brandRed)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Profile', style: GoogleFonts.cormorantGaramond(fontSize: 24)),
        actions: [
          if (isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Save',
              onPressed: _saveChanges,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Photos', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),

            // ─── Profile Picture ───
            Row(
              children: [
                GestureDetector(
                  onTap: _isUploadingProfile ? null : _pickAndUploadProfileImage,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: AppColors.borderSubtle,
                        child: _profileImageFile != null
                            ? ClipOval(
                                child: Image.file(
                                  _profileImageFile!,
                                  fit: BoxFit.cover,
                                  width: 100,
                                  height: 100,
                                ),
                              )
                            : (_currentProfileUrl != null && _currentProfileUrl!.isNotEmpty
                                ? ClipOval(
                                    child: CachedNetworkImage(
                                      imageUrl: _currentProfileUrl!,
                                      fit: BoxFit.cover,
                                      width: 100,
                                      height: 100,
                                      placeholder: (context, url) =>
                                          const CircularProgressIndicator(),
                                      errorWidget: (context, url, error) =>
                                          const Icon(Icons.error, color: Colors.red),
                                    ),
                                  )
                                : const Icon(Icons.person, size: 60, color: AppColors.brandRed)),
                      ),
                      if (_isUploadingProfile)
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withOpacity(0.4),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Profile Picture',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        _isUploadingProfile ? 'Uploading...' : 'Tap to change',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: _isUploadingProfile ? AppColors.brandRed : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ─── Cover Photo ───
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cover Photo', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _isUploadingCover ? null : _pickAndUploadCoverImage,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        height: 160,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderSubtle),
                          color: Colors.grey.shade100,
                          image: _coverImageFile != null
                              ? DecorationImage(
                                  image: FileImage(_coverImageFile!),
                                  fit: BoxFit.cover,
                                )
                              : (_currentCoverUrl != null && _currentCoverUrl!.isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage(_currentCoverUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null),
                        ),
                        child: _coverImageFile == null &&
                                (_currentCoverUrl == null || _currentCoverUrl!.isEmpty)
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_photo_alternate_outlined,
                                        size: 48,
                                        color: AppColors.brandRed.withOpacity(0.6)),
                                    const SizedBox(height: 8),
                                    Text('Tap to set cover photo',
                                        style: GoogleFonts.inter(color: Colors.grey)),
                                  ],
                                ),
                              )
                            : null,
                      ),

                      // Upload overlay
                      if (_isUploadingCover)
                        Container(
                          height: 160,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.black.withOpacity(0.45),
                          ),
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(color: Colors.white),
                                SizedBox(height: 12),
                                Text(
                                  'Uploading cover photo...',
                                  style: TextStyle(color: Colors.white, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Edit badge (bottom right)
                      if (!_isUploadingCover)
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.edit, color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text('Change',
                                    style: TextStyle(color: Colors.white, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ─── Basic Info ───
            Text('Basic Information',
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                  labelText: 'Full Name', border: OutlineInputBorder()),
              validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _headlineController,
              decoration: const InputDecoration(
                  labelText: 'Headline', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                  labelText: 'Location', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                  labelText: 'Phone Number', border: OutlineInputBorder()),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 32),

            // ─── About ───
            Text('About Me',
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _aboutController,
              maxLines: 6,
              maxLength: 1500,
              decoration: const InputDecoration(
                labelText: 'Tell your story (200–1500 characters)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 40),

            // ─── Experience ───
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Experience',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600)),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: AppColors.brandRed),
                  onPressed: _addExperience,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_experiences.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No experience added yet',
                    style: TextStyle(color: Colors.grey)),
              ),
            ..._experiences
                .asMap()
                .entries
                .map((entry) => _buildExperienceEditTile(entry.key, entry.value)),
            const SizedBox(height: 32),

            // ─── Education ───
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Education',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600)),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: AppColors.brandRed),
                  onPressed: _addEducation,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_educations.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No education added yet',
                    style: TextStyle(color: Colors.grey)),
              ),
            ..._educations
                .asMap()
                .entries
                .map((entry) => _buildEducationEditTile(entry.key, entry.value)),

            const SizedBox(height: 80),

            // ─── Save Button ───
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Save Profile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: (isSaving || _isUploadingProfile || _isUploadingCover)
                  ? null
                  : _saveChanges,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildExperienceEditTile(int index, Map<String, dynamic> exp) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Experience #${index + 1}',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => setState(() => _experiences.removeAt(index)),
                ),
              ],
            ),
            TextFormField(
              initialValue: exp['title']?.toString() ?? '',
              decoration: const InputDecoration(labelText: 'Job Title'),
              onChanged: (v) => _experiences[index]['title'] = v,
            ),
            TextFormField(
              initialValue: exp['company']?.toString() ?? '',
              decoration: const InputDecoration(labelText: 'Company'),
              onChanged: (v) => _experiences[index]['company'] = v,
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue:
                        exp['start'] != null ? _formatDate(exp['start']) : '',
                    decoration:
                        const InputDecoration(labelText: 'Start (yyyy-MM)'),
                    onChanged: (v) {
                      try {
                        _experiences[index]['start'] =
                            Timestamp.fromDate(DateTime.parse('$v-01'));
                      } catch (_) {}
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue:
                        exp['end'] != null ? _formatDate(exp['end']) : '',
                    decoration: const InputDecoration(
                        labelText: 'End (yyyy-MM or blank)'),
                    onChanged: (v) {
                      if (v.trim().isEmpty) {
                        _experiences[index].remove('end');
                      } else {
                        try {
                          _experiences[index]['end'] =
                              Timestamp.fromDate(DateTime.parse('$v-01'));
                        } catch (_) {}
                      }
                    },
                  ),
                ),
              ],
            ),
            TextFormField(
              initialValue: exp['location']?.toString() ?? '',
              decoration: const InputDecoration(labelText: 'Location'),
              onChanged: (v) => _experiences[index]['location'] = v,
            ),
            TextFormField(
              initialValue: exp['description']?.toString() ?? '',
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description'),
              onChanged: (v) => _experiences[index]['description'] = v,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEducationEditTile(int index, Map<String, dynamic> edu) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Education #${index + 1}',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => setState(() => _educations.removeAt(index)),
                ),
              ],
            ),
            TextFormField(
              initialValue: edu['degree']?.toString() ?? '',
              decoration: const InputDecoration(labelText: 'Degree'),
              onChanged: (v) => _educations[index]['degree'] = v,
            ),
            TextFormField(
              initialValue: edu['school']?.toString() ?? '',
              decoration:
                  const InputDecoration(labelText: 'School / University'),
              onChanged: (v) => _educations[index]['school'] = v,
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue:
                        edu['start'] != null ? _formatDate(edu['start']) : '',
                    decoration:
                        const InputDecoration(labelText: 'Start (yyyy-MM)'),
                    onChanged: (v) {
                      try {
                        _educations[index]['start'] =
                            Timestamp.fromDate(DateTime.parse('$v-01'));
                      } catch (_) {}
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue:
                        edu['end'] != null ? _formatDate(edu['end']) : '',
                    decoration:
                        const InputDecoration(labelText: 'End (yyyy-MM)'),
                    onChanged: (v) {
                      try {
                        _educations[index]['end'] =
                            Timestamp.fromDate(DateTime.parse('$v-01'));
                      } catch (_) {}
                    },
                  ),
                ),
              ],
            ),
            TextFormField(
              initialValue: edu['fieldOfStudy']?.toString() ?? '',
              decoration: const InputDecoration(labelText: 'Field of Study'),
              onChanged: (v) => _educations[index]['fieldOfStudy'] = v,
            ),
            TextFormField(
              initialValue: edu['grade']?.toString() ?? '',
              decoration:
                  const InputDecoration(labelText: 'Grade / Honors (optional)'),
              onChanged: (v) => _educations[index]['grade'] = v,
            ),
          ],
        ),
      ),
    );
  }

  void _addExperience() {
    setState(() {
      _experiences.add({
        'title': '',
        'company': '',
        'start': Timestamp.now(),
        'end': null,
        'location': '',
        'description': '',
      });
    });
  }

  void _addEducation() {
    setState(() {
      _educations.add({
        'degree': '',
        'school': '',
        'start': Timestamp.now(),
        'end': Timestamp.now(),
        'fieldOfStudy': '',
        'grade': '',
      });
    });
  }

  String _formatDate(dynamic value) {
    if (value == null) return '';
    DateTime? date =
        value is Timestamp ? value.toDate() : DateTime.tryParse(value.toString());
    return date != null ? DateFormat('yyyy-MM').format(date) : '';
  }
}