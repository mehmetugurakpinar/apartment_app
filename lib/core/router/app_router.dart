import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../l10n/app_localizations.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/building/screens/building_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/forum/screens/forum_screen.dart';
import '../../features/timeline/screens/timeline_screen.dart';
import '../../features/timeline/screens/user_search_screen.dart';
import '../../features/timeline/screens/timeline_post_detail_screen.dart';
import '../../features/messaging/screens/conversations_screen.dart';
import '../../features/messaging/screens/chat_screen.dart';
import '../../features/social/screens/user_profile_screen.dart';
import '../../features/social/screens/followers_screen.dart';
import '../../features/profile/screens/profile_screen.dart';

/// Bridges Riverpod [authStateProvider] changes into a [ChangeNotifier]
/// so GoRouter re-evaluates its redirect on login/logout.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final authRefresh = _AuthRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: authRefresh,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final isAuthenticated =
          authState.status == AuthStatus.authenticated;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (!isAuthenticated && !isAuthRoute) return '/login';
      if (isAuthenticated && isAuthRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomeScreen(),
            ),
          ),
          GoRoute(
            path: '/building',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: BuildingScreen(),
            ),
          ),
          GoRoute(
            path: '/notifications',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: NotificationsScreen(),
            ),
          ),
          GoRoute(
            path: '/forum',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ForumScreen(),
            ),
          ),
          GoRoute(
            path: '/timeline',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: TimelineScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/user-search',
        builder: (context, state) => const UserSearchScreen(),
      ),
      GoRoute(
        path: '/timeline/:postId',
        builder: (context, state) => TimelinePostDetailScreen(
          postId: state.pathParameters['postId']!,
        ),
      ),
      GoRoute(
        path: '/messages',
        builder: (context, state) => const ConversationsScreen(),
      ),
      GoRoute(
        path: '/messages/:convId',
        builder: (context, state) {
          final extra = state.extra;
          String? otherUserName;
          if (extra is ConversationItem) {
            otherUserName = extra.displayName;
          }
          return ChatScreen(
            conversationId: state.pathParameters['convId']!,
            otherUserName: otherUserName,
          );
        },
      ),
      GoRoute(
        path: '/users/:id',
        builder: (context, state) => UserProfileScreen(
          userId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/users/:id/followers',
        builder: (context, state) => FollowersScreen(
          userId: state.pathParameters['id']!,
          isFollowing: false,
        ),
      ),
      GoRoute(
        path: '/users/:id/following',
        builder: (context, state) => FollowersScreen(
          userId: state.pathParameters['id']!,
          isFollowing: true,
        ),
      ),
    ],
  );
});

class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  static const _routes = ['/home', '/building', '/notifications', '/forum', '/timeline'];

  int _calculateIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = _routes.indexOf(location);
    return index >= 0 ? index : 0;
  }

  @override
  Widget build(BuildContext context) {
    // Trigger loading user buildings & auto-select first one
    ref.watch(userBuildingsProvider);

    final locale = ref.watch(localeProvider);
    final isTr = locale.languageCode == 'tr';
    final currentIndex = _calculateIndex(context);

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          context.go(_routes[index]);
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: isTr ? 'Ana Sayfa' : 'Home',
          ),
          NavigationDestination(
            icon: const Icon(Icons.apartment_outlined),
            selectedIcon: const Icon(Icons.apartment),
            label: isTr ? 'Bina' : 'Building',
          ),
          NavigationDestination(
            icon: const Icon(Icons.notifications_outlined),
            selectedIcon: const Icon(Icons.notifications),
            label: isTr ? 'Bildirimler' : 'Alerts',
          ),
          NavigationDestination(
            icon: const Icon(Icons.forum_outlined),
            selectedIcon: const Icon(Icons.forum),
            label: 'Forum',
          ),
          NavigationDestination(
            icon: const Icon(Icons.public_outlined),
            selectedIcon: const Icon(Icons.public),
            label: isTr ? 'Topluluk' : 'Community',
          ),
        ],
      ),
    );
  }
}
