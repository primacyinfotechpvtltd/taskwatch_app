import 'package:pi_task_watch/exports.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'dart:math' as math;

class DashboardAnnouncementSection extends StatelessWidget {
  const DashboardAnnouncementSection({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<AnnouncementController>()
        ? Get.find<AnnouncementController>()
        : Get.put(AnnouncementController());

    return Obx(() {
      if (controller.isLoading.value && controller.announcements.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
            ),
          ),
        );
      }

      // Filter active approved announcements for the dashboard preview
      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      
      final activeAnnouncements = controller.announcements.where((a) {
        // Show if state is approved
        if (a.state != 'approved') return false;
        
        // And if current date is within start and end date (inclusive)
        try {
          final start = DateTime.parse(a.dateStart);
          final end = DateTime.parse(a.dateEnd).add(const Duration(days: 1)); // inclusive of end day
          return now.isAfter(start) && now.isBefore(end);
        } catch (_) {
          return true; // fallback if parse fails
        }
      }).toList();

      debugPrint("DASHBOARD_ANNOUNCEMENTS_COUNT: ${controller.announcements.length}");
      debugPrint("DASHBOARD_ACTIVE_COUNT: ${activeAnnouncements.length}");
      for (var a in controller.announcements) {
        debugPrint("DASHBOARD_ANNOUNCEMENT: name=${a.name}, state=${a.state}, start=${a.dateStart}, end=${a.dateEnd}");
      }

      return Container(
        margin: const EdgeInsets.only(top: 16),
        decoration: AppTheme.glassDecoration(borderRadius: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.campaign_rounded,
                          color: AppTheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Announcements',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF25181E),
                        ),
                      ),
                      if (activeAnnouncements.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: const BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                          child: Text(
                            '${activeAnnouncements.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => _showAllAnnouncementsDialog(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'View All',
                          style: GoogleFonts.inter(
                            color: AppTheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _showAddAnnouncementDialog(context),
                        icon: const Icon(Icons.add_rounded, size: 20),
                        color: AppTheme.primary,
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.primary.withOpacity(0.1),
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(28, 28),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 0.5),

            // Announcement List
            if (activeAnnouncements.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.notifications_none_rounded,
                        size: 32,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No active announcements',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: activeAnnouncements.length > 3 ? 3 : activeAnnouncements.length,
                separatorBuilder: (context, index) => const Divider(height: 1, thickness: 0.5),
                itemBuilder: (context, index) {
                  final announcement = activeAnnouncements[index];
                  return AnnouncementListTile(
                    announcement: announcement,
                    onTap: () => _showAnnouncementDetail(context, announcement),
                  );
                },
              ),
          ],
        ),
      );
    });
  }

  void _showAnnouncementDetail(BuildContext context, AnnouncementModel announcement) {
    DialogUtils.showAppDialog(
      context: context,
      title: 'Announcement Details',
      content: AnnouncementDetailDialog(announcement: announcement),
    );
  }

  void _showAddAnnouncementDialog(BuildContext context) {
    DialogUtils.showAppDialog(
      context: context,
      title: 'Add Announcement',
      content: const AddAnnouncementDialog(),
    );
  }

  void _showAllAnnouncementsDialog(BuildContext context) {
    DialogUtils.showAppDialog(
      context: context,
      title: 'All Announcements',
      content: const AllAnnouncementsDialog(),
    );
  }
}

class AnnouncementListTile extends StatelessWidget {
  final AnnouncementModel announcement;
  final VoidCallback onTap;

