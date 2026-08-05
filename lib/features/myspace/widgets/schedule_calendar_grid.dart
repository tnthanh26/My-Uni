import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_uni/models/event_model.dart';
import '../models/myspace_models.dart';

/// Standalone 24-hour Schedule Calendar Grid widget for MySpace.
/// Isolated with [RepaintBoundary] so that parent setState calls
/// do not trigger costly rebuilds/repaints of the entire grid timeline.
class ScheduleCalendarGrid extends StatefulWidget {
  final DateTime focusedDate;
  final int selectedWeekday;
  final List<StudyClass> dayClasses;
  final List<EventModel> dayEvents;
  final Function(StudyClass) onScheduleTap;
  final Function(EventModel) onEventTap;
  final ScrollController? scrollController;

  const ScheduleCalendarGrid({
    super.key,
    required this.focusedDate,
    required this.selectedWeekday,
    required this.dayClasses,
    required this.dayEvents,
    required this.onScheduleTap,
    required this.onEventTap,
    this.scrollController,
  });

  @override
  State<ScheduleCalendarGrid> createState() => _ScheduleCalendarGridState();
}

class _ScheduleCalendarGridState extends State<ScheduleCalendarGrid> {
  ScrollController? _internalController;
  static const double _hourHeight = 64.0;

  ScrollController get _activeController =>
      widget.scrollController ??
      (_internalController ??= ScrollController(
        initialScrollOffset: _calculateInitialOffset(),
      ));

  double _calculateInitialOffset() {
    final sortedClasses = List<StudyClass>.from(widget.dayClasses)
      ..sort((a, b) => a.startHourFraction.compareTo(b.startHourFraction));

    final sortedEvents = List<EventModel>.from(widget.dayEvents)
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    final List<double> startHours = [];

    if (sortedClasses.isNotEmpty) {
      startHours.add(sortedClasses.first.startHourFraction);
    }

    if (sortedEvents.isNotEmpty) {
      final event = sortedEvents.first;
      startHours.add(event.dateTime.hour + event.dateTime.minute / 60.0);
    }

    double targetHour = 7.0;

    if (startHours.isNotEmpty) {
      startHours.sort();
      targetHour = math.max(0.0, startHours.first - 0.5);
    }

    return targetHour * _hourHeight;
  }

  @override
  void initState() {
    super.initState();
    if (widget.scrollController == null) {
      _internalController = ScrollController(
        initialScrollOffset: _calculateInitialOffset(),
      );
    }
  }

  @override
  void didUpdateWidget(covariant ScheduleCalendarGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool dateChanged = !DateUtils.isSameDay(
      oldWidget.focusedDate,
      widget.focusedDate,
    );

    if (dateChanged && widget.scrollController == null) {
      _internalController?.dispose();
      _internalController = ScrollController(
        initialScrollOffset: _calculateInitialOffset(),
      );
    }
  }

