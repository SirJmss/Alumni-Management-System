import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class AddEventScreen extends StatefulWidget {
  const AddEventScreen({super.key});

  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();

  DateTime? _startDateTime;
  DateTime? _endDateTime;

  File? _selectedImage;
  String? _imageUrl;
  bool _isLoading = false;
  String? _userRole;

  final backgroundCream = const Color(0xFFFAF7F2);
  final textDark = const Color(0xFF1A1C35);
  final textSecondary = const Color(0xFF5F6368);
  final primaryRed = const Color(0xFFB22222);

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _userRole = doc.data()?['role'] as String? ?? 'alumni';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading role: $e'),
            backgroundColor: primaryRed,
          ),
        );
      }
    }
  }

  bool get _isModeratorOrAdmin => _userRole == 'admin' || _userRole == 'moderator';

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1024,
      maxHeight: 1024,
    );

    if (pickedFile != null && mounted) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage(File imageFile) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
      final fileName = 'event_images/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';

      final ref = FirebaseStorage.instance.ref().child(fileName);
      final uploadTask = ref.putFile(imageFile);

      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image upload failed: $e'),
            backgroundColor: primaryRed,
          ),
        );
      }
      return null;
    }
  }

  Future<void> _pickDateTime(bool isStart) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: ColorScheme.light(primary: primaryRed),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: primaryRed),
          ),
        ),
        child: child!,
      ),
    );

    if (pickedDate == null || !mounted) return;

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: ColorScheme.light(primary: primaryRed),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: primaryRed),
          ),
        ),
        child: child!,
      ),
    );

    if (pickedTime == null || !mounted) return;

    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      if (isStart) _startDateTime = combined;
      else _endDateTime = combined;
    });
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'Not set';
    return DateFormat('MMM dd, yyyy • hh:mm a').format(dt);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Start date & time is required'), backgroundColor: primaryRed),
      );
      return;
    }

    if (_endDateTime != null && _endDateTime!.isBefore(_startDateTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('End cannot be before start'), backgroundColor: primaryRed),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? uploadedImageUrl;

      if (_selectedImage != null) {
        uploadedImageUrl = await _uploadImage(_selectedImage!);
        if (uploadedImageUrl == null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('Image upload failed — event saved without image'), backgroundColor: primaryRed),
          );
        }
      }

      await FirebaseFirestore.instance.collection('events').add({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'location': _locationController.text.trim(),
        'startDate': Timestamp.fromDate(_startDateTime!),
        'endDate': _endDateTime != null ? Timestamp.fromDate(_endDateTime!) : null,
        'heroImageUrl': uploadedImageUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': FirebaseAuth.instance.currentUser?.uid,
        'createdByRole': _userRole,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event created successfully'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: primaryRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userRole == null) {
      return Scaffold(backgroundColor: backgroundCream, body: const Center(child: CircularProgressIndicator()));
    }

    if (!_isModeratorOrAdmin) {
      return Scaffold(
        backgroundColor: backgroundCream,
        appBar: AppBar(
          title: Text('Add Event', style: GoogleFonts.playfairDisplay(color: textDark)),
          backgroundColor: backgroundCream,
          foregroundColor: textDark,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'Only Administrators or Moderators can create new events.',
              style: GoogleFonts.inter(fontSize: 18, color: textSecondary, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundCream,
      appBar: AppBar(
        title: Text(
          'Create New Event',
          style: GoogleFonts.playfairDisplay(fontSize: 26, color: Colors.white),
        ),
        backgroundColor: primaryRed,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Event Details',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 28),

                _buildTextField(_titleController, 'Event Title', 'What is this event called?'),
                const SizedBox(height: 24),

                _buildTextField(_descriptionController, 'Description', 'Tell people what to expect...', maxLines: 5),
                const SizedBox(height: 24),

                _buildTextField(_locationController, 'Location', 'Campus, online link, or venue'),
                const SizedBox(height: 32),

                Text(
                  'Event Image (optional)',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: textDark),
                ),
                const SizedBox(height: 12),

                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: _selectedImage == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined, size: 48, color: Colors.grey),
                              SizedBox(height: 12),
                              Text('Tap to select image', style: TextStyle(color: Colors.grey)),
                            ],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.file(_selectedImage!, fit: BoxFit.cover),
                          ),
                  ),
                ),
                const SizedBox(height: 32),

                _buildDateTimeSelector('Start Date & Time', _startDateTime, true),
                const Divider(height: 48, thickness: 1, color: Color.fromARGB(255, 238, 238, 238)),
                _buildDateTimeSelector('End Date & Time (optional)', _endDateTime, false),

                const SizedBox(height: 48),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _submit,
                    icon: _isLoading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Icon(Icons.event_available, size: 24),
                    label: Text(
                      _isLoading ? 'Creating...' : 'Create Event',
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryRed,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, String hint, {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: GoogleFonts.inter(color: textDark),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.inter(color: primaryRed, fontWeight: FontWeight.w500),
        hintStyle: GoogleFonts.inter(color: textSecondary.withOpacity(0.7)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primaryRed, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      validator: (value) => value?.trim().isEmpty ?? true ? 'Required field' : null,
    );
  }

  Widget _buildDateTimeSelector(String label, DateTime? value, bool isStart) {
    return InkWell(
      onTap: () => _pickDateTime(isStart),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(fontSize: 14, color: textSecondary, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDateTime(value),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: value == null ? textSecondary : textDark,
                      fontWeight: value == null ? FontWeight.normal : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.edit_calendar_outlined, color: primaryRed, size: 24),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }
}