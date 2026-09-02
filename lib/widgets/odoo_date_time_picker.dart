import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pi_task_watch/theme/app_theme.dart';

/// ISO 8601 Week Number calculation
int getIsoWeekNumber(DateTime date) {
  // ISO week date weeks start on Monday (weekday = 1).
  // The first week of an ISO year is the one with the first Thursday in it.
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

/// The Odoo 16/17/18-style Date & Time Range Picker Widget
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

  DateTime? _hoveredDate;

  // Odoo Signature Color Palette
  static const Color odooPurple = Color(0xFF714B67);
  static const Color odooCoralRed = Color(0xFFDE4B4B);
  static const Color odooLightTeal = Color(0xFFC3E7EB);

  @override
  void initState() {
    super.initState();
    _isRangeMode = (widget.initialStartDate != null && widget.initialEndDate != null) &&
        widget.allowRange;

    _selectedStartDate = widget.initialStartDate ?? widget.initialEndDate;
    _selectedEndDate = _isRangeMode ? widget.initialEndDate : null;

    final now = DateTime.now();
    _currentMonth = DateTime(
      _selectedStartDate?.year ?? now.year,
      _selectedStartDate?.month ?? now.month,
      1,
    );

    _startTime = _selectedStartDate != null
        ? TimeOfDay.fromDateTime(_selectedStartDate!)
        : const TimeOfDay(hour: 18, minute: 0);

    _endTime = _selectedEndDate != null
        ? TimeOfDay.fromDateTime(_selectedEndDate!)
        : const TimeOfDay(hour: 18, minute: 0);
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

      // If no start date or both start and end dates are already set -> start a new selection
      if (_selectedStartDate == null || (_selectedStartDate != null && _selectedEndDate != null)) {
        _selectedStartDate = cleanDay;
        _selectedEndDate = null;
      } else {
        // Start date is set, end date is null
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

    if (_selectedEndDate != null) {
      if (widget.includeTime) {
        finalEnd = DateTime(
          _selectedEndDate!.year,
          _selectedEndDate!.month,
          _selectedEndDate!.day,
          _endTime.hour,
          _endTime.minute,
        );
      } else {
        finalEnd = DateTime(
          _selectedEndDate!.year,
          _selectedEndDate!.month,
          _selectedEndDate!.day,
          23,
          59,
          59,
        );
      }
    }

    if (!_isRangeMode) {
      // In Single Date mode: finalStart is the single deadline date
      widget.onApply(null, finalStart);
      return;
    }

    // If start is after end, adjust end to match start or swap
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

  Future<void> _openQuickTimeEditor({required bool isStart}) async {
    final initial = isStart ? _startTime : _endTime;
    int hour12 = initial.hourOfPeriod == 0 ? 12 : initial.hourOfPeriod;
    int minute = initial.minute;
    bool isAm = initial.period == DayPeriod.am;

    final picked = await showDialog<TimeOfDay>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Container(
                width: 280,
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 18,
                          color: odooPurple,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isStart ? 'Set Start Time' : 'Set End Time',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Hours Dropdown / Spinner
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: hour12,
                              isDense: true,
                              items: List.generate(12, (i) => i + 1).map((h) {
                                return DropdownMenuItem(
                                  value: h,
                                  child: Text(
                                    h.toString().padLeft(2, '0'),
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() => hour12 = val);
                                }
                              },
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            ':',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                        // Minutes Dropdown
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: (minute ~/ 5) * 5,
                              isDense: true,
                              items: List.generate(12, (i) => i * 5).map((m) {
                                return DropdownMenuItem(
                                  value: m,
                                  child: Text(
                                    m.toString().padLeft(2, '0'),
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() => minute = val);
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // AM / PM Toggle
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: () => setDialogState(() => isAm = true),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(8),
                                  bottomLeft: Radius.circular(8),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: isAm ? odooPurple : Colors.transparent,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(7),
                                      bottomLeft: Radius.circular(7),
                                    ),
                                  ),
                                  child: Text(
                                    'AM',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isAm ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () => setDialogState(() => isAm = false),
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(8),
                                  bottomRight: Radius.circular(8),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: !isAm ? odooPurple : Colors.transparent,
                                    borderRadius: const BorderRadius.only(
                                      topRight: Radius.circular(7),
                                      bottomRight: Radius.circular(7),
                                    ),
                                  ),
                                  child: Text(
                                    'PM',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: !isAm ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogCtx).pop(null),
                          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            int finalHour = hour12 % 12;
                            if (!isAm) finalHour += 12;
                            Navigator.of(dialogCtx).pop(TimeOfDay(hour: finalHour, minute: minute));
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: odooPurple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          child: const Text('Set Time', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
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
          // 1. Header: < > Month Year  [ 📅 ]
          _buildHeader(),

          const Divider(height: 1, color: Color(0xFFEEEEEE)),

          // 2. Calendar Grid (Week numbers + Mon to Sun days)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: _buildCalendarGrid(),
          ),

          const Divider(height: 1, color: Color(0xFFEEEEEE)),

          // 3. Bottom Toolbar: [ 12:00am ] ➔ [ 9:45am ]  [ 🧹 ]  [ Apply ]
          _buildBottomToolbar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final monthName = DateFormat('MMMM yyyy').format(_currentMonth);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          // Previous Month Button
          InkWell(
            onTap: _previousMonth,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.chevron_left_rounded,
                size: 20,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Next Month Button
          InkWell(
            onTap: _nextMonth,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Month & Year Text
          Expanded(
            child: Text(
              monthName,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF2E2E2E),
              ),
            ),
          ),

          // Odoo-style Range Toggle Button [ 📅+ ]
          if (widget.allowRange)
            Tooltip(
              message: _isRangeMode
                  ? 'Switch to Single Date mode'
                  : 'Switch to Date Range mode (Double date)',
              child: InkWell(
                onTap: _toggleRangeMode,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                  decoration: BoxDecoration(
                    color: _isRangeMode
                        ? const Color(0xFF714B67).withValues(alpha: 0.12)
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _isRangeMode ? odooPurple : Colors.grey.shade300,
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_month_outlined,
                        size: 15,
                        color: _isRangeMode ? odooPurple : Colors.grey.shade700,
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        _isRangeMode ? Icons.remove : Icons.add,
                        size: 11,
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
    // Generate 6 rows of 7 days (Monday through Sunday)
    // 1. First day of the month
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    // Monday = 1, Sunday = 7
    final firstWeekday = firstDayOfMonth.weekday; // 1 to 7

    // Start date for the first row (Monday of the starting week)
    final gridStartDate = firstDayOfMonth.subtract(Duration(days: firstWeekday - 1));

    final rows = <Widget>[];

    // Weekday Headers: ISO Week, M, T, W, T, F, S, S
    rows.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            // ISO week column header (empty / spacer)
            const SizedBox(
              width: 28,
              child: Text(
                '',
                textAlign: TextAlign.center,
              ),
            ),
            ...['M', 'T', 'W', 'T', 'F', 'S', 'S'].map(
              (dayLetter) => Expanded(
                child: Text(
                  dayLetter,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF222222),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    DateTime currentDay = gridStartDate;

    for (int rowIdx = 0; rowIdx < 6; rowIdx++) {
      // Calculate ISO week number for this week row
      final weekNum = getIsoWeekNumber(currentDay);

      final dayCells = <Widget>[];

      // Week number cell
      dayCells.add(
        SizedBox(
          width: 28,
          child: Text(
            '$weekNum',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF222222),
            ),
          ),
        ),
      );

      for (int colIdx = 0; colIdx < 7; colIdx++) {
        final cellDate = currentDay;
        final isCurrentMonth = cellDate.month == _currentMonth.month;

        dayCells.add(
          Expanded(
            child: _buildDayCell(cellDate, isCurrentMonth),
          ),
        );

        currentDay = currentDay.add(const Duration(days: 1));
      }

      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.5),
          child: Row(
            children: dayCells,
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }

  Widget _buildDayCell(DateTime date, bool isCurrentMonth) {
    final cleanDate = DateTime(date.year, date.month, date.day);

    final startDay = _selectedStartDate != null
        ? DateTime(
            _selectedStartDate!.year,
            _selectedStartDate!.month,
            _selectedStartDate!.day,
          )
        : null;

    final endDay = _selectedEndDate != null
        ? DateTime(
            _selectedEndDate!.year,
            _selectedEndDate!.month,
            _selectedEndDate!.day,
          )
        : null;

    final isStart = startDay != null && cleanDate.isAtSameMomentAs(startDay);
    final isEnd = endDay != null && cleanDate.isAtSameMomentAs(endDay);
    final isInRange = startDay != null &&
        endDay != null &&
        cleanDate.isAfter(startDay) &&
        cleanDate.isBefore(endDay);

    final isSingleSelected = isStart && (endDay == null || startDay.isAtSameMomentAs(endDay));

    final isHoverPreview = startDay != null &&
        endDay == null &&
        _hoveredDate != null &&
        _hoveredDate!.isAfter(startDay) &&
        cleanDate.isAfter(startDay) &&
        (cleanDate.isBefore(_hoveredDate!) || cleanDate.isAtSameMomentAs(_hoveredDate!));

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredDate = cleanDate),
      onExit: (_) => setState(() => _hoveredDate = null),
      child: GestureDetector(
        onTap: () => _onDayTapped(cleanDate),
        child: SizedBox(
          height: 32,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Background Range connector (Soft Light Teal)
              if (startDay != null && endDay != null && startDay.isBefore(endDay)) ...[
                if (isStart)
                  Positioned.fill(
                    left: 16,
                    child: Container(
                      color: odooLightTeal,
                    ),
                  ),
                if (isInRange)
                  Positioned.fill(
                    child: Container(
                      color: odooLightTeal,
                    ),
                  ),
                if (isEnd)
                  Positioned.fill(
                    right: 16,
                    child: Container(
                      color: odooLightTeal,
                    ),
                  ),
              ] else if (isHoverPreview) ...[
                Positioned.fill(
                  child: Container(
                    color: odooLightTeal.withValues(alpha: 0.5),
                  ),
                ),
              ],

              // 2. Day Circle / Highlight
              Container(
                width: 30,
                height: 30,
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
                    fontSize: 12,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          if (widget.includeTime) ...[
            if (!_isRangeMode) ...[
              // Single Date Mode: Single Time Box (e.g. 6:00pm)
              InkWell(
                onTap: () => _openQuickTimeEditor(isStart: true),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    _formatTime(_startTime),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
              const Spacer(),
            ] else ...[
              // Range Mode: Start Time Box (e.g. 12:00am)
              InkWell(
                onTap: () => _openQuickTimeEditor(isStart: true),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    _formatTime(_startTime),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 13,
                color: Colors.black87,
              ),
              const SizedBox(width: 6),
              // End Time Box (e.g. 9:45am)
              InkWell(
                onTap: () => _openQuickTimeEditor(isStart: false),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    _formatTime(_endTime),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
              const Spacer(),
            ],
          ] else ...[
            const Spacer(),
          ],

          // Eraser / Clear Button [ 🧹 ]
          Tooltip(
            message: 'Clear date selection',
            child: InkWell(
              onTap: _clearSelection,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Icon(
                  Icons.backspace_outlined,
                  size: 15,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Primary "Apply" Button (Odoo purple #714B67)
          ElevatedButton(
            onPressed: _apply,
            style: ElevatedButton.styleFrom(
              backgroundColor: odooPurple,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Apply',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A dedicated form field widget that displays the Odoo-styled Planned Date range
/// and opens the Odoo Date Range Picker popover on click.
class OdooPlannedDateField extends StatelessWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final String label;
  final bool isReadOnly;
  final bool includeTime;
  final ValueChanged<OdooDateRangeResult>? onChanged;
  final VoidCallback? onClear;

  const OdooPlannedDateField({
    super.key,
    this.startDate,
    this.endDate,
    this.label = 'Planned Date',
    this.isReadOnly = false,
    this.includeTime = true,
    this.onChanged,
    this.onClear,
  });

  String _formatDateTime(DateTime dt) {
    if (includeTime) {
      return DateFormat('MM/dd/yyyy hh:mm:ss a').format(dt);
    }
    return DateFormat('MM/dd/yyyy').format(dt);
  }

  String _formatCompact(DateTime dt) {
    if (includeTime) {
      return DateFormat('MMM d, h:mm a').format(dt);
    }
    return DateFormat('MMM d, yyyy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final bool hasStart = startDate != null;
    final bool hasEnd = endDate != null;
    final bool hasValues = hasStart || hasEnd;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            if (hasValues && onChanged != null && !isReadOnly) ...[
              const Spacer(),
              InkWell(
                onTap: onClear ?? () => onChanged?.call(const OdooDateRangeResult()),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'Clear',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ),
            ],
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
                  );
                  if (result != null && onChanged != null) {
                    onChanged!(result);
                  }
                },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: isReadOnly ? Colors.grey.shade100 : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hasValues
                    ? const Color(0xFF00A09D).withValues(alpha: 0.5)
                    : Colors.grey.shade300,
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 15,
                  color: hasValues ? const Color(0xFF714B67) : Colors.grey.shade500,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: (hasStart && hasEnd)
                      ? Row(
                          children: [
                            // Start Date
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00A09D).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: const Color(0xFF00A09D).withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Text(
                                  _formatDateTime(startDate!),
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1B4965),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                size: 13,
                                color: Colors.grey,
                              ),
                            ),
                            // End Date
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF714B67).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: const Color(0xFF714B67).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  _formatCompact(endDate!),
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF714B67),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        )
                      : (hasValues
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00A09D).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: const Color(0xFF00A09D).withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                _formatDateTime((endDate ?? startDate)!),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1B4965),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            )
                          : Text(
                              isReadOnly ? 'No planned date' : 'Select planned date...',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            )),
                ),
                if (isReadOnly)
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 13,
                    color: Colors.grey.shade600,
                  )
                else
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    size: 20,
                    color: Colors.grey.shade600,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
