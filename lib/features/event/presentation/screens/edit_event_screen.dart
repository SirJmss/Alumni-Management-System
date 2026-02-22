import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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

  bool _isLoading = false;

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
  }

  Future<void> _pickDateTime(bool isStart) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFFE64646)),
        ),
        child: child!,
      ),
    );

    if (pickedDate == null) return;

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFFE64646)),
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
      if (isStart) {
        _startDateTime = combined;
      } else {
        _endDateTime = combined;
      }
    });
  }

  String _formatDateTime(DateTime? dt) {
    return dt != null ? DateFormat('MMM dd, yyyy • hh:mm a').format(dt) : 'Not set';
  }

  Future<void> _updateEvent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final updates = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'location': _locationController.text.trim(),
        'startDate': Timestamp.fromDate(_startDateTime!),
        'updatedAt': FieldValue.serverTimestamp(),
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
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE6D3AE),
      appBar: AppBar(
        title: const Text('Edit Event'),
        backgroundColor: const Color(0xFFE64646),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTextField(_titleController, 'Event Title', 'Update title'),
                const SizedBox(height: 24),
                _buildTextField(_descriptionController, 'Description', 'Update description', maxLines: 6),
                const SizedBox(height: 24),
                _buildTextField(_locationController, 'Location', 'Update venue or link'),
                const SizedBox(height: 32),

                _buildDateTimeTile('Start', _startDateTime, true),
                const Divider(height: 32),
                _buildDateTimeTile('End (optional)', _endDateTime, false),

                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _updateEvent,
                    icon: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                        : const Icon(Icons.save, size: 24),
                    label: Text(
                      _isLoading ? 'Updating...' : 'Save Changes',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE64646),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
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
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Color(0xFFE64646)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE64646), width: 2),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.9),
      ),
      validator: (value) => value?.trim().isEmpty ?? true ? 'This field is required' : null,
    );
  }

  Widget _buildDateTimeTile(String label, DateTime? value, bool isStart) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        '$label: ${_formatDateTime(value)}',
        style: TextStyle(color: value == null ? Colors.grey[700] : Colors.black87),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.edit_calendar, color: Color(0xFFE64646)),
        onPressed: () => _pickDateTime(isStart),
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