import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'services/moodle_service.dart';
import 'services/moodle_token_storage.dart';
import 'package:my_uni/utils/app_feedback.dart';

class MoodleWebviewPage extends StatefulWidget {
  final String moodleUrl;
  const MoodleWebviewPage({super.key, required this.moodleUrl});

  @override
  State<MoodleWebviewPage> createState() => _MoodleWebviewPageState();
}

class _MoodleWebviewPageState extends State<MoodleWebviewPage> {
  late final WebViewController _controller;
  int _loadingProgress = 0;
  bool _hasTokenFound = false;
  bool _isPlatformAvailable = true;

  @override
  void initState() {
    super.initState();
    if (WebViewPlatform.instance == null) {
      _isPlatformAvailable = false;
      return;
    }

    final initialUrl = MoodleService.getSsoLaunchUrl(widget.moodleUrl);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) {
              setState(() {
                _loadingProgress = progress;
              });
            }
          },
          onPageStarted: (url) {
            debugPrint('🛫 [WEBVIEW] PAGE STARTED: $url');
            _checkAndExtractToken(url);
          },
          onPageFinished: (url) async {
            debugPrint('✅ [WEBVIEW] PAGE FINISHED: $url');
            _checkAndExtractToken(url);

            // Kiểm tra bóc tách Token tự động từ trang DOM (đặc biệt trang user/managetoken.php)
            try {
              final jsResult = await _controller.runJavaScriptReturningResult(
                '''(function() {
                  // 1. Quét tìm dòng chứa 'Moodle mobile web service' trong bảng Security keys của user/managetoken.php
                  var rows = document.querySelectorAll('tr');
                  for (var i = 0; i < rows.length; i++) {
                    var txt = rows[i].innerText || '';
                    if (txt.indexOf('Moodle mobile web service') !== -1 || txt.indexOf('mobile') !== -1) {
                      var m = txt.match(/\\b([a-f0-9]{32})\\b/i);
                      if (m) return m[1];
                    }
                  }
                  // 2. Quét tìm authtoken/wstoken trên tất cả link hoặc form
                  var elems = document.querySelectorAll('a[href*="authtoken"], a[href*="wstoken"], a[href*="export_execute.php"]');
                  for (var j = 0; j < elems.length; j++) {
                    var href = elems[j].href || '';
                    if (href.indexOf('authtoken=') !== -1 || href.indexOf('wstoken=') !== -1) {
                      return href;
                    }
                  }
                  return document.body ? document.body.innerText : '';
                })()''',
              );
              final jsStr = jsResult.toString();
              if (jsStr.contains('authtoken=') || jsStr.contains('wstoken=')) {
                debugPrint('🔎 [AUTO JS INSPECT] Found token link: $jsStr');
                _checkAndExtractToken(jsStr);
              } else {
                final hexMatch = RegExp(
                  r'\b([a-f0-9]{32})\b',
                ).firstMatch(jsStr);
                if (hexMatch != null) {
                  final token = hexMatch.group(1)!;
                  debugPrint(
                    '🎯 [MANAGETOKEN SUCCESS MATCH] Found 32-char Moodle mobile wstoken: $token',
                  );
                  _hasTokenFound = true;
                  _saveTokenAndComplete(token);
                }
              }
            } catch (e) {
              debugPrint('AUTO JS INSPECTION ERROR: $e');
            }
          },
          onUrlChange: (change) {
            debugPrint('🔄 [WEBVIEW] URL CHANGE: ${change.url}');
            if (change.url != null) {
              _checkAndExtractToken(change.url!);
            }
          },
          onNavigationRequest: (request) {
            debugPrint('➡️ [WEBVIEW] NAV REQUEST: ${request.url}');
            if (_checkAndExtractToken(request.url)) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true) {
              debugPrint('WEBVIEW MAINFRAME ERROR: ${error.description}');
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(initialUrl));
  }

  bool _isTriggeringAutoToken = false;
  bool _isOauthCompleted = false;

  bool _checkAndExtractToken(String url) {
    if (_hasTokenFound) return true;

    debugPrint('🧐 [CHECK TOKEN] Inspecting URL: $url');

    // 1. Nhận diện khi Microsoft OAuth vừa xác thực thành công
    if (url.contains('oauth2callback.php') ||
        url.contains('/auth/oauth2/login.php') ||
        url.contains('/auth/oidc/')) {
      _isOauthCompleted = true;
      debugPrint(
        '⚡ [OAUTH DETECTED] User successfully authenticated via Microsoft OAuth!',
      );
    }

    // 2. Trích xuất token từ URL nếu có
    final token = MoodleService.extractTokenFromUrl(url);
    if (token != null && token.trim().isNotEmpty) {
      debugPrint('🎯 [TOKEN MATCH] Successfully found wstoken: $token');
      _hasTokenFound = true;
      _saveTokenAndComplete(token);
      return true;
    }

    // 3. Khi người dùng hoàn tất đăng nhập Outlook và đáp xuống trang chủ Moodle,
    // tự động điều hướng ngầm tới user/managetoken.php hoặc calendar/export.php để bóc tách wstoken 32 ký tự hex!
    final cleanedUrl = widget.moodleUrl.trim().replaceAll(RegExp(r'/$'), '');
    final isDashboardOrRoot =
        url.contains('/my') ||
        url == '$cleanedUrl/' ||
        url == cleanedUrl ||
        url.contains('/user/profile.php');

    final isOAuthProcessingPage =
        url.contains('oauth2callback.php') ||
        url.contains('/auth/oauth2/login.php') ||
        url.contains('/auth/oidc/') ||
        url.contains('/login/') ||
        url.contains('login.microsoftonline.com');

    if ((_isOauthCompleted || isDashboardOrRoot) &&
        !isOAuthProcessingPage &&
        !_isTriggeringAutoToken &&
        !_hasTokenFound &&
        !url.contains('managetoken') &&
        !url.contains('calendar/export.php')) {
      _isTriggeringAutoToken = true;
      final targetUrl = '$cleanedUrl/user/managetoken.php';
      debugPrint(
        '🚀 [AUTO TOKEN FETCH] User logged in! Navigating to managetoken URL: $targetUrl',
      );
      Future.microtask(() async {
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted && !_hasTokenFound) {
          _controller.loadRequest(Uri.parse(targetUrl));
        }
      });
    }

    return false;
  }

  Future<void> _saveTokenAndComplete(String token) async {
    debugPrint('🎉 MOODLE WSTOKEN ACQUIRED SUCCESSFULLY: $token');
    await MoodleTokenStorage.saveToken(token);
    if (!mounted) return;
    AppFeedback.showSuccess(
      context,
      'Đăng nhập Moodle qua Outlook thành công!',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    const Color primaryColor = Color(0xFF5893D8);

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF121212)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 1,
        titleSpacing: 0,
        leading: IconButton(
          icon: Icon(
            Icons.close_rounded,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
          onPressed: () {
            FocusManager.instance.primaryFocus?.unfocus();
            Navigator.pop(context, false);
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Đăng nhập Moodle Outlook',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
                color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            Text(
              widget.moodleUrl,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'Poppins',
                color: isDarkMode ? Colors.white54 : Colors.grey.shade600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            icon: Icon(
              Icons.refresh_rounded,
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
            onPressed: _isPlatformAvailable
                ? () async {
                    try {
                      await _controller.reload();
                    } catch (e) {
                      debugPrint('RELOAD ERROR: $e');
                    }
                  }
                : null,
          ),
        ],
      ),
      body: SafeArea(
        child: !_isPlatformAvailable
            ? Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.build_circle_rounded,
                        size: 56,
                        color: Color(0xFF5893D8),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Cần khởi động lại ứng dụng',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Vì vừa thêm thư viện WebView mới vào dự án, bạn cần TẮT APP (Stop) và CHẠY LẠI (Stop & Run / Rebuild) để máy nạp mã mã nguồn Native vào APK.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          fontFamily: 'Encode Sans Expanded',
                          color: isDarkMode
                              ? Colors.white70
                              : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                children: [
                  if (_loadingProgress < 100)
                    LinearProgressIndicator(
                      value: _loadingProgress / 100.0,
                      backgroundColor: primaryColor.withValues(alpha: 0.15),
                      color: primaryColor,
                      minHeight: 3,
                    ),
                  Expanded(child: WebViewWidget(controller: _controller)),
                ],
              ),
      ),
    );
  }
}
