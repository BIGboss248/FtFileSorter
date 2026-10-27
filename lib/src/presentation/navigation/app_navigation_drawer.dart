import 'package:flutter/material.dart';

import 'app_destination.dart';

/// Hamburger menu shared by every top-level screen.
///
/// The active destination is highlighted through [NavigationDrawer]'s
/// `selectedIndex`, which is read from the surrounding [AppShellScope].
class AppNavigationDrawer extends StatelessWidget {
  const AppNavigationDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final scope = AppShellScope.maybeOf(context);
    final current = scope?.currentDestination;

    return NavigationDrawer(
      selectedIndex: current?.index,
      onDestinationSelected: (index) {
        _select(context, scope, AppDestination.values[index]);
      },
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.sort, color: colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Ft File Sorter',
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                current?.description ?? 'Document sorting toolkit',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const Divider(indent: 28, endIndent: 28, height: 1),
        const SizedBox(height: 12),
        for (final destination in AppDestination.values)
          NavigationDrawerDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: Flexible(
              child: Text(destination.title, overflow: TextOverflow.ellipsis),
            ),
          ),
      ],
    );
  }

  /// Closes the drawer and asks the shell to show [destination]. When there is
  /// no shell (a screen rendered on its own) only the drawer is closed.
  void _select(
    BuildContext context,
    AppShellScope? scope,
    AppDestination destination,
  ) {
    Navigator.of(context).pop();
    scope?.onDestinationSelected(destination);
  }
}
