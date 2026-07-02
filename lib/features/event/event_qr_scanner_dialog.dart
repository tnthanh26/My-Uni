import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_uni/web_mod/services/activity_service.dart';

class EventQrScannerDialog extends StatefulWidget {
  const EventQrScannerDialog({super.key});

  @override
  State<EventQrScannerDialog> createState() => _EventQrScannerDialogState();
}

class _EventQrScannerDialogState extends State<EventQrScannerDialog> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _isProcessing = false;
  String? _errorMessage;
  String? _successMessage;
  Timer? _messageTimer;

  @override
  void dispose() {
    _messageTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

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
        _showError('Mã QR không đúng định dạng sự kiện.');
        return;
      }

      if (decoded['type'] != 'myuni_event_qr') {
        _showError('Đây không phải mã QR điểm danh sự kiện của MyUni.');
        return;
      }

      final activityId = decoded['activityId']?.toString().trim();
      final title = decoded['title']?.toString() ?? 'Sự kiện';

      if (activityId == null || activityId.isEmpty) {
        _showError('Mã QR không có thông tin sự kiện.');
        return;
      }

      // Fetch current user data from Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError('Bạn cần đăng nhập để điểm danh.');
        return;
      }

      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userSnapshot.exists) {
        _showError('Không tìm thấy thông tin tài khoản của bạn.');
        return;
      }

      final userData = userSnapshot.data() as Map<String, dynamic>;
      final studentId = userData['studentId']?.toString().trim();

      if (studentId == null ||
          studentId.isEmpty ||
          studentId == 'Chưa cập nhật MSSV') {
        _showError('Vui lòng cập nhật MSSV tại trang cá nhân trước khi điểm danh.');
        return;
      }

      // Attach email to studentData
      userData['email'] = user.email ?? '';

      // Call service to check-in
      final isNewCheckIn = await ActivityService.checkInToEventFromStudent(
        activityId: activityId,
        studentUid: user.uid,
        studentData: userData,
      );

      if (!mounted) return;

      if (isNewCheckIn) {
        _showSuccess('Điểm danh thành công: $title');
      } else {
        _showSuccess('Bạn đã điểm danh sự kiện này trước đó rồi.');
      }
    } catch (e) {
      final errorMsg = e.toString().replaceFirst('Exception: ', '');
      _showError(errorMsg);
    }
  }

  void _showSuccess(String message) {
    _messageTimer?.cancel();

    setState(() {
      _successMessage = message;
      _errorMessage = null;
      _isProcessing = false;
    });

    _messageTimer = Timer(const Duration(seconds: 3), () {
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

    _messageTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _errorMessage = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final hasMessage = _successMessage != null || _errorMessage != null;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E1E24) : Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Color(0xFF6C63FF),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Quét QR hoạt động',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDarkMode ? Colors.white : const Color(0xFF1A1F37),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),

            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                width: 260,
                height: 260,
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
                              color: const Color(0xFF6C63FF),
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),

                    if (hasMessage)
                      Positioned(
                        top: 10,
                        left: 10,
                        right: 10,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _successMessage != null
                                ? Colors.green.withOpacity(0.94)
                                : Colors.redAccent.withOpacity(0.94),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _successMessage != null
                                    ? Icons.check_circle_rounded
                                    : Icons.error_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _successMessage ?? _errorMessage ?? '',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Nunito',
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    if (_isProcessing)
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Đang xử lý...',
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            Text(
              'Đưa mã QR của hoạt động/sự kiện vào khung quét bạn nhé!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                color: isDarkMode ? Colors.white60 : const Color(0xFF667085),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
