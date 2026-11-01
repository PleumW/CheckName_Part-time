import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/shift_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shift_provider.dart';
import '../../providers/notification_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/timetable_grid_widget.dart';
import '../../widgets/user_avatar.dart';

enum ScheduleViewMode { timetable, list }

class ScheduleManagementScreen extends ConsumerStatefulWidget {
  const ScheduleManagementScreen({super.key});

  @override
  ConsumerState<ScheduleManagementScreen> createState() => _ScheduleManagementScreenState();
}

class _ScheduleManagementScreenState extends ConsumerState<ScheduleManagementScreen> {
  ScheduleViewMode _viewMode = ScheduleViewMode.timetable;
  String _selectedStore = 'All';
  String _selectedUserId = 'All';

  static const List<String> _stores = ['All', 'Tokio Haus', 'Kita Cafe', 'Freshly House'];
  static const List<String> _cleanStoreOptions = ['Tokio Haus', 'Kita Cafe', 'Freshly House'];

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  TimeOfDay _parseTimeString(String timeStr) {
    try {
      final parts = timeStr.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {
      return const TimeOfDay(hour: 10, minute: 0);
    }
  }

  String _thaiMonth(int month) {
    const months = [
      'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final shiftState = ref.watch(shiftProvider);
    final shiftNotifier = ref.read(shiftProvider.notifier);
    final usersAsync = ref.watch(allUsersProvider);
    final users = usersAsync.value ?? [];

    final shifts = [...shiftState.shifts]..sort((a, b) => a.date.compareTo(b.date));

    // Filter shifts based on local filters
    final filteredShifts = shifts.where((shift) {
      if (_selectedStore != 'All' && shift.storeName != _selectedStore) {
        return false;
      }
      if (_selectedUserId != 'All' && shift.userId != _selectedUserId) {
        return false;
      }
      return true;
    }).toList();

    final start = shiftState.selectedWeekStart;
    final end = start.add(const Duration(days: 6));
    final weekTitle = '${start.day} ${_thaiMonth(start.month)} - ${end.day} ${_thaiMonth(end.month)} ${end.year + 543}';

    return Scaffold(
      backgroundColor: AppTheme.milk,
      appBar: AppBar(
        title: const Text('จัดการตารางงาน (Schedules)'),
        actions: [
          if (shifts.isNotEmpty)
            IconButton(
              icon: Icon(
                _viewMode == ScheduleViewMode.timetable
                    ? Icons.view_list_rounded
                    : Icons.grid_view_rounded,
                color: Colors.white,
              ),
              tooltip: _viewMode == ScheduleViewMode.timetable
                  ? 'เปลี่ยนเป็นแบบรายการ'
                  : 'เปลี่ยนเป็นแบบตารางสอน',
              onPressed: () {
                setState(() {
                  _viewMode = _viewMode == ScheduleViewMode.timetable
                      ? ScheduleViewMode.list
                      : ScheduleViewMode.timetable;
                });
              },
            ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'เพิ่มกะงานใหม่',
            onPressed: () => _showAddShiftDialog(context, users),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.mocha,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_circle_outline),
        label: const Text('เพิ่มกะงานใหม่'),
        onPressed: () => _showAddShiftDialog(context, users),
      ),
      body: shifts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'ยังไม่มีการกำหนดกะงานในระบบ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'กดปุ่ม "เพิ่มกะงานใหม่" เพื่อสร้างกะงานให้พนักงาน',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => _showAddShiftDialog(context, users),
                    icon: const Icon(Icons.add),
                    label: const Text('สร้างกะงานแรก'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.mocha),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Week Navigator Bar
                _buildWeekNavigator(weekTitle, shiftNotifier),

                // Controls: Store Chips, Mode Toggle & User Filter
                _buildControlsBar(users),

                // Content Area (Timetable Grid or List View)
                Expanded(
                  child: _viewMode == ScheduleViewMode.timetable
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                          child: TimetableGridWidget(
                            daysOfWeek: shiftState.daysOfWeek,
                            getShiftsForDay: (date) {
                              return filteredShifts.where((shift) {
                                return shift.date.year == date.year &&
                                    shift.date.month == date.month &&
                                    shift.date.day == date.day;
                              }).toList();
                            },
                            startHour: 8.0,
                            endHour: 22.0,
                            onShiftTap: (shift) => _showAdminShiftManageSheet(context, shift, users),
                          ),
                        )
                      : _buildListView(filteredShifts, users),
                ),

                // Legend at bottom
                if (_viewMode == ScheduleViewMode.timetable) _buildStoreLegend(),
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
              const Icon(Icons.calendar_month, color: AppTheme.mocha, size: 18),
              const SizedBox(width: 8),
              Text(
                weekTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppTheme.mocha,
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => notifier.goToToday(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('วันนี้', style: TextStyle(color: AppTheme.mocha, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: AppTheme.mocha),
                tooltip: 'สัปดาห์ถัดไป',
                onPressed: () => notifier.nextWeek(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlsBar(List<UserModel> users) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        children: [
          // Store filter chips & View mode toggle buttons
          Row(
            children: [
              // Store Chips
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _stores.map((store) {
                      final isSelected = _selectedStore == store;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: ChoiceChip(
                          label: Text(
                            store == 'All' ? 'ทุกร้าน' : store,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Colors.white : AppTheme.textDark,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: AppTheme.mocha,
                          backgroundColor: AppTheme.milk,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _selectedStore = store),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // View switcher toggle buttons
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.milk,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.latte),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => setState(() => _viewMode = ScheduleViewMode.timetable),
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: _viewMode == ScheduleViewMode.timetable ? AppTheme.mocha : Colors.transparent,
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
                        ),
                        child: Icon(
                          Icons.grid_view_rounded,
                          size: 16,
                          color: _viewMode == ScheduleViewMode.timetable ? Colors.white : Colors.grey,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _viewMode = ScheduleViewMode.list),
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: _viewMode == ScheduleViewMode.list ? AppTheme.mocha : Colors.transparent,
                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(9)),
                        ),
                        child: Icon(
                          Icons.view_list_rounded,
                          size: 16,
                          color: _viewMode == ScheduleViewMode.list ? Colors.white : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // User filter if users are available
          if (users.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.person_search_rounded, size: 16, color: AppTheme.mocha),
                const SizedBox(width: 6),
                const Text('พนักงาน: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                const SizedBox(width: 6),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedUserId,
                      isDense: true,
                      isExpanded: true,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textDark),
                      selectedItemBuilder: (context) {
                        return [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              CircleAvatar(
                                radius: 9,
                                backgroundColor: Color(0xFFEDE4DC),
                                child: Icon(Icons.people_alt_rounded, size: 11, color: AppTheme.mocha),
                              ),
                              SizedBox(width: 6),
                              Flexible(
                                child: Text('ตารางโดยรวมของพนักงาน (ทุกคน)', overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                          ...users.map((u) {
                            final label = u.nickname.isNotEmpty ? '${u.nickname} (${u.fullName})' : (u.fullName.isNotEmpty ? u.fullName : u.email);
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                UserAvatar(imageSource: u.profileImage, radius: 9),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(label, overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            );
                          }),
                        ];
                      },
                      items: [
                        DropdownMenuItem(
                          value: 'All',
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              CircleAvatar(
                                radius: 10,
                                backgroundColor: Color(0xFFEDE4DC),
                                child: Icon(Icons.people_alt_rounded, size: 12, color: AppTheme.mocha),
                              ),
                              SizedBox(width: 8),
                              Text('ตารางโดยรวมของพนักงาน (ทุกคน)'),
                            ],
                          ),
                        ),
                        ...users.map(
                          (u) => DropdownMenuItem(
                            value: u.id,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                UserAvatar(imageSource: u.profileImage, radius: 11),
                                const SizedBox(width: 8),
                                Text(
                                  u.nickname.isNotEmpty ? '${u.nickname} (${u.fullName})' : (u.fullName.isNotEmpty ? u.fullName : u.email),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedUserId = val);
                      },
                    ),
                  ),
                ),
                if (_selectedUserId != 'All')
                  IconButton(
                    icon: const Icon(Icons.clear, size: 16, color: Colors.grey),
                    tooltip: 'ล้างการกรองพนักงาน',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => setState(() => _selectedUserId = 'All'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildListView(List<ShiftModel> shifts, List<UserModel> users) {
    if (shifts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.filter_alt_off_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'ไม่พบกะงานตามตัวกรองที่เลือก',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: shifts.length,
      itemBuilder: (context, index) {
        final shift = shifts[index];
        final color = shift.storeColor;
        final dateStr = '${shift.date.day}/${shift.date.month}/${shift.date.year + 543}';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 58,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _showAdminShiftManageSheet(context, shift, users),
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
                            const SizedBox(width: 8),
                            _buildStatusBadge(shift.status),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              dateStr,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 10),
                            const Icon(Icons.access_time, size: 12, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              '${shift.startTime} - ${shift.endTime} น.',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textDark),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (shift.userName.isNotEmpty) ...[
                              UserAvatar(
                                imageSource: users.where((u) => u.id == shift.userId).firstOrNull?.profileImage,
                                radius: 8,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                shift.userName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              'หน้าที่: ${shift.role}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: AppTheme.mocha, size: 20),
                      tooltip: 'แก้ไขกะงาน',
                      onPressed: () => _showEditShiftDialog(context, shift, users),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                      tooltip: 'ยกเลิกกะงาน',
                      onPressed: () => _confirmDeleteShift(context, shift),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStoreLegend() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLegendDot(const Color(0xFFD97736), 'Tokio Haus'),
          const SizedBox(width: 16),
          _buildLegendDot(const Color(0xFF4E878C), 'Kita Cafe'),
          const SizedBox(width: 16),
          _buildLegendDot(const Color(0xFF9D65C9), 'Freshly House'),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String text;

    switch (status) {
      case 'completed':
        bg = Colors.green.shade50;
        fg = Colors.green.shade700;
        text = 'เสร็จสิ้น';
        break;
      case 'in_progress':
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade800;
        text = 'กำลังทำงาน';
        break;
      default:
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade700;
        text = 'นัดหมาย';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _thaiWeekday(int weekday) {
    const days = ['', 'จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์', 'อาทิตย์'];
    return days[weekday];
  }

  void _confirmDeleteShift(BuildContext context, ShiftModel shift) {
    final staffName = shift.userName.isNotEmpty ? shift.userName : 'พนักงาน';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยกเลิกกะงาน'),
        content: Text('คุณต้องการยกเลิกกะงาน "${shift.storeName} (${shift.startTime} - ${shift.endTime} น.)" ของ $staffName ออกจากระบบใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('ไม่ยกเลิก'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(shiftProvider.notifier).deleteShift(shift.id);
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('ยกเลิกกะงานออกจากตารางเรียบร้อยแล้ว'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('ยืนยันยกเลิกกะงาน', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAdminShiftManageSheet(BuildContext context, ShiftModel shift, List<UserModel> users) {
    final assignedUser = users.where((u) => u.id == shift.userId).firstOrNull;
    final storeColor = shift.storeColor;
    final dateFormatted = 'วัน${_thaiWeekday(shift.date.weekday)}ที่ ${shift.date.day} ${_thaiMonth(shift.date.month)} ${shift.date.year + 543}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header: Store Name & Day & Status
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: storeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.storefront_rounded, color: storeColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shift.storeName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: storeColor,
                          ),
                        ),
                        Text(
                          dateFormatted,
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(shift.status),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),

              // Shift Details Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.milk,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.latte),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        UserAvatar(
                          imageSource: assignedUser?.profileImage,
                          radius: 13,
                        ),
                        const SizedBox(width: 8),
                        const Text('พนักงาน: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                        Expanded(
                          child: Text(
                            shift.userName.isNotEmpty ? shift.userName : (assignedUser?.displayName ?? 'ไม่ระบุชื่อพนักงาน'),
                            style: const TextStyle(fontSize: 13, color: AppTheme.textDark, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.access_time_filled, size: 18, color: AppTheme.mocha),
                        const SizedBox(width: 8),
                        const Text('เวลาทำงาน: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                        Text(
                          '${shift.startTime} - ${shift.endTime} น. (${shift.durationHours.toStringAsFixed(0)} ชม.)',
                          style: const TextStyle(fontSize: 13, color: AppTheme.textDark),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.work_outline, size: 18, color: AppTheme.mocha),
                        const SizedBox(width: 8),
                        const Text('ตำแหน่งหน้าที่: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                        Expanded(
                          child: Text(
                            shift.role,
                            style: const TextStyle(fontSize: 13, color: AppTheme.textDark),
                          ),
                        ),
                      ],
                    ),
                    if (shift.note != null && shift.note!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.notes, size: 18, color: AppTheme.mocha),
                          const SizedBox(width: 8),
                          const Text('หมายเหตุ: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                          Expanded(
                            child: Text(
                              shift.note!,
                              style: const TextStyle(fontSize: 13, color: AppTheme.textDark),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons: ONLY Cancel and Edit (No Check In / Check Out)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _confirmDeleteShift(context, shift);
                      },
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                      label: const Text(
                        'ยกเลิกกะงาน',
                        style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _showEditShiftDialog(context, shift, users);
                      },
                      icon: const Icon(Icons.edit_calendar, size: 18),
                      label: const Text(
                        'แก้ไขตารางงาน',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.mocha,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditShiftDialog(BuildContext context, ShiftModel shift, List<UserModel> users) {
    String selectedStore = shift.storeName;
    DateTime selectedDate = shift.date;
    TimeOfDay selectedStartTime = _parseTimeString(shift.startTime);
    TimeOfDay selectedEndTime = _parseTimeString(shift.endTime);
    bool isFlexibleStart = shift.isFlexibleStart;

    String selectedUserId = shift.userId;
    String selectedUserName = shift.userName;

    final noteController = TextEditingController(text: shift.note ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: const [
                        Icon(Icons.edit_calendar, color: AppTheme.mocha, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'แก้ไขตารางงาน (Edit Shift)',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 1. Employee Selection
                    const Text('เลือกพนักงานที่จัดตารางงาน', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    Builder(
                      builder: (context) {
                        final editUserList = users.isNotEmpty
                            ? users
                            : [
                                UserModel(
                                  id: selectedUserId,
                                  firstName: selectedUserName.isNotEmpty ? selectedUserName : 'พนักงานทั่วไป',
                                  lastName: '',
                                  role: 'user',
                                  bankAccount: '',
                                )
                              ];
                        final currentEditUser = editUserList.where((u) => u.id == selectedUserId).firstOrNull ?? editUserList.first;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: editUserList.any((u) => u.id == selectedUserId)
                                  ? selectedUserId
                                  : editUserList.first.id,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.person, color: AppTheme.mocha, size: 20),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              selectedItemBuilder: (context) {
                                return editUserList.map((u) {
                                  final label = u.nickname.isNotEmpty
                                      ? '${u.nickname} (${u.fullName})'
                                      : (u.fullName.isNotEmpty ? u.fullName : u.email);
                                  return Row(
                                    children: [
                                      UserAvatar(imageSource: u.profileImage, radius: 11),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          label.isNotEmpty ? label : 'พนักงานทั่วไป',
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 13, color: AppTheme.textDark, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList();
                              },
                              items: editUserList.map((u) {
                                final label = u.nickname.isNotEmpty
                                    ? '${u.nickname} (${u.fullName})'
                                    : (u.fullName.isNotEmpty ? u.fullName : u.email);
                                return DropdownMenuItem(
                                  value: u.id,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      UserAvatar(imageSource: u.profileImage, radius: 13),
                                      const SizedBox(width: 10),
                                      Text(
                                        label.isNotEmpty ? label : 'พนักงานทั่วไป',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setModalState(() {
                                    selectedUserId = val;
                                    final matchedUser = editUserList.where((u) => u.id == val).firstOrNull;
                                    if (matchedUser != null) {
                                      selectedUserName = matchedUser.displayName;
                                    }
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.latte.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.latte),
                              ),
                              child: Row(
                                children: [
                                  UserAvatar(imageSource: currentEditUser.profileImage, radius: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          currentEditUser.fullName.isNotEmpty
                                              ? '${currentEditUser.displayName} (${currentEditUser.fullName})'
                                              : currentEditUser.displayName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark),
                                        ),
                                        if (currentEditUser.email.isNotEmpty)
                                          Text(
                                            currentEditUser.email,
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.mocha.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      currentEditUser.role == 'admin' ? 'ผู้ดูแล' : 'พนักงาน',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.mocha),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 14),

                    // 2. Clean Store Selection
                    const Text('เลือกร้าน', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _cleanStoreOptions.contains(selectedStore) ? selectedStore : _cleanStoreOptions.first,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.storefront, color: AppTheme.mocha, size: 20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _cleanStoreOptions.map((store) {
                        return DropdownMenuItem(value: store, child: Text(store));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedStore = val);
                      },
                    ),

                    const SizedBox(height: 14),

                    // 3. Date Selection
                    const Text('วันที่ทำงาน', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 90)),
                          lastDate: DateTime.now().add(const Duration(days: 180)),
                        );
                        if (picked != null) {
                          setModalState(() => selectedDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month, size: 18, color: AppTheme.mocha),
                            const SizedBox(width: 8),
                            Text(
                              '${selectedDate.day}/${selectedDate.month}/${selectedDate.year + 543}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            const Text('เปลี่ยนวันที่', style: TextStyle(color: AppTheme.mocha, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // 4. Custom Time Selection
                    const Text('เวลาทำงาน (ระบุเวลาเองได้)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),

                    // Flexible Start Switch
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isFlexibleStart ? AppTheme.mocha.withValues(alpha: 0.08) : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isFlexibleStart ? AppTheme.mocha.withValues(alpha: 0.3) : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isFlexibleStart ? AppTheme.mocha.withValues(alpha: 0.15) : Colors.grey.shade200,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.school_rounded,
                              size: 20,
                              color: isFlexibleStart ? AppTheme.mocha : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'กะหลังเลิกเรียน (เลิกเรียนไวที่สุด)',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isFlexibleStart
                                      ? 'เวลาเริ่มยืดหยุ่น: คิดเงินตามเวลา Check In จริง และไม่คิดค่าสาย ☕'
                                      : 'เปิดเมื่อพนักงานมาทันทีที่เลิกเรียน',
                                  style: TextStyle(fontSize: 11, color: isFlexibleStart ? AppTheme.mocha : Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: isFlexibleStart,
                            activeThumbColor: AppTheme.mocha,
                            activeTrackColor: AppTheme.mocha.withValues(alpha: 0.35),
                            onChanged: (val) {
                              setModalState(() {
                                isFlexibleStart = val;
                                if (val) {
                                  selectedEndTime = const TimeOfDay(hour: 21, minute: 30);
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        // Start Time Picker
                        Expanded(
                          child: isFlexibleStart
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.mocha.withValues(alpha: 0.06),
                                    border: Border.all(color: AppTheme.mocha.withValues(alpha: 0.3)),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.school_rounded, size: 18, color: AppTheme.mocha),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: const [
                                            Text('เวลาเริ่มงาน', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                            FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                'เลิกเรียนไวที่สุด 🎒',
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.mocha),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : InkWell(
                                  onTap: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: selectedStartTime,
                                      helpText: 'เลือกเวลาเริ่มงาน',
                                    );
                                    if (picked != null) {
                                      setModalState(() => selectedStartTime = picked);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade400),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.access_time, size: 18, color: AppTheme.mocha),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('เวลาเริ่มงาน', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                            Text(
                                              '${_formatTimeOfDay(selectedStartTime)} น.',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 12),

                        // End Time Picker
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: selectedEndTime,
                                helpText: 'เลือกเวลาเลิกงาน',
                              );
                              if (picked != null) {
                                setModalState(() => selectedEndTime = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.access_time_filled, size: 18, color: AppTheme.mocha),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('เวลาเลิกงาน', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                      Text(
                                        '${_formatTimeOfDay(selectedEndTime)} น.',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Note Field
                    TextField(
                      controller: noteController,
                      decoration: InputDecoration(
                        labelText: 'หมายเหตุงาน',
                        hintText: 'เช่น เตรียมวัตถุดิบ, ดูแลความสะอาด',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Save Changes Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final startFormatted = isFlexibleStart ? 'เลิกเรียนไวที่สุด' : _formatTimeOfDay(selectedStartTime);
                          final endFormatted = _formatTimeOfDay(selectedEndTime);

                          final updatedShift = shift.copyWith(
                            userId: selectedUserId,
                            userName: selectedUserName,
                            storeName: selectedStore,
                            date: DateTime(selectedDate.year, selectedDate.month, selectedDate.day),
                            startTime: startFormatted,
                            endTime: endFormatted,
                            role: shift.role.isNotEmpty ? shift.role : 'Staff',
                            note: noteController.text.trim(),
                          );

                          ref.read(shiftProvider.notifier).updateShift(updatedShift);

                          // Send notification to employee
                          ref.read(notificationProvider.notifier).sendShiftUpdatedNotification(
                            targetUserId: selectedUserId,
                            employeeName: selectedUserName,
                            storeName: selectedStore,
                            date: updatedShift.date,
                            startTime: startFormatted,
                            endTime: endFormatted,
                            role: updatedShift.role,
                            shiftId: updatedShift.id,
                            note: updatedShift.note ?? '',
                          );

                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('บันทึกการแก้ไขกะงานของ $selectedUserName เรียบร้อยแล้ว'),
                              backgroundColor: AppTheme.mocha,
                            ),
                          );
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('บันทึกการแก้ไข', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.mocha,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddShiftDialog(BuildContext context, List<UserModel> users) {
    final selectedStores = <String>{'Tokio Haus'};
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedStartTime = const TimeOfDay(hour: 10, minute: 0);
    TimeOfDay selectedEndTime = const TimeOfDay(hour: 18, minute: 0);
    bool isFlexibleStart = false;

    String selectedUserId = users.isNotEmpty ? users.first.id : 'user-default';
    String selectedUserName = users.isNotEmpty ? users.first.displayName : 'พนักงานทั่วไป';

    final noteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: const [
                        Icon(Icons.add_task, color: AppTheme.mocha, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'กำหนดกะงานใหม่ (Add Shift)',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 1. Employee Selection (เลือกรายชื่อพนักงาน)
                    const Text('เลือกพนักงานที่จัดตารางงาน', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    Builder(
                      builder: (context) {
                        final addUserList = users.isNotEmpty
                            ? users
                            : [
                                UserModel(
                                  id: 'user-default',
                                  firstName: 'พนักงานทั่วไป',
                                  lastName: '(Staff)',
                                  role: 'user',
                                  bankAccount: '',
                                )
                              ];
                        final currentAddUser = addUserList.where((u) => u.id == selectedUserId).firstOrNull ?? addUserList.first;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: addUserList.any((u) => u.id == selectedUserId)
                                  ? selectedUserId
                                  : addUserList.first.id,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.person, color: AppTheme.mocha, size: 20),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              selectedItemBuilder: (context) {
                                return addUserList.map((u) {
                                  final label = u.nickname.isNotEmpty
                                      ? '${u.nickname} (${u.fullName})'
                                      : (u.fullName.isNotEmpty ? u.fullName : u.email);
                                  return Row(
                                    children: [
                                      UserAvatar(imageSource: u.profileImage, radius: 11),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          label.isNotEmpty ? label : 'พนักงานทั่วไป (Staff)',
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 13, color: AppTheme.textDark, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList();
                              },
                              items: addUserList.map((u) {
                                final label = u.nickname.isNotEmpty
                                    ? '${u.nickname} (${u.fullName})'
                                    : (u.fullName.isNotEmpty ? u.fullName : u.email);
                                return DropdownMenuItem(
                                  value: u.id,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      UserAvatar(imageSource: u.profileImage, radius: 13),
                                      const SizedBox(width: 10),
                                      Text(
                                        label.isNotEmpty ? label : 'พนักงานทั่วไป (Staff)',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setModalState(() {
                                    selectedUserId = val;
                                    final matchedUser = addUserList.where((u) => u.id == val).firstOrNull;
                                    if (matchedUser != null) {
                                      selectedUserName = matchedUser.displayName;
                                    }
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.latte.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.latte),
                              ),
                              child: Row(
                                children: [
                                  UserAvatar(imageSource: currentAddUser.profileImage, radius: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          currentAddUser.fullName.isNotEmpty
                                              ? '${currentAddUser.displayName} (${currentAddUser.fullName})'
                                              : currentAddUser.displayName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark),
                                        ),
                                        if (currentAddUser.email.isNotEmpty)
                                          Text(
                                            currentAddUser.email,
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.mocha.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      currentAddUser.role == 'admin' ? 'ผู้ดูแล' : 'พนักงาน',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.mocha),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 14),

                    // 2. Clean Store Selection (เลือกได้มากกว่า 1 ร้าน)
                    const Text('เลือกร้าน (เลือกได้มากกว่า 1 ร้าน)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _cleanStoreOptions.map((store) {
                        final isSelected = selectedStores.contains(store);
                        return FilterChip(
                          selected: isSelected,
                          label: Text(
                            store,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Colors.white : AppTheme.textDark,
                            ),
                          ),
                          selectedColor: AppTheme.mocha,
                          checkmarkColor: Colors.white,
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: isSelected ? AppTheme.mocha : Colors.grey.shade300,
                            ),
                          ),
                          onSelected: (selected) {
                            setModalState(() {
                              if (selected) {
                                selectedStores.add(store);
                              } else {
                                if (selectedStores.length > 1) {
                                  selectedStores.remove(store);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('กรุณาเลือกร้านอย่างน้อย 1 ร้าน'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 14),

                    // 3. Date Selection
                    const Text('วันที่ทำงาน', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 30)),
                          lastDate: DateTime.now().add(const Duration(days: 90)),
                        );
                        if (picked != null) {
                          setModalState(() => selectedDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month, size: 18, color: AppTheme.mocha),
                            const SizedBox(width: 8),
                            Text(
                              '${selectedDate.day}/${selectedDate.month}/${selectedDate.year + 543}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            const Text('เลือกวันที่', style: TextStyle(color: AppTheme.mocha, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // 4. Custom Time Selection (ระบุเวลาเองได้อิสระ)
                    const Text('เวลาทำงาน (ระบุเวลาเองได้)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),

                    // Flexible Start Switch
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isFlexibleStart ? AppTheme.mocha.withValues(alpha: 0.08) : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isFlexibleStart ? AppTheme.mocha.withValues(alpha: 0.3) : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isFlexibleStart ? AppTheme.mocha.withValues(alpha: 0.15) : Colors.grey.shade200,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.school_rounded,
                              size: 20,
                              color: isFlexibleStart ? AppTheme.mocha : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'กะหลังเลิกเรียน (เลิกเรียนไวที่สุด)',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isFlexibleStart
                                      ? 'เวลาเริ่มยืดหยุ่น: คิดเงินตามเวลา Check In จริง และไม่คิดค่าสาย ☕'
                                      : 'เปิดเมื่อต้องการให้พนักงานมาทันทีที่เลิกเรียน',
                                  style: TextStyle(fontSize: 11, color: isFlexibleStart ? AppTheme.mocha : Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: isFlexibleStart,
                            activeThumbColor: AppTheme.mocha,
                            activeTrackColor: AppTheme.mocha.withValues(alpha: 0.35),
                            onChanged: (val) {
                              setModalState(() {
                                isFlexibleStart = val;
                                if (val) {
                                  selectedEndTime = const TimeOfDay(hour: 21, minute: 30);
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        // Start Time Picker
                        Expanded(
                          child: isFlexibleStart
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.mocha.withValues(alpha: 0.06),
                                    border: Border.all(color: AppTheme.mocha.withValues(alpha: 0.3)),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.school_rounded, size: 18, color: AppTheme.mocha),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: const [
                                            Text('เวลาเริ่มงาน', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                            FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                'เลิกเรียนไวที่สุด 🎒',
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.mocha),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : InkWell(
                                  onTap: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: selectedStartTime,
                                      helpText: 'เลือกเวลาเริ่มงาน',
                                    );
                                    if (picked != null) {
                                      setModalState(() => selectedStartTime = picked);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade400),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.access_time, size: 18, color: AppTheme.mocha),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('เวลาเริ่มงาน', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                            Text(
                                              '${_formatTimeOfDay(selectedStartTime)} น.',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 12),

                        // End Time Picker
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: selectedEndTime,
                                helpText: 'เลือกเวลาเลิกงาน',
                              );
                              if (picked != null) {
                                setModalState(() => selectedEndTime = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.access_time_filled, size: 18, color: AppTheme.mocha),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('เวลาเลิกงาน', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                      Text(
                                        '${_formatTimeOfDay(selectedEndTime)} น.',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Note Field
                    TextField(
                      controller: noteController,
                      decoration: InputDecoration(
                        labelText: 'หมายเหตุงาน',
                        hintText: 'เช่น เตรียมวัตถุดิบ, ดูแลความสะอาด',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (selectedStores.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('กรุณาเลือกร้านอย่างน้อย 1 ร้าน')),
                            );
                            return;
                          }
                          final startFormatted = isFlexibleStart ? 'เลิกเรียนไวที่สุด' : _formatTimeOfDay(selectedStartTime);
                          final endFormatted = _formatTimeOfDay(selectedEndTime);
                          final nowMs = DateTime.now().millisecondsSinceEpoch;

                          int counter = 0;
                          for (final store in selectedStores) {
                            final newShift = ShiftModel(
                              id: 'shift-${nowMs + counter}',
                              userId: selectedUserId,
                              userName: selectedUserName,
                              storeName: store,
                              date: DateTime(selectedDate.year, selectedDate.month, selectedDate.day),
                              startTime: startFormatted,
                              endTime: endFormatted,
                              role: 'Staff',
                              branchLocation: '', // ลบส่วนของสาขาออกตามคำขอ
                              note: noteController.text.trim(),
                              status: 'upcoming',
                            );

                            ref.read(shiftProvider.notifier).addShift(newShift);

                            // Send Realtime Notification to the employee
                            ref.read(notificationProvider.notifier).sendShiftAssignedNotification(
                              targetUserId: selectedUserId,
                              employeeName: selectedUserName,
                              storeName: store,
                              date: newShift.date,
                              startTime: startFormatted,
                              endTime: endFormatted,
                              role: newShift.role,
                              shiftId: newShift.id,
                              note: newShift.note ?? '',
                            );
                            counter++;
                          }

                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('เพิ่มกะงานที่ ${selectedStores.join(", ")} ให้ $selectedUserName สำเร็จ!'),
                              backgroundColor: AppTheme.mocha,
                            ),
                          );
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('บันทึกกะงาน', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.mocha,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
