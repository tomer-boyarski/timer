import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// Excel column mappings to stage IDs
/// Based on actual Excel file structure:
/// Column A (0): Date
/// Column B (1): prep_treadmill
/// Column C (2): run (the main variable - add 5s each session)
/// Column D (3): walk
///
/// Stages with FIXED durations (not in Excel):
/// - initialization: 3s
/// - prep_ekg: 5s
/// - treadmill_countdown: 5s
/// - accelerate: 15s
/// - decelerate: 12s
///
/// Stages with VARIABLE durations (read from Excel):
/// - prep_treadmill: from column B
/// - run: from column C (main variable - add 5s each session)
/// - walk: from column D
class ExcelColumnMapping {
  static const Map<String, int> stageToColumn = {
    'prep_treadmill': 1, // Column B
    'run': 2, // Column C
    'walk': 3, // Column D
  };

  static const Map<int, String> columnToStage = {
    1: 'prep_treadmill',
    2: 'run',
    3: 'walk',
  };

  // Fixed durations for stages not variable in Excel
  static const int initializationDuration = 3;
  static const int prepEkgDuration = 5;
  static const int treadmillCountdownDuration = 5;
  static const int accelerateDuration = 15;
  static const int decelerateDuration = 12;

  // Default durations for variable stages (used when Excel has no data)
  static const int defaultPrepTreadmillDuration = 10;
  static const int defaultRunDuration = 300; // 5 minutes
  static const int defaultWalkDuration = 180; // 3 minutes
}

/// Data class for a session row
class SessionData {
  final DateTime date;
  final Map<String, int> stageDurations;

  const SessionData({
    required this.date,
    required this.stageDurations,
  });

  /// Get duration for a stage, returns 0 if not found
  int getDuration(String stageId) => stageDurations[stageId] ?? 0;
}

/// Service for reading and writing Excel run log
class ExcelService {
  /// Default Excel file path (fixed location)
  static String get defaultExcelPath {
    // Fixed path to the meditation-exercise data folder
    if (!kIsWeb && Platform.isWindows) {
      return r'C:\projects\meditation-exercise\data\polar\run_log.xlsx';
    }
    return 'run_log.xlsx';
  }