  @override
  void dispose() {
    _internalController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final dayClasses = List<StudyClass>.from(widget.dayClasses)
      ..sort((a, b) => a.startHourFraction.compareTo(b.startHourFraction));

    final dayEvents = List<EventModel>.from(widget.dayEvents)
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    const double hourHeight = 64.0;
    const int startHourGrid = 0; // Từ 00:00 sáng
    const int totalHours = 24;   // 00:00 đến 23:00 (đủ 24 tiếng)
    const double gridTopOffset = 8.0;

    final now = DateTime.now();
    final String currentTimeText = DateFormat('HH:mm').format(now);
    final isTodaySelected = widget.focusedDate.year == now.year &&
        widget.focusedDate.month == now.month &&
        widget.focusedDate.day == now.day;
    final currentHourFraction = now.hour + (now.minute / 60.0);
    final showNowLine = isTodaySelected && currentHourFraction >= 0.0 && currentHourFraction <= 24.0;
    final double nowTop = (currentHourFraction - startHourGrid) * hourHeight + gridTopOffset;

    return RepaintBoundary(
      child: SingleChildScrollView(
        controller: _activeController,
        physics: const ClampingScrollPhysics(),
        child: Container(
          padding: const EdgeInsets.only(top: 12, bottom: 24, left: 12, right: 16),
          child: Stack(
            children: [
              // Background Hour Grid Lines
              Column(
                children: List.generate(totalHours, (index) {
                  final hour = startHourGrid + index;
                  final timeText = "${hour.toString().padLeft(2, '0')}:00";
                  return SizedBox(
                    height: hourHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 50,
                          child: Text(
                            timeText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? Colors.white38 : Colors.black45,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.only(top: 8),
                            height: 1,
                            color: isDarkMode ? Colors.white12 : Colors.black12,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),

              // Empty State Watermark
              if (dayClasses.isEmpty && dayEvents.isEmpty)
                Positioned(
                  top: 120,
                  left: 60,
                  right: 20,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: (isDarkMode ? Colors.black26 : Colors.white).withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDarkMode ? Colors.white12 : Colors.black12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.event_available, color: isDarkMode ? Colors.white54 : Colors.black45),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              DateUtils.isSameDay(widget.focusedDate, DateTime.now())
                                  ? 'Hôm nay không có lịch học hoặc sự kiện'
                                  : 'Ngày này không có lịch học hoặc sự kiện',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isDarkMode ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Class Blocks Positioned by Start & End Time (Google Calendar Solid Fill Style)
              ...dayClasses.map((c) {
                final startH = StudyClass.parseTimeToHourFraction(c.start);
                var endH = StudyClass.parseTimeToHourFraction(c.end);
                if (endH <= startH) endH = startH + 1.5;

                final topPos = (startH - startHourGrid) * hourHeight + gridTopOffset;
                final blockHeight = math.max(48.0, (endH - startH) * hourHeight - 4);

                final Color cardColor = isDarkMode
                    ? Color.alphaBlend(Colors.black.withValues(alpha: 0.15), c.color)
                    : c.color;

                return Positioned(
                  top: topPos,
                  left: 56.0,
                  right: 0.0,
                  height: blockHeight,
                  child: GestureDetector(
                    onTap: () => widget.onScheduleTap(c),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            c.name,
                            maxLines: blockHeight < 55 ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              fontFamily: 'Poppins',
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 12,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "${c.start} - ${c.end}",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                              if (c.room.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Text(
                                  "• ${c.room.startsWith('Phòng') ? c.room : 'Phòng ${c.room}'}",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.95),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              // Event Blocks Positioned by Event Start Time (Vibrant Purple Style)
              ...dayEvents.map((ev) {
                final startH = ev.dateTime.hour + (ev.dateTime.minute / 60.0);
                final topPos = (startH - startHourGrid) * hourHeight + gridTopOffset;

                double blockHeight = 60.0;
                if (ev.endDateTime != null) {
                  var endH = ev.endDateTime!.hour + (ev.endDateTime!.minute / 60.0);
                  if (endH <= startH) endH = startH + 1.0;
                  blockHeight = math.max(48.0, (endH - startH) * hourHeight - 4);
                }

                final bool isInterested = ev.isFromFacultyEvent;
                final Color eventBgColor = isInterested
                    ? (isDarkMode
                        ? const Color(0xFF426C93)
                        : const Color(0xFF5F8FB8))
                    : (isDarkMode
                        ? const Color(0xFF55508A)
                        : const Color(0xFF7D74B2));

                final String eventTagText = isInterested ? 'QUAN TÂM' : 'SỰ KIỆN';

                final String timeStr = ev.endDateTime != null
                    ? "${DateFormat('HH:mm').format(ev.dateTime)} - ${DateFormat('HH:mm').format(ev.endDateTime!)}"
                    : DateFormat('HH:mm').format(ev.dateTime);

                return Positioned(
                  top: topPos,
                  left: 56.0,
                  right: 0.0,
                  height: blockHeight,
                  child: GestureDetector(
                    onTap: () => widget.onEventTap(ev),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: eventBgColor,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.14),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        ev.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.white24,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        eventTagText,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time_rounded,
                                      size: 11,
                                      color: Colors.white.withValues(alpha: 0.85),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      timeStr,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white.withValues(alpha: 0.85),
                                      ),
                                    ),
                                    if (ev.location.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          "• ${ev.location}",
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.white.withValues(alpha: 0.9),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              // Red Current Time Line Indicator (Apple Calendar Style)
              if (showNowLine)
                Positioned(
                  top: nowTop - 6,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 50,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? const Color(0xFFFF453A)
                                    : const Color(0xFFFF3B30),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                currentTimeText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  height: 1.2,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Nunito',
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: isDarkMode
                                ? const Color(0xFFFF453A)
                                : const Color(0xFFFF3B30),
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
    );
  }
}
