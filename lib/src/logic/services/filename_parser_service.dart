import '../../data/models/code_segment.dart';

/// Exception thrown when filename parsing fails validation.
class FilenameParserException implements Exception {
  final String message;
  const FilenameParserException(this.message);

  @override
  String toString() => 'FilenameParserException: $message';
}

/// Result object for non-throwing / reactive UI consumption.
class FilenameParseResult {
  final bool isSuccess;
  final Map<String, String>? data;
  final String? errorMessage;
  final String evaluatedBaseName;
  final int expectedLength;

  const FilenameParseResult.success({
    required this.data,
    required this.evaluatedBaseName,
    required this.expectedLength,
  })  : isSuccess = true,
        errorMessage = null;

  const FilenameParseResult.failure({
    required this.errorMessage,
    required this.evaluatedBaseName,
    required this.expectedLength,
  })  : isSuccess = false,
        data = null;
}

/// Decoupled service for parsing and validating filenames against dynamic schemas.
class FilenameParserService {
  const FilenameParserService();

  /// Calculates the total expected character count of the base filename
  /// including segments and any intervening delimiters.
  static int calculateExpectedLength(
    List<CodeSegment> segments, {
    String delimiter = '',
  }) {
    if (segments.isEmpty) return 0;
    final totalSegmentLength = segments.fold<int>(
      0,
      (sum, segment) => sum + segment.length,
    );
    final totalDelimiterLength =
        delimiter.isNotEmpty ? (segments.length - 1) * delimiter.length : 0;
    return totalSegmentLength + totalDelimiterLength;
  }

  /// Extracts the clean base filename by stripping folder paths and file extensions.
  /// Handles both Windows (`\`) and POSIX (`/`) separators seamlessly.
  static String extractBaseName(String fullFilePath) {
    var trimmed = fullFilePath.trim();
    if (trimmed.isEmpty) return '';

    // Strip leading/trailing quote characters often added by Windows "Copy as path"
    if ((trimmed.startsWith('"') && trimmed.endsWith('"')) ||
        (trimmed.startsWith("'") && trimmed.endsWith("'"))) {
      trimmed = trimmed.substring(1, trimmed.length - 1).trim();
    }

    // Isolate filename after last slash/backslash
    final lastSeparator = trimmed.lastIndexOf(RegExp(r'[\\/]'));
    var fileName = lastSeparator != -1
        ? trimmed.substring(lastSeparator + 1)
        : trimmed;

    // Remove file extension if present
    final lastDot = fileName.lastIndexOf('.');
    if (lastDot > 0) {
      fileName = fileName.substring(0, lastDot);
    }

    return fileName;
  }

  /// Parses the [fullFilePath] according to [orderedSegments] and [delimiter].
  ///
  /// Returns a Map of segment ID to extracted substring.
  /// Throws [FilenameParserException] if the filename fails validation.
  Map<String, String>? parseFilename(
    String fullFilePath,
    List<CodeSegment> orderedSegments, {
    String delimiter = '',
  }) {
    if (fullFilePath.trim().isEmpty) {
      throw const FilenameParserException('File path or filename cannot be empty.');
    }

    if (orderedSegments.isEmpty) {
      throw const FilenameParserException('At least one code segment is required.');
    }

    for (final segment in orderedSegments) {
      if (segment.length <= 0) {
        throw FilenameParserException(
          'Segment "${segment.label}" must have a length greater than 0.',
        );
      }
    }

    final baseName = extractBaseName(fullFilePath);
    if (baseName.isEmpty) {
      throw const FilenameParserException('Extracted base filename is empty.');
    }

    final expectedLength = calculateExpectedLength(
      orderedSegments,
      delimiter: delimiter,
    );

    if (baseName.length != expectedLength) {
      throw FilenameParserException(
        'Filename "$baseName" has ${baseName.length} characters, '
        'but expected $expectedLength characters.',
      );
    }

    final result = <String, String>{};
    var cursor = 0;

    for (var i = 0; i < orderedSegments.length; i++) {
      final segment = orderedSegments[i];
      final segmentEnd = cursor + segment.length;

      if (segmentEnd > baseName.length) {
        throw FilenameParserException(
          'Unexpected overflow reading segment "${segment.label}".',
        );
      }

      final value = baseName.substring(cursor, segmentEnd);
      result[segment.id] = value;
      cursor = segmentEnd;

      // Validate intervening delimiter
      if (delimiter.isNotEmpty && i < orderedSegments.length - 1) {
        final delimiterEnd = cursor + delimiter.length;
        if (delimiterEnd > baseName.length) {
          throw FilenameParserException(
            'Incomplete delimiter after segment "${segment.label}".',
          );
        }

        final actualDelimiter = baseName.substring(cursor, delimiterEnd);
        if (actualDelimiter != delimiter) {
          throw FilenameParserException(
            'Expected delimiter "$delimiter" after "${segment.label}" at character position $cursor, '
            'but found "$actualDelimiter".',
          );
        }
        cursor = delimiterEnd;
      }
    }

    return result;
  }

  /// Safe evaluation method that captures errors and returns a [FilenameParseResult].
  FilenameParseResult tryParse(
    String fullFilePath,
    List<CodeSegment> orderedSegments, {
    String delimiter = '',
  }) {
    final baseName = extractBaseName(fullFilePath);
    final expectedLength = calculateExpectedLength(
      orderedSegments,
      delimiter: delimiter,
    );

    try {
      final data = parseFilename(
        fullFilePath,
        orderedSegments,
        delimiter: delimiter,
      );
      return FilenameParseResult.success(
        data: data,
        evaluatedBaseName: baseName,
        expectedLength: expectedLength,
      );
    } on FilenameParserException catch (e) {
      return FilenameParseResult.failure(
        errorMessage: e.message,
        evaluatedBaseName: baseName,
        expectedLength: expectedLength,
      );
    } catch (e) {
      return FilenameParseResult.failure(
        errorMessage: e.toString(),
        evaluatedBaseName: baseName,
        expectedLength: expectedLength,
      );
    }
  }
}
