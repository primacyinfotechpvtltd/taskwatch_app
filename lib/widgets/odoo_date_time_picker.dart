import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// ISO 8601 Week Number calculation
int getIsoWeekNumber(DateTime date) {
  final thursday = date.add(Duration(days: 4 - date.weekday));
  final firstThursdayOfYear = DateTime(thursday.year, 1, 4);
  final firstThursday = firstThursdayOfYear.add(
    Duration(days: 4 - firstThursdayOfYear.weekday),
  );
  return 1 + (thursday.difference(firstThursday).inDays / 7).round();
}

/// Result returned from Odoo date/time range picker
class OdooDateRangeResult {
  final DateTime? startDate;
  final DateTime? endDate;

  const OdooDateRangeResult({
    this.startDate,
    this.endDate,
  });

  bool get isEmpty => startDate == null && endDate == null;
  bool get hasRange => startDate != null && endDate != null;
  bool get isSingleDate => startDate != null && endDate == null;

  Duration? get duration {
    if (startDate != null && endDate != null) {
      final diff = endDate!.difference(startDate!);
      return diff.isNegative ? Duration.zero : diff;
    }
    return null;
  }
}

/// Shows the Odoo-style Date & Time Range Picker dialog / popover
Future<OdooDateRangeResult?> showOdooDateRangePicker({
  required BuildContext context,
  DateTime? initialStartDate,
  DateTime? initialEndDate,
  DateTime? firstDate,
  DateTime? lastDate,
  bool includeTime = true,
  bool allowRange = true,
  String title = 'Select Planned Date',
}) async {
  return showDialog<OdooDateRangeResult>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (ctx) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        elevation: 0,
        child: OdooDateRangePicker(
          initialStartDate: initialStartDate,
          initialEndDate: initialEndDate,
          firstDate: firstDate ?? DateTime.now().subtract(const Duration(days: 365 * 2)),
          lastDate: lastDate ?? DateTime.now().add(const Duration(days: 365 * 3)),
          includeTime: includeTime,
          allowRange: allowRange,
          onApply: (start, end) {
            Navigator.of(ctx).pop(OdooDateRangeResult(
              startDate: start,
              endDate: end,
            ));
          },
          onCancel: () {
            Navigator.of(ctx).pop(null);
          },
        ),
      );
    },
  );
}

/// The exact Odoo 16/17/18-style Date & Time Range Picker Widget matching web Odoo
class OdooDateRangePicker extends StatefulWidget {
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final bool includeTime;
  final bool allowRange;
  final void Function(DateTime? startDate, DateTime? endDate) onApply;
  final VoidCallback? onCancel;

  const OdooDateRangePicker({
    super.key,
    this.initialStartDate,
    this.initialEndDate,
    required this.firstDate,
    required this.lastDate,
    this.includeTime = true,
    this.allowRange = true,
    required this.onApply,
    this.onCancel,
  });

  @override
  State<OdooDateRangePicker> createState() => _OdooDateRangePickerState();
}

class _OdooDateRangePickerState extends State<OdooDateRangePicker> {
  late DateTime _currentMonth;
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  bool _isRangeMode = false;

  // Time components
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  bool _activeTimeSlotIsStart = true;
  final ScrollController _timeScrollController = ScrollController();

  DateTime? _hoveredDate;

  // Odoo Signature Color Palette
  static const Color odooPurple = Color(0xFF714B67);
  static const Color odooCoralRed = Color(0xFFDE4B4B);
  static const Color odooLightTeal = Color(0xFFC3E7EB);
  static const Color odooActiveTimeBlue = Color(0xFFD6E4F0);

