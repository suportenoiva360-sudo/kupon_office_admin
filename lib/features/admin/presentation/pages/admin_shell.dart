import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kupon_office_admin/app/theme/app_theme.dart';
import 'package:kupon_office_admin/core/providers/user_provider.dart';
import 'package:kupon_office_admin/core/routes/app_router.dart'
    show invalidateAdminCache;

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
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
      label: 'Configurações do Sistema',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProvider>().loadAll();
    });
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
                      _nav.goBranch(8, initialLocation: _nav.currentIndex == 8),
                  child: Container(
                    height: 48,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppTheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _nav.currentIndex == 8
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
