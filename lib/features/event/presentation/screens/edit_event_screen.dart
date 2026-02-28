import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class EditEventScreen extends StatefulWidget {
  final String eventId;
  final Map<String, dynamic> event;

  const EditEventScreen({super.key, required this.eventId, required this.event});

  @override
  State<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends State<EditEventScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;

  DateTime? _startDateTime;
  DateTime? _endDateTime;

  File? _newImageFile;               // new image selected locally
  String? _currentImageUrl;          // existing URL from Firestore
  bool _removeImage = false;         // flag if user wants to remove existing image
  bool _isLoading = false;

  final backgroundCream = const Color(0xFFFAF7F2);
  final textDark = const Color(0xFF1A1C35);
  final textSecondary = const Color(0xFF5F6368);
  final primaryRed = const Color(0xFFB22222);

  final ImagePicker _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(text: widget.event['title'] ?? '');
    _descriptionController = TextEditingController(text: widget.event['description'] ?? '');
    _locationController = TextEditingController(text: widget.event['location'] ?? '');

    final startTs = widget.event['startDate'] as Timestamp?;
    if (startTs != null) _startDateTime = startTs.toDate();

    final endTs = widget.event['endDate'] as Timestamp?;
    if (endTs != null) _endDateTime = endTs.toDate();

    _currentImageUrl = widget.event['heroImageUrl'] as String?;
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1024,
      maxHeight: 1024,
    );

    if (pickedFile != null && mounted) {
      setState(() {
        _newImageFile = File(pickedFile.path);
        _removeImage = false; // reset remove flag if new image is picked
      });
    }
  }

  Future<String?> _uploadImage(File imageFile) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
      final fileName = 'event_images/$userId/edit_${widget.eventId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final ref = FirebaseStorage.instance.ref().child(fileName);
      final uploadTask = ref.putFile(imageFile);

      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image upload failed: $e'), backgroundColor: primaryRed),
        );
      }
      return null;
    }
  }

  Future<void> _pickDateTime(bool isStart) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: isStart ? (_startDateTime ?? DateTime.now()) : (_endDateTime ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2035),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: ColorScheme.light(primary: primaryRed),
          textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: primaryRed)),
        ),
        child: child!,
      ),
    );

    if (pickedDate == null) return;

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(isStart ? (_startDateTime ?? DateTime.now()) : (_endDateTime ?? DateTime.now())),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: ColorScheme.light(primary: primaryRed),
          textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: primaryRed)),
        ),
        child: child!,
      ),
    );

    if (pickedTime == null) return;

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
    return dt != null ? DateFormat('MMM dd, yyyy • hh:mm a').format(dt) : 'Not set';
  }

  Future<void> _updateEvent() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Start date & time required'), backgroundColor: primaryRed),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? newImageUrl;

      // Handle image update logic
      if (_removeImage) {
        newImageUrl = null; // remove image
      } else if (_newImageFile != null) {
        newImageUrl = await _uploadImage(_newImageFile!);
        if (newImageUrl == null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('Image upload failed — keeping previous image'), backgroundColor: primaryRed),
          );
        }
      } else {
        newImageUrl = _currentImageUrl; // keep existing
      }

      final updates = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'location': _locationController.text.trim(),
        'startDate': Timestamp.fromDate(_startDateTime!),
        'updatedAt': FieldValue.serverTimestamp(),
        'heroImageUrl': newImageUrl,
      };

      if (_endDateTime != null) {
        updates['endDate'] = Timestamp.fromDate(_endDateTime!);
      }

      await FirebaseFirestore.instance.collection('events').doc(widget.eventId).update(updates);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event updated successfully'), backgroundColor: Colors.green),
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
    return Scaffold(
      backgroundColor: backgroundCream,
      appBar: AppBar(
        title: Text(
          'Edit Event',
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
                  'Update Event Details',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 28),

                _buildTextField(_titleController, 'Event Title', 'Update the event name'),
                const SizedBox(height: 24),

                _buildTextField(_descriptionController, 'Description', 'Revise the description', maxLines: 6),
                const SizedBox(height: 24),

                _buildTextField(_locationController, 'Location', 'Update venue or link'),
                const SizedBox(height: 32),

                // Image section
                Text(
                  'Event Image',
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
                    child: _newImageFile != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.file(_newImageFile!, fit: BoxFit.cover),
                          )
                        : _currentImageUrl != null && !_removeImage
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: CachedNetworkImage(
                                  imageUrl: _currentImageUrl!,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                  errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.grey),
                                ),
                              )
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate_outlined, size: 48, color: Colors.grey),
                                  SizedBox(height: 12),
                                  Text('Tap to change / upload image', style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                  ),
                ),

                if (_currentImageUrl != null && !_removeImage && _newImageFile == null) ...[
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _removeImage = true;
                        _newImageFile = null;
                      });
                    },
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                    label: const Text('Remove current image', style: TextStyle(color: Colors.redAccent)),
                  ),
                ],

                const SizedBox(height: 32),

                _buildDateTimeSelector('Start Date & Time', _startDateTime, true),
                const Divider(height: 48, thickness: 1, color: Color.fromARGB(255, 238, 238, 238)),
                _buildDateTimeSelector('End Date & Time (optional)', _endDateTime, false),

                const SizedBox(height: 48),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _updateEvent,
                    icon: _isLoading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Icon(Icons.save_outlined, size: 24),
                    label: Text(
                      _isLoading ? 'Updating...' : 'Save Changes',
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