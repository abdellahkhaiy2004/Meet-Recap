import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Tracks which tabs were visited so Android back can return to the previous tab.
// Architecture §9c: "track tab history in ShellController".
final _tabHistoryProvider = StateProvider<List<int>>((ref) => const []);

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  DateTime? _lastBackPress;

  void _onTabTap(int index) {
    if (widget.shell.currentIndex == index) return; // already selected
    ref.read(_tabHistoryProvider.notifier).update(
          (h) => [...h, widget.shell.currentIndex],
        );
    widget.shell.goBranch(index);
  }

  void _onBack() {
    final history = ref.read(_tabHistoryProvider);

    if (history.isNotEmpty) {
      // Return to previous tab instead of exiting.
      final prev = history.last;
      ref.read(_tabHistoryProvider.notifier).update(
            (h) => h.sublist(0, h.length - 1),
          );
      widget.shell.goBranch(prev);
      return;
    }

    // Double-tap to exit guard (architecture §9c).
    final now = DateTime.now();
    final lastPress = _lastBackPress;
    if (lastPress == null ||
        now.difference(lastPress) > const Duration(seconds: 2)) {
      _lastBackPress = now;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('Appuyez encore pour quitter'),
            duration: Duration(seconds: 2),
          ),
        );
      return;
    }
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        body: widget.shell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: widget.shell.currentIndex,
          onDestinationSelected: _onTabTap,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.mic_none_outlined),
              selectedIcon: Icon(Icons.mic),
              label: 'Enregistrer',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined),
              selectedIcon: Icon(Icons.calendar_today),
              label: 'Calendrier',
            ),
            NavigationDestination(
              icon: Icon(Icons.folder_outlined),
              selectedIcon: Icon(Icons.folder),
              label: 'Dossiers',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Réglages',
            ),
          ],
        ),
      ),
    );
  }
}
