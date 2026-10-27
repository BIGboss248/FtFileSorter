import 'package:flutter/material.dart';

import '../navigation/app_destination.dart';
import 'configuration_screen.dart';
import 'document_analyzer_screen.dart';
import 'excel_analyzer_screen.dart';
import 'file_indexer_screen.dart';

/// Root widget of the app.
///
/// Shows a single top-level screen at a time and exposes the other screens
/// through the hamburger (drawer) menu of their app bars. The File Indexer is
/// the default destination.
class AppShell extends StatefulWidget {
  /// Destination shown when the app starts.
  final AppDestination initialDestination;

  const AppShell({
    super.key,
    this.initialDestination = AppDestination.fileIndexer,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late AppDestination _destination;
  late final Set<AppDestination> _visitedDestinations;

  @override
  void initState() {
    super.initState();
    _destination = widget.initialDestination;
    // Screens are built lazily on first visit and then kept alive so switching
    // destinations does not throw away state such as an indexed folder.
    _visitedDestinations = {_destination};
  }

  void _selectDestination(AppDestination destination) {
    if (destination == _destination) return;

    setState(() {
      _destination = destination;
      _visitedDestinations.add(destination);
    });
  }

  Widget _screenFor(AppDestination destination) {
    return switch (destination) {
      AppDestination.fileIndexer => const FileIndexerScreen(),
      AppDestination.configuration => const ConfigurationScreen(),
      AppDestination.excelAnalyzer => const ExcelAnalyzerScreen(),
      AppDestination.documentAnalyzer => const DocumentAnalyzerScreen(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return AppShellScope(
      currentDestination: _destination,
      onDestinationSelected: _selectDestination,
      child: IndexedStack(
        index: _destination.index,
        children: [
          for (final destination in AppDestination.values)
            if (_visitedDestinations.contains(destination))
              _screenFor(destination)
            else
              const SizedBox.shrink(),
        ],
      ),
    );
  }
}
