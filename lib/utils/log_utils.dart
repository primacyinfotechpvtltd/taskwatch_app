import 'dart:io';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class LogUtils {
  static Logger? _logger;
  static File? _logFile;

  static Future<void> init() async {
    if (_logger != null) return;

    try {
      final directory = await getApplicationSupportDirectory();
      final logDirectory = Directory('${directory.path}/logs');
      if (!await logDirectory.exists()) {
        await logDirectory.create(recursive: true);
      }

      _logFile = File('${logDirectory.path}/app_log.txt');
      
      // Clear log file if it's too large (> 5MB)
      if (await _logFile!.exists() && await _logFile!.length() > 5 * 1024 * 1024) {
        await _logFile!.delete();
      }

      _logger = Logger(
        printer: PrettyPrinter(
          methodCount: 0,
          errorMethodCount: 8,
          lineLength: 120,
          colors: true,
          printEmojis: true,
          printTime: true,
        ),
        output: MultiOutput([
          ConsoleOutput(),
          FileOutput(file: _logFile!),
        ]),
      );

      _logger!.i('Logging initialized. Log file: ${_logFile!.path}');
      _logger!.i('Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
    } catch (e) {
      debugPrint('Failed to initialize logger: $e');
    }
  }

  static void i(String message) {
    _logger?.i(message);
    if (_logger == null) debugPrint('[INFO] $message');
  }

  static void e(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger?.e(message, error, stackTrace);
    if (_logger == null) debugPrint('[ERROR] $message: $error');
  }

  static void w(String message) {
    _logger?.w(message);
    if (_logger == null) debugPrint('[WARN] $message');
  }

  static String get logFilePath => _logFile?.path ?? 'Log not initialized';
}

class FileOutput extends LogOutput {
  final File file;

  FileOutput({required this.file});

  @override
  void output(OutputEvent event) {
    final List<String> lines = event.lines;
    for (var line in lines) {
      file.writeAsStringSync('$line\n', mode: FileMode.append);
    }
  }
}
