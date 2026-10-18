import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kupon_office_admin/app/theme/app_theme.dart';
import 'package:kupon_office_admin/core/providers/user_provider.dart';
import 'package:kupon_office_admin/core/widgets/kupon_loader.dart';
import 'package:kupon_office_admin/core/routes/app_router.dart'
    show invalidateAdminCache;
import 'package:kupon_office_admin/features/admin/application/admin_activity_center.dart';
import 'package:kupon_office_admin/features/admin/support/admin_system_notifications.dart';

class AdminShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AdminShell({super.key, required this.navigationShell});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  StatefulNavigationShell get _nav => widget.navigationShell;

  static const _destinations = [
    _NavDestination(
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard_rounded,
      label: 'Painel',
    ),
    _NavDestination(
      icon: Icons.directions_car_outlined,
      selectedIcon: Icons.directions_car_rounded,
      label: 'Motoristas',
    ),
    _NavDestination(
      icon: Icons.group_outlined,
      selectedIcon: Icons.group_rounded,
      label: 'Utilizadores',
    ),
    _NavDestination(
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet_rounded,
      label: 'Tarifas e Finanças',
    ),
    _NavDestination(
      icon: Icons.support_agent_outlined,
      selectedIcon: Icons.support_agent_rounded,
      label: 'Tickets de Suporte',
    ),
    _NavDestination(
      icon: Icons.local_offer_outlined,
      selectedIcon: Icons.local_offer_rounded,
      label: 'Promoções',
    ),
    _NavDestination(
      icon: Icons.card_membership_outlined,
      selectedIcon: Icons.card_membership_rounded,
      label: 'Planos',
    ),
    _NavDestination(
      icon: Icons.workspace_premium_outlined,
      selectedIcon: Icons.workspace_premium_rounded,
      label: 'Pacotes KupON',
    ),
    _NavDestination(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
      label: 'Configurações do Sistema',
    ),
  ];

  @override
  void initState() {
    super.initState();
    AdminActivityCenter.instance.onActivity = _onNewActivity;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProvider>().loadAll();
      AdminActivityCenter.instance.init();
      // Notificações nativas do browser (aparecem com o painel em background).
      AdminSystemNotifications.ensurePermission();
    });
  }

  @override
  void dispose() {
    AdminActivityCenter.instance.onActivity = null;
    super.dispose();
  }

  /// Aviso discreto quando chega atividade nova em tempo real.
  void _onNewActivity(AdminActivityItem item) {
    if (!mounted) return;
    // Tab escondida → notificação nativa do browser (é o "background").
    if (AdminSystemNotifications.isSupported) {
      AdminSystemNotifications.show(
        title: item.title,
        body: item.subtitle,
        tag: item.id,
      );
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          item.title,
          style: GoogleFonts.spaceGrotesk(fontSize: 13, color: Colors.white),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1C1B1B),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Ver',
          textColor: AppTheme.primaryContainer,
          onPressed: () {
            if (mounted) context.go(item.route);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: Row(
          children: [
            _buildSidebar(),
            const VerticalDivider(
              width: 1,
              thickness: 1,
              color: Color(0xFF2A2A2A),
            ),
            Expanded(child: _nav),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    final userProv = context.watch<UserProvider>();
    final adminName = userProv.profile?['name'] ?? 'Admin Profile';
    final adminPhoto = userProv.userPhoto;

    return Container(
      width: 280,
      color: const Color(0xFF131313),
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: _buildBrand(),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                mainAxisExtent: 92,
              ),
              itemCount: _destinations.length,
              itemBuilder: (_, i) => _buildGridTile(i),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const Divider(color: Color(0xFF2A2A2A), height: 1),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () =>
                      _nav.goBranch(9, initialLocation: _nav.currentIndex == 9),
                  child: Container(
                    height: 48,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppTheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _nav.currentIndex == 9
                            ? Colors.white.withValues(alpha: 0.7)
                            : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.errorContainer.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.emergency,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'EMERGENCIA',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFF2A2A2A), height: 1),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFFF6B00),
                          width: 1.5,
                        ),
                      ),
                      child: ClipOval(
                        child: adminPhoto != null && adminPhoto.isNotEmpty
                            ? Image.network(
                                adminPhoto,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    _defaultProfileIcon(),
                              )
                            : _defaultProfileIcon(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            adminName,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFE5E2E1),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'ACESSO MASTER',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: const Color(
                                0xFFE2BFB0,
                              ).withValues(alpha: 0.6),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    _buildBell(),
                    IconButton(
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: Color(0xFFCF6679),
                        size: 18,
                      ),
                      onPressed: _logout,
                      tooltip: 'Sair',
                    ),
                  ],
                ),
                const SafeArea(top: false, child: SizedBox(height: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _defaultProfileIcon() {
    return Container(
      color: const Color(0xFF2A2A2A),
      child: const Icon(
        Icons.person_rounded,
        color: Color(0xFFE2BFB0),
        size: 20,
      ),
    );
  }

  Widget _buildBrand() {
    return Row(
      children: [
        SvgPicture.asset('assets/icons/kupon-logo.svg', width: 50, height: 50),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'KUPON',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryContainer,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'CENTRO DE OPERAÇÕES',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFE2BFB0).withValues(alpha: 0.7),
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGridTile(int index) {
    final isSelected = _nav.currentIndex == index;
    final dest = _destinations[index];
    return GestureDetector(
      onTap: () =>
          _nav.goBranch(index, initialLocation: index == _nav.currentIndex),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.secondaryContainer
              : const Color(0xFF1C1B1B).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFF6B00).withValues(alpha: 0.4)
                : const Color(0xFF2A2A2A),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? dest.selectedIcon : dest.icon,
              color: isSelected
                  ? const Color(0xFF4B1B00)
                  : const Color(0xFFE2BFB0).withValues(alpha: 0.75),
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              dest.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10.5,
                height: 1.15,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF4B1B00)
                    : const Color(0xFFE2BFB0).withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBell() {
    final center = AdminActivityCenter.instance;
    return ListenableBuilder(
      listenable: center,
      builder: (context, _) {
        final unreadCount = center.unreadCount;
        return MenuAnchor(
          style: const MenuStyle(
            backgroundColor: WidgetStatePropertyAll(Color(0xFF1C1B1B)),
            elevation: WidgetStatePropertyAll(8),
            padding: WidgetStatePropertyAll(EdgeInsets.zero),
          ),
          menuChildren: [_buildActivityMenu(center)],
          builder: (context, controller, child) => IconButton(
            onPressed: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text(unreadCount > 9 ? '9+' : '$unreadCount'),
              backgroundColor: const Color(0xFFFF6B00),
              textColor: Colors.white,
              child: Icon(
                unreadCount > 0
                    ? Icons.notifications_rounded
                    : Icons.notifications_outlined,
                color: const Color(0xFFE2BFB0).withValues(alpha: 0.75),
                size: 20,
              ),
            ),
            tooltip: 'Atividade',
          ),
        );
      },
    );
  }

  Widget _buildActivityMenu(AdminActivityCenter center) {
    final filter = center.activeFilter;
    final items = center.filteredItems;
    final unreadIds = center.unreadItems.map((e) => e.id).toSet();
    final hasUnread = unreadIds.isNotEmpty;
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1B1B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Atividade',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFE5E2E1),
                    ),
                  ),
                ),
                if (hasUnread)
                  TextButton(
                    onPressed: center.markAllRead,
                    child: Text(
                      'Marcar lido',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFFF6B00),
                      ),
                    ),
                  ),
                IconButton(
                  tooltip: 'Atualizar',
                  onPressed: center.loading ? null : center.refresh,
                  icon: Icon(
                    Icons.refresh_rounded,
                    size: 16,
                    color: const Color(0xFFE2BFB0).withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          // Chips de categoria (o badge global continua a contar tudo).
          _buildActivityFilterChips(center, filter),
          // Limpeza no âmbito do chip ativo.
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: _activityAction(
                    label: 'Limpar lidas',
                    icon: Icons.done_all_rounded,
                    color: const Color(0xFF4CAF88),
                    enabled: center.hasSeenIn(filter),
                    onPressed: () => center.clearSeenIn(filter),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _activityAction(
                    label: 'Limpar resolvidos',
                    icon: Icons.cleaning_services_rounded,
                    color: const Color(0xFFE2BFB0),
                    enabled: items.isNotEmpty,
                    onPressed: () => center.purgeResolved(group: filter),
                  ),
                ),
              ],
            ),
          ),
          // Ativação manual das notificações nativas (browsers que exigem
          // gesto do utilizador para pedir permissão).
          if (AdminSystemNotifications.isSupported &&
              AdminSystemNotifications.permissionStatus == 'default')
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  await AdminSystemNotifications.ensurePermission();
                  if (mounted) setState(() {});
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFF242322),
                    border: Border(
                      bottom: BorderSide(color: Color(0xFF2A2A2A)),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.notifications_active_rounded,
                        size: 15,
                        color: Color(0xFFFF6B00),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ativar notificações do sistema',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFE5E2E1),
                              ),
                            ),
                            Text(
                              'Avisos do browser mesmo com o painel escondido',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 10.5,
                                color: const Color(0xFF9C9896),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const Divider(color: Color(0xFF2A2A2A), height: 1),
          if (center.error != null) _activityError(center),
          Flexible(
            child: (center.loading && items.isEmpty)
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(child: KuponLoader(size: 64)),
                  )
                : items.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.notifications_none_rounded,
                          size: 32,
                          color: const Color(
                            0xFFE2BFB0,
                          ).withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          filter == 'all'
                              ? 'Sem atividade no momento'
                              : 'Sem atividade em ${center.groupLabel(filter)}',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 12,
                            color: const Color(
                              0xFFE2BFB0,
                            ).withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  )
                : ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 360),
                    // MenuAnchor exige dimensões intrínsecas (dry layout), que o
                    // ListView (mesmo com shrinkWrap) não suporta. Column dentro
                    // de SingleChildScrollView resolve.
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < items.length; i++) ...[
                            if (i > 0)
                              const Divider(
                                color: Color(0xFF2A2A2A),
                                height: 1,
                                indent: 16,
                                endIndent: 16,
                              ),
                            // `context` here belongs to the menu overlay, which is
                            // the only context from which MenuController is reachable.
                            Builder(
                              builder: (context) => _buildActivityTile(
                                context,
                                items[i],
                                unreadIds.contains(items[i].id),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// Banner de erro do feed (permite recarregar sem fechar o menu).
  /// Chips do sino: Todas / Ação / Suporte / Pagamentos / Novidades.
  Widget _buildActivityFilterChips(
    AdminActivityCenter center,
    String active,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Row(
          children: [
            for (final key in AdminActivityCenter.groupKeys)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => center.setFilter(key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: active == key
                          ? const Color(0xFFFF6B00).withValues(alpha: 0.16)
                          : const Color(0xFF242322),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: active == key
                            ? const Color(0xFFFF6B00)
                            : const Color(0xFF2A2A2A),
                      ),
                    ),
                    child: Text(
                      center.groupLabel(key),
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: active == key
                            ? const Color(0xFFFF6B00)
                            : const Color(0xFF9C9896),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _activityAction({
    required String label,
    required IconData icon,
    required Color color,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: enabled ? onPressed : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF242322),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 13,
                color: enabled ? color : const Color(0xFF5C5856),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: enabled
                        ? const Color(0xFFE5E2E1)
                        : const Color(0xFF5C5856),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _activityError(AdminActivityCenter center) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      color: const Color(0xFFCF6679).withValues(alpha: 0.12),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 16,
            color: Color(0xFFCF6679),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              center.error!,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                color: const Color(0xFFCF6679),
              ),
            ),
          ),
          TextButton(
            onPressed: center.loading ? null : center.refresh,
            child: Text(
              'Tentar novamente',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFCF6679),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTile(
    BuildContext context,
    AdminActivityItem item,
    bool isUnread,
  ) {
    final (icon, accent) = switch (item.kind) {
      'sos' => (Icons.emergency, const Color(0xFFCF6679)),
      'approval' => (Icons.directions_car_rounded, const Color(0xFFFF6B00)),
      _ => (Icons.support_agent_rounded, const Color(0xFFE2BFB0)),
    };
    final titleColor = const Color(
      0xFFE5E2E1,
    ).withValues(alpha: isUnread ? 1 : 0.55);
    return InkWell(
      onTap: () {
        MenuController.maybeOf(context)?.close();
        AdminActivityCenter.instance.markSeen(item.id);
        context.go(item.route);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 12.5,
                            fontWeight: isUnread
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: titleColor,
                          ),
                        ),
                      ),
                      if (isUnread)
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF6B00),
                            shape: BoxShape.circle,
                          ),
                        ),
                      Text(
                        _timeAgo(item.at),
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          color: const Color(
                            0xFFE2BFB0,
                          ).withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      color: const Color(0xFFE2BFB0).withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'há ${diff.inHours} h';
    return '${at.day.toString().padLeft(2, '0')}/${at.month.toString().padLeft(2, '0')}';
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1B1B),
        title: Text(
          'Sair do painel?',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: const Color(0xFFE5E2E1),
          ),
        ),
        content: Text(
          'Sua sessão será encerrada.',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 14,
            color: const Color(0xFFE2BFB0),
          ),
        ),
        actions: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancelar',
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFE2BFB0),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  'Sair',
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFCF6679),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      invalidateAdminCache();
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      context.go('/login');
    }
  }
}

class _NavDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _NavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}