  const AnnouncementListTile({
    super.key,
    required this.announcement,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final startDate = _formatDateStr(announcement.dateStart);
    final endDate = _formatDateStr(announcement.dateEnd);

    if (announcement.isBirthdayAnnouncement) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              colors: [
                Color(0xFFFFECEF),
                Color(0xFFFFF0E0),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: const Color(0xFFFFD0D5).withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4D6D).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cake_rounded,
                  color: Color(0xFFFF4D6D),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF4D6D).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Birthday 🎂',
                            style: GoogleFonts.inter(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFFF4D6D),
                            ),
                          ),
                        ),
                        Text(
                          '$startDate - $endDate',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      announcement.title,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF25181E),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline_rounded,
                          size: 11,
                          color: Color(0xFFFF4D6D),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          announcement.birthdayEmployee.isNotEmpty
                              ? announcement.birthdayEmployee
                              : announcement.author,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFFF4D6D),
                          ),
                        ),
                        const Spacer(),
                        _buildStateBadge(announcement.state),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (announcement.isVacationAnnouncement) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              colors: [
                Color(0xFFE0F7FA),
                Color(0xFFB2DFDB),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: const Color(0xFF00796B).withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00796B).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.beach_access_rounded,
                  color: Color(0xFF00796B),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00796B).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Vacation 🏖️',
                            style: GoogleFonts.inter(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF00796B),
                            ),
                          ),
                        ),
                        Text(
                          '$startDate - $endDate',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      announcement.title,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF25181E),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline_rounded,
                          size: 11,
                          color: Color(0xFF00796B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          announcement.author,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF00796B),
                          ),
                        ),
                        const Spacer(),
                        _buildStateBadge(announcement.state),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (announcement.isWarningAnnouncement) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              colors: [
                Color(0xFFFFF8E1),
                Color(0xFFFFE082),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: const Color(0xFFF57F17).withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF57F17).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFF57F17),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF57F17).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Alert ⚠️',
                            style: GoogleFonts.inter(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFF57F17),
                            ),
                          ),
                        ),
                        Text(
                          '$startDate - $endDate',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      announcement.title,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF25181E),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline_rounded,
                          size: 11,
                          color: Color(0xFFF57F17),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          announcement.author,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFF57F17),
                          ),
                        ),
                        const Spacer(),
                        _buildStateBadge(announcement.state),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    announcement.title,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF25181E),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$startDate - $endDate',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              announcement.plainContent,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.person_outline_rounded,
                  size: 11,
                  color: AppTheme.primary.withOpacity(0.7),
                ),
                const SizedBox(width: 4),
                Text(
                  announcement.author,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary.withOpacity(0.8),
                  ),
                ),
                const Spacer(),
                _buildStateBadge(announcement.state),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStateBadge(String state) {
    Color color;
    String label;

    switch (state) {
      case 'approved':
        color = AppTheme.secondary;
        label = 'Approved';
        break;
      case 'to_approve':
        color = AppTheme.tertiary;
        label = 'To Approve';
        break;
      case 'draft':
        color = Colors.grey.shade600;
        label = 'Draft';
        break;
      case 'expired':
        color = AppTheme.error;
        label = 'Expired';
        break;
      case 'rejected':
        color = AppTheme.error;
        label = 'Refused';
        break;
      case 'cancel':
        color = Colors.grey.shade400;
        label = 'Cancelled';
        break;
      default:
        color = Colors.grey;
        label = state.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  String _formatDateStr(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('d MMM').format(date);
    } catch (_) {
      return dateStr;
    }
  }
}

class AnnouncementDetailDialog extends StatefulWidget {
  final AnnouncementModel announcement;

  const AnnouncementDetailDialog({
    super.key,
    required this.announcement,
  });

  @override
  State<AnnouncementDetailDialog> createState() => _AnnouncementDetailDialogState();
}

class _AnnouncementDetailDialogState extends State<AnnouncementDetailDialog> {
  OverlayEntry? _leftConfettiEntry;
  OverlayEntry? _rightConfettiEntry;

