// lib/vat/screens/vat_details_page.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/vat_response_model.dart';
import '../service/vat_service.dart';
import 'vat_update_page.dart';
import 'vat_payment_page.dart';
import '../../RJSC/screens/rjsc_attachment_viewer.dart';

class VatDetailsPage extends StatefulWidget {
  final VatResponseModel vat;
  final String? currentUserId;

  const VatDetailsPage({
    super.key,
    required this.vat,
    required this.currentUserId,
  });

  @override
  State<VatDetailsPage> createState() => _VatDetailsPageState();
}

class _VatDetailsPageState extends State<VatDetailsPage> {
  late VatResponseModel _vat;
  bool _busy = false;

  bool get _isMine =>
      widget.currentUserId != null &&
      widget.currentUserId == _vat.userId;

  @override
  void initState() {
    super.initState();
    _vat = widget.vat;
  }

  // ============ DELETE ============
  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete VAT?'),
        content: const Text(
          'This will permanently delete this VAT and its registration process. '
          'Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await VatService.deleteVat(
        id: _vat.id!,
        userId: widget.currentUserId!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('VAT deleted successfully')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      _snack('Failed: $e', true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ============ EDIT ============
  Future<void> _openEdit() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => VatUpdatePage(vat: _vat.toVatModel()),
      ),
    );
    if (updated == true) {
      try {
        final fresh = await VatService.findById(_vat.id!);
        if (mounted) setState(() => _vat = fresh);
      } catch (_) {}
      if (mounted) Navigator.pop(context, true);
    }
  }

  // ============ PAYMENT ============
  Future<void> _openPayment() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => VatPaymentPage(
          vat: _vat,
          currentUserId: widget.currentUserId,
        ),
      ),
    );
    if (changed == true) {
      setState(() {});
    }
  }

  // ============ OPEN VIEWER ============
  Future<void> _openViewer(String attachmentId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RJSCAttachmentViewer(
          attachmentId: attachmentId,
          jwtToken: token,
        ),
      ),
    );
  }

  // ============ SNACK ============
  void _snack(String msg, [bool isError = false]) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final process = _vat.vatRegistrationProcessResponseDTO;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
          'VAT Details',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        actions: [
          if (_isMine) ...[
            IconButton(
              icon: const Icon(Icons.edit, color: Color(0xFF1565C0)),
              tooltip: 'Edit',
              onPressed: _busy ? null : _openEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: 'Delete',
              onPressed: _busy ? null : _confirmDelete,
            ),
          ],
        ],
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---- Header card ----
                  _headerCard(),

                  const SizedBox(height: 14),

                  // ---- Registration progress ----
                  if (process != null) _processCard(process),

                  const SizedBox(height: 14),

                  // ---- Business Info ----
                  _sectionCard(
                    title: 'Business Information',
                    icon: Icons.info_outline,
                    rows: [
                      _kv('Business Name', _vat.buisnessName),
                      _kv('Owner',
                          _vat.userName.isEmpty ? '-' : _vat.userName),
                      _kv('TIN No.', _vat.tinNo),
                      _kv('Trade License No.', _vat.tradeLicenseNo),
                      _kv('Business Address', _vat.adress),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ---- Business Details ----
                  _sectionCard(
                    title: 'Business Details',
                    icon: Icons.business_center_outlined,
                    rows: [
                      _kv('Nature of Business', _vat.natureOfBuisness),
                      _kv('Annual Turnover', _vat.annualTurnOver),
                      _kv('Main Product / Service', _vat.mainProduct),
                      _kv('No. of Employees', '${_vat.numberOfEmployee}'),
                      _kv('No. of Businesses', '${_vat.numberOfBuisness}'),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ---- Documents ----
                  if (_vat.documents.isNotEmpty)
                    _sectionCard(
                      title: 'Documents (${_vat.documents.length})',
                      icon: Icons.attach_file,
                      children: [
                        ..._vat.documents.asMap().entries.map((e) {
                          final idx = e.key + 1;
                          final id = e.value;
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1565C0)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.description,
                                    color: Color(0xFF1565C0),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Document $idx',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.visibility,
                                      color: Color(0xFF1565C0), size: 20),
                                  onPressed: () => _openViewer(id),
                                  tooltip: 'View',
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),

                  // ✅ Payment CTA — only for my own VAT
                  if (_isMine) ...[
                    const SizedBox(height: 14),
                    _paymentCta(),
                  ],

                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  // ============ Header Card ============
  Widget _headerCard() {
    final process = _vat.vatRegistrationProcessResponseDTO;
    final isApproved = process != null && process.status == true;
    final color = isApproved ? Colors.green : Colors.orange;
    final label = isApproved ? 'Approved' : 'Pending';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1565C0),
            const Color(0xFF1565C0).withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.receipt_long,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _vat.buisnessName.isEmpty
                          ? 'Unnamed Business'
                          : _vat.buisnessName,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Application ID: VAT-${_vat.id?.substring(0, _vat.id!.length > 8 ? 8 : _vat.id!.length).toUpperCase() ?? '?'}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isApproved ? Icons.check_circle : Icons.hourglass_top,
                  color: color,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============ Registration Process Card ============
  Widget _processCard(VatRegistrationProcessResponseModel p) {
    return _sectionCard(
      title: 'Registration Progress',
      icon: Icons.track_changes,
      children: [
        _kv('Advocate', p.advocateName.isEmpty ? '-' : p.advocateName),
        _kv('Status', p.status ? 'Active' : 'Inactive'),
        const SizedBox(height: 8),
        if (p.steps.isNotEmpty) ...[
          Text(
            'Steps (${p.steps.length})',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 6),
          ...p.steps.asMap().entries.map((e) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(top: 1),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF1565C0),
                    ),
                    child: Center(
                      child: Text(
                        '${e.key + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      e.value,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  // ============ Payment CTA ============
  Widget _paymentCta() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.payments,
                    color: Colors.green.shade700, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payments',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      'Total: ৳ 5,000',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _openPayment,
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('View'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============ Reusable UI ============
  Widget _sectionCard({
    required String title,
    required IconData icon,
    List<Widget>? children,
    List<Widget>? rows,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child:
                    Icon(icon, color: const Color(0xFF1565C0), size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (rows != null) ...rows,
          if (children != null) ...children,
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              k,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              v.isEmpty ? '-' : v,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}