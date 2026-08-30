import 'package:logger/logger.dart';

/// Global logger instance for the application.
final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 120,
    colors: true,
    printEmojis: true,
    // Use dateTimeFormat instead of deprecated printTime.
    dateTimeFormat: DateTimeFormat.none,
  ),
);