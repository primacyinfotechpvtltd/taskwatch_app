import 'dart:io';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

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

      // Silent file logger - no terminal/console output to keep terminal 100% clean
      _logger = Logger(
        printer: SimplePrinter(printTime: false),
        output: FileOutput(file: _logFile!),
      );

      _logger!.i('Logging initialized. Log file: ${_logFile!.path}');
      _logger!.i('Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
    } catch (_) {}
  }

  static void i(String message) {
    _logger?.i(message);
  }

  static void e(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger?.e(message, error, stackTrace);
  }

  static void w(String message) {
    _logger?.w(message);
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
      try {
        file.writeAsStringSync('$line\n', mode: FileMode.append);
      } catch (_) {}
    }
  }
}
