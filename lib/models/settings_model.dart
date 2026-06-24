import 'dart:convert';

class SettingsModel {
  final Duration idleThreshold;
  final Duration calculationDuration;
  final int perSessionScreenshot;
  final int offlineTime;
  final String timezone;
  final bool maintenance;

  SettingsModel({
    required this.idleThreshold,
    required this.calculationDuration,
    required this.perSessionScreenshot,
    required this.offlineTime,
    required this.timezone,
    required this.maintenance,
  });

  factory SettingsModel.fromJson(Map<String, dynamic> json) {
    // Parse values from API
    final idleTimeValue =
        json['idle_time'] != null ? int.parse(json['idle_time'].toString()) : 0;
    final sessionDurationValue =
        json['session_duration'] != null
            ? int.parse(json['session_duration'].toString())
            : 0;
    final perSessionScreenshotValue = json['per_session_screenshot'] ?? 0;
    final offlineTimeValue = json['offline_time'] ?? 0;

    // Apply fallback values if API returns 0 or invalid values
    return SettingsModel(
      idleThreshold: Duration(
        minutes: idleTimeValue > 0 ? idleTimeValue : 5, // Default: 5 minutes
      ),
      calculationDuration: Duration(
        minutes:
            sessionDurationValue > 0
                ? sessionDurationValue
                : 10, // Default: 10 minutes
      ),
      perSessionScreenshot:
          perSessionScreenshotValue > 0
              ? perSessionScreenshotValue
              : 3, // Default: 3 screenshots
      offlineTime:
          offlineTimeValue > 0 ? offlineTimeValue : 30, // Default: 30 minutes
      timezone:
          json['timezone']?.toString().isNotEmpty == true
              ? json['timezone'].toString()
              : 'UTC',
      maintenance: json['maintenance'] ?? false,
    );
  }

  // Factory method to create default settings when API fails or returns invalid data
  factory SettingsModel.createDefault() {
    return SettingsModel(
      idleThreshold: Duration(minutes: 5), // 5 minutes idle threshold
      calculationDuration: Duration(minutes: 10), // 10 minutes session duration
      perSessionScreenshot: 3, // 3 screenshots per session
      offlineTime: 30, // 30 minutes offline time
      timezone: 'UTC', // UTC timezone
      maintenance: false, // Not in maintenance mode
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'idle_time': idleThreshold.inMinutes,
      'session_duration': calculationDuration.inMinutes,
      'per_session_screenshot': perSessionScreenshot,
      'offline_time': offlineTime,
      'timezone': timezone,
      'maintenance': maintenance,
    };
  }

  SettingsModel copyWith({
    Duration? idleThreshold,
    Duration? sessionDuration,
    int? perSessionScreenshot,
    int? offlineTime,
    String? timezone,
    bool? maintenance,
  }) {
    return SettingsModel(
      idleThreshold: idleThreshold ?? this.idleThreshold,
      calculationDuration: Duration(
        minutes: sessionDuration?.inMinutes ?? calculationDuration.inMinutes,
      ),
      perSessionScreenshot: perSessionScreenshot ?? this.perSessionScreenshot,
      offlineTime: offlineTime ?? this.offlineTime,
      timezone: timezone ?? this.timezone,
      maintenance: maintenance ?? this.maintenance,
    );
  }

  // Check if settings have valid (non-zero) values
  bool get hasValidValues {
    return idleThreshold.inMinutes > 0 &&
        calculationDuration.inMinutes > 0 &&
        perSessionScreenshot > 0;
  }

  // Check if settings appear to be default/fallback values
  bool get isUsingFallbackValues {
    return idleThreshold.inMinutes == 5 &&
        calculationDuration.inMinutes == 10 &&
        perSessionScreenshot == 3 &&
        offlineTime == 30;
  }

  @override
  String toString() => jsonEncode(toJson());
}
