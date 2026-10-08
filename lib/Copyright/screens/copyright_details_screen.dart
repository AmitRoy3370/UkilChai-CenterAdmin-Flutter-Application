// lib/Copyright/screens/copyright_details_screen.dart

import 'package:flutter/material.dart';
import '../../Auth/AuthService.dart';
import '../../RJSC/screens/rjsc_attachment_viewer.dart'; // ← path adjust
import '../models/copyright_response_dto.dart';
import '../models/copyright_model.dart';
import '../services/copyright_service.dart';
import 'copyright_update_screen.dart';
import 'widgets/copyright_payment_section.dart'; // ← NEW

class CopyrightDetailsScreen extends StatefulWidget {
  final CopyrightResponseDTO copyright;
  final bool isOwner;

  const CopyrightDetailsScreen({
    super.key,
    required this.copyright,
    required this.isOwner,
  });

  @override
  State<CopyrightDetailsScreen> createState() => _CopyrightDetailsScreenState();
}

class _CopyrightDetailsScreenState extends State<CopyrightDetailsScreen> {
  late CopyrightResponseDTO _c;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _c = widget.copyright;
  }

  // ---------- Delete ----------
  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Copyright?'),
        content: const Text(
          'This action cannot be undone. Are you sure you want to delete this copyright registration?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);

    final userId = await AuthService.getUserId() ?? '';
    final res = await CopyrightService.deleteCopyright(
      id: _c.id ?? '',
      userId: userId,
    );

    if (!mounted) return;
    setState(() => _isDeleting = false);

    if (res['status'] == 'success') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copyright deleted successfully'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Failed to delete'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ---------- Edit ----------
  Future<void> _openEdit() async {
    final model = CopyrightModel(
      id: _c.id,
      userId: _c.userId,
      author: _c.author,
      typeOfWork: _c.typeOfWork,
      yearOfCreation: _c.yearOfCreation,
      titleOfWork: _c.titleOfWork,
      description: _c.description,
      applicationName: _c.userName,
      mobileNumber: _c.mobileNumber,
      email: _c.email,
      adress: _c.adress,
      documents: _c.documents,
    );

    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CopyrightUpdateScreen(existingCopyright: model),
      ),
    );

    if (changed == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  // ---------- Open document in viewer ----------
  Future<void> _openDocument(String attachmentId) async {
    final token = await AuthService.getToken() ?? '';
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black87,
          appBar: AppBar(
            backgroundColor: Colors.black87,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text(
              'Document Viewer',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          body: RJSCAttachmentViewer(
            attachmentId: attachmentId,
            jwtToken: token,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final process = _c.registrationProcess;
    final isApproved = process != null && process.status == true;
    final isPending = process == null;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          'Copyright Details',
          style: TextStyle(color: Colors.black87, fontSize: 18),
        ),
        actions: [
          if (widget.isOwner)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.black87),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              onSelected: (v) {
                if (v == 'edit') _openEdit();
                if (v == 'delete') _confirmDelete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18, color: Color(0xFF1A3FBF)),
                      SizedBox(width: 10),
                      Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline,
                          size: 18, color: Colors.red),
                      SizedBox(width: 10),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _isDeleting
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---------- Header Card ----------
                  _headerCard(isApproved, isPending),

                  const SizedBox(height: 16),

                  // ---------- Work Info ----------
                  _section(
                    title: 'Work Information',
                    children: [
                      _infoRow('Author / Creator', _c.author),
                      _infoRow('Type of Work', _c.typeOfWork),
                      _infoRow('Year of Creation',
                          _c.yearOfCreation.year.toString()),
                      _infoRow('Description', _c.description),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ---------- Applicant Info ----------
                  _section(
                    title: 'Applicant Information',
                    children: [
                      _infoRow('Name', _c.userName),
                      _infoRow('Mobile', _c.mobileNumber),
                      _infoRow('Email', _c.email),
                      _infoRow('Address', _c.adress),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ---------- Documents (with viewer) ----------
                  _section(
                    title: 'Documents',
                    children: [
                      if (_c.documents.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Icon(Icons.folder_off_outlined,
                                  color: Colors.grey.shade400, size: 20),
                              const SizedBox(width: 8),
                              Text('No documents uploaded',
                                  style:
                                      TextStyle(color: Colors.grey.shade600)),
                            ],
                          ),
                        )
                      else
                        ..._c.documents.asMap().entries.map((e) {
                          return _documentTile(
                            index: e.key + 1,
                            attachmentId: e.value,
                            onTap: () => _openDocument(e.value),
                          );
                        }),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ---------- Application Status ----------
                  _section(
                    title: 'Application Status',
                    children: [
                      if (isPending)
                        _infoRow('Status', 'Pending Review')
                      else if (process != null) ...[
                        _infoRow('Status',
                            process.status == true ? 'Approved' : 'Processing'),
                        if (process.advocateName.isNotEmpty)
                          _infoRow('Assigned Advocate', process.advocateName),
                        if (process.stpes.isNotEmpty)
                          _infoRow('Progress', process.stpes.join(' → ')),
                      ],
                      if (_c.id != null) _infoRow('Application ID', _c.id!),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ---------- Payment Section (NEW) ----------
                  if (_c.id != null)
                    CopyrightPaymentSection(
                      copyrightId: _c.id!,
                      isOwner: widget.isOwner,
                    ),

                  const SizedBox(height: 30),

                  // ---------- Owner Actions ----------
                  if (widget.isOwner) ...[
                    OutlinedButton.icon(
                      onPressed: _openEdit,
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit Copyright'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        side: const BorderSide(color: Color(0xFF1A3FBF)),
                        foregroundColor: const Color(0xFF1A3FBF),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _confirmDelete,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete Copyright'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        side: const BorderSide(color: Colors.red),
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  // ============================================================
  // WIDGETS
  // ============================================================

  Widget _headerCard(bool isApproved, bool isPending) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1A3FBF).withOpacity(0.1),
            ),
            child: const Icon(Icons.copyright,
                color: Color(0xFF1A3FBF), size: 36),
          ),
          const SizedBox(height: 12),
          Text(
            _c.titleOfWork.isEmpty ? 'Untitled' : _c.titleOfWork,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            _c.typeOfWork.isEmpty ? '-' : _c.typeOfWork,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 12),
          _statusChip(isApproved, isPending),
        ],
      ),
    );
  }

  Widget _section({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A3FBF),
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  /// Each document tile → tappable → opens RJSCAttachmentViewer
  Widget _documentTile({
    required int index,
    required String attachmentId,
    required VoidCallback onTap,
  }) {
    final lower = attachmentId.toLowerCase();
    final isPdf = lower.contains('pdf') || lower.endsWith('.pdf');
    final isImage = lower.contains('jpg') ||
        lower.contains('jpeg') ||
        lower.contains('png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.png');

    IconData icon = Icons.insert_drive_file;
    Color iconColor = Colors.grey;
    Color bgColor = Colors.grey.shade50;

    if (isPdf) {
      icon = Icons.picture_as_pdf;
      iconColor = Colors.red;
      bgColor = Colors.red.shade50;
    } else if (isImage) {
      icon = Icons.image;
      iconColor = Colors.blue;
      bgColor = Colors.blue.shade50;
    }

    return Material(
      color: const Color(0xFFF5F7FA),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7FA),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Document $index',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tap to view',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.visibility_outlined,
                  size: 18, color: Color(0xFF1A3FBF)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip(bool isApproved, bool isPending) {
    final color = isApproved
        ? const Color(0xFF2E7D32)
        : (isPending ? const Color(0xFFE65100) : Colors.grey);
    final label = isApproved
        ? 'Approved'
        : (isPending ? 'Pending Review' : 'Unknown');
    final icon = isApproved
        ? Icons.check_circle
        : (isPending ? Icons.hourglass_empty : Icons.help);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}