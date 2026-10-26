import 'dart:math' as math;
import '../../data/models/document_code_analysis.dart';
import '../../data/models/document_type_info.dart';

/// Decoupled, unit-testable service for analyzing 18-character document codes.
///
/// Decomposition rules:
/// - Total Code Length: 18 characters
/// - Characters 1–10: Prefix / Project / Plant identification code (10 chars)
/// - Characters 11–12: Document Type code (2 chars)
/// - Characters 13–18: Suffix / Sequence / Sheet / Revision code (6 chars)
class DocumentCodeParserService {
  const DocumentCodeParserService();

  /// Target character count for valid document codes.
  static const int expectedLength = 18;

  /// Extracts the base candidate code from raw input (which may be a full file path,
  /// quoted string, or filename with extension).
  static String sanitizeInput(String rawInput) {
    var trimmed = rawInput.trim();
    if (trimmed.isEmpty) return '';

    // Strip wrapping quotes (e.g. from Windows "Copy as path")
    if ((trimmed.startsWith('"') && trimmed.endsWith('"')) ||
        (trimmed.startsWith("'") && trimmed.endsWith("'"))) {
      trimmed = trimmed.substring(1, trimmed.length - 1).trim();
    }

    // If a full path was provided, isolate the filename after the last separator
    final lastSeparator = trimmed.lastIndexOf(RegExp(r'[\\/]'));
    var code = lastSeparator != -1
        ? trimmed.substring(lastSeparator + 1)
        : trimmed;

    // If a recognized extension is present (e.g. .pdf, .xlsx, .dwg), strip it
    final lastDot = code.lastIndexOf('.');
    if (lastDot > 0 && lastDot >= 10) {
      code = code.substring(0, lastDot);
    }

    // Remove any accidental whitespace inside the code
    code = code.replaceAll(RegExp(r'\s+'), '');

    return code.toUpperCase();
  }

  /// Evaluates the [rawInput] and returns a structured [DocumentCodeAnalysis].
  DocumentCodeAnalysis analyze(String rawInput) {
    final sanitized = sanitizeInput(rawInput);
    final totalLength = sanitized.length;

    if (sanitized.isEmpty) {
      return DocumentCodeAnalysis.empty();
    }

    // Extract Prefix: Characters 1-10 (indices 0..9)
    final prefixCode = sanitized.substring(0, math.min(10, totalLength));

    // Extract Document Type: Characters 11-12 (indices 10..11)
    String documentTypeCode = '';
    DocumentTypeInfo? documentTypeInfo;
    if (totalLength >= 11) {
      documentTypeCode = sanitized.substring(10, math.min(12, totalLength));
      if (documentTypeCode.length == 2) {
        documentTypeInfo = DocumentTypeInfo.resolve(documentTypeCode);
      }
    }

    // Extract Suffix: Characters 13-18 (indices 12..17)
    String suffixCode = '';
    if (totalLength >= 13) {
      suffixCode = sanitized.substring(12, math.min(18, totalLength));
    }

    // Validation status
    final isValidLength = totalLength == expectedLength;
    final String statusMessage;

    if (totalLength < 11) {
      statusMessage =
          'Enter at least 12 characters to detect document type ($totalLength/$expectedLength).';
    } else if (totalLength < expectedLength) {
      final remaining = expectedLength - totalLength;
      statusMessage =
          'Document type identified ($documentTypeCode). Enter $remaining more character${remaining == 1 ? '' : 's'} ($totalLength/$expectedLength).';
    } else if (totalLength == expectedLength) {
      statusMessage = 'Valid 18-character code. Document type: ${documentTypeInfo?.title ?? documentTypeCode}.';
    } else {
      statusMessage =
          'Code exceeds $expectedLength characters (currently $totalLength). Only first $expectedLength characters will be evaluated.';
    }

    return DocumentCodeAnalysis(
      rawInput: rawInput,
      sanitizedCode: sanitized,
      totalLength: totalLength,
      isValidLength: isValidLength,
      prefixCode: prefixCode,
      documentTypeCode: documentTypeCode,
      suffixCode: suffixCode,
      documentTypeInfo: documentTypeInfo,
      statusMessage: statusMessage,
    );
  }
}
