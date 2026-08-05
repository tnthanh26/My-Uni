import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_uni/models/event_model.dart';
import '../models/myspace_models.dart';

enum _TimelineItemType { studyClass, personalEvent, interestedEvent }

class _TimelineItem {
  final String id;
  final String title;
  final double startHourFraction;
  final double endHourFraction;
  final String timeRangeText;
  final String location;
  final Color color;
  final _TimelineItemType type;
  final StudyClass? rawClass;
  final EventModel? rawEvent;

  _TimelineItem({
    required this.id,
    required this.title,
    required this.startHourFraction,
    required this.endHourFraction,
    required this.timeRangeText,
    required this.location,
    required this.color,
    required this.type,
    this.rawClass,
    this.rawEvent,
  });

  int get priorityRank {
    switch (type) {
      case _TimelineItemType.studyClass:
        return 1;
      case _TimelineItemType.personalEvent:
        return 2;
      case _TimelineItemType.interestedEvent:
        return 3;
    }
  }

  double get duration => endHourFraction - startHourFraction;
}

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

    double targetHour = 10.0; // Mặc định 10:00 AM cho ngày trống

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

    // Build timeline items
    final List<_TimelineItem> items = [];

    for (final c in widget.dayClasses) {
      final startH = StudyClass.parseTimeToHourFraction(c.start);
      var endH = StudyClass.parseTimeToHourFraction(c.end);
      if (endH <= startH) endH = startH + 1.5;

      final Color cardColor = isDarkMode
          ? Color.alphaBlend(Colors.black.withValues(alpha: 0.15), c.color)
          : c.color;

      items.add(
        _TimelineItem(
          id: 'class_${c.id}',
          title: c.name,
          startHourFraction: startH,
          endHourFraction: endH,
          timeRangeText: '${c.start} - ${c.end}',
          location: c.room.isNotEmpty ? (c.room.startsWith('Phòng') ? c.room : 'Phòng ${c.room}') : '',
          color: cardColor,
          type: _TimelineItemType.studyClass,
          rawClass: c,
        ),
      );
    }

    for (final ev in widget.dayEvents) {
      final startH = ev.dateTime.hour + (ev.dateTime.minute / 60.0);
      var endH = startH + 1.5;
      if (ev.endDateTime != null) {
        final parsedEndH = ev.endDateTime!.hour + (ev.endDateTime!.minute / 60.0);
        if (parsedEndH > startH) endH = parsedEndH;
      }

      final isPersonal = !ev.isFromFacultyEvent;
      final Color cardColor = isPersonal
          ? (isDarkMode ? const Color(0xFF55508A) : const Color(0xFF7D74B2))
          : (isDarkMode ? const Color(0xFF426C93) : const Color(0xFF5F8FB8));

      final String timeText = ev.endDateTime != null
          ? "${DateFormat('HH:mm').format(ev.dateTime)} - ${DateFormat('HH:mm').format(ev.endDateTime!)}"
          : DateFormat('HH:mm').format(ev.dateTime);

      items.add(
        _TimelineItem(
          id: 'event_${ev.id}',
          title: ev.title,
          startHourFraction: startH,
          endHourFraction: endH,
          timeRangeText: timeText,
          location: ev.location,
          color: cardColor,
          type: isPersonal ? _TimelineItemType.personalEvent : _TimelineItemType.interestedEvent,
          rawEvent: ev,
        ),
      );
    }

    // Sort items by priority, start time, and duration
    items.sort((a, b) {
      if (a.startHourFraction != b.startHourFraction) {
        return a.startHourFraction.compareTo(b.startHourFraction);
      }
      if (a.priorityRank != b.priorityRank) {
        return a.priorityRank.compareTo(b.priorityRank);
      }
      return b.duration.compareTo(a.duration);
    });

    // Group items into overlapping cluster buckets
    final List<List<_TimelineItem>> clusters = [];

    for (final item in items) {
      bool added = false;
      for (final cluster in clusters) {
        final bool overlaps = cluster.any((cItem) {
          return item.startHourFraction < cItem.endHourFraction &&
                 item.endHourFraction > cItem.startHourFraction;
        });

        if (overlaps) {
          cluster.add(item);
          added = true;
          break;
        }
      }

      if (!added) {
        clusters.add([item]);
      }
    }

    return RepaintBoundary(
      child: SingleChildScrollView(
        controller: _activeController,
        physics: const ClampingScrollPhysics(),
        child: Container(
          padding: const EdgeInsets.only(top: 12, bottom: 24, left: 12, right: 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double availableWidth = math.max(0.0, constraints.maxWidth - 56.0);

              final List<Widget> positionedCards = [];

              for (final cluster in clusters) {
                // Sort items in cluster by priority rank (Class -> Personal Event -> Interested Event)
                cluster.sort((a, b) {
                  if (a.priorityRank != b.priorityRank) {
                    return a.priorityRank.compareTo(b.priorityRank);
                  }
                  if (a.startHourFraction != b.startHourFraction) {
                    return a.startHourFraction.compareTo(b.startHourFraction);
                  }
                  return b.duration.compareTo(a.duration);
                });

                final int count = cluster.length;
                final double minStartH = cluster.map((e) => e.startHourFraction).reduce(math.min);
                final double maxEndH = cluster.map((e) => e.endHourFraction).reduce(math.max);

                if (count <= 2) {
                  final double colWidth = math.max(0.0, (availableWidth - (count - 1) * 4.0) / count);

                  for (int i = 0; i < count; i++) {
                    final item = cluster[i];
                    final double topPos = (item.startHourFraction - startHourGrid) * hourHeight + gridTopOffset;
                    final double blockHeight = math.max(48.0, (item.endHourFraction - item.startHourFraction) * hourHeight - 4);
                    final double leftPos = 56.0 + i * (colWidth + 4.0);

                    positionedCards.add(
                      Positioned(
                        top: topPos,
                        left: leftPos,
                        width: colWidth,
                        height: blockHeight,
                        child: _buildItemCard(context, item, isDarkMode, blockHeight),
                      ),
                    );
                  }
                } else {
                  // 3+ items: 1 priority item + 1 summary overflow card (+ (count - 1) mục khác)
                  const int maxVisibleCols = 2;
                  final double colWidth = math.max(0.0, (availableWidth - (maxVisibleCols - 1) * 4.0) / maxVisibleCols);

                  // Col 0: 1 priority item
                  final item = cluster[0];
                  final double topPos = (item.startHourFraction - startHourGrid) * hourHeight + gridTopOffset;
                  final double blockHeight = math.max(48.0, (item.endHourFraction - item.startHourFraction) * hourHeight - 4);
                  final double leftPos = 56.0;

                  positionedCards.add(
                    Positioned(
                      top: topPos,
                      left: leftPos,
                      width: colWidth,
                      height: blockHeight,
                      child: _buildItemCard(context, item, isDarkMode, blockHeight),
                    ),
                  );

                  // Col 1: Overflow card (+ (count - 1) mục khác)
                  final double overflowTopPos = (minStartH - startHourGrid) * hourHeight + gridTopOffset;
                  final double overflowBlockHeight = math.max(52.0, (maxEndH - minStartH) * hourHeight - 4);
                  final double overflowLeftPos = 56.0 + 1 * (colWidth + 4.0);
                  final int overflowCount = count - 1;

                  positionedCards.add(
                    Positioned(
                      top: overflowTopPos,
                      left: overflowLeftPos,
                      width: colWidth,
                      height: overflowBlockHeight,
                      child: _buildOverflowCard(context, cluster, overflowCount, isDarkMode),
                    ),
                  );
                }
              }

              return Stack(
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

                  // Render Multi-column Positioned Cards
                  ...positionedCards,

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
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(
    BuildContext context,
    _TimelineItem item,
    bool isDarkMode,
    double blockHeight,
  ) {
    return GestureDetector(
      onTap: () {
        if (item.rawClass != null) {
          widget.onScheduleTap(item.rawClass!);
        } else if (item.rawEvent != null) {
          widget.onEventTap(item.rawEvent!);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
        decoration: BoxDecoration(
          color: item.color,
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: blockHeight < 55 ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontFamily: 'Poppins',
                      height: 1.2,
                    ),
                  ),
                ),
                if (item.type != _TimelineItemType.studyClass)
                  Container(
                    margin: const EdgeInsets.only(left: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.type == _TimelineItemType.interestedEvent ? 'QUAN TÂM' : 'SỰ KIỆN',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 7.5,
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
                  color: Colors.white.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    item.location.isNotEmpty
                        ? "${item.timeRangeText} • ${item.location}"
                        : item.timeRangeText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverflowCard(
    BuildContext context,
    List<_TimelineItem> clusterItems,
    int overflowCount,
    bool isDarkMode,
  ) {
    const Color primaryColor = Color(0xFF5893D8);

    final Color surfaceColor = isDarkMode
        ? const Color(0xFF2A2D32)
        : const Color(0xFFF4F7FA);

    final Color borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.10)
        : const Color(0xFFDCE3EA);

    final Color primaryTextColor = isDarkMode
        ? Colors.white
        : const Color(0xFF1D2939);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () {
          _showClusterOverflowBottomSheet(
            context,
            clusterItems,
          );
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: borderColor,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(
                    alpha: isDarkMode ? 0.16 : 0.10,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.more_horiz_rounded,
                  size: 18,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 5),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '+$overflowCount mục khác',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Encode Sans Expanded',
                    fontSize: 10,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: primaryTextColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showClusterOverflowBottomSheet(
    BuildContext context,
    List<_TimelineItem> clusterItems,
  ) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    const Color primaryColor = Color(0xFF5893D8);
    final Color primaryTextColor = isDarkMode ? Colors.white : const Color(0xFF1D2939);
    final Color secondaryTextColor = isDarkMode ? Colors.white60 : const Color(0xFF667085);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.65,
          ),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.white30 : Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  18,
                  0,
                  10,
                  12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(
                          alpha: isDarkMode ? 0.16 : 0.10,
                        ),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.layers_outlined,
                        color: primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lịch trùng thời gian',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                              color: primaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${clusterItems.length} lịch học và sự kiện trong cùng khung giờ',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily:
                                  'Encode Sans Expanded',
                              fontSize: 11.5,
                              height: 1.35,
                              color: secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Đóng',
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: clusterItems.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = clusterItems[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        if (item.rawClass != null) {
                          widget.onScheduleTap(item.rawClass!);
                        } else if (item.rawEvent != null) {
                          widget.onEventTap(item.rawEvent!);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: item.color,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              item.type == _TimelineItemType.studyClass
                                  ? Icons.school_rounded
                                  : Icons.event_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.location.isNotEmpty
                                        ? '${item.timeRangeText} • ${item.location}'
                                        : item.timeRangeText,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withValues(alpha: 0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: Colors.white70,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}