  @override
  void initState() {
    super.initState();
    if (widget.announcement.isBirthdayAnnouncement) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerConfetti();
      });
    }
  }

  @override
  void dispose() {
    _clearConfetti();
    super.dispose();
  }

  void _clearConfetti() {
    _leftConfettiEntry?.remove();
    _leftConfettiEntry = null;
    _rightConfettiEntry?.remove();
    _rightConfettiEntry = null;
  }

  void _triggerConfetti() {
    final overlayState = Overlay.of(context);
    if (overlayState == null) return;

    // Create Left Confetti Entry
    _leftConfettiEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 0,
        left: 0,
        width: 350,
        height: 350,
        child: IgnorePointer(
          child: Lottie.asset(
            'assets/Confetti Popper.json',
            repeat: true,
          ),
        ),
      ),
    );

    // Create Right Confetti Entry (mirrored)
    _rightConfettiEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 0,
        right: 0,
        width: 350,
        height: 350,
        child: IgnorePointer(
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationY(math.pi),
            child: Lottie.asset(
              'assets/Confetti Popper.json',
              repeat: true,
            ),
          ),
        ),
      ),
    );

    overlayState.insert(_leftConfettiEntry!);
    overlayState.insert(_rightConfettiEntry!);

    // Let it pop for 2 full cycles (approx 4 seconds) then clean up
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        _clearConfetti();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final start = _formatFullDate(widget.announcement.dateStart);
    final end = _formatFullDate(widget.announcement.dateEnd);
    final created = _formatDateTime(widget.announcement.createDate);

    return Container(
      width: 400,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status and meta
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStateBadge(widget.announcement.state),
                Text(
                  'Code: ${widget.announcement.name}',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Title
            Text(
              widget.announcement.title,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF25181E),
              ),
            ),
            const SizedBox(height: 16),

            // Details card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primary.withOpacity(0.05)),
              ),
              child: Column(
                children: [
                  _buildDetailRow(
                    icon: Icons.date_range_rounded,
                    label: 'Validity Period',
                    value: '$start to $end',
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    icon: Icons.person_outline_rounded,
                    label: 'Created By',
                    value: widget.announcement.author,
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    icon: Icons.access_time_rounded,
                    label: 'Created Date',
                    value: created,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 1. Decorative / Category Card (Top)
            if (widget.announcement.isBirthdayAnnouncement) ...[
              // Festive birthday card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFFECEF),
                      Color(0xFFFFF0E0),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFD0D5).withOpacity(0.5)),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.cake_rounded,
                      color: Color(0xFFFF4D6D),
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Wish them a wonderful day! 🎉",
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF25181E),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Send your warmest wishes to your team member.",
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ] else if (widget.announcement.isVacationAnnouncement) ...[
              // Beach Vacation Lottie Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFE0F7FA),
                      Color(0xFFE0F2F1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF00796B).withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      height: 140,
                      child: Lottie.asset(
                        'assets/Beach Vacation.json',
                        repeat: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Have a fantastic vacation! 🏖️",
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF004D40),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Wishing them refreshing time off and pleasant travels.",
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.teal.shade800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ] else if (widget.announcement.isWarningAnnouncement) ...[
              // Warning / Alert Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFFF8E1),
                      Color(0xFFFFF3E0),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF57F17).withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      height: 140,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/hr_warning.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Important Alert! ⚠️",
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF5D4037),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Please pay close attention to this notice.",
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.amber.shade900,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 2. Message / Description content (Bottom)
            if (widget.announcement.content.isNotEmpty &&
                widget.announcement.plainContent.isNotEmpty &&
                widget.announcement.plainContent != 'false') ...[
              Text(
                'Message',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF25181E),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: HtmlTextRenderer(htmlText: widget.announcement.content),
              ),
              const SizedBox(height: 24),
            ] else ...[
              const SizedBox(height: 16),
            ],

            // Back button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStateBadge(String state) {
    Color color;
    String label;

    switch (state) {
      case 'approved':
        color = AppTheme.secondary;
        label = 'Approved';
        break;
      case 'to_approve':
        color = AppTheme.tertiary;
        label = 'Waiting Approval';
        break;
      case 'draft':
        color = Colors.grey.shade600;
        label = 'Draft';
        break;
      case 'expired':
        color = AppTheme.error;
        label = 'Expired';
        break;
      case 'rejected':
        color = AppTheme.error;
        label = 'Refused';
        break;
      case 'cancel':
        color = Colors.grey.shade400;
        label = 'Cancelled';
        break;
      default:
        color = Colors.grey;
        label = state.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primary.withOpacity(0.8)),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF25181E),
          ),
        ),
      ],
    );
  }

  String _formatFullDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  String _formatDateTime(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy, hh:mm a').format(date);
    } catch (_) {
      return dateStr;
    }
  }
}

class AddAnnouncementDialog extends StatefulWidget {
  const AddAnnouncementDialog({super.key});

  @override
  State<AddAnnouncementDialog> createState() => _AddAnnouncementDialogState();
}

