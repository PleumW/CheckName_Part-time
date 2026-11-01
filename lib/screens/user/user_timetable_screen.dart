import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/shift_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shift_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/timetable_grid_widget.dart';
import '../../widgets/shift_detail_sheet.dart';

enum TimetableDisplayMode { grid, agenda }
enum UserScheduleScope { myShifts, allUsers }

class UserTimetableScreen extends ConsumerStatefulWidget {
  const UserTimetableScreen({super.key});

  @override
  ConsumerState<UserTimetableScreen> createState() => _UserTimetableScreenState();
}

class _UserTimetableScreenState extends ConsumerState<UserTimetableScreen> {
  TimetableDisplayMode _displayMode = TimetableDisplayMode.grid;
  UserScheduleScope _scheduleScope = UserScheduleScope.myShifts;

  static const List<String> _stores = ['All', 'Tokio Haus', 'Kita Cafe', 'Freshly House'];

  @override
  Widget build(BuildContext context) {
    final shiftState = ref.watch(shiftProvider);
    final shiftNotifier = ref.read(shiftProvider.notifier);

    final start = shiftState.selectedWeekStart;
    final end = start.add(const Duration(days: 6));
    final weekTitle = '${start.day} ${_thaiMonth(start.month)} - ${end.day} ${_thaiMonth(end.month)} ${end.year + 543}';

    final currentUser = ref.watch(authProvider);
    final isMyShiftsOnly = _scheduleScope == UserScheduleScope.myShifts &&
        currentUser != null &&
        currentUser.id.isNotEmpty;

    bool isUserShift(ShiftModel s) {
      if (currentUser == null) return false;
      if (s.userId.isNotEmpty && s.userId == currentUser.id) return true;
      if (currentUser.nickname.isNotEmpty && s.userName == currentUser.nickname) return true;
      final full = '${currentUser.firstName} ${currentUser.lastName}'.trim();
      if (currentUser.firstName.isNotEmpty && (s.userName == currentUser.firstName || s.userName == full)) return true;
      return false;
    }

    // Filter shifts for a day based on scope
    List<ShiftModel> getShiftsForDay(DateTime date) {
      final dayShifts = shiftState.shiftsForDay(date);
      if (isMyShiftsOnly) {
        return dayShifts.where(isUserShift).toList();
      }
      return dayShifts;
    }

    // Filter shifts for the active week based on scope
    final activeWeekShifts = isMyShiftsOnly
        ? shiftState.currentWeekShifts.where(isUserShift).toList()
        : shiftState.currentWeekShifts;

    return Scaffold(
      backgroundColor: AppTheme.milk,
      appBar: AppBar(
        title: const Text('ตารางเข้างาน (Timetable)'),
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () => shiftNotifier.goToToday(),
            icon: const Icon(Icons.today, color: Colors.white, size: 18),
            label: const Text(
              'วันนี้',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Schedule Scope Switcher: กะงานของฉัน vs ตารางโดยรวมของทุกคน
          _buildScopeSwitcher(currentUser),

          // Week Navigator Bar
          _buildWeekNavigator(weekTitle, shiftNotifier),

          // Store Filter Chips & View Mode Toggle
          _buildFiltersAndModeToggle(shiftState, shiftNotifier),

          // Weekly Stats Summary Banner
          _buildStatsBanner(activeWeekShifts, isMyShiftsOnly),

          // Main Timetable Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
              child: _displayMode == TimetableDisplayMode.grid
                  ? TimetableGridWidget(
                      daysOfWeek: shiftState.daysOfWeek,
                      getShiftsForDay: (date) => getShiftsForDay(date),
                      startHour: 8.0,
                      endHour: 22.0,
                    )
                  : _buildAgendaView(shiftState, getShiftsForDay, isMyShiftsOnly),
            ),
          ),

          // Store Legend at bottom
          _buildStoreLegend(),
        ],
      ),
    );
  }

  Widget _buildWeekNavigator(String weekTitle, ShiftNotifier notifier) {
    return Container(
      color: AppTheme.latte.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppTheme.mocha),
            tooltip: 'สัปดาห์ก่อนหน้า',
            onPressed: () => notifier.previousWeek(),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.date_range, color: AppTheme.mocha, size: 18),
              const SizedBox(width: 8),
              Text(
                weekTitle,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: AppTheme.mocha),
            tooltip: 'สัปดาห์ถัดไป',
            onPressed: () => notifier.nextWeek(),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersAndModeToggle(ShiftState state, ShiftNotifier notifier) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Column(
        children: [
          Row(
            children: [
              // Store Chips
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _stores.map((store) {
                      final isSelected = state.selectedStoreFilter == store;
                      final label = store == 'All' ? 'ทุกร้าน 🐾' : store;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: FilterChip(
                          label: Text(label),
                          selected: isSelected,
                          onSelected: (_) => notifier.selectStoreFilter(store),
                          backgroundColor: Colors.white,
                          selectedColor: AppTheme.mocha.withValues(alpha: 0.2),
                          checkmarkColor: AppTheme.mocha,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? AppTheme.mocha : AppTheme.textDark,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: isSelected ? AppTheme.mocha : Colors.grey.shade300,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Mode Toggle (Grid vs Agenda)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildModeButton(
                      mode: TimetableDisplayMode.grid,
                      icon: Icons.grid_on_rounded,
                      tooltip: 'มุมมองตารางสอน',
                    ),
                    _buildModeButton(
                      mode: TimetableDisplayMode.agenda,
                      icon: Icons.view_agenda_rounded,
                      tooltip: 'มุมมองรายวัน',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton({
    required TimetableDisplayMode mode,
    required IconData icon,
    required String tooltip,
  }) {
    final isSelected = _displayMode == mode;
    return InkWell(
      onTap: () => setState(() => _displayMode = mode),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.mocha : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isSelected ? Colors.white : Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _buildScopeSwitcher(UserModel? currentUser) {
    final myLabel = currentUser != null && currentUser.nickname.isNotEmpty
        ? 'กะงานของ${currentUser.nickname}'
        : 'กะงานของฉัน';

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.latte),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _scheduleScope = UserScheduleScope.myShifts),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _scheduleScope == UserScheduleScope.myShifts
                      ? AppTheme.mocha
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_rounded,
                      size: 16,
                      color: _scheduleScope == UserScheduleScope.myShifts
                          ? Colors.white
                          : AppTheme.textDark,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      myLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _scheduleScope == UserScheduleScope.myShifts
                            ? Colors.white
                            : AppTheme.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _scheduleScope = UserScheduleScope.allUsers),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _scheduleScope == UserScheduleScope.allUsers
                      ? AppTheme.mocha
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.groups_rounded,
                      size: 16,
                      color: _scheduleScope == UserScheduleScope.allUsers
                          ? Colors.white
                          : AppTheme.textDark,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'ตารางโดยรวม (ทุกคน)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _scheduleScope == UserScheduleScope.allUsers
                            ? Colors.white
                            : AppTheme.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBanner(List<ShiftModel> activeShifts, bool isMyShiftsOnly) {
    final totalHours = activeShifts.fold(0.0, (sum, s) => sum + s.durationHours);
    final totalCount = activeShifts.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.latte.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              isMyShiftsOnly ? 'กะงานของคุณ' : 'กะงานทั้งหมด',
              '$totalCount กะ',
            ),
            Container(height: 20, width: 1, color: Colors.grey.shade400),
            _buildStatItem(
              isMyShiftsOnly ? 'ชั่วโมงของคุณ' : 'ชั่วโมงรวม',
              '${totalHours.toStringAsFixed(1)} ชม.',
            ),
            Container(height: 20, width: 1, color: Colors.grey.shade400),
            _buildStatItem(
              'โหมดแสดงผล',
              isMyShiftsOnly ? 'กะงานส่วนตัว 🐾' : 'ตารางโดยรวม 🐾',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppTheme.mocha,
          ),
        ),
      ],
    );
  }

  Widget _buildAgendaView(
    ShiftState state,
    List<ShiftModel> Function(DateTime) getShiftsForDay,
    bool isMyShiftsOnly,
  ) {
    final today = DateTime.now();

    return ListView.builder(
      itemCount: state.daysOfWeek.length,
      itemBuilder: (context, index) {
        final dayDate = state.daysOfWeek[index];
        final shifts = getShiftsForDay(dayDate);
        final isToday = dayDate.year == today.year &&
            dayDate.month == today.month &&
            dayDate.day == today.day;
        final dayName = _thaiDayName(dayDate.weekday);
        final dayColor = _thaiDayColor(dayDate.weekday);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isToday ? dayColor : Colors.grey.shade200,
              width: isToday ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isToday
                      ? dayColor.withValues(alpha: 0.15)
                      : dayColor.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: dayColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        dayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${dayDate.day} ${_thaiMonth(dayDate.month)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const Spacer(),
                    if (isToday)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade400,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'วันนี้',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Shifts inside day
              if (shifts.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      isMyShiftsOnly ? 'ไม่มีกะงานของคุณในวันนี้ ☕' : 'ไม่มีกะงานในวันนี้ ☕',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                )
              else
                Column(
                  children: shifts.map((shift) {
                    final color = shift.storeColor;
                    return InkWell(
                      onTap: () => ShiftDetailSheet.show(context, shift),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            // Store Color bar
                            Container(
                              width: 4,
                              height: 48,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        shift.storeName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: color,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          shift.role,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: color,
                                          ),
                                        ),
                                      ),
                                      if (shift.userName.isNotEmpty) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.latte.withValues(alpha: 0.5),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            shift.userName,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.mocha,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(shift.isFlexibleStart ? Icons.school_rounded : Icons.access_time, size: 14, color: shift.isFlexibleStart ? AppTheme.mocha : Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(
                                        shift.isFlexibleStart
                                            ? '🎒 ${shift.startTime} - ${shift.endTime} (${shift.durationHours.toStringAsFixed(1)} ชม.)'
                                            : '${shift.startTime} - ${shift.endTime} (${shift.durationHours.toStringAsFixed(0)} ชม.)',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textDark,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          shift.branchLocation,
                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Action Arrow
                            Icon(Icons.chevron_right, color: Colors.grey.shade400),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStoreLegend() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendDot(const Color(0xFFD97736), 'Tokio Haus'),
            const SizedBox(width: 14),
            _buildLegendDot(const Color(0xFF4E878C), 'Kita Cafe'),
            const SizedBox(width: 14),
            _buildLegendDot(const Color(0xFF9D65C9), 'Freshly House'),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendDot(Color color, String name) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          name,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppTheme.textDark,
          ),
        ),
      ],
    );
  }

  String _thaiMonth(int month) {
    const months = ['', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.', 'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'];
    return months[month];
  }

  String _thaiDayName(int weekday) {
    const days = ['', 'วันจันทร์', 'วันอังคาร', 'วันพุธ', 'วันพฤหัสบดี', 'วันศุกร์', 'วันเสาร์', 'วันอาทิตย์'];
    return days[weekday];
  }

  Color _thaiDayColor(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return const Color(0xFFE5A93B);
      case DateTime.tuesday:
        return const Color(0xFFE96C89);
      case DateTime.wednesday:
        return const Color(0xFF43A047);
      case DateTime.thursday:
        return const Color(0xFFF57C00);
      case DateTime.friday:
        return const Color(0xFF1E88E5);
      case DateTime.saturday:
        return const Color(0xFF8E24AA);
      case DateTime.sunday:
      default:
        return const Color(0xFFE53935);
    }
  }
}
