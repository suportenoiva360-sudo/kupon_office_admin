import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kupon_office_admin/app/theme/app_theme.dart';
import 'package:kupon_office_admin/core/widgets/kupon_loader.dart';
import 'package:kupon_office_admin/app/widgets/profile_cover_header.dart';
import 'package:kupon_office_admin/features/admin/presentation/widgets/admin_driver_documents.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminDriverDetailPage extends StatefulWidget {
  final String driverId;

  const AdminDriverDetailPage({super.key, required this.driverId});

  @override
  State<AdminDriverDetailPage> createState() => _AdminDriverDetailPageState();
}

class _AdminDriverDetailPageState extends State<AdminDriverDetailPage> {
  final _db = Supabase.instance.client;
  bool _loading = true;
  bool _saving = false;
  bool _loadFailed = false;
  Map<String, dynamic>? _driver;
  List<Map<String, dynamic>> _trips = [];
  int _selectedTab = 0;

  /// `drivers.documents_url` (mapa `{tipo: url}` gravado no registo).
  Map<String, dynamic>? get _docUrls {
    final raw = _driver?['documents_url'];
    return raw is Map ? raw.cast<String, dynamic>() : null;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final driver = await _db
          .from('drivers')
          .select(
            '*, users!inner(id, name, email, phone, photo_url, created_at)',
          )
          .eq('id', widget.driverId)
          .single();

      final trips = await _db
          .from('trips')
          .select(
            'id, status, category, created_at, pickup_name, destination_name, estimated_fare',
          )
          .eq('driver_id', widget.driverId)
          .order('created_at', ascending: false)
          .limit(20);

      if (mounted) {
        setState(() {
          _driver = driver;
          _trips = List<Map<String, dynamic>>.from(trips as List);
          _loading = false;
          _loadFailed = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
      }
    }
  }

  Future<void> _toggleApproval(bool approve) async {
    setState(() => _saving = true);
    try {
      await _db
          .from('drivers')
          .update({'is_approved': approve})
          .eq('id', widget.driverId);
      if (!mounted) return;
      setState(() {
        _driver?['is_approved'] = approve;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve ? 'Motorista aprovado com sucesso' : 'Aprovação revogada',
          ),
          backgroundColor: approve
              ? const Color(0xFF4CAF88)
              : const Color(0xFFCF6679),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao atualizar aprovação: $e'),
          backgroundColor: const Color(0xFFCF6679),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppTheme.surface,
        body: KuponLoader(),
      );
    }
    if (_driver == null) {
      return Scaffold(
        backgroundColor: AppTheme.surface,
        appBar: AppBar(
          backgroundColor: AppTheme.surface,
          title: Text(
            'Perfil do Motorista',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _loadFailed
                    ? 'Não foi possível carregar o motorista.'
                    : 'Motorista nao encontrado',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  color: const Color(0xFFE2BFB0),
                ),
              ),
              if (_loadFailed) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _loading = true;
                      _loadFailed = false;
                    });
                    _load();
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Tentar novamente'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final user = _driver!['users'] as Map<String, dynamic>? ?? {};
    final name = user['name'] as String? ?? 'Motorista';
    final photo = user['photo_url'] as String?;
    final email = user['email'] as String? ?? '–';
    final phone = user['phone'] as String? ?? '–';
    final isApproved = _driver!['is_approved'] as bool? ?? false;
    final isOnline = _driver!['is_online'] as bool? ?? false;
    final rating = (_driver!['rating'] as num?)?.toStringAsFixed(1) ?? '–';
    final totalTrips = _driver!['total_trips'] as int? ?? 0;
    final category = _driver!['category'] as String? ?? '–';
    final model = _driver!['vehicle_model'] as String? ?? '–';
    final plate = _driver!['vehicle_plate'] as String? ?? '–';
    final color = _driver!['vehicle_color'] as String? ?? '–';
    final year = _driver!['vehicle_year']?.toString() ?? '–';

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  ProfileCoverHeader(
                    name: name,
                    handle: '@${name.toLowerCase().replaceAll(' ', '')}',
                    photoUrl: photo,
                    onEdit: () {},
                    verified: isApproved,
                    avatarBadge: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isOnline
                            ? const Color(0xFF4CAF88)
                            : AppTheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: const Color(0xFF0A0A0A),
                          width: 2,
                        ),
                      ),
                      child: Text(
                        isOnline ? 'ON' : 'OFF',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    meta: [
                      ProfileMetaItem(
                        icon: Icons.star_rounded,
                        text: rating,
                        highlight: true,
                      ),
                      ProfileMetaItem(
                        icon: Icons.directions_car_rounded,
                        text: '$totalTrips viagens',
                      ),
                      ProfileMetaItem(
                        icon: Icons.category_rounded,
                        text: _catLabel(category),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      children: [
                        _buildApprovalBanner(isApproved),
                        const SizedBox(height: 16),
                        _buildStatsRow(rating, totalTrips),
                        const SizedBox(height: 20),
                        _buildTabs(),
                        const SizedBox(height: 20),
                        if (_selectedTab == 0)
                          _buildInfoTab(
                            email,
                            phone,
                            model,
                            plate,
                            color,
                            year,
                            widget.driverId,
                            user['id'] as String?,
                          )
                        else if (_selectedTab == 1)
                          _buildTripsTab()
                        else
                          _buildDocumentsTab(
                            widget.driverId,
                            user['id'] as String?,
                          ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildBottomBar(isApproved),
        ],
      ),
    );
  }

  Widget _buildApprovalBanner(bool isApproved) {
    final color = isApproved
        ? const Color(0xFF4CAF88)
        : const Color(0xFFF5C842);
    final icon = isApproved
        ? Icons.verified_rounded
        : Icons.pending_actions_rounded;
    final label = isApproved ? 'Motorista Aprovado' : 'Aguardando Aprovação';
    final sub = isApproved
        ? 'Habilitado para receber corridas'
        : 'Revise os documentos antes de aprovar';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  sub,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    color: const Color(0xFFE2BFB0).withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(String rating, int totalTrips) {
    return Row(
      children: [
        _statCard(
          Icons.star_rounded,
          rating,
          'Avaliação',
          AppTheme.primaryContainer,
        ),
        const SizedBox(width: 12),
        _statCard(
          Icons.directions_car_rounded,
          '$totalTrips',
          'Viagens',
          const Color(0xFF7B8CDE),
        ),
        const SizedBox(width: 12),
        _statCard(
          Icons.account_balance_wallet_rounded,
          '0 Kz',
          'Ganhos',
          const Color(0xFF4CAF88),
        ),
      ],
    );
  }

  Widget _statCard(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.outlineVariant),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFE5E2E1),
              ),
            ),
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                color: const Color(0xFFE2BFB0).withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(60),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Row(
        children: [
          _tabItem(0, 'Informações', Icons.info_outline_rounded),
          _tabItem(1, 'Histórico', Icons.history_rounded),
          _tabItem(2, 'Documentos', Icons.folder_rounded),
        ],
      ),
    );
  }

  Widget _tabItem(int index, String label, IconData icon) {
    final sel = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel ? AppTheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(60),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: sel ? Colors.black : const Color(0xFFE2BFB0),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: sel ? Colors.black : const Color(0xFFE2BFB0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTab(
    String email,
    String phone,
    String model,
    String plate,
    String color,
    String year,
    String driverId,
    String? userId,
  ) {
    return Column(
      children: [
        _infoSection('Dados Pessoais', [
          _InfoRow(Icons.email_outlined, 'EMAIL', email),
          _InfoRow(Icons.phone_outlined, 'TELEFONE', phone),
        ]),
        const SizedBox(height: 12),
        _infoSection('Veículo', [
          _InfoRow(Icons.directions_car_outlined, 'MODELO', model),
          _InfoRow(Icons.numbers_rounded, 'PLACA', plate),
          _InfoRow(Icons.color_lens_outlined, 'COR', color),
          _InfoRow(Icons.calendar_today_outlined, 'ANO', year),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Documentos',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              DriverDocumentsSection(
                driverId: driverId,
                userId: userId,
                docUrls: _docUrls,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoSection(String title, List<_InfoRow> rows) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFE5E2E1),
            ),
          ),
          const SizedBox(height: 16),
          ...rows.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      r.icon,
                      color: const Color(0xFFE2BFB0),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.label,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: const Color(
                              0xFFE2BFB0,
                            ).withValues(alpha: 0.5),
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          r.value,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFE5E2E1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsTab(String driverId, String? userId) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Documentos do motorista',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          DriverDocumentsSection(
            driverId: driverId,
            userId: userId,
            docUrls: _docUrls,
          ),
          const SizedBox(height: 8),
          Text(
            'A revisão manual garante que os documentos estão legíveis e '
            'dentro da validade antes de aprovar.',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripsTab() {
    if (_trips.isEmpty) {
      return Column(
        children: [
          const SizedBox(height: 40),
          const Icon(
            Icons.directions_car_outlined,
            size: 48,
            color: Color(0xFFE2BFB0),
          ),
          const SizedBox(height: 12),
          Text(
            'Nenhuma viagem registrada',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 13,
              color: const Color(0xFFE2BFB0).withValues(alpha: 0.8),
            ),
          ),
        ],
      );
    }
    return Column(
      children: _trips
          .map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildTripTile(t),
            ),
          )
          .toList(),
    );
  }

  Widget _buildTripTile(Map<String, dynamic> trip) {
    final status = trip['status'] as String? ?? 'pending';
    final category = trip['category'] as String? ?? '–';
    final pickup = trip['pickup_name'] as String? ?? '–';
    final dest = trip['destination_name'] as String? ?? '–';
    final fare = trip['estimated_fare'];
    final date = _fmtDate(trip['created_at']);
    final statusColor = _statusColor(status);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.directions_car_rounded,
              color: statusColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _catLabel(category),
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFE5E2E1),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _chip(status, statusColor),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$pickup → $dest',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    color: const Color(0xFFE2BFB0).withValues(alpha: 0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                date,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  color: const Color(0xFFE2BFB0).withValues(alpha: 0.5),
                ),
              ),
              if (fare != null)
                Text(
                  '$fare Kz',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    color: AppTheme.primaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        _statusLabel(status),
        style: GoogleFonts.spaceGrotesk(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildBottomBar(bool isApproved) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: const BoxDecoration(
          color: AppTheme.surfaceContainerLow,
          border: Border(
            top: BorderSide(color: AppTheme.outlineVariant, width: 1),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _saving ? null : () => Navigator.pop(context),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.outlineVariant),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.arrow_back_rounded,
                          size: 16,
                          color: Color(0xFFE2BFB0),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Voltar',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFE5E2E1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: _saving
                    ? null
                    : () {
                        if (isApproved) {
                          _toggleApproval(false);
                        } else {
                          final user =
                              _driver!['users'] as Map<String, dynamic>? ?? {};
                          showDriverApprovalReview(
                            context,
                            driverId: widget.driverId,
                            userId: user['id'] as String?,
                            driverName:
                                user['name'] as String? ?? 'Motorista',
                            onApprove: () => _toggleApproval(true),
                          );
                        }
                      },
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: isApproved
                        ? const Color(0xFF93000A)
                        : const Color(0xFF4CAF88),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color:
                            (isApproved
                                    ? const Color(0xFF93000A)
                                    : const Color(0xFF4CAF88))
                                .withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isApproved
                                    ? Icons.cancel_outlined
                                    : Icons.verified_rounded,
                                size: 16,
                                color: Colors.black,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isApproved
                                    ? 'Revogar Aprovação'
                                    : 'Aprovar Motorista',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                              ),
                            ],
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

  Color _statusColor(String s) {
    switch (s) {
      case 'in_progress':
        return AppTheme.primaryContainer;
      case 'completed':
        return const Color(0xFF4CAF88);
      case 'cancelled':
        return const Color(0xFFCF6679);
      default:
        return const Color(0xFFF5C842);
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'in_progress':
        return 'Em andamento';
      case 'completed':
        return 'Concluída';
      case 'cancelled':
        return 'Cancelada';
      case 'accepted':
        return 'Aceita';
      default:
        return 'Pendente';
    }
  }

  String _catLabel(String c) {
    switch (c) {
      case 'moto':
        return 'Moto';
      case 'car_standard':
        return 'Standard';
      case 'car_comfort':
        return 'Comfort';
      case 'car_luxury':
        return 'Luxury';
      default:
        return c;
    }
  }

  String _fmtDate(dynamic v) {
    if (v is! String || v.isEmpty) return '–';
    final d = DateTime.tryParse(v);
    if (d == null) return '–';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}

class _InfoRow {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);
}
