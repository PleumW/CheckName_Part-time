import 'package:flutter/material.dart';
import '../models/shift_model.dart';
import '../theme/app_theme.dart';
import 'shift_detail_sheet.dart';

class TimetableGridWidget extends StatefulWidget {
  final List<DateTime> daysOfWeek;
  final List<ShiftModel> Function(DateTime) getShiftsForDay;
  final double startHour; // e.g. 8.0 (08:00)
  final double endHour;   // e.g. 21.0 (21:00)
  final void Function(ShiftModel)? onShiftTap;

  const TimetableGridWidget({
    super.key,
    required this.daysOfWeek,
    required this.getShiftsForDay,
    this.startHour = 8.0,
    this.endHour = 21.0,
    this.onShiftTap,
  });

  @override
  State<TimetableGridWidget> createState() => _TimetableGridWidgetState();
}

class _TimetableGridWidgetState extends State<TimetableGridWidget> {
  final ScrollController _headerScrollController = ScrollController();
  final ScrollController _bodyScrollController = ScrollController();

  static const double _hourWidth = 72.0;
  static const double _dayColumnWidth = 75.0;
  static const double _rowHeight = 84.0;
  static const double _timeHeaderHeight = 44.0;

  @override
  void initState() {
    super.initState();
    // Synchronize horizontal scroll between header and content
    _bodyScrollController.addListener(() {
      if (_headerScrollController.hasClients &&
          _headerScrollController.offset != _bodyScrollController.offset) {
        _headerScrollController.jumpTo(_bodyScrollController.offset);
      }
    });
  }

