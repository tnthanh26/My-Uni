import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import './models/myspace_models.dart';
import './services/moodle_service.dart';
import './services/moodle_token_storage.dart';
import 'package:my_uni/utils/app_feedback.dart';

const Color hcmusBlueAccent = Color(0xFF5893D8);
const Color hcmusLightGrey = Color(0xFFEFEFEF);
const Color hcmusRed = Color(0xFFFF6868);

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
    const double width = 92;
    const double height = 30;
    const double knobSize = 22;
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
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Text Layer
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              left: isEnabled ? 8 : (knobSize + 8),
              right: isEnabled ? (knobSize + 8) : 8,
              child: Center(
                child: Text(
                  'Đồng bộ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Encode Sans Expanded',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
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
                    style: TextStyle(
                      fontFamily: 'Encode Sans Expanded',
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: isEnabled ? onColor : const Color(0xFF333333),
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
                      'xem ${totalDeadlinesCount - deadlines.length} deadline khác',
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

class MySpaceDeadlineDetailList extends StatefulWidget {
  final List<Deadline> deadlines;
  final int selectedWeekday;
  final List<Map<String, dynamic>> currentWeek;
  final ValueChanged<String> onToggleDeadline;
  final ValueChanged<String> onDeleteDeadline;
  final ValueChanged<Deadline> onEditDeadline;
  final bool initialShowAll;

  const MySpaceDeadlineDetailList({
    super.key,
    required this.deadlines,
    required this.selectedWeekday,
    required this.currentWeek,
    required this.onToggleDeadline,
    required this.onDeleteDeadline,
    required this.onEditDeadline,
    this.initialShowAll = false,
  });

  @override
  State<MySpaceDeadlineDetailList> createState() => _MySpaceDeadlineDetailListState();
}

class _MySpaceDeadlineDetailListState extends State<MySpaceDeadlineDetailList> {
  late bool _showAll;
  bool _isCompletedExpanded = false;

  @override
  void initState() {
    super.initState();
    _showAll = widget.initialShowAll;
  }

  @override
  void didUpdateWidget(covariant MySpaceDeadlineDetailList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialShowAll != oldWidget.initialShowAll) {
      _showAll = widget.initialShowAll;
    }
  }

  Widget _buildGroupSection({
    required String title,
    required List<Deadline> items,
    required Color headerColor,
    required bool isDarkMode,
    bool isCompletedSection = false,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    final bool isExpanded = isCompletedSection ? _isCompletedExpanded : true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: InkWell(
            onTap: isCompletedSection
                ? () => setState(() => _isCompletedExpanded = !_isCompletedExpanded)
                : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "$title (${items.length})",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                    color: headerColor,
                  ),
                ),
                if (isCompletedSection) ...[
                  const SizedBox(width: 4),
                  Icon(
                    _isCompletedExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: headerColor,
                    size: 18,
                  ),
                ],
              ],
            ),
          ),
        ),
        // Group Items
        if (isExpanded)
          ...items.map(
            (d) => _DeadlineDetailCard(
              deadline: d,
              onToggleDeadline: widget.onToggleDeadline,
              onDeleteDeadline: widget.onDeleteDeadline,
              onEditDeadline: widget.onEditDeadline,
              showDate: true,
            ),
          ),
      ],
    );
  }

  Widget _buildToggleAction(bool isDarkMode) {
    final Color activeColor = _showAll ? hcmusBlueAccent : hcmusRed;
    final String label = _showAll ? "Xem theo ngày" : "Xem tất cả";

    return InkWell(
      onTap: () => setState(() {
        _showAll = !_showAll;
      }),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: activeColor.withValues(alpha: isDarkMode ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(12),
          border: null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins',
                color: activeColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    Map<String, dynamic>? selectedDateMap;
    for (final d in widget.currentWeek) {
      if (d['value'] == widget.selectedWeekday) {
        selectedDateMap = d;
        break;
      }
    }
    final selectedDate = ((selectedDateMap ?? (widget.currentWeek.isNotEmpty ? widget.currentWeek.first : null))?['fullDate'] as DateTime?) ?? DateTime.now();

    final List<Deadline> filteredDeadlines = widget.deadlines.where((d) {
      return d.dueDate.year == selectedDate.year &&
          d.dueDate.month == selectedDate.month &&
          d.dueDate.day == selectedDate.day;
    }).toList()
      ..sort((a, b) {
        final aTime = a.dueTime.hour * 60 + a.dueTime.minute;
        final bTime = b.dueTime.hour * 60 + b.dueTime.minute;
        return aTime.compareTo(bTime);
      });

    // Gom nhóm cho chế độ xem Tất cả
    final List<Deadline> overdue = [];
    final List<Deadline> todayAndTomorrow = [];
    final List<Deadline> thisWeek = [];
    final List<Deadline> upcoming = [];
    final List<Deadline> completed = [];

    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime tomorrow = today.add(const Duration(days: 1));
    final DateTime oneWeekLater = today.add(const Duration(days: 7));

    for (var d in widget.deadlines) {
      if (d.isCompleted) {
        completed.add(d);
      } else {
        final dDate = DateTime(d.dueDate.year, d.dueDate.month, d.dueDate.day);
        if (dDate.isBefore(today)) {
          overdue.add(d);
        } else if (dDate == today || dDate == tomorrow) {
          todayAndTomorrow.add(d);
        } else if (dDate.isAfter(tomorrow) && dDate.isBefore(oneWeekLater)) {
          thisWeek.add(d);
        } else {
          upcoming.add(d);
        }
      }
    }

    int compareTimes(Deadline a, Deadline b) {
      final dateCompare = a.dueDate.compareTo(b.dueDate);
      if (dateCompare != 0) return dateCompare;
      final aTime = a.dueTime.hour * 60 + a.dueTime.minute;
      final bTime = b.dueTime.hour * 60 + b.dueTime.minute;
      return aTime.compareTo(bTime);
    }

    overdue.sort(compareTimes);
    todayAndTomorrow.sort(compareTimes);
    thisWeek.sort(compareTimes);
    upcoming.sort(compareTimes);
    completed.sort(compareTimes);

    return Column(
      children: [
        // Header: Title + Modern Segmented Toggle
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 4,
                      height: 18,
                      decoration: BoxDecoration(
                        color: _showAll ? hcmusRed : hcmusBlueAccent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _showAll ? "Tất cả" : "Theo ngày",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Poppins',
                          color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildToggleAction(isDarkMode),
            ],
          ),
        ),

        // List of Deadlines
        Expanded(
          child: _showAll
              ? (widget.deadlines.isEmpty
                  ? Center(
                      child: Text(
                        'Không có deadline nào!',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.only(top: 5, bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildGroupSection(
                            title: "Quá hạn",
                            items: overdue,
                            headerColor: hcmusRed,
                            isDarkMode: isDarkMode,
                          ),
                          _buildGroupSection(
                            title: "Hôm nay & Ngày mai",
                            items: todayAndTomorrow,
                            headerColor: isDarkMode ? const Color(0xFFF87171) : const Color(0xFFDC2626),
                            isDarkMode: isDarkMode,
                          ),
                          _buildGroupSection(
                            title: "Trong 7 ngày tới",
                            items: thisWeek,
                            headerColor: isDarkMode ? const Color(0xFFFB923C) : const Color(0xFFEA580C),
                            isDarkMode: isDarkMode,
                          ),
                          _buildGroupSection(
                            title: "Xa hơn (Trên 7 ngày)",
                            items: upcoming,
                            headerColor: isDarkMode ? const Color(0xFF4ADE80) : const Color(0xFF448E58),
                            isDarkMode: isDarkMode,
                          ),
                          _buildGroupSection(
                            title: "Đã hoàn thành",
                            items: completed,
                            headerColor: isDarkMode ? const Color(0xFF4ADE80) : const Color(0xFF448E58),
                            isDarkMode: isDarkMode,
                            isCompletedSection: true,
                          ),
                        ],
                      ),
                    ))
              : (filteredDeadlines.isEmpty
                  ? Center(
                      child: Text(
                        'Không có deadline cho ngày này!',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 10, bottom: 20),
                      itemCount: filteredDeadlines.length,
                      itemBuilder: (context, index) => _DeadlineDetailCard(
                        deadline: filteredDeadlines[index],
                        onToggleDeadline: widget.onToggleDeadline,
                        onDeleteDeadline: widget.onDeleteDeadline,
                        onEditDeadline: widget.onEditDeadline,
                        showDate: false,
                      ),
                    )),
        ),
      ],
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
              AppFeedback.showWarning(sheetContext, 'Điền đường dẫn Moodle trước đã.');
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
                                  isEnabled = false;
                                });
                                await saveCurrentConfig();
                                if (sheetContext.mounted) {
                                  AppFeedback.showInfo(sheetContext, 'Đã ngắt kết nối Moodle.');
                                }
                                return;
                              }
                              final moodleUrl = moodleUrlController.text.trim();
                              if (moodleUrl.isEmpty) {
                                AppFeedback.showWarning(sheetContext, 'Điền đường dẫn Moodle trước đã.');
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
                              AppFeedback.showSuccess(sheetContext, 'Đã chạy đồng bộ Moodle.');
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

Future<bool> showMoodleLoginDialog(
    BuildContext context, {
      required String moodleUrl,
    }) async {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  bool isConnecting = false;
  bool obscurePassword = true;

  final bool? result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final bool isDarkMode =
              Theme.of(context).brightness == Brightness.dark;

          final Color surfaceColor = isDarkMode
              ? const Color(0xFF1C1E21)
              : Colors.white;

          final Color primaryTextColor = isDarkMode
              ? Colors.white
              : const Color(0xFF1D2939);

          final Color secondaryTextColor = isDarkMode
              ? Colors.white60
              : const Color(0xFF667085);

          final Color borderColor = isDarkMode
              ? Colors.white.withValues(alpha: 0.10)
              : const Color(0xFFE4E7EC);

          final Color fieldColor = isDarkMode
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFF7F9FC);

          Future<void> handleConnect() async {
            final String username =
            usernameController.text.trim();

            final String password =
            passwordController.text.trim();

            if (username.isEmpty || password.isEmpty) {
              AppFeedback.showWarning(
                dialogContext,
                'Vui lòng nhập đầy đủ tên đăng nhập và mật khẩu.',
              );
              return;
            }

            FocusScope.of(dialogContext).unfocus();

            setDialogState(() {
              isConnecting = true;
            });

            try {
              final token =
              await MoodleService.connectAndGetToken(
                moodleUrl: moodleUrl,
                username: username,
                password: password,
              );

              if (token == null ||
                  token.trim().isEmpty) {
                if (!dialogContext.mounted) return;

                setDialogState(() {
                  isConnecting = false;
                });

                AppFeedback.showError(
                  dialogContext,
                  'Không thể kết nối Moodle. Vui lòng kiểm tra lại thông tin đăng nhập.',
                );
                return;
              }

              await MoodleTokenStorage.saveToken(token);

              if (dialogContext.mounted) {
                Navigator.pop(dialogContext, true);
              }
            } catch (e) {
              if (!dialogContext.mounted) return;

              setDialogState(() {
                isConnecting = false;
              });

              AppFeedback.showError(
                dialogContext,
                'Đã xảy ra lỗi khi kết nối Moodle.',
              );
            }
          }

          InputDecoration buildInputDecoration({
            required String label,
            required String hint,
            required IconData prefixIcon,
            Widget? suffixIcon,
          }) {
            return InputDecoration(
              labelText: label,
              hintText: hint,
              filled: true,
              fillColor: fieldColor,
              prefixIcon: Icon(
                prefixIcon,
                size: 20,
                color: secondaryTextColor,
              ),
              suffixIcon: suffixIcon,
              labelStyle: TextStyle(
                fontFamily: 'Encode Sans Expanded',
                fontSize: 12,
                color: secondaryTextColor,
              ),
              floatingLabelStyle: const TextStyle(
                fontFamily: 'Encode Sans Expanded',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: hcmusBlueAccent,
              ),
              hintStyle: TextStyle(
                fontFamily: 'Encode Sans Expanded',
                fontSize: 12,
                color: isDarkMode
                    ? Colors.white30
                    : const Color(0xFF98A2B3),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 15,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: borderColor,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: borderColor,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: hcmusBlueAccent,
                  width: 1.5,
                ),
              ),
            );
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            child: Container(
              constraints: const BoxConstraints(
                maxWidth: 420,
              ),
              padding: const EdgeInsets.fromLTRB(
                20,
                16,
                20,
                20,
              ),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: borderColor,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: isDarkMode ? 0.30 : 0.10,
                    ),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Kết nối Moodle',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: primaryTextColor,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Đóng',
                          splashRadius: 20,
                          onPressed: isConnecting
                              ? null
                              : () {
                            Navigator.pop(
                              dialogContext,
                              false,
                            );
                          },
                          icon: Icon(
                            Icons.close_rounded,
                            size: 21,
                            color: isConnecting
                                ? secondaryTextColor.withValues(
                              alpha: 0.40,
                            )
                                : secondaryTextColor,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    Text(
                      'Đăng nhập bằng tài khoản Moodle của trường để đồng bộ deadline và dữ liệu học tập.',
                      style: TextStyle(
                        fontFamily: 'Encode Sans Expanded',
                        fontSize: 12.5,
                        height: 1.5,
                        color: secondaryTextColor,
                      ),
                    ),

                    const SizedBox(height: 20),

                    TextField(
                      controller: usernameController,
                      enabled: !isConnecting,
                      textInputAction:
                      TextInputAction.next,
                      autofillHints: const [
                        AutofillHints.username,
                      ],
                      style: TextStyle(
                        fontFamily:
                        'Encode Sans Expanded',
                        fontSize: 13,
                        color: primaryTextColor,
                      ),
                      decoration: buildInputDecoration(
                        label: 'Tên đăng nhập',
                        hint: 'Nhập tên đăng nhập Moodle',
                        prefixIcon:
                        Icons.person_outline_rounded,
                      ),
                    ),

                    const SizedBox(height: 14),

                    TextField(
                      controller: passwordController,
                      enabled: !isConnecting,
                      obscureText: obscurePassword,
                      textInputAction:
                      TextInputAction.done,
                      autofillHints: const [
                        AutofillHints.password,
                      ],
                      onSubmitted: (_) {
                        if (!isConnecting) {
                          handleConnect();
                        }
                      },
                      style: TextStyle(
                        fontFamily:
                        'Encode Sans Expanded',
                        fontSize: 13,
                        color: primaryTextColor,
                      ),
                      decoration: buildInputDecoration(
                        label: 'Mật khẩu',
                        hint: 'Nhập mật khẩu Moodle',
                        prefixIcon:
                        Icons.lock_outline_rounded,
                        suffixIcon: IconButton(
                          tooltip: obscurePassword
                              ? 'Hiện mật khẩu'
                              : 'Ẩn mật khẩu',
                          splashRadius: 18,
                          onPressed: isConnecting
                              ? null
                              : () {
                            setDialogState(() {
                              obscurePassword =
                              !obscurePassword;
                            });
                          },
                          icon: Icon(
                            obscurePassword
                                ? Icons
                                .visibility_off_outlined
                                : Icons
                                .visibility_outlined,
                            size: 20,
                            color: secondaryTextColor,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: hcmusBlueAccent.withValues(
                          alpha: isDarkMode ? 0.12 : 0.07,
                        ),
                        borderRadius:
                        BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 1),
                            child: Icon(
                              Icons
                                  .shield_outlined,
                              size: 17,
                              color: hcmusBlueAccent,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'MyUni chỉ sử dụng thông tin này để kết nối và đồng bộ dữ liệu. Mật khẩu không được lưu trên máy chủ của ứng dụng.',
                              style: TextStyle(
                                fontFamily:
                                'Encode Sans Expanded',
                                fontSize: 11.5,
                                height: 1.45,
                                color: isDarkMode
                                    ? Colors.white70
                                    : const Color(
                                  0xFF475467,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: FilledButton.icon(
                        onPressed: isConnecting
                            ? null
                            : handleConnect,
                        icon: isConnecting
                            ? const SizedBox(
                          width: 17,
                          height: 17,
                          child:
                          CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Icon(
                          Icons.link_rounded,
                          size: 18,
                        ),
                        label: Text(
                          isConnecting
                              ? 'Đang kết nối...'
                              : 'Kết nối Moodle',
                          style: const TextStyle(
                            fontFamily:
                            'Encode Sans Expanded',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor:
                          hcmusBlueAccent,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                          hcmusBlueAccent.withValues(
                            alpha: 0.55,
                          ),
                          disabledForegroundColor:
                          Colors.white,
                          elevation: 0,
                          shape:
                          RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(12),
                          ),
                        ),
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

  usernameController.dispose();
  passwordController.dispose();

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
            child: Icon(Icons.calendar_month_rounded, size: 18, color: isDarkMode ? Colors.white70 : Colors.black87),
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
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final timeLeftData = _getTimeLeft(deadline, isDarkMode);
    return Container(
      height: 50, margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2C3A4D) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4, offset: const Offset(0, 3))],
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
          Expanded(
            child: Text(
              deadline.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'Poppins',
                color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                decoration: deadline.isCompleted ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          Container(
            height: 18,
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: isDarkMode ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
          ),
          SizedBox(
            width: 100,
            child: RichText(
              textAlign: TextAlign.left,
              text: TextSpan(
                style: TextStyle(fontSize: 10, fontFamily: 'Poppins', color: isDarkMode ? Colors.white70 : const Color(0xFF0F172A)),
                children: [
                  if (timeLeftData['text'] == 'Quá trễ rùi')
                    const TextSpan(text: 'Còn ', style: TextStyle(color: Colors.transparent)),
                  if (timeLeftData['text'] != 'Quá trễ rùi')
                    const TextSpan(text: 'Còn '),
                  TextSpan(
                    text: timeLeftData['text'].replaceAll('còn ', ''),
                    style: TextStyle(color: timeLeftData['color'], fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          if (deadline.isCompleted) ...[
            SizedBox(
              width: 18,
              child: Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  icon: SvgPicture.asset(
                    'assets/icons/trash.svg',
                    width: 18,
                    height: 18,
                    colorFilter: const ColorFilter.mode(Color(0xFFFF6666), BlendMode.srcIn),
                  ),
                  onPressed: () => onDeleteDeadline(deadline.id),
                ),
              ),
            ),
          ] else
            const SizedBox(width: 18),
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
  final bool showDate;

  const _DeadlineDetailCard({
    required this.deadline,
    required this.onToggleDeadline,
    required this.onDeleteDeadline,
    required this.onEditDeadline,
    this.showDate = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 22, left: 20, right: 20), height: 94,
      child: Stack(
        children: [
          Container(width: double.infinity, height: 94, decoration: BoxDecoration(color: isDarkMode ? const Color(0xFF2C3A4D) : const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 32, offset: const Offset(0, 4))])),
          Positioned(
            left: 14,
            top: 14,
            right: 48,
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
          Positioned(
            left: 14,
            top: 36,
            right: 48,
            child: Text(
              deadline.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Lexend Deca',
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: isDarkMode ? Colors.white : const Color(0xFF24252C),
                decoration: deadline.isCompleted ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          Positioned(
            left: 14,
            top: 64,
            child: Row(
              children: [
                const Icon(Icons.access_time_filled, size: 14, color: hcmusBlueAccent),
                const SizedBox(width: 6),
                Text(
                  showDate
                      ? "${deadline.dueTime.hour}:${deadline.dueTime.minute.toString().padLeft(2, '0')} - ${deadline.dueDate.day.toString().padLeft(2, '0')}/${deadline.dueDate.month.toString().padLeft(2, '0')}"
                      : "${deadline.dueTime.hour}:${deadline.dueTime.minute.toString().padLeft(2, '0')}",
                  style: const TextStyle(fontFamily: 'Lexend Deca', fontSize: 11, color: hcmusBlueAccent),
                ),
              ],
            ),
          ),
          Positioned(right: 18, top: 8, child: GestureDetector(onTap: () => _showDeadlineActionMenu(context, deadline, onEditDeadline: onEditDeadline, onDeleteDeadline: onDeleteDeadline), child: Icon(Icons.more_horiz, color: isDarkMode ? Colors.white60 : const Color(0xFF6E6A7C), size: 20))),
          Positioned(right: 15, top: 58, child: GestureDetector(onTap: () => onToggleDeadline(deadline.id), child: Container(width: 24, height: 24, decoration: BoxDecoration(color: deadline.isCompleted ? hcmusBlueAccent : (isDarkMode ? const Color(0xFF2C2C2E) : Colors.white), shape: BoxShape.circle, border: Border.all(color: isDarkMode ? Colors.white54 : Colors.black, width: 1)), child: deadline.isCompleted ? const Icon(Icons.check, color: Colors.white, size: 16) : null))),
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
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: hcmusBlueAccent), 
              title: Text('Chỉnh sửa deadline', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87, fontFamily: 'Lexend Deca')),
              onTap: () { Navigator.pop(context); onEditDeadline(deadline); },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)), 
              title: Text('Xóa deadline', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87, fontFamily: 'Lexend Deca')),
              onTap: () { Navigator.pop(context); onDeleteDeadline(deadline.id); },
            ),
            const SizedBox(height: 10),

          ],
        ),
      );
    },
  );
}

Map<String, dynamic> _getTimeLeft(Deadline deadline, bool isDarkMode) {
  final now = DateTime.now();
  final deadlineDateTime = DateTime(deadline.dueDate.year, deadline.dueDate.month, deadline.dueDate.day, deadline.dueTime.hour, deadline.dueTime.minute);
  final difference = deadlineDateTime.difference(now);
  if (difference.isNegative) {
    return {
      'text': 'Quá trễ rùi', 
      'color': isDarkMode ? const Color(0xFFF87171) : const Color(0xFFDC2626)
    };
  }
  final int days = difference.inDays;
  final int hours = difference.inHours % 24;
  final int minutes = difference.inMinutes % 60;
  String timeText = '';
  if (days > 0) timeText += '$days ngày $hours giờ';
  else if (hours > 0) timeText += '$hours giờ $minutes phút';
  else timeText += '$minutes phút';
  late final Color textColor;
  if (difference.inDays < 1) {
    textColor = isDarkMode ? const Color(0xFFF87171) : const Color(0xFFDC2626);
  } else if (difference.inDays < 3) {
    textColor = isDarkMode ? const Color(0xFFFB923C) : const Color(0xFFEA580C);
  } else {
    textColor = isDarkMode ? const Color(0xFF4ADE80) : const Color(0xFF448E58);
  }
  return {'text': timeText, 'color': textColor};
}

Future<bool?> showMoodlePolicyDialog(BuildContext context) async {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
      return Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header bar indicator (gray pill)
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 10),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: isDarkMode ? hcmusBlueAccent.withValues(alpha: 0.18) : const Color(0xFFEAF2FF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.description_rounded, color: hcmusBlueAccent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Chính sách đồng bộ',
                        style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Poppins',
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext, false),
                      icon: Icon(Icons.close_rounded, color: isDarkMode ? Colors.white70 : Colors.black87),
                    ),
                  ],
                ),
              ),
              const Divider(height: 16),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      // Title: Đồng bộ Deadline từ Moodle
                      Text(
                        'Đồng bộ Deadline từ Moodle',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                          color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Subtitle: Tự động cập nhật deadline học tập
                      Text(
                        'Tự động cập nhật deadline học tập',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Poppins',
                          color: hcmusBlueAccent,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Introduction text
                      Text(
                        'Tính năng này giúp MyUni tự động lấy các bài tập và deadline từ hệ thống Moodle của trường để hiển thị trong ứng dụng, giúp bạn không cần tạo deadline thủ công.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          fontFamily: 'Poppins',
                          color: isDarkMode ? Colors.white70 : Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Warning box
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.orange.withValues(alpha: 0.1) : const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDarkMode ? Colors.orange.withValues(alpha: 0.3) : const Color(0xFFFED7AA)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    height: 1.45,
                                    fontFamily: 'Poppins',
                                    color: isDarkMode ? Colors.white70 : Colors.grey.shade800,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: 'Lưu ý: ',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade800),
                                    ),
                                    const TextSpan(
                                      text: 'Tính năng này chỉ hoạt động nếu trường hoặc chương trình đào tạo của bạn sử dụng Moodle để quản lý bài tập và thời hạn nộp. Nếu chương trình học của bạn không sử dụng Moodle, bạn vẫn có thể quản lý deadline bằng cách tạo thủ công trong MyUni.',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Section: Cách hoạt động
                      _buildSectionHeader(context, 'Cách hoạt động', Icons.alt_route_rounded),
                      const SizedBox(height: 12),
                      _buildStepItem(context, '1', 'Chọn địa chỉ Moodle của trường hoặc nhập đường dẫn Moodle.'),
                      _buildStepItem(context, '2', 'Đăng nhập bằng tài khoản Moodle của bạn.'),
                      _buildStepItem(context, '3', 'Sau khi đăng nhập thành công, MyUni sẽ nhận access token từ Moodle để đồng bộ dữ liệu.'),
                      _buildStepItem(context, '4', 'Những lần đồng bộ sau sẽ sử dụng token này, bạn không cần đăng nhập lại trừ khi token hết hạn hoặc bị thu hồi.'),
                      const SizedBox(height: 20),
                      // Section: Quyền riêng tư & Bảo mật
                      _buildSectionHeader(context, '🔒 Quyền riêng tư & Bảo mật', Icons.security_rounded),
                      const SizedBox(height: 12),
                      _buildPolicyPoint(context, '🔒 MyUni không lưu mật khẩu Moodle của bạn.', isTitle: true),
                      _buildPolicyPoint(context, 'Mật khẩu chỉ được sử dụng trong quá trình đăng nhập với Moodle để lấy access token.'),
                      _buildPolicyPoint(context, 'Sau khi đăng nhập thành công, ứng dụng chỉ lưu access token cần thiết để đồng bộ deadline.'),
                      _buildPolicyPoint(context, 'Bạn có thể ngắt kết nối hoặc đăng nhập lại bất cứ lúc nào.'),
                      _buildPolicyPoint(context, 'Token chỉ được sử dụng để đọc các thông tin cần thiết phục vụ việc đồng bộ deadline và không được sử dụng cho bất kỳ mục đích nào khác.'),
                      const SizedBox(height: 20),
                      // Section: Bạn đồng ý tiếp tục?
                      _buildSectionHeader(context, 'Bạn đồng ý tiếp tục?', Icons.help_outline_rounded),
                      const SizedBox(height: 12),
                      Text(
                        'Bằng việc tiếp tục, bạn xác nhận rằng:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Poppins',
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildBulletPoint(context, 'Bạn đã đọc và hiểu cách hoạt động của tính năng.'),
                      _buildBulletPoint(context, 'Bạn đồng ý đăng nhập Moodle để MyUni lấy access token phục vụ việc đồng bộ deadline.'),
                      _buildBulletPoint(context, 'Bạn đã đọc và hiểu chính sách bảo mật của tính năng này.'),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              // Footer Buttons
              const Divider(height: 16),
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 16, top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          side: BorderSide(color: isDarkMode ? Colors.white30 : Colors.black26),
                        ),
                        onPressed: () => Navigator.pop(sheetContext, false),
                        child: Text(
                          'Quay lại',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hcmusBlueAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () => Navigator.pop(sheetContext, true),
                        child: const Text(
                          'Tiếp tục',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _buildSectionHeader(BuildContext context, String text, IconData icon) {
  final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
  return Row(
    children: [
      Icon(icon, size: 18, color: hcmusBlueAccent),
      const SizedBox(width: 8),
      Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          fontFamily: 'Poppins',
          color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
        ),
      ),
    ],
  );
}

Widget _buildStepItem(BuildContext context, String number, String text) {
  final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
  return Padding(
    padding: const EdgeInsets.only(bottom: 10.0, left: 4.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.only(top: 2.0),
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: hcmusBlueAccent,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              fontFamily: 'Poppins',
              color: isDarkMode ? Colors.white70 : Colors.grey.shade800,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildPolicyPoint(BuildContext context, String text, {bool isTitle = false}) {
  final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
  return Padding(
    padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isTitle)
          const Padding(
            padding: EdgeInsets.only(top: 6.0),
            child: Icon(Icons.circle, size: 5, color: hcmusBlueAccent),
          ),
        if (!isTitle) const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              fontWeight: isTitle ? FontWeight.w600 : FontWeight.normal,
              fontFamily: 'Poppins',
              color: isTitle 
                  ? (isDarkMode ? Colors.white : Colors.black87)
                  : (isDarkMode ? Colors.white70 : Colors.grey.shade800),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildBulletPoint(BuildContext context, String text) {
  final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
  return Padding(
    padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 3.0),
          child: Icon(Icons.check_circle_outline_rounded, size: 15, color: hcmusBlueAccent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              fontFamily: 'Poppins',
              color: isDarkMode ? Colors.white70 : Colors.grey.shade800,
            ),
          ),
        ),
      ],
    ),
  );
}
