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
  final _batchYearController = TextEditingController();
  final _courseController = TextEditingController();
  final _skillsController = TextEditingController();

  // Date of Birth
  DateTime? _dateOfBirth;

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
  List<String> _skills = [];

  // Verified fields flags
  bool _batchVerified = false;
  bool _courseVerified = false;

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
    _batchYearController.dispose();
    _courseController.dispose();
    _skillsController.dispose();
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
          _batchYearController.text = _safe('batch_year');
          _courseController.text = _safe('course');
          _currentProfileUrl = _safe('profilePictureUrl');
          _currentCoverUrl = _safe('coverPhotoUrl');

          _batchVerified = userData?['batch_verified'] == true;
          _courseVerified = userData?['course_verified'] == true;

          // Date of birth
          final dob = userData?['date_of_birth'];
          if (dob is Timestamp) {
            _dateOfBirth = dob.toDate();
          }

          // Skills
          final rawSkills = userData?['skills'];
          if (rawSkills is List) {
            _skills = rawSkills.map((e) => e.toString()).toList();
          }

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

      debugPrint('Cloudinary response [$folder]: ${response.statusCode}');

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
            ? const SnackBar(content: Text('Profile picture uploaded'), backgroundColor: Colors.green)
            : const SnackBar(content: Text('Failed to upload profile picture'), backgroundColor: Colors.red),
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
            ? const SnackBar(content: Text('Cover photo uploaded'), backgroundColor: Colors.green)
            : const SnackBar(content: Text('Failed to upload cover photo'), backgroundColor: Colors.red),
      );
    }
  }

  // ─── Date of Birth Picker ───
  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 25),
      firstDate: DateTime(1940),
      lastDate: DateTime(now.year - 15),
      helpText: 'Select Date of Birth',
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.brandRed),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: AppColors.brandRed),
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null && mounted) {
      setState(() => _dateOfBirth = picked);
    }
  }

  // ─── Skills ───
  void _addSkill(String skill) {
    final trimmed = skill.trim();
    if (trimmed.isEmpty) return;
    if (_skills.length >= 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 20 skills allowed'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_skills.any((s) => s.toLowerCase() == trimmed.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Skill already added'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() => _skills.add(trimmed));
    _skillsController.clear();
  }

  void _removeSkill(int index) {
    setState(() => _skills.removeAt(index));
  }

  // ─── Validators ───
  String? _validateName(String? v) {
    final val = v?.trim() ?? '';
    if (val.isEmpty) return 'Full name is required';
    if (val.length < 2) return 'Name must be at least 2 characters';
    if (val.length > 100) return 'Name must be under 100 characters';
    if (!RegExp(r"^[a-zA-Z\s\-'.]+$").hasMatch(val)) {
      return 'Name can only contain letters, spaces, hyphens, and apostrophes';
    }
    return null;
  }

  String? _validateHeadline(String? v) {
    final val = v?.trim() ?? '';
    if (val.isEmpty) return null;
    if (val.length > 220) return 'Headline must be under 220 characters';
    return null;
  }

  String? _validateAbout(String? v) {
    final val = v?.trim() ?? '';
    if (val.isEmpty) return null;
    if (val.length < 10) return 'About must be at least 10 characters if filled';
    if (val.length > 1500) return 'About must be under 1500 characters';
    return null;
  }

  String? _validateLocation(String? v) {
    final val = v?.trim() ?? '';
    if (val.isEmpty) return null;
    if (val.length > 100) return 'Location must be under 100 characters';
    if (!RegExp(r"^[a-zA-Z0-9\s\-',./]+$").hasMatch(val)) {
      return 'Location contains invalid characters';
    }
    return null;
  }

  String? _validatePhone(String? v) {
    final val = v?.trim() ?? '';
    if (val.isEmpty) return null;
    final digitsOnly = val.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    if (!RegExp(r'^\d+$').hasMatch(digitsOnly)) {
      return 'Phone number can only contain digits, spaces, +, -, ()';
    }
    if (digitsOnly.length < 7) return 'Phone number is too short';
    if (digitsOnly.length > 15) return 'Phone number is too long';
    return null;
  }

  String? _validateBatchYear(String? v) {
    final val = v?.trim() ?? '';
    if (val.isEmpty) return null;
    final year = int.tryParse(val);
    if (year == null) return 'Enter a valid year (e.g. 2018)';
    final now = DateTime.now();
    if (year < 1950) return 'Year must be 1950 or later';
    if (year > now.year) return 'Year cannot be in the future';
    return null;
  }

  String? _validateCourse(String? v) {
    final val = v?.trim() ?? '';
    if (val.isEmpty) return null;
    if (val.length > 100) return 'Course must be under 100 characters';
    return null;
  }

  String? _validateJobTitle(String? v) {
    final val = v?.trim() ?? '';
    if (val.isEmpty) return 'Job title is required';
    if (val.length > 100) return 'Job title must be under 100 characters';
    return null;
  }

  String? _validateCompany(String? v) {
    final val = v?.trim() ?? '';
    if (val.isEmpty) return 'Company name is required';
    if (val.length > 100) return 'Company must be under 100 characters';
    return null;
  }

  String? _validateDateField(String? v, {bool required = false}) {
    final val = v?.trim() ?? '';
    if (val.isEmpty) return required ? 'Date is required' : null;
    if (!RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(val)) {
      return 'Use format yyyy-MM (e.g. 2020-06)';
    }
    final parts = val.split('-');
    final year = int.tryParse(parts[0]) ?? 0;
    final now = DateTime.now();
    if (year < 1950) return 'Year must be 1950 or later';
    if (year > now.year) return 'Year cannot be in the future';
    return null;
  }

  String? _validateEndDate(String? v, String startVal) {
    final val = v?.trim() ?? '';
    if (val.isEmpty) return null;
    final dateError = _validateDateField(val);
    if (dateError != null) return dateError;
    if (startVal.isNotEmpty &&
        RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(startVal)) {
      try {
        final start = DateTime.parse('$startVal-01');
        final end = DateTime.parse('$val-01');
        if (end.isBefore(start)) return 'End date must be after start date';
      } catch (_) {}
    }
    return null;
  }

  String? _validateDegree(String? v) {
    final val = v?.trim() ?? '';
    if (val.isEmpty) return 'Degree is required';
    if (val.length > 100) return 'Degree must be under 100 characters';
    return null;
  }

  String? _validateSchool(String? v) {
    final val = v?.trim() ?? '';
    if (val.isEmpty) return 'School name is required';
    if (val.length > 150) return 'School name must be under 150 characters';
    return null;
  }

  bool _validateExperienceDates() {
    for (int i = 0; i < _experiences.length; i++) {
      final exp = _experiences[i];
      final start = exp['_startText']?.toString().trim() ?? _formatDate(exp['start']);
      final end = exp['_endText']?.toString().trim() ?? _formatDate(exp['end']);
      if (start.isNotEmpty && end.isNotEmpty) {
        try {
          final s = DateTime.parse('$start-01');
          final e = DateTime.parse('$end-01');
          if (e.isBefore(s)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Experience #${i + 1}: End date must be after start date'),
                backgroundColor: Colors.red,
              ),
            );
            return false;
          }
        } catch (_) {}
      }
    }
    return true;
  }

  bool _validateEducationDates() {
    for (int i = 0; i < _educations.length; i++) {
      final edu = _educations[i];
      final start = edu['_startText']?.toString().trim() ?? _formatDate(edu['start']);
      final end = edu['_endText']?.toString().trim() ?? _formatDate(edu['end']);
      if (start.isNotEmpty && end.isNotEmpty) {
        try {
          final s = DateTime.parse('$start-01');
          final e = DateTime.parse('$end-01');
          if (e.isBefore(s)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Education #${i + 1}: End date must be after start date'),
                backgroundColor: Colors.red,
              ),
            );
            return false;
          }
        } catch (_) {}
      }
    }
    return true;
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fix the errors before saving'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_validateExperienceDates()) return;
    if (!_validateEducationDates()) return;

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

      final cleanExperiences = _experiences.map((e) {
        final copy = Map<String, dynamic>.from(e);
        copy.remove('_startText');
        copy.remove('_endText');
        return copy;
      }).toList();

      final cleanEducations = _educations.map((e) {
        final copy = Map<String, dynamic>.from(e);
        copy.remove('_startText');
        copy.remove('_endText');
        return copy;
      }).toList();

      final Map<String, dynamic> updates = {
        'name': _nameController.text.trim(),
        'headline': _headlineController.text.trim(),
        'about': _aboutController.text.trim(),
        'location': _locationController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'profilePictureUrl': _currentProfileUrl ?? _safe('profilePictureUrl'),
        'coverPhotoUrl': _currentCoverUrl ?? _safe('coverPhotoUrl'),
        'experience': cleanExperiences,
        'education': cleanEducations,
        'skills': _skills,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Batch year — only save if not verified
      if (!_batchVerified) {
        updates['batch_year'] = _batchYearController.text.trim();
      }

      // Course — only save if not verified
      if (!_courseVerified) {
        updates['course'] = _courseController.text.trim();
      }

      // Date of birth
      if (_dateOfBirth != null) {
        updates['date_of_birth'] = Timestamp.fromDate(_dateOfBirth!);
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update(updates);

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

    final email = FirebaseAuth.instance.currentUser?.email ?? '—';

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Profile', style: GoogleFonts.cormorantGaramond(fontSize: 24)),
        actions: [
          if (isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
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

            // ─── PHOTOS ───
            _sectionHeader('Photos'),
            const SizedBox(height: 16),

            // Profile Picture
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
                            ? ClipOval(child: Image.file(_profileImageFile!, fit: BoxFit.cover, width: 100, height: 100))
                            : (_currentProfileUrl != null && _currentProfileUrl!.isNotEmpty
                                ? ClipOval(
                                    child: CachedNetworkImage(
                                      imageUrl: _currentProfileUrl!,
                                      fit: BoxFit.cover,
                                      width: 100,
                                      height: 100,
                                      placeholder: (context, url) => const CircularProgressIndicator(),
                                      errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.red),
                                    ),
                                  )
                                : const Icon(Icons.person, size: 60, color: AppColors.brandRed)),
                      ),
                      if (_isUploadingProfile)
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withOpacity(0.4)),
                          child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Profile Picture', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        _isUploadingProfile ? 'Uploading...' : 'Tap to change',
                        style: GoogleFonts.inter(fontSize: 13, color: _isUploadingProfile ? AppColors.brandRed : Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Cover Photo
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
                          ? DecorationImage(image: FileImage(_coverImageFile!), fit: BoxFit.cover)
                          : (_currentCoverUrl != null && _currentCoverUrl!.isNotEmpty
                              ? DecorationImage(image: NetworkImage(_currentCoverUrl!), fit: BoxFit.cover)
                              : null),
                    ),
                    child: _coverImageFile == null && (_currentCoverUrl == null || _currentCoverUrl!.isEmpty)
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined, size: 48, color: AppColors.brandRed.withOpacity(0.6)),
                                const SizedBox(height: 8),
                                Text('Tap to set cover photo', style: GoogleFonts.inter(color: Colors.grey)),
                              ],
                            ),
                          )
                        : null,
                  ),
                  if (_isUploadingCover)
                    Container(
                      height: 160,
                      width: double.infinity,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.black.withOpacity(0.45)),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 12),
                            Text('Uploading cover photo...', style: TextStyle(color: Colors.white, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  if (!_isUploadingCover)
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(20)),
                        child: const Row(
                          children: [
                            Icon(Icons.edit, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text('Change', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ─── BASIC INFO ───
            _sectionHeader('Basic Information'),
            const SizedBox(height: 12),

            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name *',
                border: OutlineInputBorder(),
                helperText: 'Letters, spaces, hyphens and apostrophes only',
              ),
              validator: _validateName,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _headlineController,
              decoration: const InputDecoration(
                labelText: 'Headline / Tagline',
                border: OutlineInputBorder(),
                helperText: 'e.g. Software Engineer at TechCorp (max 220 chars)',
                counterText: '',
              ),
              maxLength: 220,
              validator: _validateHeadline,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location / City',
                border: OutlineInputBorder(),
                helperText: 'e.g. Cebu City, Philippines',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              validator: _validateLocation,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Contact Number',
                border: OutlineInputBorder(),
                helperText: 'e.g. +639392265335 (with country code)',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
              validator: _validatePhone,
            ),
            const SizedBox(height: 16),

            // Email — read only
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade400),
                color: Colors.grey.shade100,
              ),
              child: Row(
                children: [
                  const Icon(Icons.email_outlined, color: Colors.grey, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Email', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 2),
                        Text(email, style: GoogleFonts.inter(fontSize: 15, color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
                    child: Text('Read only', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'Email is managed via Firebase Auth. Use account settings to change it.',
                style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 32),

            // ─── ALUMNI INFO ───
            _sectionHeader('Alumni Information'),
            const SizedBox(height: 12),

            // Batch Year
            TextFormField(
              controller: _batchYearController,
              enabled: !_batchVerified,
              decoration: InputDecoration(
                labelText: 'Batch / Graduation Year',
                border: const OutlineInputBorder(),
                helperText: _batchVerified ? 'Verified — cannot be changed' : 'e.g. 2018 (Class of 2018)',
                prefixIcon: const Icon(Icons.school_outlined),
                suffixIcon: _batchVerified
                    ? const Icon(Icons.verified, color: Colors.green)
                    : null,
                fillColor: _batchVerified ? Colors.grey.shade100 : null,
                filled: _batchVerified,
              ),
              keyboardType: TextInputType.number,
              validator: _validateBatchYear,
            ),
            const SizedBox(height: 16),

            // Course / Degree
            TextFormField(
              controller: _courseController,
              enabled: !_courseVerified,
              decoration: InputDecoration(
                labelText: 'Course / Degree',
                border: const OutlineInputBorder(),
                helperText: _courseVerified ? 'Verified — cannot be changed' : 'e.g. BS Computer Science',
                prefixIcon: const Icon(Icons.menu_book_outlined),
                suffixIcon: _courseVerified
                    ? const Icon(Icons.verified, color: Colors.green)
                    : null,
                fillColor: _courseVerified ? Colors.grey.shade100 : null,
                filled: _courseVerified,
              ),
              textCapitalization: TextCapitalization.words,
              validator: _validateCourse,
            ),
            const SizedBox(height: 32),

            // ─── DATE OF BIRTH ───
            _sectionHeader('Personal'),
            const SizedBox(height: 12),

            GestureDetector(
              onTap: _pickDateOfBirth,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cake_outlined, color: Colors.grey, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Date of Birth', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 2),
                          Text(
                            _dateOfBirth != null
                                ? DateFormat('MMMM dd, yyyy').format(_dateOfBirth!)
                                : 'Tap to select',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              color: _dateOfBirth != null ? Colors.black87 : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.edit_outlined, color: Colors.grey, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'Used for reunion suggestions. Kept private.',
                style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 32),

            // ─── ABOUT ───
            _sectionHeader('About Me'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _aboutController,
              maxLines: 6,
              maxLength: 1500,
              decoration: const InputDecoration(
                labelText: 'Tell your story',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
                helperText: 'Optional — 200–1500 characters: career, interests, etc.',
              ),
              validator: _validateAbout,
            ),
            const SizedBox(height: 32),

            // ─── SKILLS ───
            _sectionHeader('Skills / Interests'),
            const SizedBox(height: 4),
            Text('Add up to 20 skills or interests', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),

            // Skills input
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _skillsController,
                    decoration: const InputDecoration(
                      labelText: 'Add a skill',
                      border: OutlineInputBorder(),
                      helperText: 'e.g. Flutter, Project Management',
                    ),
                    textCapitalization: TextCapitalization.words,
                    onFieldSubmitted: _addSkill,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => _addSkill(_skillsController.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Skills chips
            if (_skills.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _skills.asMap().entries.map((entry) {
                  return Chip(
                    label: Text(entry.value, style: GoogleFonts.inter(fontSize: 13)),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => _removeSkill(entry.key),
                    backgroundColor: AppColors.brandRed.withOpacity(0.08),
                    deleteIconColor: AppColors.brandRed,
                    side: BorderSide(color: AppColors.brandRed.withOpacity(0.3)),
                  );
                }).toList(),
              ),
            const SizedBox(height: 40),

            // ─── EXPERIENCE ───
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionHeader('Experience'),
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
                child: Text('No experience added yet', style: TextStyle(color: Colors.grey)),
              ),
            ..._experiences.asMap().entries.map((entry) => _buildExperienceEditTile(entry.key, entry.value)),
            const SizedBox(height: 32),

            // ─── EDUCATION ───
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionHeader('Education'),
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
                child: Text('No education added yet', style: TextStyle(color: Colors.grey)),
              ),
            ..._educations.asMap().entries.map((entry) => _buildEducationEditTile(entry.key, entry.value)),

            const SizedBox(height: 80),

            // ─── SAVE BUTTON ───
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Save Profile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: (isSaving || _isUploadingProfile || _isUploadingCover) ? null : _saveChanges,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          title,
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      );

  Widget _buildExperienceEditTile(int index, Map<String, dynamic> exp) {
    String startText = _formatDate(exp['start']);
    String endText = _formatDate(exp['end']);

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
                Text('Experience #${index + 1}', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => setState(() => _experiences.removeAt(index)),
                ),
              ],
            ),
            TextFormField(
              initialValue: exp['title']?.toString() ?? '',
              decoration: const InputDecoration(labelText: 'Job Title *', helperText: 'Required'),
              textCapitalization: TextCapitalization.words,
              validator: _validateJobTitle,
              onChanged: (v) => _experiences[index]['title'] = v,
            ),
            TextFormField(
              initialValue: exp['company']?.toString() ?? '',
              decoration: const InputDecoration(labelText: 'Company *', helperText: 'Required'),
              textCapitalization: TextCapitalization.words,
              validator: _validateCompany,
              onChanged: (v) => _experiences[index]['company'] = v,
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: startText,
                    decoration: const InputDecoration(labelText: 'Start *', helperText: 'yyyy-MM'),
                    validator: (v) => _validateDateField(v, required: true),
                    onChanged: (v) {
                      startText = v.trim();
                      _experiences[index]['_startText'] = v.trim();
                      try {
                        _experiences[index]['start'] = Timestamp.fromDate(DateTime.parse('$v-01'));
                      } catch (_) {}
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: endText,
                    decoration: const InputDecoration(labelText: 'End', helperText: 'yyyy-MM or blank'),
                    validator: (v) => _validateEndDate(v, startText),
                    onChanged: (v) {
                      endText = v.trim();
                      _experiences[index]['_endText'] = v.trim();
                      if (v.trim().isEmpty) {
                        _experiences[index].remove('end');
                      } else {
                        try {
                          _experiences[index]['end'] = Timestamp.fromDate(DateTime.parse('$v-01'));
                        } catch (_) {}
                      }
                    },
                  ),
                ),
              ],
            ),
            TextFormField(
              initialValue: exp['location']?.toString() ?? '',
              decoration: const InputDecoration(labelText: 'Location', helperText: 'Optional'),
              validator: _validateLocation,
              onChanged: (v) => _experiences[index]['location'] = v,
            ),
            TextFormField(
              initialValue: exp['description']?.toString() ?? '',
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Description', helperText: 'Optional — max 500 characters', counterText: ''),
              validator: (v) {
                final val = v?.trim() ?? '';
                if (val.isEmpty) return null;
                if (val.length > 500) return 'Description must be under 500 characters';
                return null;
              },
              onChanged: (v) => _experiences[index]['description'] = v,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEducationEditTile(int index, Map<String, dynamic> edu) {
    String startText = _formatDate(edu['start']);
    String endText = _formatDate(edu['end']);

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
                Text('Education #${index + 1}', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => setState(() => _educations.removeAt(index)),
                ),
              ],
            ),
            TextFormField(
              initialValue: edu['degree']?.toString() ?? '',
              decoration: const InputDecoration(labelText: 'Degree *', helperText: 'e.g. Bachelor of Science'),
              textCapitalization: TextCapitalization.words,
              validator: _validateDegree,
              onChanged: (v) => _educations[index]['degree'] = v,
            ),
            TextFormField(
              initialValue: edu['school']?.toString() ?? '',
              decoration: const InputDecoration(labelText: 'School / University *', helperText: 'Required'),
              textCapitalization: TextCapitalization.words,
              validator: _validateSchool,
              onChanged: (v) => _educations[index]['school'] = v,
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: startText,
                    decoration: const InputDecoration(labelText: 'Start *', helperText: 'yyyy-MM'),
                    validator: (v) => _validateDateField(v, required: true),
                    onChanged: (v) {
                      startText = v.trim();
                      _educations[index]['_startText'] = v.trim();
                      try {
                        _educations[index]['start'] = Timestamp.fromDate(DateTime.parse('$v-01'));
                      } catch (_) {}
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: endText,
                    decoration: const InputDecoration(labelText: 'End', helperText: 'yyyy-MM'),
                    validator: (v) => _validateEndDate(v, startText),
                    onChanged: (v) {
                      endText = v.trim();
                      _educations[index]['_endText'] = v.trim();
                      try {
                        _educations[index]['end'] = Timestamp.fromDate(DateTime.parse('$v-01'));
                      } catch (_) {}
                    },
                  ),
                ),
              ],
            ),
            TextFormField(
              initialValue: edu['fieldOfStudy']?.toString() ?? '',
              decoration: const InputDecoration(labelText: 'Field of Study', helperText: 'Optional — e.g. Computer Science'),
              textCapitalization: TextCapitalization.words,
              validator: (v) {
                final val = v?.trim() ?? '';
                if (val.isEmpty) return null;
                if (val.length > 100) return 'Field of study must be under 100 characters';
                return null;
              },
              onChanged: (v) => _educations[index]['fieldOfStudy'] = v,
            ),
            TextFormField(
              initialValue: edu['grade']?.toString() ?? '',
              decoration: const InputDecoration(labelText: 'Grade / Honors', helperText: 'Optional — e.g. Cum Laude, 1.5 GWA'),
              validator: (v) {
                final val = v?.trim() ?? '';
                if (val.isEmpty) return null;
                if (val.length > 50) return 'Grade must be under 50 characters';
                return null;
              },
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
    DateTime? date = value is Timestamp ? value.toDate() : DateTime.tryParse(value.toString());
    return date != null ? DateFormat('yyyy-MM').format(date) : '';
  }
}