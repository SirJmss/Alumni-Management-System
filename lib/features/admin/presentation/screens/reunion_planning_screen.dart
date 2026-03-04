import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:alumni/core/constants/app_colors.dart';

class ReunionAndEventsScreen extends StatefulWidget {
  const ReunionAndEventsScreen({super.key});

  @override
  State<ReunionAndEventsScreen> createState() => _ReunionAndEventsScreenState();
}

class _ReunionAndEventsScreenState extends State<ReunionAndEventsScreen> {
  String? selectedFilterType;
  String? selectedValue;

  final statusOptions = ['All', 'draft', 'published', 'ongoing', 'completed', 'cancelled'];
  final reunionTypeOptions = ['All', 'batch-reunion', 'grand-homecoming', 'decade-reunion', 'class-reunion'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softWhite,
      appBar: AppBar(
        backgroundColor: AppColors.cardWhite,
        elevation: 0,
        title: Text(
          'Reunions & Major Events',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 26,
            fontWeight: FontWeight.w300,
            color: AppColors.darkText,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButton<String?>(
              value: selectedFilterType,
              hint: const Text('Filter by...'),
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: null, child: Text('All Events')),
                DropdownMenuItem(value: 'status', child: Text('Status')),
                DropdownMenuItem(value: 'reunionType', child: Text('Reunion Type')),
              ],
              onChanged: (value) {
                setState(() {
                  selectedFilterType = value;
                  selectedValue = null;
                });
              },
            ),
          ),
          if (selectedFilterType != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: DropdownButton<String>(
                value: selectedValue,
                hint: Text(selectedFilterType == 'status' ? 'Select Status' : 'Select Type'),
                underline: const SizedBox(),
                items: (selectedFilterType == 'status' ? statusOptions : reunionTypeOptions)
                    .map((v) => DropdownMenuItem(value: v == 'All' ? null : v, child: Text(v)))
                    .toList(),
                onChanged: (value) => setState(() => selectedValue = value),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 24, left: 16),
            child: FilledButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New Reunion'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandRed,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () => _showEventForm(),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reunions & Major Alumni Events',
              style: GoogleFonts.cormorantGaramond(fontSize: 28, color: AppColors.darkText),
            ),
            const SizedBox(height: 4),
            Text(
              'Manage batch reunions, homecomings, and flagship gatherings',
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.mutedText),
            ),
            const SizedBox(height: 24),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _getFilteredEvents(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'Error loading events:\n${snapshot.error.toString().split('\n').first}',
                          style: const TextStyle(color: Colors.red, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.celebration_outlined, size: 80, color: Colors.grey[400]),
                          const SizedBox(height: 24),
                          Text(
                            'No matching reunions or major events found',
                            style: GoogleFonts.inter(fontSize: 18, color: Colors.grey[700]),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try changing the filter or create a new one',
                            style: GoogleFonts.inter(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final data = docs[i].data() as Map<String, dynamic>;
                      final id = docs[i].id;

                      final start = (data['startDate'] as Timestamp?)?.toDate();
                      final status = (data['status'] as String?)?.toLowerCase() ?? 'draft';
                      final type = data['type'] as String?;
                      final isReunion = type != null && type.contains('reunion');

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: ListTile(
                          leading: CircleAvatar(
                            radius: 28,
                            backgroundColor: isReunion ? AppColors.brandRed.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
                            child: Icon(
                              isReunion ? Icons.celebration : Icons.event,
                              color: isReunion ? AppColors.brandRed : Colors.blue,
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  data['title'] ?? 'No title',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                ),
                              ),
                              if (isReunion)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.brandRed.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'REUNION',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: AppColors.brandRed,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['description']?.toString() ?? 'No description',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(fontSize: 13, color: AppColors.mutedText),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  _StatusBadge(status: status),
                                  const SizedBox(width: 12),
                                  if (start != null)
                                    Text(
                                      DateFormat('MMM dd, yyyy • h:mm a').format(start),
                                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedText),
                                    ),
                                  const SizedBox(width: 12),
                                  Text(
                                    data['location'] ?? 'Not specified',
                                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedText),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (status == 'draft')
                                IconButton(
                                  icon: const Icon(Icons.publish, color: Colors.blue, size: 22),
                                  tooltip: 'Publish Event',
                                  onPressed: () => _publishEvent(id),
                                ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 22),
                                tooltip: 'Edit',
                                onPressed: () => _showEventForm(eventId: id, initialData: data),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 22, color: Colors.redAccent),
                                tooltip: 'Delete',
                                onPressed: () => _confirmDelete(id, data['title'] ?? 'this event'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Stream<QuerySnapshot> _getFilteredEvents() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('events');

    if (selectedFilterType == 'status' && selectedValue != null) {
      query = query.where('status', isEqualTo: selectedValue);
    } else if (selectedFilterType == 'reunionType' && selectedValue != null) {
      query = query.where('type', isEqualTo: selectedValue);
    } else {
      query = query.where('type', whereIn: ['batch-reunion', 'grand-homecoming', 'decade-reunion', 'class-reunion']);
    }

    return query.orderBy('startDate', descending: true).snapshots();
  }

  Widget _StatusBadge({required String status}) {
    Color color;
    switch (status.toLowerCase()) {
      case 'published':
        color = Colors.blue;
        break;
      case 'ongoing':
        color = Colors.green;
        break;
      case 'completed':
        color = Colors.grey;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.inter(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Future<void> _publishEvent(String eventId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Publish Event'),
        content: const Text('Are you sure you want to publish this event?\nIt will become visible to alumni.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Publish'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('events').doc(eventId).update({
        'status': 'published',
        'publishedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Event published successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error publishing: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showEventForm({String? eventId, Map<String, dynamic>? initialData}) {
    final isEdit = eventId != null;
    final titleCtrl = TextEditingController(text: initialData?['title'] ?? '');
    final descCtrl = TextEditingController(text: initialData?['description'] ?? '');
    final locationCtrl = TextEditingController(text: initialData?['location'] ?? '');
    final batchCtrl = TextEditingController(text: initialData?['batchYear'] ?? '');
    String selectedType = initialData?['type'] ?? 'batch-reunion';

    DateTime? startDate = (initialData?['startDate'] as Timestamp?)?.toDate();
    DateTime? endDate = (initialData?['endDate'] as Timestamp?)?.toDate();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Reunion/Event' : 'Create New Reunion/Event'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Title *'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Description', alignLabelWithHint: true),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: locationCtrl,
                    decoration: const InputDecoration(labelText: 'Location / Platform'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: batchCtrl,
                    decoration: const InputDecoration(labelText: 'Batch / Year (e.g. Batch 2015)'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: const InputDecoration(labelText: 'Event Type'),
                    items: const [
                      DropdownMenuItem(value: 'batch-reunion', child: Text('Batch Reunion')),
                      DropdownMenuItem(value: 'grand-homecoming', child: Text('Grand Homecoming')),
                      DropdownMenuItem(value: 'decade-reunion', child: Text('Decade Reunion')),
                      DropdownMenuItem(value: 'class-reunion', child: Text('Class Reunion')),
                      DropdownMenuItem(value: 'other', child: Text('Other Major Event')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedType = val);
                    },
                  ),
                  const SizedBox(height: 24),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      startDate == null ? 'Start Date & Time *' : DateFormat('MMM dd, yyyy • h:mm a').format(startDate!),
                      style: GoogleFonts.inter(fontSize: 14),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: startDate ?? DateTime.now(),
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                        );
                        if (date != null) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(startDate ?? DateTime.now()),
                          );
                          if (time != null) {
                            setDialogState(() {
                              startDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                            });
                          }
                        }
                      },
                    ),
                  ),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      endDate == null ? 'End Date & Time (optional)' : DateFormat('MMM dd, yyyy • h:mm a').format(endDate!),
                      style: GoogleFonts.inter(fontSize: 14),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: endDate ?? DateTime.now().add(const Duration(hours: 2)),
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                        );
                        if (date != null) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(endDate ?? DateTime.now()),
                          );
                          if (time != null) {
                            setDialogState(() {
                              endDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                            });
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty || startDate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Title and start date are required')),
                  );
                  return;
                }

                final data = {
                  'title': titleCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                  'location': locationCtrl.text.trim(),
                  'batchYear': batchCtrl.text.trim().isNotEmpty ? batchCtrl.text.trim() : null,
                  'type': selectedType,
                  'startDate': Timestamp.fromDate(startDate!),
                  if (endDate != null) 'endDate': Timestamp.fromDate(endDate!),
                  'updatedAt': FieldValue.serverTimestamp(),
                  if (!isEdit) ...{
                    'createdAt': FieldValue.serverTimestamp(),
                    'createdBy': FirebaseAuth.instance.currentUser?.uid,
                    'status': 'draft', // still defaults to draft
                    'registeredCount': 0,
                  },
                };

                try {
                  if (isEdit) {
                    await FirebaseFirestore.instance.collection('events').doc(eventId).update(data);
                  } else {
                    await FirebaseFirestore.instance.collection('events').add(data);
                  }

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isEdit ? 'Event updated' : 'Event created (draft)'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error saving event: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              child: Text(isEdit ? 'Update' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(String eventId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Are you sure you want to delete "$title"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('events').doc(eventId).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event deleted'), backgroundColor: Colors.green),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting event: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}