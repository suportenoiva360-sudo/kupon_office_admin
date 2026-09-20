import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:kupon_office_admin/features/admin/presentation/pages/admin_login_page.dart';
import 'package:kupon_office_admin/features/admin/presentation/pages/admin_shell.dart';
import 'package:kupon_office_admin/features/admin/presentation/pages/admin_dashboard_page.dart';
import 'package:kupon_office_admin/features/admin/presentation/pages/admin_drivers_page.dart';
import 'package:kupon_office_admin/features/admin/presentation/pages/admin_users_page.dart';
import 'package:kupon_office_admin/features/admin/presentation/pages/admin_financeiro_page.dart';
import 'package:kupon_office_admin/features/admin/presentation/pages/admin_suporte_page.dart';
import 'package:kupon_office_admin/features/admin/presentation/pages/admin_driver_detail_page.dart';
import 'package:kupon_office_admin/features/admin/presentation/pages/admin_promocoes_page.dart';
import 'package:kupon_office_admin/features/admin/presentation/pages/admin_planos_page.dart';
import 'package:kupon_office_admin/features/admin/presentation/pages/admin_sos_page.dart';
import 'package:kupon_office_admin/features/admin/presentation/pages/admin_configuracoes_page.dart';
import 'package:kupon_office_admin/features/admin/presentation/pages/admin_map_page.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

bool? _isAdminCache;
String? _cachedUserId;

Future<bool> _isAdmin() async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return false;

  if (_isAdminCache != null && _cachedUserId == userId) return _isAdminCache!;

  try {
    final profile = await Supabase.instance.client
        .from('users')
        .select('role')
        .eq('id', userId)
        .maybeSingle();

    _isAdminCache = profile?['role'] == 'admin';
    _cachedUserId = userId;
    return _isAdminCache!;
  } catch (_) {
    return false;
  }
}

void invalidateAdminCache() {
  _isAdminCache = null;
  _cachedUserId = null;
}

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/login',
  redirect: (context, state) async {
    final session = Supabase.instance.client.auth.currentSession;
    final loggedIn = session != null;
    final onLogin = state.matchedLocation == '/login';

    if (!loggedIn && !onLogin) return '/login';
    if (loggedIn && onLogin) {
      final admin = await _isAdmin();
      return admin ? '/dashboard' : null;
    }

    if (loggedIn && !onLogin) {
      final admin = await _isAdmin();
      if (!admin) return '/login';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const AdminLoginPage(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => AdminShell(
        navigationShell: navigationShell,
      ),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/dashboard',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: AdminDashboardPage(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/motoristas',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: AdminDriversPage(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/usuarios',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: AdminUsersPage(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/financeiro',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: AdminFinanceiroPage(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/suporte',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: AdminSuportePage(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/promocoes',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: AdminPromocoesPage(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/planos',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: AdminPlanosPage(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/configuracoes',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: AdminConfiguracoesPage(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/sos',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: AdminSosPage(),
              ),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/mapa',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AdminMapPage(),
    ),
    GoRoute(
      path: '/motorista/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => AdminDriverDetailPage(
        driverId: state.pathParameters['id']!,
      ),
    ),
  ],
);
