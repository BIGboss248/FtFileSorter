import 'package:flutter/material.dart';
import 'document_type_info.dart';

/// Represents the full analyzed state of an 18-character document code input.
@immutable
class DocumentCodeAnalysis {
  /// The raw string as typed or pasted by the user.
  final String rawInput;

  /// The cleaned code (stripped of paths, extensions, whitespace, converted to uppercase).
  final String sanitizedCode;

  /// Current character count of the sanitized code.
  final int totalLength;

  /// True if the code has exactly 18 characters.
  final bool isValidLength;

  /// Prefix code: Characters 1-10 (Project, Plant, or Unit identification).
  final String prefixCode;

  /// Document type code: Characters 11-12.
  final String documentTypeCode;

  /// Suffix code: Characters 13-18 (Sequence, Sheet, Revision).
  final String suffixCode;

  /// Resolved document type info (title, description, target save file extensions).
  final DocumentTypeInfo? documentTypeInfo;

  /// Informational or validation message for the user.
  final String? statusMessage;

  const DocumentCodeAnalysis({
    required this.rawInput,
    required this.sanitizedCode,
    required this.totalLength,
    required this.isValidLength,
    required this.prefixCode,
    required this.documentTypeCode,
    required this.suffixCode,
    this.documentTypeInfo,
    this.statusMessage,
  });

  /// Factory for an empty initial state.
  factory DocumentCodeAnalysis.empty() {
    return const DocumentCodeAnalysis(
      rawInput: '',
      sanitizedCode: '',
      totalLength: 0,
      isValidLength: false,
      prefixCode: '',
      documentTypeCode: '',
      suffixCode: '',
      documentTypeInfo: null,
      statusMessage: null,
    );
  }

  /// Whether characters 11 and 12 are available and extracted.
  bool get hasDocumentType => documentTypeCode.length == 2;

  /// Whether the input is empty.
  bool get isEmpty => sanitizedCode.isEmpty;

  /// List of target file types to save (empty if doc type is not yet known).
  List<String> get targetFileTypes =>
      documentTypeInfo?.targetFileTypes ?? const [];
}
