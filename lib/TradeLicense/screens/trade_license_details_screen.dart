// lib/TradeLicense/screens/trade_license_details_screen.dart

import 'package:flutter/material.dart';
import '../../Auth/AuthService.dart';
import '../../ChatRelatedPages/FreeConsultantPage.dart';
import '../../RJSC/screens/rjsc_attachment_viewer.dart';
import '../models/trade_license_response_dto.dart';
import '../models/trade_license_model.dart';
import '../services/trade_license_service.dart';
import 'trade_license_update_screen.dart';
import 'widgets/trade_license_payment_section.dart';
import '../screens/widgets/make_tl_payment_sheet.dart';

class TradeLicenseDetailsScreen extends StatefulWidget {
  final TradeLicenseResponseDTO license;
  final bool isOwner;

  const TradeLicenseDetailsScreen({
    super.key,
    required this.license,
    required this.isOwner,
  });

  @override
  State<TradeLicenseDetailsScreen> createState() =>
      _TradeLicenseDetailsScreenState();
}

class _TradeLicenseDetailsScreenState extends State<TradeLicenseDetailsScreen> {
  late TradeLicenseResponseDTO _l;
  bool _isDeleting = false;
  String? _currentUserId;
  String? _currentUserName;

  @override
  void initState() {
    super.initState();
    _l = widget.license;
    _loadUser();
  }

  Future<void> _loadUser() async {
    final userId = await AuthService.getUserId();
    if (!mounted) return;
    setState(() {
      _currentUserId = userId;
      _currentUserName = '';
    });
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Trade License?'),
        content: const Text(
            'This action cannot be undone. Are you sure you want to delete this trade license?'),
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
    final res = await TradeLicenseService.deleteTradeLicense(
      id: _l.id ?? '',
      userId: userId,
    );
    if (!mounted) return;
    setState(() => _isDeleting = false);

    if (res['status'] == 'success') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trade license deleted'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(res['message'] ?? 'Failed to delete'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _openEdit() async {
    final model = TradeLicenseModel(
      id: _l.id,
      userId: _l.userId,
      buisnessName: _l.buisnessName,
      mobileNumber: _l.mobileNumber,
      emailAdress: _l.emailAdress,
      buisnessType: _l.buisnessType,
      buisnessCategory: _l.buisnessCategory,
      documents: _l.documents,
    );
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TradeLicenseUpdateScreen(existingLicense: model),
      ),
    );
    if (changed == true && mounted) {
      Navigator.pop(context, true);
    }
  }

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
            title: const Text('Document Viewer',
                style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
          body: RJSCAttachmentViewer(
            attachmentId: attachmentId,
            jwtToken: token,
          ),
        ),
      ),
    );
  }

  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FreeConsultantPage(
          currentUserId: _currentUserId,
          currentUserName: _currentUserName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final process = _l.tradeLicenseRegistrationProcess;
    final isApproved = process != null && process.status == true;
    final isPending = process == null;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text('Trade License Details',
            style: TextStyle(color: Colors.black87, fontSize: 18)),
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
                      Icon(Icons.edit, size: 18, color: Color(0xFF1E7A3A)),
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
                  _header(isApproved, isPending),
                  const SizedBox(height: 16),

                  // ---------- Business Information ----------
                  _section('Business Information', [
                    _row('Business Name', _l.buisnessName),
                    _row('Business Type', _l.buisnessType),
                    _row('Category', _l.buisnessCategory),
                  ]),
                  const SizedBox(height: 16),

                  // ---------- Contact Information ----------
                  _section('Contact Information', [
                    _row('Owner / Applicant', _l.userName),
                    _row('Mobile', _l.mobileNumber),
                    _row('Email', _l.emailAdress),
                  ]),
                  const SizedBox(height: 16),

                  // ---------- Documents ----------
                  _section('Documents', [
                    if (_l.documents.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Icon(Icons.folder_off_outlined,
                                color: Colors.grey.shade400, size: 20),
                            const SizedBox(width: 8),
                            Text('No documents uploaded',
                                style: TextStyle(
                                    color: Colors.grey.shade600)),
                          ],
                        ),
                      )
                    else
                      ..._l.documents.asMap().entries.map((e) {
                        return _docTile(
                          index: e.key + 1,
                          id: e.value,
                          onTap: () => _openDocument(e.value),
                        );
                      }),
                  ]),
                  const SizedBox(height: 16),

                  // ---------- Application Status ----------
                  _section('Application Status', [
                    if (isPending)
                      _row('Status', 'Pending Review')
                    else if (process != null) ...[
                      _row('Status',
                          process.status == true ? 'Approved' : 'Processing'),
                      if (process.advocateName.isNotEmpty)
                        _row('Assigned Advocate', process.advocateName),
                      if (process.steps.isNotEmpty)
                        _row('Progress', process.steps.join(' → ')),
                    ],
                    if (_l.id != null) _row('Application ID', _l.id!),
                  ]),

                  // ---------- Payment Section (only for owner) ----------
                  if (widget.isOwner && _l.id != null) ...[
                    const SizedBox(height: 16),
                    TradeLicensePaymentSection(
                      tradeLicenseId: _l.id!,
                      isOwner: true,
                    ),
                  ],

                  const SizedBox(height: 20),

                  // ---------- Chat with Executive (everyone) ----------
                  OutlinedButton.icon(
                    onPressed: _openChat,
                    icon: const Icon(Icons.chat),
                    label: const Text('Chat with Executive'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      side: const BorderSide(color: Color(0xFF1E7A3A)),
                      foregroundColor: const Color(0xFF1E7A3A),
                    ),
                  ),

                  // ---------- Owner actions ----------
                  if (widget.isOwner) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _openEdit,
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit Trade License'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        side: const BorderSide(color: Color(0xFF1E7A3A)),
                        foregroundColor: const Color(0xFF1E7A3A),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _confirmDelete,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete Trade License'),
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

  Widget _header(bool isApproved, bool isPending) {
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
              color: const Color(0xFF1E7A3A).withOpacity(0.1),
            ),
            child: const Icon(Icons.store,
                color: Color(0xFF1E7A3A), size: 36),
          ),
          const SizedBox(height: 12),
          Text(
            _l.buisnessName.isEmpty ? 'Untitled' : _l.buisnessName,
            textAlign: TextAlign.center,
            style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(_l.buisnessType.isEmpty ? '-' : _l.buisnessType,
              style:
                  TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 12),
          _statusChip(isApproved, isPending),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
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
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E7A3A))),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: TextStyle(
                    color: Colors.grey.shade600, fontSize: 13)),
          ),
          Expanded(
            child: Text(value.isEmpty ? '-' : value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _docTile({
    required int index,
    required String id,
    required VoidCallback onTap,
  }) {
    final isPdf = id.toLowerCase().contains('pdf');
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
                  color: isPdf ? Colors.red.shade50 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isPdf ? Icons.picture_as_pdf : Icons.image,
                  color: isPdf ? Colors.red : Colors.blue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Document $index',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    Text('Tap to view',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              const Icon(Icons.visibility_outlined,
                  size: 18, color: Color(0xFF1E7A3A)),
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
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}