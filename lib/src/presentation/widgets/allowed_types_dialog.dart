import 'package:flutter/material.dart';

import '../../data/models/document_type_info.dart';
import '../../logic/services/allowed_types_rules_service.dart';

/// Dialog for assigning allowed file extensions to document types.
///
/// Every change is written immediately to the shared rules JSON so the CLI tool
/// picks up the same assignments. Document types without a rule keep every file
/// type; unchecking an extension marks it for the trash step in the CLI.
class AllowedTypesDialog extends StatefulWidget {
  const AllowedTypesDialog({
    super.key,
    required this.extensionsByDocumentType,
    this.rulesService = const AllowedTypesRulesService(),
  });

  /// Extensions observed in the current index, grouped by document type.
  final Map<String, Set<String>> extensionsByDocumentType;

  /// Persistence for the shared rules JSON. Overridable for tests.
  final AllowedTypesRulesService rulesService;

  @override
  State<AllowedTypesDialog> createState() => _AllowedTypesDialogState();
}

class _AllowedTypesDialogState extends State<AllowedTypesDialog> {
  Map<String, Set<String>> _rules = const {};
  String _rulesPath = '';
  String? _error;

  @override
  void initState() {
    super.initState();

    try {
      _rulesPath = widget.rulesService.resolvePathSync();
      _rules = widget.rulesService.loadSync();
    } catch (error) {
      _error = 'Could not load the rules file: $error';
    }
  }

  Set<String> _detected(String type) =>
      widget.extensionsByDocumentType[type] ?? const <String>{};

  List<String> _extensionsFor(String type) {
    final all = {..._detected(type), ...?_rules[type]}.toList()..sort();
    return all;
  }

  bool _isAllowed(String type, String extension) {
    final rule = _rules[type];
    if (rule == null) return true;
    return rule.contains(extension);
  }

  void _toggle(String type, String extension, bool selected) {
    final current = Set<String>.from(_rules[type] ?? _detected(type));
    if (selected) {
      current.add(extension);
    } else {
      current.remove(extension);
    }
    _persist(Map<String, Set<String>>.from(_rules)..[type] = current);
  }

  void _clearRule(String type) {
    _persist(Map<String, Set<String>>.from(_rules)..remove(type));
  }

  void _persist(Map<String, Set<String>> updated) {
    setState(() {
      _rules = updated;
      _error = null;
    });

    try {
      final path = widget.rulesService.saveSync(updated);
      if (!mounted) return;
      setState(() => _rulesPath = path);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Could not save the rules file: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: const Text('Allowed File Types per Document Type'),
      content: SizedBox(
        width: 720,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 540),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unchecked extensions are moved to trash by the CLI after '
                  'copying. Use "No rule" to keep every file type for a '
                  'document type.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(color: colorScheme.onErrorContainer),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (widget.extensionsByDocumentType.isEmpty)
                  Text(
                    'Index a folder with document codes to edit file type '
                    'rules.',
                    style: theme.textTheme.bodyMedium,
                  )
                else
                  for (final type
                      in (widget.extensionsByDocumentType.keys.toList()
                        ..sort()))
                    _buildTypeRow(type, theme, colorScheme),
                const Divider(height: 28),
                Row(
                  children: [
                    Icon(
                      Icons.save_outlined,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Shared rules file (changes save automatically)',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SelectableText(
                  _rulesPath.isEmpty ? 'Resolving...' : _rulesPath,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildTypeRow(String type, ThemeData theme, ColorScheme colorScheme) {
    final title = DocumentTypeInfo.standardTypes[type]?.title;
    final extensions = _extensionsFor(type);
    final hasRule = _rules.containsKey(type);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  type,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  (title == null || title.isEmpty)
                      ? 'Unmapped document type'
                      : title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (hasRule)
                TextButton(
                  onPressed: () => _clearRule(type),
                  child: const Text('No rule'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (extensions.isEmpty)
            Text(
              'No file types found for this document type in the current index.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 2,
              children: [
                for (final extension in extensions)
                  FilterChip(
                    label: Text('.$extension'),
                    selected: _isAllowed(type, extension),
                    onSelected: (selected) =>
                        _toggle(type, extension, selected),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
