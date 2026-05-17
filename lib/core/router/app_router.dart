import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/pages/calendar_page.dart';
import '../../presentation/pages/folder_detail_page.dart';
import '../../presentation/pages/folders_page.dart';
import '../../presentation/pages/home_shell.dart';
import '../../presentation/pages/meeting_detail_page.dart';
import '../../presentation/pages/new_folder_page.dart';
import '../../presentation/pages/processing_page.dart';
import '../../presentation/pages/record_page.dart';
import '../../presentation/pages/schedule_event_page.dart';
import '../../presentation/pages/settings_page.dart';

final _rootNavKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavKey,
    initialLocation: '/record',
    routes: [
      // ── Bottom-nav shell (4 independent back-stacks) ───────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(shell: shell),
        branches: [
          // Tab 0 — Record
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/record',
              pageBuilder: (c, s) => _slide(
                s,
                RecordPage(
                  folderId: s.uri.queryParameters['folderId'],
                  eventId:  s.uri.queryParameters['eventId'],
                ),
              ),
            ),
          ]),
          // Tab 1 — Calendar
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/calendar',
              pageBuilder: (c, s) => _slide(s, const CalendarPage()),
              routes: [
                GoRoute(
                  path: 'schedule',
                  pageBuilder: (c, s) => _slide(s, const ScheduleEventPage()),
                ),
              ],
            ),
          ]),
          // Tab 2 — Folders
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/folders',
              pageBuilder: (c, s) => _slide(s, const FoldersPage()),
              routes: [
                GoRoute(
                  path: 'new',
                  pageBuilder: (c, s) => _slide(s, const NewFolderPage()),
                ),
                GoRoute(
                  path: ':folderId',
                  pageBuilder: (c, s) => _slide(
                    s,
                    FolderDetailPage(folderId: s.pathParameters['folderId']!),
                  ),
                  routes: [
                    GoRoute(
                      path: 'meetings/:meetingId',
                      pageBuilder: (c, s) => _slide(
                        s,
                        MeetingDetailPage(
                          meetingId: s.pathParameters['meetingId']!,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ]),
          // Tab 3 — Settings
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/settings',
              pageBuilder: (c, s) => _slide(s, const SettingsPage()),
            ),
          ]),
        ],
      ),

      // ── Full-screen routes above the shell ─────────────────────────────
      GoRoute(
        path: '/processing/:draftId',
        parentNavigatorKey: _rootNavKey,
        pageBuilder: (c, s) => _slide(
          s,
          ProcessingPage(draftId: s.pathParameters['draftId']!),
        ),
      ),
    ],
  );
});

// Shared page transition: fade + 12 px vertical slide, 280 ms easeOutCubic.
CustomTransitionPage<void> _slide(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.04), // 12 px slide-up (≈ 4 % of screen)
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
