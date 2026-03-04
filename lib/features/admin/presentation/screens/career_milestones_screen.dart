import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:alumni/core/constants/app_colors.dart';

class CareerMilestonesScreen extends StatefulWidget {
  const CareerMilestonesScreen({super.key});

  @override
  State<CareerMilestonesScreen> createState() => _CareerMilestonesScreenState();
}

class _CareerMilestonesScreenState extends State<CareerMilestonesScreen> {
  String? selectedStatusFilter = 'pending';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softWhite,
      appBar: AppBar(
        backgroundColor: AppColors.cardWhite,
        elevation: 0,
        title: Text(
          'Career Milestones',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 26,
            fontWeight: FontWeight.w300,
            color: AppColors.darkText,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButton<String?>(
              value: selectedStatusFilter,
              hint: const Text('Filter by status'),
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: null, child: Text('All')),
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                DropdownMenuItem(value: 'approved', child: Text('Approved')),
                DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
              ],
              onChanged: (value) => setState(() => selectedStatusFilter = value),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Career Milestones Moderation',
              style: GoogleFonts.cormorantGaramond(fontSize: 28, color: AppColors.darkText),
            ),
            const SizedBox(height: 4),
            Text(
              'Review, approve or reject alumni career updates',
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.mutedText),
            ),
            const SizedBox(height: 24),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _getFilteredMilestones(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading milestones:\n${snapshot.error}',
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  final milestones = snapshot.data?.docs ?? [];

                  if (milestones.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.work_history_outlined, size: 80, color: Colors.grey[400]),
                          const SizedBox(height: 24),
                          Text(
                            'No career milestones found',
                            style: GoogleFonts.inter(fontSize: 18, color: Colors.grey[700]),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            selectedStatusFilter != null
                                ? 'No milestones with status: $selectedStatusFilter'
                                : 'Alumni can submit their career updates from their profile',
                            style: GoogleFonts.inter(fontSize: 14, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: milestones.length,
                    itemBuilder: (context, index) {
                      final doc = milestones[index];
                      final data = doc.data() as Map<String, dynamic>;

                      final date = (data['date'] as Timestamp?)?.toDate();
                      final status = (data['status'] as String?)?.toLowerCase() ?? 'pending';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          leading: CircleAvatar(
                            radius: 28,
                            backgroundColor: _getStatusColor(status).withOpacity(0.15),
                            child: Icon(Icons.workspace_premium, color: _getStatusColor(status)),
                          ),
                          title: Text(
                            data['title'] ?? 'Untitled Milestone',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${data['userName'] ?? 'Unknown Alumni'} • ${data['company'] ?? 'No company'}',
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 4),
                              if (date != null)
                                Text(
                                  DateFormat('MMM dd, yyyy').format(date),
                                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedText),
                                ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(status).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      status.toUpperCase(),
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: _getStatusColor(status),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    (data['type'] as String?)?.toUpperCase() ?? 'OTHER',
                                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedText),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (status == 'pending') ...[
                                IconButton(
                                  icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 22),
                                  tooltip: 'Approve',
                                  onPressed: () => _updateStatus(doc.id, 'approved'),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 22),
                                  tooltip: 'Reject',
                                  onPressed: () => _updateStatus(doc.id, 'rejected'),
                                ),
                              ],
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 22),
                                tooltip: 'Edit',
                                onPressed: () => _showEditForm(doc.id, data),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 22, color: Colors.redAccent),
                                tooltip: 'Delete',
                                onPressed: () => _confirmDelete(doc.id, data['title'] ?? 'this milestone'),
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

  Stream<QuerySnapshot> _getFilteredMilestones() {
    Query query = FirebaseFirestore.instance.collection('career_milestones').orderBy('date', descending: true);

    if (selectedStatusFilter != null) {
      query = query.where('status', isEqualTo: selectedStatusFilter);
    }

    return query.snapshots();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Future<void> _updateStatus(String milestoneId, String newStatus) async {
    final action = newStatus == 'approved' ? 'approve' : 'reject';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${action.capitalize()} Milestone'),
        content: Text('Are you sure you want to $action this career milestone?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action.capitalize(), style: TextStyle(color: newStatus == 'approved' ? Colors.green : Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('career_milestones').doc(milestoneId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        if (newStatus == 'approved') ...{
          'approvedBy': FirebaseAuth.instance.currentUser?.uid,
          'approvedAt': FieldValue.serverTimestamp(),
        },
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Milestone ${newStatus == 'approved' ? 'approved' : 'rejected'}'),
          backgroundColor: newStatus == 'approved' ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showEditForm(String milestoneId, Map<String, dynamic> initialData) {
    final titleCtrl = TextEditingController(text: initialData['title'] ?? '');
    final companyCtrl = TextEditingController(text: initialData['company'] ?? '');
    final descCtrl = TextEditingController(text: initialData['description'] ?? '');
    String selectedType = initialData['type'] ?? 'promotion';

    DateTime? milestoneDate = (initialData['date'] as Timestamp?)?.toDate();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Career Milestone'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Milestone Title *'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: companyCtrl,
                    decoration: const InputDecoration(labelText: 'Company / Organization'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Description', alignLabelWithHint: true),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    decoration: const InputDecoration(labelText: 'Milestone Type'),
                    items: const [
                      DropdownMenuItem(value: 'promotion', child: Text('Promotion')),
                      DropdownMenuItem(value: 'new_job', child: Text('New Job')),
                      DropdownMenuItem(value: 'award', child: Text('Award / Recognition')),
                      DropdownMenuItem(value: 'certification', child: Text('Certification / Degree')),
                      DropdownMenuItem(value: 'retirement', child: Text('Retirement')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedType = val);
                    },
                  ),
                  const SizedBox(height: 24),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      milestoneDate == null ? 'Date *' : DateFormat('MMM dd, yyyy').format(milestoneDate!),
                      style: GoogleFonts.inter(fontSize: 14),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: milestoneDate ?? DateTime.now(),
                          firstDate: DateTime(1990),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setDialogState(() => milestoneDate = date);
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
                if (titleCtrl.text.trim().isEmpty || milestoneDate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Title and date are required')),
                  );
                  return;
                }

                final data = {
                  'title': titleCtrl.text.trim(),
                  'company': companyCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                  'type': selectedType,
                  'date': Timestamp.fromDate(milestoneDate!),
                  'updatedAt': FieldValue.serverTimestamp(),
                };

                try {
                  await FirebaseFirestore.instance.collection('career_milestones').doc(milestoneId).update(data);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Milestone updated'), backgroundColor: Colors.green),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(String milestoneId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Milestone'),
        content: Text('Are you sure you want to delete "$title"?\nThis cannot be undone.'),
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
        await FirebaseFirestore.instance.collection('career_milestones').doc(milestoneId).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Milestone deleted'), backgroundColor: Colors.green),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

// Add this extension at the bottom of the file
extension StringExtension on String {
  String capitalize() {
    return isEmpty ? this : "${this[0].toUpperCase()}${substring(1)}";
  }
}