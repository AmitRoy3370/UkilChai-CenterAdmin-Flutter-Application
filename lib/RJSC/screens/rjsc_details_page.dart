// lib/RJSC/screens/rjsc_details_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/rjsc_payment_section.dart';
import '../models/rjsc_response_dto.dart';
import '../services/rjsc_service.dart';           // ✅ নতুন (delete-এর জন্য)
import 'rjsc_update_screen.dart';
import 'rjsc_attachment_viewer.dart';
import '../../ChatRelatedPages/FreeConsultantPage.dart';
import 'rjsc_services.dart';  // ✅ নতুন

class RjscDetailsPage extends StatefulWidget {
  final RjscResponseDTO rjsc;

  const RjscDetailsPage({super.key, required this.rjsc});

  @override
  State<RjscDetailsPage> createState() => _RjscDetailsPageState();
}

class _RjscDetailsPageState extends State<RjscDetailsPage> {
  static const Color _primaryGreen = Color(0xFF0B5D36);
  static const Color _lightGreenBg = Color(0xFFECFDF5);
  static const Color _borderColor = Color(0xFFE2E8F0);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textGrey = Color(0xFF64748B);

  bool _isOwner = false;
  bool _isDeleting = false;
  String? _currentUserId;
  String? _currentUserPhone;

  @override
  void initState() {
    super.initState();
    _checkOwnership();
  }

  // ============ চেক করা এই RJSC টি visiting user-এর কি না ============
  Future<void> _checkOwnership() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId') ?? '';
    final phone = prefs.getString('phoneNumber') ??
        prefs.getString('phone') ??
        prefs.getString('userPhone') ??
        '';