  @override
  void initState() {
    super.initState();
    _isRangeMode = widget.allowRange;

    _selectedStartDate = widget.initialStartDate ?? widget.initialEndDate ?? DateTime.now();
    _selectedEndDate = widget.initialEndDate;

    final now = DateTime.now();
    _currentMonth = DateTime(
      _selectedStartDate?.year ?? now.year,
      _selectedStartDate?.month ?? now.month,
      1,
    );

    _startTime = widget.initialStartDate != null
        ? TimeOfDay.fromDateTime(widget.initialStartDate!)
        : const TimeOfDay(hour: 12, minute: 0);

    if (widget.initialEndDate != null) {
      _endTime = TimeOfDay.fromDateTime(widget.initialEndDate!);
    } else {
      final startMin = _startTime.hour * 60 + _startTime.minute;
      final endMin = (startMin + 120) % (24 * 60);
      _endTime = TimeOfDay(hour: endMin ~/ 60, minute: endMin % 60);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToActiveTime();
    });
  }

  @override
  void dispose() {
    _timeScrollController.dispose();
    super.dispose();
  }

  void _scrollToActiveTime() {
    if (!_timeScrollController.hasClients || !widget.includeTime) return;
    final active = _activeTimeSlotIsStart ? _startTime : _endTime;
    final totalMinutes = active.hour * 60 + active.minute;
    final index = (totalMinutes / 15).floor();
    final offset = (index * 28.0).clamp(0.0, _timeScrollController.position.maxScrollExtent);
    _timeScrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _toggleRangeMode() {
    if (!widget.allowRange) return;
    setState(() {
      _isRangeMode = !_isRangeMode;
      if (!_isRangeMode) {
        _selectedEndDate = null;
      } else {
        if (_selectedStartDate == null) {
          final now = DateTime.now();
          _selectedStartDate = DateTime(now.year, now.month, now.day);
        }
      }
    });
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  void _onDayTapped(DateTime day) {
    setState(() {
      final cleanDay = DateTime(day.year, day.month, day.day);

      if (!_isRangeMode) {
        _selectedStartDate = cleanDay;
        _selectedEndDate = null;
        return;
      }

      // Range Mode Logic
      if (_selectedStartDate == null || (_selectedStartDate != null && _selectedEndDate != null)) {
        _selectedStartDate = cleanDay;
        _selectedEndDate = null;
      } else {
        final startDayOnly = DateTime(
          _selectedStartDate!.year,
          _selectedStartDate!.month,
          _selectedStartDate!.day,
        );

        if (cleanDay.isBefore(startDayOnly)) {
          _selectedStartDate = cleanDay;
          _selectedEndDate = null;
        } else {
          _selectedEndDate = cleanDay;
        }
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedStartDate = null;
      _selectedEndDate = null;
    });
  }

  void _apply() {
    DateTime? finalStart;
    DateTime? finalEnd;

    if (_selectedStartDate != null) {
      if (widget.includeTime) {
        finalStart = DateTime(
          _selectedStartDate!.year,
          _selectedStartDate!.month,
          _selectedStartDate!.day,
          _startTime.hour,
          _startTime.minute,
        );
      } else {
        finalStart = DateTime(
          _selectedStartDate!.year,
          _selectedStartDate!.month,
          _selectedStartDate!.day,
        );
      }
    }

    final effectiveEndDate = _selectedEndDate ?? (_isRangeMode ? _selectedStartDate : null);

    if (effectiveEndDate != null && _isRangeMode) {
      if (widget.includeTime) {
        finalEnd = DateTime(
          effectiveEndDate.year,
          effectiveEndDate.month,
          effectiveEndDate.day,
          _endTime.hour,
          _endTime.minute,
        );
        // If on the same day and end time <= start time, advance end time forward by 2 hours
        if (_selectedStartDate != null &&
            effectiveEndDate.year == _selectedStartDate!.year &&
            effectiveEndDate.month == _selectedStartDate!.month &&
            effectiveEndDate.day == _selectedStartDate!.day) {
          final startMinutes = _startTime.hour * 60 + _startTime.minute;
          final endMinutes = _endTime.hour * 60 + _endTime.minute;
          if (endMinutes <= startMinutes && finalStart != null) {
            finalEnd = finalStart.add(const Duration(hours: 2));
          }
        }
      } else {
        finalEnd = DateTime(
          effectiveEndDate.year,
          effectiveEndDate.month,
          effectiveEndDate.day,
          23,
          59,
          59,
        );
      }
    }

    if (!_isRangeMode) {
      widget.onApply(finalStart, null);
      return;
    }

    if (finalStart != null && finalEnd != null && finalStart.isAfter(finalEnd)) {
      final temp = finalStart;
      finalStart = finalEnd;
      finalEnd = temp;
    }

    widget.onApply(finalStart, finalEnd);
  }

  String _formatTime(TimeOfDay tod) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, tod.hour, tod.minute);
    return DateFormat('hh:mma').format(dt).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.includeTime ? 365 : 275,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Two-Column Layout: Left Time Slot List + Right Calendar Grid
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left Column: Scrollable 15-min Time Slot List (matches Image 2)
                if (widget.includeTime) ...[
                  _buildTimeSlotColumn(),
                  const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFEEEEEE)),
                ],

                // Right Column: Header + Calendar Grid
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeader(),
                      const Divider(height: 1, color: Color(0xFFEEEEEE)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        child: _buildCalendarGrid(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFEEEEEE)),

          // 2. Bottom Toolbar: [ 12:00pm ] ➔ [ 2:00pm ]   [ 🧹 ]  [ Apply ]
          _buildBottomToolbar(),
        ],
      ),
    );
  }

  Widget _buildTimeSlotColumn() {
    final activeTime = _activeTimeSlotIsStart ? _startTime : _endTime;
    final slots = List.generate(96, (i) {
      final hour = i ~/ 4;
      final minute = (i % 4) * 15;
      return TimeOfDay(hour: hour, minute: minute);
    });

    return SizedBox(
      width: 100,
      height: 270,
      child: ListView.builder(
        controller: _timeScrollController,
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        itemCount: slots.length,
        itemExtent: 28,
        itemBuilder: (context, index) {
          final slot = slots[index];
          final isSelected = slot.hour == activeTime.hour &&
              ((slot.minute - activeTime.minute).abs() < 15);
          final label = _formatTime(slot);

          return InkWell(
            onTap: () {
              setState(() {
                if (_activeTimeSlotIsStart) {
                  _startTime = slot;
                  final startMin = slot.hour * 60 + slot.minute;
                  final endMin = _endTime.hour * 60 + _endTime.minute;
                  if (_selectedStartDate == null ||
                      _selectedEndDate == null ||
                      (_selectedStartDate!.year == _selectedEndDate!.year &&
                          _selectedStartDate!.month == _selectedEndDate!.month &&
                          _selectedStartDate!.day == _selectedEndDate!.day)) {
                    if (endMin <= startMin) {
                      final newEndMin = (startMin + 120) % (24 * 60);
                      _endTime = TimeOfDay(hour: newEndMin ~/ 60, minute: newEndMin % 60);
                    }
                  }
                } else {
                  _endTime = slot;
                }
              });
            },
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? odooActiveTimeBlue : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFF222222),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    final monthName = DateFormat('MMMM yyyy').format(_currentMonth);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          // Previous Month Button
          InkWell(
            onTap: _previousMonth,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(
                Icons.chevron_left_rounded,
                size: 18,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(width: 2),

          // Next Month Button
          InkWell(
            onTap: _nextMonth,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Month & Year Text
          Expanded(
            child: Text(
              monthName,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF2E2E2E),
              ),
            ),
          ),

          // Odoo-style Range Toggle Button [ 📅- / 📅+ ]
          if (widget.allowRange)
            Tooltip(
              message: _isRangeMode
                  ? 'Switch to Single Date mode'
                  : 'Switch to Date Range mode',
              child: InkWell(
                onTap: _toggleRangeMode,
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isRangeMode
                        ? const Color(0xFF714B67).withValues(alpha: 0.12)
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _isRangeMode ? odooPurple : Colors.grey.shade300,
                      width: 1.1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_month_outlined,
                        size: 13,
                        color: _isRangeMode ? odooPurple : Colors.grey.shade700,
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        _isRangeMode ? Icons.remove : Icons.add,
                        size: 10,
                        color: _isRangeMode ? odooPurple : Colors.grey.shade700,
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

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final firstWeekday = firstDayOfMonth.weekday; // 1 to 7 (Mon = 1)
    final gridStartDate = firstDayOfMonth.subtract(Duration(days: firstWeekday - 1));

    final rows = <Widget>[];

    // Weekday Headers: W, T, F, S, S (matching Image 2)
    rows.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map(
            (dayLetter) => Expanded(
              child: Text(
                dayLetter,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF222222),
                ),
              ),
            ),
          ).toList(),
        ),
      ),
    );

    DateTime currentDay = gridStartDate;

    for (int rowIdx = 0; rowIdx < 6; rowIdx++) {
      final dayCells = <Widget>[];

      for (int colIdx = 0; colIdx < 7; colIdx++) {
        final day = currentDay;
        final cell = _buildDayCell(day);
        dayCells.add(Expanded(child: cell));
        currentDay = currentDay.add(const Duration(days: 1));
      }

      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(children: dayCells),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }

  Widget _buildDayCell(DateTime date) {
    final isCurrentMonth = date.month == _currentMonth.month;

    final dateOnly = DateTime(date.year, date.month, date.day);
    final startDateOnly = _selectedStartDate != null
        ? DateTime(_selectedStartDate!.year, _selectedStartDate!.month, _selectedStartDate!.day)
        : null;
    final endDateOnly = _selectedEndDate != null
        ? DateTime(_selectedEndDate!.year, _selectedEndDate!.month, _selectedEndDate!.day)
        : null;

    final bool isStart = startDateOnly != null && dateOnly.isAtSameMomentAs(startDateOnly);
    final bool isEnd = endDateOnly != null && dateOnly.isAtSameMomentAs(endDateOnly);
    final bool isSingleSelected = !_isRangeMode && isStart;

    final bool isInRange = _isRangeMode &&
        startDateOnly != null &&
        endDateOnly != null &&
        dateOnly.isAfter(startDateOnly) &&
        dateOnly.isBefore(endDateOnly);

    final bool isHoverPreview = _isRangeMode &&
        startDateOnly != null &&
        endDateOnly == null &&
        _hoveredDate != null &&
        dateOnly.isAfter(startDateOnly) &&
        (dateOnly.isBefore(_hoveredDate!) || dateOnly.isAtSameMomentAs(_hoveredDate!));

    return MouseRegion(
      onEnter: (_) {
        if (_isRangeMode && _selectedStartDate != null && _selectedEndDate == null) {
          setState(() => _hoveredDate = dateOnly);
        }
      },
      onExit: (_) {
        if (_hoveredDate != null) {
          setState(() => _hoveredDate = null);
        }
      },
      child: GestureDetector(
        onTap: () => _onDayTapped(date),
        child: Container(
          height: 26,
          alignment: Alignment.center,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Range Background Ribbon
              if (_isRangeMode && endDateOnly != null && (isInRange || isStart || isEnd)) ...[
                if (isInRange)
                  Positioned.fill(
                    child: Container(color: odooLightTeal),
                  ),
                if (isStart)
                  Positioned.fill(
                    left: 12,
                    child: Container(color: odooLightTeal),
                  ),
                if (isEnd)
                  Positioned.fill(
                    right: 12,
                    child: Container(color: odooLightTeal),
                  ),
              ] else if (isHoverPreview) ...[
                Positioned.fill(
                  child: Container(color: odooLightTeal.withValues(alpha: 0.5)),
                ),
              ],

              // Day Number Circle
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isStart
                      ? odooCoralRed
                      : (isEnd
                          ? odooLightTeal
                          : (isSingleSelected
                              ? odooCoralRed
                              : (isInRange
                                  ? odooLightTeal
                                  : (isHoverPreview
                                      ? odooLightTeal.withValues(alpha: 0.5)
                                      : Colors.transparent)))),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${date.day}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: isStart || isEnd ? FontWeight.bold : FontWeight.w500,
                    color: isStart
                        ? Colors.white
                        : (isEnd
                            ? const Color(0xFF222222)
                            : (isInRange
                                ? const Color(0xFF222222)
                                : (isCurrentMonth
                                    ? const Color(0xFF222222)
                                    : Colors.grey.shade400))),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          if (widget.includeTime) ...[
            if (!_isRangeMode) ...[
              // Single Date Mode: Time Box (e.g. 12:00pm)
              InkWell(
                onTap: () {
                  setState(() => _activeTimeSlotIsStart = true);
                  _scrollToActiveTime();
                },
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _activeTimeSlotIsStart ? odooActiveTimeBlue : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _activeTimeSlotIsStart ? const Color(0xFF93C5FD) : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    _formatTime(_startTime),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _activeTimeSlotIsStart ? const Color(0xFF1E3A8A) : Colors.black87,
                    ),
                  ),
                ),
              ),
            ] else ...[
              // Range Mode: Start Time Box ➔ End Time Box (matching Image 2)
              InkWell(
                onTap: () {
                  setState(() => _activeTimeSlotIsStart = true);
                  _scrollToActiveTime();
                },
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _activeTimeSlotIsStart ? odooActiveTimeBlue : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _activeTimeSlotIsStart ? const Color(0xFF93C5FD) : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    _formatTime(_startTime),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _activeTimeSlotIsStart ? const Color(0xFF1E3A8A) : Colors.black87,
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.grey),
              ),
              InkWell(
                onTap: () {
                  setState(() => _activeTimeSlotIsStart = false);
                  _scrollToActiveTime();
                },
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: !_activeTimeSlotIsStart ? odooActiveTimeBlue : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: !_activeTimeSlotIsStart ? const Color(0xFF93C5FD) : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    _formatTime(_endTime),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: !_activeTimeSlotIsStart ? const Color(0xFF1E3A8A) : Colors.black87,
                    ),
                  ),
                ),
              ),
            ],
          ],

          const Spacer(),

          // Eraser / Clear Button [ 🧹 ]
          Tooltip(
            message: 'Clear selection',
            child: InkWell(
              onTap: _clearSelection,
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Icon(
                  Icons.cleaning_services_rounded,
                  size: 15,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Purple Apply Button [ Apply ] (matches Image 2)
          ElevatedButton(
            onPressed: _apply,
            style: ElevatedButton.styleFrom(
              backgroundColor: odooPurple,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: const Size(60, 32),
            ),
            child: Text(
              'Apply',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A clean form field that displays the planned date range and opens the Odoo Date Range Picker when tapped
class OdooPlannedDateField extends StatelessWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isReadOnly;
  final bool includeTime;
  final String label;
  final void Function(OdooDateRangeResult result) onChanged;
  final VoidCallback? onClear;

  const OdooPlannedDateField({
    super.key,
    this.startDate,
    this.endDate,
    this.isReadOnly = false,
    this.includeTime = true,
    this.label = 'Planned Date',
    required this.onChanged,
    this.onClear,
  });

  String _formatDisplay(DateTime dt) {
    if (includeTime) {
      return DateFormat('MMM d, hh:mma').format(dt).toLowerCase();
    }
    return DateFormat('MMM d, yyyy').format(dt);
  }

  String _getDisplayText() {
    if (startDate == null && endDate == null) {
      return 'Set planned date...';
    }
    if (startDate != null && endDate != null) {
      return '${_formatDisplay(startDate!)} ➔ ${_formatDisplay(endDate!)}';
    }
    if (startDate != null) {
      return _formatDisplay(startDate!);
    }
    return _formatDisplay(endDate!);
  }

  @override
  Widget build(BuildContext context) {
    final hasDate = startDate != null || endDate != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF00A09D),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '?',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF00A09D),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: isReadOnly
              ? null
              : () async {
                  final result = await showOdooDateRangePicker(
                    context: context,
                    initialStartDate: startDate,
                    initialEndDate: endDate,
                    includeTime: includeTime,
                    allowRange: true,
                  );
                  if (result != null) {
                    onChanged(result);
                  }
                },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isReadOnly ? Colors.grey.shade100 : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hasDate ? const Color(0xFFEF5350).withValues(alpha: 0.5) : Colors.grey.shade300,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  size: 18,
                  color: hasDate ? const Color(0xFFEF5350) : Colors.grey.shade600,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _getDisplayText(),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: hasDate ? FontWeight.w600 : FontWeight.w400,
                      color: hasDate ? const Color(0xFFEF5350) : Colors.grey.shade500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasDate && !isReadOnly) ...[
                  InkWell(
                    onTap: () {
                      if (onClear != null) {
                        onClear!();
                      } else {
                        onChanged(const OdooDateRangeResult());
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