  /// Read the last session from the Excel file
  /// Returns null if file doesn't exist or can't be read
  Future<SessionData?> readLastSession([String? filePath]) async {
    final path = filePath ?? defaultExcelPath;

    try {
      final file = File(path);
      if (!await file.exists()) {
        debugPrint('Excel file not found: $path');
        return null;
      }

      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);

      // Get the first (or only) sheet
      final sheetName = excel.tables.keys.first;
      final sheet = excel.tables[sheetName];

      if (sheet == null || sheet.maxRows < 2) {
        debugPrint('Excel sheet is empty or has no data rows');
        return null;
      }

      // Find the last row with actual data (not empty rows)
      // Start from the end and work backwards to find a row with a date value
      int lastRowIndex = -1;
      for (int i = sheet.maxRows - 1; i >= 1; i--) {
        // Skip header row (index 0)
        final row = sheet.rows[i];
        if (row.isNotEmpty && row[0] != null && row[0]!.value != null) {
          // Found a row with a date in column A
          lastRowIndex = i;
          break;
        }
      }

      if (lastRowIndex < 1) {
        debugPrint('No data rows found in Excel file');
        return null;
      }

      debugPrint('Found last data row at index: $lastRowIndex');
      final row = sheet.rows[lastRowIndex];

      // Parse date from column A
      DateTime date = DateTime.now();
      final dateCell = row[0];
      if (dateCell != null && dateCell.value != null) {
        final dateValue = dateCell.value;
        if (dateValue is DateCellValue) {
          date = DateTime(dateValue.year, dateValue.month, dateValue.day);
        } else if (dateValue is TextCellValue) {
          // Try parsing as text date - get string representation
          final textStr = dateValue.value.toString();
          try {
            date = DateFormat('M/d/yyyy').parse(textStr);
          } catch (_) {
            try {
              date = DateFormat('yyyy-MM-dd').parse(textStr);
            } catch (_) {}
          }
        }
      }

      // Parse stage durations
      final stageDurations = <String, int>{};

      for (final entry in ExcelColumnMapping.columnToStage.entries) {
        final colIndex = entry.key;
        final stageId = entry.value;

        if (colIndex < row.length) {
          final cell = row[colIndex];
          if (cell != null && cell.value != null) {
            final value = cell.value;
            int? duration;

            if (value is IntCellValue) {
              duration = value.value;
            } else if (value is DoubleCellValue) {
              // Excel stores time as fraction of day (e.g., 0:09:05 = 545/86400)
              final doubleVal = value.value;
              if (doubleVal < 1) {
                // Time value - convert from fraction of day to seconds
                duration = (doubleVal * 24 * 60 * 60).round();
              } else {
                duration = doubleVal.toInt();
              }
            } else if (value is TimeCellValue) {
              // Time cell value - convert hours:minutes:seconds to total seconds
              duration = value.hour * 3600 + value.minute * 60 + value.second;
            } else if (value is TextCellValue) {
              // Try parsing as integer or time string
              final textStr = value.value.toString();
              duration = int.tryParse(textStr);
              if (duration == null && textStr.contains(':')) {
                // Parse time string like "0:09:05"
                final parts = textStr.split(':');
                if (parts.length == 3) {
                  final h = int.tryParse(parts[0]) ?? 0;
                  final m = int.tryParse(parts[1]) ?? 0;
                  final s = int.tryParse(parts[2]) ?? 0;
                  duration = h * 3600 + m * 60 + s;
                } else if (parts.length == 2) {
                  final m = int.tryParse(parts[0]) ?? 0;
                  final s = int.tryParse(parts[1]) ?? 0;
                  duration = m * 60 + s;
                }
              }
            }

            if (duration != null && duration > 0) {
              stageDurations[stageId] = duration;
              debugPrint(
                  'Parsed $stageId from column $colIndex: $duration seconds');
            }
          }
        }
      }

      debugPrint('Read session data: date=$date, durations=$stageDurations');
      return SessionData(date: date, stageDurations: stageDurations);
    } catch (e) {
      debugPrint('Error reading Excel file: $e');
      return null;
    }
  }

  /// Append a new session to the Excel file
  /// Preserves existing formatting
  Future<bool> appendSession({
    required Map<String, int> stageDurations,
    String? filePath,
  }) async {
    final path = filePath ?? defaultExcelPath;

    try {
      final file = File(path);
      if (!await file.exists()) {
        debugPrint('Excel file not found: $path');
        return false;
      }

      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);

      // Get the first sheet
      final sheetName = excel.tables.keys.first;
      final sheet = excel.tables[sheetName];

      if (sheet == null) {
        debugPrint('Excel sheet not found');
        return false;
      }

      // Find the next row to write to
      final nextRow = sheet.maxRows;

      // Get today's date
      final today = DateTime.now();
      final dateStr = DateFormat('M/d/yyyy').format(today);

      // Write date to column A
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: nextRow),
        TextCellValue(dateStr),
      );

      // Write stage durations to appropriate columns as time values
      for (final entry in ExcelColumnMapping.stageToColumn.entries) {
        final stageId = entry.key;
        final colIndex = entry.value;

        final duration = stageDurations[stageId];
        if (duration != null) {
          // Convert seconds to time value (hours, minutes, seconds)
          final hours = duration ~/ 3600;
          final minutes = (duration % 3600) ~/ 60;
          final seconds = duration % 60;

          sheet.updateCell(
            CellIndex.indexByColumnRow(
                columnIndex: colIndex, rowIndex: nextRow),
            TimeCellValue(hour: hours, minute: minutes, second: seconds),
          );
        }
      }

      // Save the file
      final outputBytes = excel.encode();
      if (outputBytes != null) {
        await file.writeAsBytes(outputBytes);
        debugPrint('Session saved to Excel: $stageDurations');
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error writing to Excel file: $e');
      return false;
    }
  }

  /// Create default stage durations with 5 seconds added to run
  static Map<String, int> addRunBonus(Map<String, int> durations,
      {int bonus = 5}) {
    final result = Map<String, int>.from(durations);
    if (result.containsKey('run')) {
      result['run'] = result['run']! + bonus;
    }
    return result;
  }
}
