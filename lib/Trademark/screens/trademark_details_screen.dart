// lib/Trademark/screens/trademark_details_screen.dart

import 'package:flutter/material.dart';
import '../../Auth/AuthService.dart';
import '../../ChatRelatedPages/FreeConsultantPage.dart';
import '../../RJSC/screens/rjsc_attachment_viewer.dart';
import '../models/trademark_response_dto.dart';
import '../models/trademark_model.dart';
import '../services/trademark_service.dart';
import 'trademark_update_screen.dart';
import 'widgets/trademark_payment_section.dart';

class TrademarkDetailsScreen extends StatefulWidget {
  final TrademarkResponse trademark;
  final bool isOwner;

  const TrademarkDetailsScreen({
    super.key,
    required this.trademark,
    required this.isOwner,
  });

  @override
  State<TrademarkDetailsScreen> createState() => _TrademarkDetailsScreenState();
}

class _TrademarkDetailsScreenState extends State<TrademarkDetailsScreen> {
  late TrademarkResponse _t;
  bool _isDeleting = false;
  String? _currentUserId;
  String? _currentUserName;

  @override
  void initState() {
    super.initState();
    _t = widget.trademark;
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
        title: const Text('Delete Trademark?'),
        content: const Text(
            'This action cannot be undone. Are you sure you want to delete this trademark?'),
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
    final res = await TrademarkService.deleteTrademark(
      id: _t.id ?? '',
      userId: userId,
    );
    if (!mounted) return;
    setState(() => _isDeleting = false);

    if (res['status'] == 'success') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trademark deleted'),
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
    final model = TrademarkModel(
      id: _t.id,
      userId: _t.userId,
      legalProtection: _t.legalProtection,
      nationWiseValidity: _t.nationWiseValidity,
      applicationType: _t.applicationType,
      applicationName: _t.applicationName,
      governmentFee: _t.governmentFee,
      organaizationalName: _t.organaizationalName,
      trademarkName: _t.trademarkName,
      trademarkType: _t.trademarkType,
      classOfGoods: _t.classOfGoods,
      adress: _t.adress,
      email: _t.email,
      mobileNumber: _t.mobileNumber,
      documents: _t.documents,
    );
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TrademarkUpdateScreen(existingTrademark: model),
      ),
    );
    if (changed == true && mounted) Navigator.pop(context, true);
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
    final process = _t.registrationProcess;
    final isApproved = process != null && process.status == true;
    final isPending = process == null;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text('Trademark Details',
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
                      Icon(Icons.edit, size: 18, color: Color(0xFF6A1B9A)),
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
                  _section('Trademark Information', [
                    _row('Trademark Name', _t.trademarkName),
                    _row('Trademark Type', _t.trademarkType),
                    _row('Class of Goods', _t.classOfGoods),
                    _row('Organization', _t.organaizationalName),
                    _row('Legal Protection', _t.legalProtection),
                    _row('Nation Validity', _t.nationWiseValidity),
                    _row('Government Fee',
                        '৳ ${_t.governmentFee.toStringAsFixed(0)}'),
                  ]),
                  const SizedBox(height: 16),
                  _section('Applicant Information', [
                    _row('Applicant Type', _t.applicationType),
                    _row('Applicant Name', _t.applicationName),
                    _row('Mobile', _t.mobileNumber),
                    _row('Email', _t.email),
                    _row('Address', _t.adress),
                  ]),
                  const SizedBox(height: 16),
                  _section('Documents', [
                    if (_t.documents.isEmpty)
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
                      ..._t.documents.asMap().entries.map((e) {
                        return _docTile(
                          index: e.key + 1,
                          id: e.value,
                          onTap: () => _openDocument(e.value),
                        );
                      }),
                  ]),
                  const SizedBox(height: 16),
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
                    if (_t.id != null) _row('Application ID', _t.id!),
                  ]),

                  // ---------- Payment Section (owner only) ----------
                  if (widget.isOwner && _t.id != null) ...[
                    const SizedBox(height: 16),
                    TrademarkPaymentSection(
                      trademarkId: _t.id!,
                      isOwner: true,
                    ),
                  ],

                  const SizedBox(height: 20),

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
                  if (widget.isOwner) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _openEdit,
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit Trademark'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        side: const BorderSide(color: Color(0xFF6A1B9A)),
                        foregroundColor: const Color(0xFF6A1B9A),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _confirmDelete,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete Trademark'),
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
              color: const Color(0xFF6A1B9A).withOpacity(0.1),
            ),
            child: const Icon(Icons.verified,
                color: Color(0xFF6A1B9A), size: 36),
          ),
          const SizedBox(height: 12),
          Text(
            _t.trademarkName.isEmpty ? 'Untitled' : _t.trademarkName,
            textAlign: TextAlign.center,
            style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(_t.trademarkType.isEmpty ? '-' : _t.trademarkType,
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
                  color: Color(0xFF6A1B9A))),
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
                  size: 18, color: Color(0xFF6A1B9A)),
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