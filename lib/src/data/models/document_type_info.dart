import 'package:flutter/material.dart';

/// Represents a recognized document type extracted from characters 11-12
/// of an 18-character document code, including the specific file types that
/// need to be saved for that document type.
@immutable
class DocumentTypeInfo {
  final String code;
  final String title;
  final String description;
  final List<String> targetFileTypes;
  final IconData icon;

  const DocumentTypeInfo({
    required this.code,
    required this.title,
    required this.description,
    required this.targetFileTypes,
    this.icon = Icons.description_outlined,
  });

  /// Comprehensive registry of standard technical, engineering, and administrative
  /// document types mapped by their 2-character code (Characters 11 & 12).
  static final Map<String, DocumentTypeInfo> standardTypes = {
    'DW': const DocumentTypeInfo(
      code: 'DW',
      title: 'Engineering Drawing',
      description: 'Technical CAD layout, assembly, or detail drawing.',
      targetFileTypes: ['.pdf', '.dwg', '.dxf'],
      icon: Icons.architecture_outlined,
    ),
    'DR': const DocumentTypeInfo(
      code: 'DR',
      title: 'Engineering Drawing',
      description: 'Engineering schematic, diagram, or plan drawing.',
      targetFileTypes: ['.pdf', '.dwg', '.dxf'],
      icon: Icons.architecture_outlined,
    ),
    'SP': const DocumentTypeInfo(
      code: 'SP',
      title: 'Technical Specification',
      description: 'Engineering design specification, scope, or standard.',
      targetFileTypes: ['.pdf', '.docx', '.doc'],
      icon: Icons.article_outlined,
    ),
    'SC': const DocumentTypeInfo(
      code: 'SC',
      title: 'Specification / Criteria',
      description: 'Technical specification, requirement or criteria document.',
      targetFileTypes: ['.pdf', '.docx', '.doc'],
      icon: Icons.article_outlined,
    ),
    'DS': const DocumentTypeInfo(
      code: 'DS',
      title: 'Equipment Data Sheet',
      description: 'Process, equipment, or instrument parameter data sheet.',
      targetFileTypes: ['.pdf', '.xlsx', '.xls'],
      icon: Icons.table_chart_outlined,
    ),
    'DT': const DocumentTypeInfo(
      code: 'DT',
      title: 'Data Sheet / Schedule',
      description: 'Technical data sheet, component list, or schedule.',
      targetFileTypes: ['.pdf', '.xlsx', '.xls'],
      icon: Icons.table_chart_outlined,
    ),
    'RP': const DocumentTypeInfo(
      code: 'RP',
      title: 'Technical Report',
      description: 'Engineering study, evaluation, or inspection report.',
      targetFileTypes: ['.pdf', '.docx', '.doc'],
      icon: Icons.assignment_outlined,
    ),
    'MR': const DocumentTypeInfo(
      code: 'MR',
      title: 'Material Requisition',
      description: 'Procurement requisition and bill of materials report.',
      targetFileTypes: ['.pdf', '.docx', '.xlsx'],
      icon: Icons.receipt_long_outlined,
    ),
    'CA': const DocumentTypeInfo(
      code: 'CA',
      title: 'Calculation Note',
      description: 'Engineering sizing, stress, or hydraulic calculation.',
      targetFileTypes: ['.pdf', '.xlsx', '.xls'],
      icon: Icons.calculate_outlined,
    ),
    'CL': const DocumentTypeInfo(
      code: 'CL',
      title: 'Calculation Sheet / Checklist',
      description: 'Technical calculation spreadsheet or verification checklist.',
      targetFileTypes: ['.pdf', '.xlsx', '.xls'],
      icon: Icons.checklist_outlined,
    ),
    'PR': const DocumentTypeInfo(
      code: 'PR',
      title: 'Standard Procedure',
      description: 'Operating, testing, commissioning, or maintenance procedure.',
      targetFileTypes: ['.pdf', '.docx'],
      icon: Icons.format_list_numbered_outlined,
    ),
    'PL': const DocumentTypeInfo(
      code: 'PL',
      title: 'Project Plan / Schedule',
      description: 'Master project execution plan, baseline schedule, or roadmap.',
      targetFileTypes: ['.pdf', '.mpp', '.xlsx'],
      icon: Icons.calendar_today_outlined,
    ),
    'PI': const DocumentTypeInfo(
      code: 'PI',
      title: 'Piping & Instrumentation Diagram',
      description: 'P&ID schematic, line diagram, or instrument loop diagram.',
      targetFileTypes: ['.pdf', '.dwg', '.dxf'],
      icon: Icons.account_tree_outlined,
    ),
    'EL': const DocumentTypeInfo(
      code: 'EL',
      title: 'Electrical Schematic',
      description: 'Single-line diagram, wiring diagram, or electrical schematic.',
      targetFileTypes: ['.pdf', '.dwg', '.dxf'],
      icon: Icons.bolt_outlined,
    ),
    'ST': const DocumentTypeInfo(
      code: 'ST',
      title: 'Structural Drawing',
      description: 'Structural steel, foundation, or reinforcement drawing.',
      targetFileTypes: ['.pdf', '.dwg', '.ifc'],
      icon: Icons.foundation_outlined,
    ),
    'CV': const DocumentTypeInfo(
      code: 'CV',
      title: 'Civil Engineering Drawing',
      description: 'Civil grading, drainage, earthworks, or site plan.',
      targetFileTypes: ['.pdf', '.dwg', '.dxf'],
      icon: Icons.landscape_outlined,
    ),
    'CO': const DocumentTypeInfo(
      code: 'CO',
      title: 'Commercial / Contract',
      description: 'Commercial agreement, contract amendment, or legal correspondence.',
      targetFileTypes: ['.pdf'],
      icon: Icons.gavel_outlined,
    ),
    'QC': const DocumentTypeInfo(
      code: 'QC',
      title: 'Quality Control / Certificate',
      description: 'Inspection test plan, mill certificate, or quality record.',
      targetFileTypes: ['.pdf', '.xlsx'],
      icon: Icons.verified_outlined,
    ),
    'MO': const DocumentTypeInfo(
      code: 'MO',
      title: 'Operation & Maintenance Manual',
      description: 'Equipment manual, user guide, or maintenance instructions.',
      targetFileTypes: ['.pdf'],
      icon: Icons.menu_book_outlined,
    ),
    'BD': const DocumentTypeInfo(
      code: 'BD',
      title: 'Bill of Materials / MTO',
      description: 'Material take-off spreadsheet and part numbering list.',
      targetFileTypes: ['.xlsx', '.csv', '.pdf'],
      icon: Icons.inventory_2_outlined,
    ),
  };

  /// Resolves the document type information for a 2-character code.
  /// If the code is not in the predefined registry, returns a custom descriptor.
  static DocumentTypeInfo resolve(String rawCode) {
    final cleanCode = rawCode.trim().toUpperCase();
    if (standardTypes.containsKey(cleanCode)) {
      return standardTypes[cleanCode]!;
    }

    return DocumentTypeInfo(
      code: cleanCode,
      title: 'Custom Document Type ($cleanCode)',
      description: 'Specialized or custom document type identifier.',
      targetFileTypes: const ['.pdf', '.xlsx', '.docx'],
      icon: Icons.folder_zip_outlined,
    );
  }
}
