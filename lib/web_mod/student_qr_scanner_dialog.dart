import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class StudentQrScannerDialog extends StatefulWidget {
  const StudentQrScannerDialog({super.key});

  @override
  State<StudentQrScannerDialog> createState() => _StudentQrScannerDialogState();
}

class _StudentQrScannerDialogState extends State<StudentQrScannerDialog> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final rawValue = capture.barcodes.firstOrNull?.rawValue;
    if (rawValue == null || rawValue.trim().isEmpty) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
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

      Navigator.pop(context, decoded);
    } catch (_) {
      _showError('Không đọc được nội dung QR.');
    }
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
      _isProcessing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
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
                    if (_isProcessing)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withOpacity(0.35),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            Text(
              _errorMessage ??
                  'Đưa mã QR sinh viên vào khung camera để điểm danh.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Nunito',
                color: _errorMessage == null
                    ? const Color(0xFF667085)
                    : Colors.redAccent,
                fontWeight:
                _errorMessage == null ? FontWeight.w500 : FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}