  @override
  void dispose() {
    _headerScrollController.dispose();
    _bodyScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalHours = (widget.endHour - widget.startHour).toInt();
    final gridWidth = totalHours * _hourWidth;
    final today = DateTime.now();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.latte.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Timetable Header Row (Corner label + Hour columns)
          SizedBox(
            height: _timeHeaderHeight,
            child: Row(
              children: [
                // Top-left corner box (Day / Time label)
                Container(
                  width: _dayColumnWidth,
                  color: AppTheme.latte.withValues(alpha: 0.6),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today, size: 12, color: AppTheme.mocha),
                        SizedBox(width: 4),
                        Text(
                          'วัน/เวลา',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.mocha,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Scrollable time axis
                Expanded(
                  child: SingleChildScrollView(
                    controller: _headerScrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    child: Container(
                      width: gridWidth,
                      color: AppTheme.milk,
                      child: Row(
                        children: List.generate(totalHours, (index) {
                          final hour = widget.startHour.toInt() + index;
                          return Container(
                            width: _hourWidth,
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(
                                  color: Colors.grey.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${hour.toString().padLeft(2, '0')}:00',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textDark,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1, color: AppTheme.latte),

          // Timetable Body (Rows for Mon - Sun)
          Expanded(
            child: SingleChildScrollView(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pinned left column: Days of the week
                  SizedBox(
                    width: _dayColumnWidth,
                    child: Column(
                      children: widget.daysOfWeek.map((dayDate) {
                        final isToday = dayDate.year == today.year &&
                            dayDate.month == today.month &&
                            dayDate.day == today.day;
                        return _buildDayHeaderCell(dayDate, isToday);
                      }).toList(),
                    ),
                  ),

                  // Horizontally scrollable shift blocks area
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _bodyScrollController,
                      scrollDirection: Axis.horizontal,
                      physics: const ClampingScrollPhysics(),
                      child: SizedBox(
                        width: gridWidth,
                        child: Column(
                          children: widget.daysOfWeek.map((dayDate) {
                            final shifts = widget.getShiftsForDay(dayDate);
                            return _buildDayRowContent(
                              dayDate: dayDate,
                              shifts: shifts,
                              gridWidth: gridWidth,
                              totalHours: totalHours,
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayHeaderCell(DateTime date, bool isToday) {
    final weekday = date.weekday;
    final colorConfig = _dayColorConfig(weekday);

    return Container(
      height: _rowHeight,
      decoration: BoxDecoration(
        color: isToday
            ? colorConfig.color.withValues(alpha: 0.18)
            : colorConfig.color.withValues(alpha: 0.07),
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.15), width: 1),
          right: BorderSide(
            color: isToday ? colorConfig.color : AppTheme.latte,
            width: isToday ? 2.5 : 1,
          ),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colorConfig.color,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                colorConfig.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${date.day}/${date.month}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                color: isToday ? colorConfig.color : AppTheme.textDark,
              ),
            ),
            if (isToday)
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.red.shade400,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'วันนี้',
                  style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayRowContent({
    required DateTime dayDate,
    required List<ShiftModel> shifts,
    required double gridWidth,
    required int totalHours,
  }) {
    return Container(
      height: _rowHeight,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.15), width: 1),
        ),
      ),
      child: Stack(
        children: [
          // Background hour vertical grid lines
          Row(
            children: List.generate(totalHours, (index) {
              return Container(
                width: _hourWidth,
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(
                      color: Colors.grey.withValues(alpha: 0.12),
                      width: 1,
                    ),
                  ),
                ),
              );
            }),
          ),

          // If no shifts on this day, show a subtle friendly empty text
          if (shifts.isEmpty)
            Center(
              child: Text(
                '— ว่าง / ไม่มีกะงาน —',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.withValues(alpha: 0.45),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),

          // Render shift cards on timeline
          ...shifts.map((shift) {
            final start = shift.startHourDecimal;
            final end = shift.endHourDecimal;

            // Bounds check
            final clampedStart = start.clamp(widget.startHour, widget.endHour);
            final clampedEnd = end.clamp(widget.startHour, widget.endHour);
            final duration = clampedEnd - clampedStart;
            if (duration <= 0) return const SizedBox.shrink();

            final left = (clampedStart - widget.startHour) * _hourWidth;
            final width = duration * _hourWidth;

            return Positioned(
              left: left + 2,
              width: width - 4,
              top: 5,
              bottom: 5,
              child: _buildShiftCard(shift),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildShiftCard(ShiftModel shift) {
    final color = shift.storeColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => widget.onShiftTap != null
            ? widget.onShiftTap!(shift)
            : ShiftDetailSheet.show(context, shift),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: shift.isFlexibleStart ? null : color.withValues(alpha: 0.18),
            gradient: shift.isFlexibleStart
                ? LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.06), // ใส (transparent / clear)
                      color.withValues(alpha: 0.65), // ขุ่น (cloudy / solid)
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: shift.isFlexibleStart ? color.withValues(alpha: 0.9) : color,
              width: shift.isFlexibleStart ? 2.0 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.12),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Store Name & Store Icon
              Row(
                children: [
                  Icon(
                    Icons.store_mall_directory_rounded,
                    size: 13,
                    color: color,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      shift.storeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),

              // Time badge (e.g. 10:00 - 18:00)
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        shift.isFlexibleStart ? Icons.school_rounded : Icons.access_time,
                        size: 10,
                        color: shift.isFlexibleStart ? AppTheme.mocha : AppTheme.textDark,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        shift.isFlexibleStart
                            ? '🎒 เลิกเรียน - ${shift.endTime}'
                            : '${shift.startTime} - ${shift.endTime}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: shift.isFlexibleStart ? AppTheme.mocha : AppTheme.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Role / Duty & Assigned Employee
              Text(
                shift.userName.isNotEmpty ? '${shift.userName} (${shift.role})' : shift.role,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _DayColorConfig _dayColorConfig(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return _DayColorConfig('จันทร์', const Color(0xFFE5A93B)); // Monday Yellow/Amber
      case DateTime.tuesday:
        return _DayColorConfig('อังคาร', const Color(0xFFE96C89)); // Tuesday Pink
      case DateTime.wednesday:
        return _DayColorConfig('พุธ', const Color(0xFF43A047)); // Wednesday Green
      case DateTime.thursday:
        return _DayColorConfig('พฤหัส', const Color(0xFFF57C00)); // Thursday Orange
      case DateTime.friday:
        return _DayColorConfig('ศุกร์', const Color(0xFF1E88E5)); // Friday Blue
      case DateTime.saturday:
        return _DayColorConfig('เสาร์', const Color(0xFF8E24AA)); // Saturday Purple
      case DateTime.sunday:
      default:
        return _DayColorConfig('อาทิตย์', const Color(0xFFE53935)); // Sunday Red
    }
  }
}

class _DayColorConfig {
  final String name;
  final Color color;
  _DayColorConfig(this.name, this.color);
}
