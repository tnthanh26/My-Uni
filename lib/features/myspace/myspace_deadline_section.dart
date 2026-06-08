import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import './models/myspace_models.dart';
import './services/moodle_service.dart';
import './services/moodle_token_storage.dart';

const Color hcmusBlueAccent = Color(0xFF5893D8);
const Color hcmusLightGrey = Color(0xFFEFEFEF);

class AutoUpdateToggle extends StatelessWidget {
  final bool isEnabled;
  final VoidCallback onTap;

  const AutoUpdateToggle({
    super.key,
    required this.isEnabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const double width = 110;
    const double height = 32;
    const double knobSize = 24;
    const Color offColor = Color(0xFF545454);
    const Color onColor = hcmusBlueAccent;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: isEnabled ? onColor : offColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Text Layer
            AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              alignment: isEnabled ? Alignment.centerLeft : Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.only(
                  left: isEnabled ? 8 : 4,
                  right: isEnabled ? 4 : 8,
                ),
                child: SizedBox(
                  width: width - knobSize - 12,
                  child: Text(
                    'Auto-update',
                    textAlign: isEnabled ? TextAlign.left : TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            // Knob Layer
            AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              alignment: isEnabled ? Alignment.centerRight : Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Container(
                  width: knobSize,
                  height: knobSize,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    isEnabled ? 'ON' : 'OFF',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class MySpaceDeadlineSection extends StatelessWidget {
  final AutoDeadlineConfig? autoDeadlineConfig;
  final List<Deadline> deadlines;
  final int totalDeadlinesCount;
  final VoidCallback onOpenAutoConfig;
  final VoidCallback onOpenDetail;
  final ValueChanged<String> onToggleDeadline;
  final ValueChanged<String> onDeleteDeadline;

  const MySpaceDeadlineSection({
    super.key,
    required this.autoDeadlineConfig,
    required this.deadlines,
    required this.totalDeadlinesCount,
    required this.onOpenAutoConfig,
    required this.onOpenDetail,
    required this.onToggleDeadline,
    required this.onDeleteDeadline,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        _DeadlineSectionHeader(
          config: autoDeadlineConfig,
          onOpenAutoConfig: onOpenAutoConfig,
          onOpenDetail: onOpenDetail,
        ),
        ...deadlines.map(
              (deadline) => _DeadlineCard(
            deadline: deadline,
            onToggleDeadline: onToggleDeadline,
            onDeleteDeadline: onDeleteDeadline,
          ),
        ),
        if (totalDeadlinesCount > deadlines.length)
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 2),
              child: Center(
                child: GestureDetector(
                  onTap: onOpenDetail,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'và ${totalDeadlinesCount - deadlines.length} deadline khác',
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w500,
                          color: isDarkMode
                              ? const Color(0xFFFFFFFF)
                              : const Color(0xFF404349),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 10,
                        color: isDarkMode ? const Color(0xFFFFFFFF) : const Color(0xFF334155),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

class MySpaceDeadlineDetailList extends StatelessWidget {
  final List<Deadline> deadlines;
  final int selectedWeekday;
  final List<Map<String, dynamic>> currentWeek;
  final ValueChanged<String> onToggleDeadline;
  final ValueChanged<String> onDeleteDeadline;
  final ValueChanged<Deadline> onEditDeadline;

  const MySpaceDeadlineDetailList({
    super.key,
    required this.deadlines,
    required this.selectedWeekday,
    required this.currentWeek,
    required this.onToggleDeadline,
    required this.onDeleteDeadline,
    required this.onEditDeadline,
  });

  @override
  Widget build(BuildContext context) {
    final selectedDate = currentWeek.firstWhere(
          (d) => d['value'] == selectedWeekday,
    )['fullDate'] as DateTime;

    final filteredDeadlines = deadlines.where((d) {
      return d.dueDate.year == selectedDate.year &&
          d.dueDate.month == selectedDate.month &&
          d.dueDate.day == selectedDate.day;
    }).toList()
      ..sort((a, b) {
        final aTime = a.dueTime.hour * 60 + a.dueTime.minute;
        final bTime = b.dueTime.hour * 60 + b.dueTime.minute;
        return aTime.compareTo(bTime);
      });

    if (filteredDeadlines.isEmpty) {
      return Center(
        child: Text(
          'Không có deadline cho ngày này!',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white70
                : Colors.black87,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: filteredDeadlines.length,
      itemBuilder: (context, index) => _DeadlineDetailCard(
        deadline: filteredDeadlines[index],
        onToggleDeadline: onToggleDeadline,
        onDeleteDeadline: onDeleteDeadline,
        onEditDeadline: onEditDeadline,
      ),
    );
  }
}

Future<void> showAutoDeadlineConfigSheet(
    BuildContext context, {
      required AutoDeadlineConfig? currentConfig,
      required Future<void> Function(AutoDeadlineConfig config) onSave,
      required Future<void> Function() onSyncNow,
    }) async {
  final baseConfig = currentConfig ?? AutoDeadlineConfig.empty(moodleUrl: '');
  final moodleUrlController = TextEditingController(text: baseConfig.moodleUrl);

  bool isEnabled = baseConfig.isEnabled;
  bool permissionRequested = baseConfig.permissionRequested;
  bool permissionGranted = baseConfig.permissionGranted;
  bool isSaving = false;
  bool isSyncing = false;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

          Future<void> saveCurrentConfig({bool closeAfterSave = false}) async {
            final moodleUrl = moodleUrlController.text.trim();
            if (isEnabled && moodleUrl.isEmpty) {
              ScaffoldMessenger.of(sheetContext).showSnackBar(
                const SnackBar(content: Text('Điền đường dẫn Moodle trước đã.')),
              );
              return;
            }

            setModalState(() { isSaving = true; });
            final config = AutoDeadlineConfig(
              isEnabled: isEnabled,
              provider: 'moodle',
              moodleUrl: moodleUrl,
              permissionRequested: permissionRequested,
              permissionGranted: permissionGranted,
              updatedAt: DateTime.now(),
            );
            await onSave(config);
            if (!sheetContext.mounted) return;
            setModalState(() { isSaving = false; });
            if (closeAfterSave) Navigator.pop(sheetContext);
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 16, right: 16, top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            color: isDarkMode ? hcmusBlueAccent.withOpacity(0.18) : const Color(0xFFEAF2FF),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.school_rounded, color: hcmusBlueAccent, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Moodle deadline sync',
                            style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Poppins',
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: isSaving || isSyncing ? null : () => Navigator.pop(sheetContext),
                          icon: Icon(Icons.close_rounded, color: isDarkMode ? Colors.white70 : Colors.black87),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cấu hình Moodle để MyUni đồng bộ upcoming events. Đăng nhập Moodle được tách riêng, mật khẩu không lưu trong app.',
                      style: TextStyle(
                        fontSize: 12, height: 1.45, fontFamily: 'Poppins',
                        color: isDarkMode ? Colors.white70 : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SwitchListTile.adaptive(
                      value: isEnabled,
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: hcmusBlueAccent,
                      title: Text(
                        'Bật tự động cập nhật deadline',
                        style: TextStyle(
                          fontFamily: 'Poppins', fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        'Đồng bộ khi mở app hoặc khi bạn bấm Sync now.',
                        style: TextStyle(
                          fontFamily: 'Poppins', fontSize: 12,
                          color: isDarkMode ? Colors.white60 : Colors.grey.shade700,
                        ),
                      ),
                      onChanged: isSaving || isSyncing ? null : (value) {
                        setModalState(() { isEnabled = value; });
                      },
                    ),
                    const SizedBox(height: 14),
                    _configLabel(context, 'Đường dẫn Moodle'),
                    const SizedBox(height: 8),
                    
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: [
                        _buildMoodlePresetChip(context, label: 'Chung', url: 'https://courses.hcmus.edu.vn', controller: moodleUrlController, setModalState: setModalState),
                        _buildMoodlePresetChip(context, label: 'FIT', url: 'https://courses.fit.hcmus.edu.vn', controller: moodleUrlController, setModalState: setModalState),
                        _buildMoodlePresetChip(context, label: 'CTDA', url: 'https://courses.ctda.hcmus.edu.vn', controller: moodleUrlController, setModalState: setModalState),
                        _buildMoodlePresetChip(context, label: 'Khác', url: '', controller: moodleUrlController,
                            setModalState: setModalState, isManual: true),
                      ],
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: moodleUrlController,
                      keyboardType: TextInputType.url,
                      onChanged: (value) => setModalState(() {}),
                      decoration: _configInputDecoration(context, 'vd: https://moodle.your-school.edu.vn'),
                    ),

                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.white.withOpacity(0.05) : const Color(0xFFF5F8FF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDarkMode ? Colors.white10 : const Color(0xFFDCE7FF)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            permissionGranted ? Icons.verified_rounded : Icons.link_off_rounded,
                            size: 18, color: permissionGranted ? const Color(0xFF448E58) : Colors.orange,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              permissionGranted
                                  ? 'Moodle đã kết nối. Bạn có thể bấm Sync now để thử đồng bộ ngay.'
                                  : 'Chưa kết nối Moodle. Bấm Connect Moodle để đăng nhập một lần và lấy token.',
                              style: TextStyle(
                                fontFamily: 'Poppins', fontSize: 12, height: 1.45,
                                color: isDarkMode ? Colors.white70 : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: permissionGranted
                                ? OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFDC2626),
                                    side: const BorderSide(color: Color(0xFFDC2626)),
                                  )
                                : null,
                            onPressed: isSaving || isSyncing ? null : () async {
                              if (permissionGranted) {
                                await MoodleTokenStorage.clearToken();
                                setModalState(() {
                                  permissionGranted = false;
                                  permissionRequested = false;
                                });
                                await saveCurrentConfig();
                                if (sheetContext.mounted) {
                                  ScaffoldMessenger.of(sheetContext).showSnackBar(const SnackBar(content: Text('Đã ngắt kết nối Moodle.')));
                                }
                                return;
                              }
                              final moodleUrl = moodleUrlController.text.trim();
                              if (moodleUrl.isEmpty) {
                                ScaffoldMessenger.of(sheetContext).showSnackBar(const SnackBar(content: Text('Điền đường dẫn Moodle trước đã.')));
                                return;
                              }
                              final connected = await showMoodleLoginDialog(sheetContext, moodleUrl: moodleUrl);
                              if (!connected) return;
                              setModalState(() {
                                permissionRequested = true;
                                permissionGranted = true;
                              });
                              await saveCurrentConfig();
                            },
                            icon: Icon(permissionGranted ? Icons.link_off_rounded : Icons.link_rounded),
                            label: Text(permissionGranted ? 'Ngắt kết nối' : 'Connect Moodle'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isSaving || isSyncing || !permissionGranted ? null : () async {
                              await saveCurrentConfig();
                              setModalState(() { isSyncing = true; });
                              await onSyncNow();
                              if (!sheetContext.mounted) return;
                              setModalState(() { isSyncing = false; });
                              ScaffoldMessenger.of(sheetContext).showSnackBar(const SnackBar(content: Text('Đã chạy đồng bộ Moodle.')));
                            },
                            icon: isSyncing
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.sync_rounded),
                            label: const Text('Sync now'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hcmusBlueAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: isSaving || isSyncing ? null : () async {
                          await saveCurrentConfig(closeAfterSave: true);
                        },
                        child: isSaving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Lưu cấu hình', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

// --- Helper Widgets & Dialogs ---

Future<bool> showMoodleLoginDialog(BuildContext context, {required String moodleUrl}) async {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  bool isConnecting = false;
  bool obscurePassword = true;

  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            titlePadding: EdgeInsets.zero,
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: isConnecting ? null : () => Navigator.pop(dialogContext, false),
                      icon: Icon(Icons.close_rounded, color: isDarkMode ? Colors.white70 : Colors.black87),
                    ),
                    const Expanded(child: Text('Kết nối Moodle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                  ],
                ),
                const Divider(height: 1),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  TextField(
                    controller: usernameController,
                    decoration: _configInputDecoration(context, 'Tên đăng nhập Moodle').copyWith(
                      prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    decoration: _configInputDecoration(context, 'Mật khẩu Moodle').copyWith(
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                      suffixIcon: IconButton(
                        onPressed: () { setDialogState(() { obscurePassword = !obscurePassword; }); },
                        icon: Icon(obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hcmusBlueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: isConnecting ? null : () async {
                    final username = usernameController.text.trim();
                    final password = passwordController.text.trim();
                    if (username.isEmpty || password.isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Điền username và password Moodle.')));
                      return;
                    }
                    setDialogState(() { isConnecting = true; });
                    final token = await MoodleService.connectAndGetToken(moodleUrl: moodleUrl, username: username, password: password);
                    if (token == null || token.trim().isEmpty) {
                      setDialogState(() { isConnecting = false; });
                      ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Không thể kết nối Moodle.')));
                      return;
                    }
                    await MoodleTokenStorage.saveToken(token);
                    if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                  },
                  child: isConnecting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Kết nối', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 4),
            ],
          );
        },
      );
    },
  );
  return result ?? false;
}

Widget _buildMoodlePresetChip(BuildContext context, {required String label, required String url, required TextEditingController controller, required StateSetter setModalState, bool isManual = false}) {
  final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
  final bool isSelected = isManual 
      ? (controller.text.isNotEmpty && !['https://courses.hcmus.edu.vn', 'https://courses.fit.hcmus.edu.vn', 'https://courses.ctda.hcmus.edu.vn'].contains(controller.text))
      : controller.text == url;

  return ChoiceChip(
    label: Text(label),
    selected: isSelected,
    onSelected: (bool selected) {
      if (selected) {
        setModalState(() {
          if (!isManual) {
            controller.text = url;
          } else if (!isSelected) {
            controller.clear();
          }
        });
      }
    },
    labelStyle: TextStyle(
      fontSize: 12, fontFamily: 'Poppins',
      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      color: isSelected ? Colors.white : (isDarkMode ? Colors.white70 : Colors.black87),
    ),
    selectedColor: hcmusBlueAccent,
    backgroundColor: isDarkMode ? const Color(0xFF2A2A2E) : const Color(0xFFF0F4F8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    side: BorderSide(color: isSelected ? hcmusBlueAccent : (isDarkMode ? Colors.white10 : Colors.black12)),
  );
}

Widget _configLabel(BuildContext context, String text) {
  final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
  return Text(
    text,
    style: TextStyle(
      fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Poppins',
      color: isDarkMode ? Colors.white : Colors.black87,
    ),
  );
}

InputDecoration _configInputDecoration(BuildContext context, String hintText) {
  final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
  return InputDecoration(
    hintText: hintText,
    hintStyle: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: isDarkMode ? Colors.white54 : null),
    filled: true,
    fillColor: isDarkMode ? const Color(0xFF23262B) : const Color(0xFFF8FAFD),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: isDarkMode ? const Color(0xFF3A3F47) : const Color(0xFFD7E1F3))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: isDarkMode ? const Color(0xFF3A3F47) : const Color(0xFFD7E1F3))),
    focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide(color: hcmusBlueAccent, width: 1.4)),
  );
}

class _DeadlineSectionHeader extends StatelessWidget {
  final AutoDeadlineConfig? config;
  final VoidCallback onOpenAutoConfig;
  final VoidCallback onOpenDetail;
  const _DeadlineSectionHeader({required this.config, required this.onOpenAutoConfig, required this.onOpenDetail});

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = config?.isEnabled ?? false;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(child: Text('Deadlines', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'Poppins', color: isDarkMode ? Colors.white : Colors.black87))),
        AutoUpdateToggle(isEnabled: isEnabled, onTap: onOpenAutoConfig),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onOpenDetail,
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: isDarkMode ? const Color(0xFF2A2A2E) : hcmusLightGrey, shape: BoxShape.circle),
            child: Icon(Icons.list_rounded, size: 18, color: isDarkMode ? Colors.white70 : Colors.black87),
          ),
        ),
      ],
    );
  }
}

class _DeadlineCard extends StatelessWidget {
  final Deadline deadline;
  final ValueChanged<String> onToggleDeadline;
  final ValueChanged<String> onDeleteDeadline;
  const _DeadlineCard({required this.deadline, required this.onToggleDeadline, required this.onDeleteDeadline});

  @override
  Widget build(BuildContext context) {
    final timeLeftData = _getTimeLeft(deadline);
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 50, margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E242B) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 3, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => onToggleDeadline(deadline.id),
            child: Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: deadline.isCompleted ? hcmusBlueAccent : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: isDarkMode ? Colors.white54 : Colors.black, width: 2),
              ),
              child: deadline.isCompleted ? const Icon(Icons.check_rounded, color: Colors.white, size: 16) : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(deadline.title, style: TextStyle(fontSize: 14, fontFamily: 'Poppins', color: isDarkMode ? Colors.white : const Color(0xFF0F172A), decoration: deadline.isCompleted ? TextDecoration.lineThrough : null))),
          SizedBox(
            width: 100,
            child: RichText(
              textAlign: TextAlign.left,
              text: TextSpan(
                style: TextStyle(fontSize: 10, fontFamily: 'Poppins', color: isDarkMode ? Colors.white70 : const Color(0xFF0F172A)),
                children: [
                  if (timeLeftData['color'] != const Color(0xFFDC2626)) const TextSpan(text: 'Còn '),
                  TextSpan(text: timeLeftData['text'].replaceAll('còn ', ''), style: TextStyle(color: timeLeftData['color'], fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 18,
            child: Align(
              alignment: Alignment.centerRight,
              child: deadline.isCompleted
                  ? IconButton(
                constraints: const BoxConstraints(), padding: EdgeInsets.zero,
                icon: SvgPicture.asset('assets/icons/trash.svg', width: 18, height: 18, colorFilter: const ColorFilter.mode(Color(0xFFFF6666), BlendMode.srcIn)),
                onPressed: () => onDeleteDeadline(deadline.id),
              )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeadlineDetailCard extends StatelessWidget {
  final Deadline deadline;
  final ValueChanged<String> onToggleDeadline;
  final ValueChanged<String> onDeleteDeadline;
  final ValueChanged<Deadline> onEditDeadline;
  const _DeadlineDetailCard({required this.deadline, required this.onToggleDeadline, required this.onDeleteDeadline, required this.onEditDeadline});


  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 15, left: 20, right: 20), height: 94,
      child: Stack(
        children: [
          Container(width: double.infinity, height: 94, decoration: BoxDecoration(color: isDarkMode ? const Color(0xFF1E242B) : const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 32, offset: const Offset(0, 4))])),
          Positioned(
            left: 14,
            top: 16,
            child: Text(
              (deadline.description == null || deadline.description!.isEmpty)
                  ? 'Không có mô tả'
                  : deadline.description!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Lexend Deca',
                fontSize: 11,
                color: isDarkMode ? Colors.white60 : const Color(0xFF6E6A7C),
              ),
            ),
          ),
          Positioned(left: 14, top: 38, child: Text(deadline.title, style: TextStyle(fontFamily: 'Lexend Deca', fontSize: 14, fontWeight: FontWeight.w400, color: isDarkMode ? Colors.white : const Color(0xFF24252C), decoration: deadline.isCompleted ? TextDecoration.lineThrough : null))),
          Positioned(left: 14, top: 64, child: Row(children: [const Icon(Icons.access_time_filled, size: 14, color: hcmusBlueAccent), const SizedBox(width: 6), Text("${deadline.dueTime.hour}:${deadline.dueTime.minute.toString().padLeft(2, '0')}", style: const TextStyle(fontFamily: 'Lexend Deca', fontSize: 11, color: hcmusBlueAccent))])),
          Positioned(right: 18, top: 12, child: GestureDetector(onTap: () => _showDeadlineActionMenu(context, deadline, onEditDeadline: onEditDeadline, onDeleteDeadline: onDeleteDeadline), child: Icon(Icons.more_horiz, color: isDarkMode ? Colors.white60 : const Color(0xFF6E6A7C), size: 20))),
          Positioned(right: 15, top: 55, child: GestureDetector(onTap: () => onToggleDeadline(deadline.id), child: Container(width: 24, height: 24, decoration: BoxDecoration(color: deadline.isCompleted ? hcmusBlueAccent : (isDarkMode ? const Color(0xFF2C2C2E) : Colors.white), shape: BoxShape.circle, border: Border.all(color: isDarkMode ? Colors.white54 : Colors.black, width: 1)), child: deadline.isCompleted ? const Icon(Icons.check, color: Colors.white, size: 16) : null))),
        ],
      ),
    );
  }
}

void _showDeadlineActionMenu(BuildContext context, Deadline deadline, {required ValueChanged<Deadline> onEditDeadline, required ValueChanged<String> onDeleteDeadline}) {
  showModalBottomSheet(
    context: context, backgroundColor: Colors.transparent,
    builder: (context) {
      final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(deadline.title, style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white70 : Colors.grey, fontFamily: 'Lexend Deca')),
            Divider(color: isDarkMode ? Colors.white12 : null),
            ListTile(leading: const Icon(Icons.edit_outlined, color: hcmusBlueAccent), title: const Text('Chỉnh sửa deadline', style: TextStyle(fontFamily: 'Lexend Deca')), onTap: () { Navigator.pop(context); onEditDeadline(deadline); }),
            ListTile(leading: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)), title: const Text('Xóa deadline', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w600, fontFamily: 'Lexend Deca')), onTap: () { Navigator.pop(context); onDeleteDeadline(deadline.id); }),
            const SizedBox(height: 10),
          ],
        ),
      );
    },
  );
}

Map<String, dynamic> _getTimeLeft(Deadline deadline) {
  final now = DateTime.now();
  final deadlineDateTime = DateTime(deadline.dueDate.year, deadline.dueDate.month, deadline.dueDate.day, deadline.dueTime.hour, deadline.dueTime.minute);
  final difference = deadlineDateTime.difference(now);
  if (difference.isNegative) return {'text': 'Quá trễ rùi', 'color': const Color(0xFFDC2626)};
  final int days = difference.inDays;
  final int hours = difference.inHours % 24;
  final int minutes = difference.inMinutes % 60;
  String timeText = '';
  if (days > 0) timeText += '$days ngày $hours giờ';
  else if (hours > 0) timeText += '$hours giờ $minutes phút';
  else timeText += '$minutes phút';
  late final Color textColor;
  if (difference.inDays < 1) textColor = const Color(0xFFDC2626);
  else if (difference.inDays < 3) textColor = const Color(0xFFEA580C);
  else textColor = const Color(0xFF448E58);
  return {'text': timeText, 'color': textColor};
}
