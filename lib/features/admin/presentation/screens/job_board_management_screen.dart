import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:alumni/core/constants/app_colors.dart'; // adjust import if needed

class JobBoardManagementScreen extends StatefulWidget {
  const JobBoardManagementScreen({super.key});

  @override
  State<JobBoardManagementScreen> createState() => _JobBoardManagementScreenState();
}

class _JobBoardManagementScreenState extends State<JobBoardManagementScreen> {
  String? selectedStatusFilter; // for optional filter: all, pending, approved, rejected

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softWhite,
      appBar: AppBar(
        backgroundColor: AppColors.cardWhite,
        elevation: 0,
        title: Text(
          'Job Board Management',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 26,
            fontWeight: FontWeight.w300,
            color: AppColors.darkText,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: DropdownButton<String>(
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
              'Job Postings',
              style: GoogleFonts.cormorantGaramond(fontSize: 24, color: AppColors.darkText),
            ),
            const SizedBox(height: 8),
            Text(
              'Review, approve, reject or manage alumni job listings',
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.mutedText),
            ),
            const SizedBox(height: 24),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _buildJobQuery(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading jobs\n${snapshot.error}',
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  final jobs = snapshot.data?.docs ?? [];

                  if (jobs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.work_off, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            'No job postings yet',
                            style: GoogleFonts.inter(fontSize: 18, color: Colors.grey[700]),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Alumni can post jobs from their profile or mobile app',
                            style: GoogleFonts.inter(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: jobs.length,
                    itemBuilder: (context, index) {
                      final doc = jobs[index];
                      final data = doc.data() as Map<String, dynamic>;

                      final postedAt = (data['postedAt'] as Timestamp?)?.toDate();
                      final status = data['status'] as String? ?? 'pending';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          leading: CircleAvatar(
                            radius: 28,
                            backgroundColor: _getStatusColor(status).withOpacity(0.15),
                            child: Icon(Icons.work, color: _getStatusColor(status)),
                          ),
                          title: Text(
                            data['title'] ?? 'No title',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['company'] ?? 'Unknown company',
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 4),
                              if (postedAt != null)
                                Text(
                                  'Posted ${DateFormat('MMM dd, yyyy').format(postedAt)}',
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
                                    data['location'] ?? 'Remote / Not specified',
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
                                  onPressed: () => _updateJobStatus(doc.id, 'approved'),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 22),
                                  tooltip: 'Reject',
                                  onPressed: () => _updateJobStatus(doc.id, 'rejected'),
                                ),
                              ],
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 22),
                                tooltip: 'Edit',
                                onPressed: () => _showEditJobDialog(doc.id, data),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 22, color: Colors.redAccent),
                                tooltip: 'Delete',
                                onPressed: () => _confirmDeleteJob(doc.id, data['title'] ?? 'this job'),
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

  Stream<QuerySnapshot> _buildJobQuery() {
    Query query = FirebaseFirestore.instance.collection('job_postings').orderBy('postedAt', descending: true);

    if (selectedStatusFilter != null) {
      query = query.where('status', isEqualTo: selectedStatusFilter);
    }

    return query.snapshots();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'expired':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  Future<void> _updateJobStatus(String jobId, String newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('job_postings').doc(jobId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        if (newStatus == 'approved') 'approvedBy': FirebaseAuth.instance.currentUser?.uid,
        if (newStatus == 'approved') 'approvedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Job marked as $newStatus'),
            backgroundColor: newStatus == 'approved' ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showEditJobDialog(String jobId, Map<String, dynamic> initialData) {
    final titleCtrl = TextEditingController(text: initialData['title'] ?? '');
    final companyCtrl = TextEditingController(text: initialData['company'] ?? '');
    final locationCtrl = TextEditingController(text: initialData['location'] ?? '');
    final descCtrl = TextEditingController(text: initialData['description'] ?? '');
    final salaryCtrl = TextEditingController(text: initialData['salaryRange'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Job Posting'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Job Title *')),
                TextField(controller: companyCtrl, decoration: const InputDecoration(labelText: 'Company *')),
                TextField(controller: locationCtrl, decoration: const InputDecoration(labelText: 'Location / Remote')),
                TextField(controller: salaryCtrl, decoration: const InputDecoration(labelText: 'Salary Range (optional)')),
                const SizedBox(height: 16),
                TextField(
                  controller: descCtrl,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Job Description', alignLabelWithHint: true),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty || companyCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Title and company are required')),
                );
                return;
              }

              try {
                await FirebaseFirestore.instance.collection('job_postings').doc(jobId).update({
                  'title': titleCtrl.text.trim(),
                  'company': companyCtrl.text.trim(),
                  'location': locationCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                  'salaryRange': salaryCtrl.text.trim().isNotEmpty ? salaryCtrl.text.trim() : null,
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Job updated'), backgroundColor: Colors.green),
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
    );
  }

  Future<void> _confirmDeleteJob(String jobId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Job Posting'),
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
        await FirebaseFirestore.instance.collection('job_postings').doc(jobId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Job deleted'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}