class _AddAnnouncementDialogState extends State<AddAnnouncementDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  bool _isGeneral = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final initialDate = isStart ? _startDate : _endDate;
    final firstDate = isStart ? DateTime.now().subtract(const Duration(days: 30)) : _startDate;
    final lastDate = DateTime.now().add(const Duration(days: 365));

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          // Ensure end date is after start date
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate.add(const Duration(days: 1));
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final controller = Get.isRegistered<AnnouncementController>()
        ? Get.find<AnnouncementController>()
        : Get.put(AnnouncementController());
    // Wrap the content in basic HTML structure since Odoo expects html
    final htmlContent = '<p>${_contentController.text.trim().replaceAll('\n', '<br/>')}</p>';

    final success = await controller.createAnnouncement(
      title: _titleController.text.trim(),
      content: htmlContent,
      startDate: _startDate,
      endDate: _endDate,
      isAnnouncement: _isGeneral,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Get.back();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Input
            Text(
              'Title *',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF25181E),
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _titleController,
              style: GoogleFonts.inter(fontSize: 12),
              decoration: const InputDecoration(
                hintText: 'Enter announcement title',
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Title is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Date Picker Row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Start Date',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF25181E),
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () => _selectDate(context, true),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 14, color: AppTheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('dd MMM yyyy').format(_startDate),
                                style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'End Date',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF25181E),
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () => _selectDate(context, false),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 14, color: AppTheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('dd MMM yyyy').format(_endDate),
                                style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // General Switch
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'General Announcement?',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF25181E),
                  ),
                ),
                Switch(
                  value: _isGeneral,
                  onChanged: (val) {
                    setState(() => _isGeneral = val);
                  },
                  activeColor: AppTheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Description Input
            Text(
              'Details *',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF25181E),
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _contentController,
              maxLines: 4,
              style: GoogleFonts.inter(fontSize: 12),
              decoration: const InputDecoration(
                hintText: 'Enter announcement details...',
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Details are required';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Submit Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSubmitting ? null : () => Get.back(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Add & Approve'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AllAnnouncementsDialog extends StatefulWidget {
  const AllAnnouncementsDialog({super.key});

  @override
  State<AllAnnouncementsDialog> createState() => _AllAnnouncementsDialogState();
}

class _AllAnnouncementsDialogState extends State<AllAnnouncementsDialog> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<AnnouncementController>()
        ? Get.find<AnnouncementController>()
        : Get.put(AnnouncementController());

    return Container(
      width: 450,
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          // Search box
          TextField(
            controller: _searchController,
            style: GoogleFonts.inter(fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Search announcements...',
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppTheme.primary),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val.trim().toLowerCase();
              });
            },
          ),
          const SizedBox(height: 12),

          // List of announcements
          Expanded(
            child: Obx(() {
              final filtered = controller.announcements.where((a) {
                if (a.state != 'approved') return false;
                if (_searchQuery.isEmpty) return true;
                return a.title.toLowerCase().contains(_searchQuery) ||
                    a.plainContent.toLowerCase().contains(_searchQuery) ||
                    a.author.toLowerCase().contains(_searchQuery);
              }).toList();

              if (controller.isLoading.value) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                  ),
                );
              }

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off_rounded, size: 36, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text(
                        'No announcements found',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (context, index) => const Divider(height: 1, thickness: 0.5),
                itemBuilder: (context, index) {
                  final announcement = filtered[index];
                  return AnnouncementListTile(
                    announcement: announcement,
                    onTap: () {
                      DialogUtils.showAppDialog(
                        context: context,
                        title: 'Announcement Details',
                        content: AnnouncementDetailDialog(announcement: announcement),
                      );
                    },
                  );
                },
              );
            }),
          ),

          // Close button
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 0.5),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Get.back(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                'Back to Dashboard',
                style: GoogleFonts.inter(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HtmlTextRenderer extends StatelessWidget {
  final String htmlText;

  const HtmlTextRenderer({
    super.key,
    required this.htmlText,
  });

  @override
  Widget build(BuildContext context) {
    if (htmlText.isEmpty) {
      return Text(
        'No message content',
        style: GoogleFonts.inter(
          fontSize: 11,
          color: Colors.grey.shade500,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    try {
      // 1. Replace block elements/br with newlines
      String parsed = htmlText
          .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
          .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
          .replaceAll(RegExp(r'</div>', caseSensitive: false), '\n')
          .replaceAll(RegExp(r'</li>', caseSensitive: false), '\n');

      // 2. Remove all remaining HTML tags (including those with attributes like <p style="...">)
      parsed = parsed.replaceAll(RegExp(r'<[^>]*>'), '');

      // 3. Decode HTML entities
      parsed = parsed
          .replaceAll('&nbsp;', ' ')
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&quot;', '"')
          .replaceAll('&#39;', "'")
          .replaceAll('&apos;', "'");

      // 4. Trim extra newlines/spaces
      parsed = parsed.trim();

      if (parsed.isEmpty || parsed == 'false') {
        return Text(
          'No message content',
          style: GoogleFonts.inter(
            fontSize: 11,
            color: Colors.grey.shade500,
            fontStyle: FontStyle.italic,
          ),
        );
      }

      return SelectableText(
        parsed,
        style: GoogleFonts.inter(
          fontSize: 11,
          color: const Color(0xFF25181E),
          height: 1.4,
        ),
      );
    } catch (e) {
      return SelectableText(
        htmlText,
        style: GoogleFonts.inter(
          fontSize: 11,
          color: const Color(0xFF25181E),
          height: 1.4,
        ),
      );
    }
  }
}
