import 'package:flutter/material.dart';

/// Top-level screens reachable from the app shell's hamburger (drawer) menu.
///
/// The declaration order defines the order of the drawer entries and the index
/// used by the shell's [IndexedStack].
enum AppDestination {
  fileIndexer(
    title: 'File Indexer',
    description: 'Index folders and export the inventory as CSV',
    icon: Icons.folder_copy_outlined,
    selectedIcon: Icons.folder_copy,
  ),
  configuration(
    title: 'Configuration',
    description: 'Sorter & filename parser settings',
    icon: Icons.tune_outlined,
    selectedIcon: Icons.tune,
  ),
  excelAnalyzer(
    title: 'Excel Analyzer',
    description: 'Inspect spreadsheet metadata',
    icon: Icons.table_chart_outlined,
    selectedIcon: Icons.table_chart,
  ),
  documentAnalyzer(
    title: 'Document Code Analyzer',
    description: 'Decode 18-character document codes',
    icon: Icons.analytics_outlined,
    selectedIcon: Icons.analytics,
  );

  const AppDestination({
    required this.title,
    required this.description,
    required this.icon,
    required this.selectedIcon,
  });

  /// Label shown in the drawer and used as the screen title.
  final String title;

  /// Supporting text shown under the title in the drawer header.
  final String description;

  /// Icon shown when the destination is not selected.
  final IconData icon;

  /// Filled icon variant shown when the destination is selected.
  final IconData selectedIcon;
}

/// Exposes the shell's active destination so nested screens (and the drawer
/// itself) can highlight the active entry and switch screens.
class AppShellScope extends InheritedWidget {
  const AppShellScope({
    super.key,
    required this.currentDestination,
    required this.onDestinationSelected,
    required super.child,
  });

  /// Destination currently displayed by the shell.
  final AppDestination currentDestination;

  /// Called when a destination is picked from the drawer.
  final ValueChanged<AppDestination> onDestinationSelected;

  /// Returns the nearest shell scope, or `null` when a screen is rendered on
  /// its own (for example in a widget test or a standalone route).
  static AppShellScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppShellScope>();
  }

  @override
  bool updateShouldNotify(AppShellScope oldWidget) {
    return currentDestination != oldWidget.currentDestination ||
        onDestinationSelected != oldWidget.onDestinationSelected;
  }
}