    if (!mounted) return;
    setState(() {
      _currentUserId = userId;
      _currentUserPhone = phone;
      _isOwner = userId.isNotEmpty && userId == widget.rjsc.userId;
    });
  }

  RjscResponseDTO get rjsc => widget.rjsc;

  @override
  Widget build(BuildContext context) {
    final process = rjsc.registrationProcess;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          'RJSC Details',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          // ✅ Edit button (only for owner)
          if (_isOwner)
            IconButton(
              icon: const Icon(Icons.edit, color: _primaryGreen),
              tooltip: 'Edit',
              onPressed: () async {
                final updated = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RjscUpdateScreen(rjsc: rjsc),
                  ),
                );
                if (updated == true && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'RJSC updated. Please go back and re-open to see changes.'),
                    ),
                  );
                }
              },
            ),

          // ✅ Delete button (only for owner)
          if (_isOwner)
            IconButton(
              icon: _isDeleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.redAccent,
                      ),
                    )
                  : const Icon(Icons.delete_outline,
                      color: Colors.redAccent),
              tooltip: 'Delete',
              onPressed: _isDeleting ? null : _confirmDelete,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _headerCard(),
            const SizedBox(height: 16),
            _infoSection(
              title: 'Company Information',
              icon: Icons.business,
              rows: [
                _DetailRow('Company Name', rjsc.companyName),
                _DetailRow('RJSC Registration No.', rjsc.registrationNo),
                _DetailRow('Compliance Service', rjsc.compilenceService),
                _DetailRow('Email', rjsc.email),
                _DetailRow('Financial Year', _formatYear(rjsc.year)),
              ],
            ),
            const SizedBox(height: 16),
            _infoSection(
              title: 'Submitted By',
              icon: Icons.person_outline,
              rows: [
                _DetailRow('User Name',
                    rjsc.userName.isEmpty ? 'Unknown' : rjsc.userName),
                _DetailRow('User ID', rjsc.userId),
              ],
            ),
            const SizedBox(height: 16),

            // Registration Process
            if (process != null) _processCard(process),
            if (process != null) const SizedBox(height: 16),

            // Documents
            _documentsSection(context),

            // ✅ Owner-only sections
            if (_isOwner) ...[
              const SizedBox(height: 16),

              // ---------- PAYMENT SECTION ----------
              RjscPaymentSection(
                rjscId: rjsc.id ?? '',
                senderUserId: rjsc.userId,
                senderUserName: rjsc.userName,
                senderPhoneNumber: _currentUserPhone ?? '',
              ),

              const SizedBox(height: 24),

              // ---------- ACTIONS ----------
              _ownerActionsSection(),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ============ Owner Actions Section ============
  Widget _ownerActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actions',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: _textGrey,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),

        // Chat with Executive
        _actionTile(
          icon: Icons.chat_bubble_outline,
          title: 'Chat with Executive',
          subtitle: 'Talk to our executive for assistance',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FreeConsultantPage(
                  currentUserId: _currentUserId,
                  currentUserName: rjsc.userName,
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 10),

        // ✅ Delete RJSC
        _actionTile(
          icon: Icons.delete_outline,
          title: 'Delete RJSC',
          subtitle: 'Permanently remove this filing',
          iconColor: Colors.redAccent,
          iconBg: const Color(0xFFFEF2F2),
          onTap: _isDeleting ? null : _confirmDelete,
        ),
      ],
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    Color iconColor = _primaryGreen,
    Color iconBg = _lightGreenBg,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                        fontSize: 11, color: _textGrey),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: _textGrey),
          ],
        ),
      ),
    );
  }

  // ============ Delete Confirmation ============
  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Color(0xFFFEF2F2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline,
                  color: Colors.redAccent, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'Delete RJSC?',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This action cannot be undone. All associated data '
              '(process, payments, documents) may be removed permanently.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: _textGrey,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rjsc.companyName.isEmpty
                        ? 'Untitled Company'
                        : rjsc.companyName,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Reg No: ${rjsc.registrationNo}',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: _textGrey),
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _textGrey,
              ),
            ),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete, size: 16),
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            label: Text(
              'Delete',
              style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteRjsc();
    }
  }

  // ============ Perform Delete ============
  Future<void> _deleteRjsc() async {
    final id = rjsc.id;
    if (id == null || id.isEmpty) {
      _showSnack('Invalid RJSC id', isError: true);
      return;
    }

    setState(() => _isDeleting = true);

    try {
      final userId = _currentUserId ?? rjsc.userId;
      final result = await RjscService.deleteRjsc(
        id: id,
        userId: userId,
      );

      if (!mounted) return;
      setState(() => _isDeleting = false);

      if (result['status'] == 'success') {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('RJSC deleted successfully')),
  );

  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const RjscServices()),
  );
} else {
        _showSnack(
          result['message']?.toString() ?? 'Delete failed',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      _showSnack('Error: $e', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : _primaryGreen,
      ),
    );
  }

  // ============ Header Card ============
  Widget _headerCard() {
    final process = rjsc.registrationProcess;
    final isCompleted = process?.status ?? false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _primaryGreen,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _primaryGreen.withOpacity(0.25),
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
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.business,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rjsc.companyName.isEmpty
                          ? 'Untitled Company'
                          : rjsc.companyName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Reg No: ${rjsc.registrationNo}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isOwner)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person,
                          color: Colors.white, size: 12),
                      const SizedBox(width: 3),
                      Text(
                        'Yours',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pillBadge(
                rjsc.compilenceService,
                Colors.white.withOpacity(0.2),
                Colors.white,
              ),
              _pillBadge(
                isCompleted ? 'Completed' : 'Pending',
                isCompleted
                    ? const Color(0xFFB9F6CA).withOpacity(0.3)
                    : const Color(0xFFFFE0B2).withOpacity(0.3),
                isCompleted
                    ? const Color(0xFFB9F6CA)
                    : const Color(0xFFFFCC80),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pillBadge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  // ============ Info Section ============
  Widget _infoSection({
    required String title,
    required IconData icon,
    required List<_DetailRow> rows,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _primaryGreen, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...rows.map((row) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 130,
                      child: Text(
                        row.label,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _textGrey,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        row.value.isEmpty ? '—' : row.value,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _textDark,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ============ Process Card ============
  Widget _processCard(dynamic process) {
    final steps = process.steps as List<String>;
    final isCompleted = process.status as bool;
    final advocateName = process.advocateName as String? ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.track_changes,
                  color: _primaryGreen, size: 20),
              const SizedBox(width: 8),
              Text(
                'Registration Process',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _textDark,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? _lightGreenBg
                      : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isCompleted ? 'Completed' : 'In Progress',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isCompleted
                        ? _primaryGreen
                        : const Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (advocateName.isNotEmpty)
            Row(
              children: [
                const Icon(Icons.gavel, size: 14, color: _textGrey),
                const SizedBox(width: 6),
                Text(
                  'Advocate: ',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: _textGrey),
                ),
                Expanded(
                  child: Text(
                    advocateName,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _textDark,
                    ),
                  ),
                ),
              ],
            ),
          if (advocateName.isNotEmpty) const SizedBox(height: 12),
          if (steps.isNotEmpty) ...[
            Text(
              'Steps:',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _textGrey,
              ),
            ),
            const SizedBox(height: 8),
            ...steps.asMap().entries.map((e) {
              final idx = e.key;
              final step = e.value;
              final isDone = idx < steps.length - (isCompleted ? 0 : 1);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isDone
                            ? _primaryGreen
                            : const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: isDone
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 12)
                          : Text(
                              '${idx + 1}',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _textGrey,
                              ),
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          step,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: _textDark,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ] else
            Text(
              'No steps recorded yet.',
              style: GoogleFonts.inter(
                  fontSize: 12, color: _textGrey),
            ),
        ],
      ),
    );
  }

  // ============ Documents Section ============
  Widget _documentsSection(BuildContext context) {
    final docs = rjsc.documents;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.attach_file,
                  color: _primaryGreen, size: 20),
              const SizedBox(width: 8),
              Text(
                'Documents (${docs.length})',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (docs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No documents uploaded.',
                style: GoogleFonts.inter(
                    fontSize: 12, color: _textGrey),
              ),
            )
          else
            ...docs.asMap().entries.map((entry) {
              final idx = entry.key;
              final docId = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => _openAttachment(context, docId),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _lightGreenBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.description_outlined,
                              color: _primaryGreen, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Document ${idx + 1}',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _textDark,
                                ),
                              ),
                              Text(
                                docId,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                    fontSize: 11, color: _textGrey),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.visibility_outlined,
                            size: 18, color: _primaryGreen),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  // ============ Open Attachment ============
  Future<void> _openAttachment(
      BuildContext context, String attachmentId) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login to view attachments'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;

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

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  // ============ Helpers ============
  String _formatYear(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

// ============ Helper Class ============
class _DetailRow {
  final String label;
  final String value;

  _DetailRow(this.label, this.value);
}