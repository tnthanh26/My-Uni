import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'services/activity_service.dart';

class StudentQrScannerDialog extends StatefulWidget {
  const StudentQrScannerDialog({
    super.key,
    required this.activityId,
  });

  final String activityId;

  @override
  State<StudentQrScannerDialog> createState() => _StudentQrScannerDialogState();
}

class _StudentQrScannerDialogState extends State<StudentQrScannerDialog> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _isProcessing = false;
  String? _errorMessage;
  String? _successMessage;
  Timer? _messageTimer;
  Map<String, dynamic>? _pendingStudentData;

  @override
  void dispose() {
    _messageTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleDetect(BarcodeCapture capture) async {
    if (_isProcessing || _pendingStudentData != null) return;

    final rawValue = capture.barcodes.isNotEmpty
        ? capture.barcodes.first.rawValue
        : null;

    if (rawValue == null || rawValue.trim().isEmpty) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final decoded = jsonDecode(rawValue);

      if (decoded is! Map<String, dynamic>) {
        _showError('Mã QR không đúng định dạng MyUni.');
        return;
      }

      if (decoded['type'] != 'myuni_student_qr') {
        _showError('Đây không phải mã QR sinh viên MyUni.');
        return;
      }

      final studentId = decoded['studentId']?.toString().trim();

      if (studentId == null ||
          studentId.isEmpty ||
          studentId == 'Chưa cập nhật MSSV') {
        _showError('QR thiếu MSSV hợp lệ.');
        return;
      }

      final studentData = Map<String, dynamic>.from(decoded);

      try {
        final isNewCheckIn = await ActivityService.addAttendanceFromQr(
          activityId: widget.activityId,
          studentData: studentData,
        );

        if (!mounted) return;

        final displayName = studentData['displayName'] ?? 'Sinh viên';
        final message = isNewCheckIn
            ? 'Đã điểm danh: $displayName'
            : '$displayName đã điểm danh trước đó';

        _showSuccess(message);
      } catch (e) {
        final errorStr = e.toString();
        if (errorStr == 'NOT_REGISTERED' || errorStr.contains('NOT_REGISTERED')) {
          setState(() {
            _pendingStudentData = studentData;
            _isProcessing = false;
          });
        } else {
          _showError('Không thể ghi nhận điểm danh: $e');
        }
      }
    } catch (e) {
      _showError('Lỗi giải mã QR: $e');
    }
  }

  Future<void> _handleApproval(bool accepted) async {
    if (_pendingStudentData == null) return;

    final displayName = _pendingStudentData!['displayName'] ?? 'Sinh viên';

    if (!accepted) {
      setState(() {
        _pendingStudentData = null;
      });
      _showError('Đã từ chối điểm danh: $displayName');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final isNewCheckIn = await ActivityService.addAttendanceFromQr(
        activityId: widget.activityId,
        studentData: _pendingStudentData!,
        force: true,
      );

      if (!mounted) return;

      final displayName = _pendingStudentData!['displayName'] ?? 'Sinh viên';
      final message = isNewCheckIn
          ? 'Đã ghi nhận vãng lai: $displayName'
          : '$displayName đã điểm danh trước đó';

      setState(() => _pendingStudentData = null);
      _showSuccess(message);
    } catch (e) {
      _showError('Lỗi khi ghi nhận: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showSuccess(String message) {
    _messageTimer?.cancel();

    setState(() {
      _successMessage = message;
      _errorMessage = null;
      _isProcessing = false;
    });

    _messageTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _successMessage = null;
      });
    });
  }

  void _showError(String message) {
    _messageTimer?.cancel();

    setState(() {
      _errorMessage = message;
      _successMessage = null;
      _isProcessing = false;
    });

    _messageTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _errorMessage = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasMessage = _successMessage != null || _errorMessage != null;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Colors.blueAccent,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Quét QR sinh viên',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1F37),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),

            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: SizedBox(
                width: 440,
                height: 330,
                child: Stack(
                  children: [
                    MobileScanner(
                      controller: _controller,
                      onDetect: _handleDetect,
                    ),

                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.blueAccent,
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                      ),
                    ),

                    if (hasMessage)
                      Positioned(
                        top: 14,
                        left: 14,
                        right: 14,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: _successMessage != null
                                ? Colors.green.withOpacity(0.94)
                                : Colors.redAccent.withOpacity(0.94),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.18),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _successMessage != null
                                    ? Icons.check_circle_rounded
                                    : Icons.error_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _successMessage ?? _errorMessage ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Nunito',
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    if (_isProcessing)
                      Positioned(
                        right: 14,
                        bottom: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Đang ghi nhận...',
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    if (_pendingStudentData != null)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withOpacity(0.85),
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.person_add_disabled_rounded,
                                color: Colors.orangeAccent,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Sinh viên chưa đăng ký!',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Nunito',
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${_pendingStudentData!['displayName']} (${_pendingStudentData!['studentId']})',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontFamily: 'Nunito',
                                ),
                              ),
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _handleApproval(false),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: const BorderSide(color: Colors.white30),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      child: const Text('Từ chối'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () => _handleApproval(true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blueAccent,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      child: const Text('Chấp nhận'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            const Text(
              'Đưa mã QR sinh viên vào khung camera ngay ngắn và đợi một xíu bạn nhé!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Nunito',
                color: Color(0xFF667085),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}