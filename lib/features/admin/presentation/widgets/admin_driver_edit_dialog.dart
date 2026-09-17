import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kupon_office_admin/app/theme/app_theme.dart';
import 'package:kupon_office_admin/features/admin/presentation/widgets/admin_driver_documents.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<bool?> showAdminDriverEditDialog(
  BuildContext context,
  Map<String, dynamic> driver,
) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: AdminDriverEditDialog(driver: driver),
    ),
  );
}

class AdminDriverEditDialog extends StatefulWidget {
  final Map<String, dynamic> driver;

  const AdminDriverEditDialog({super.key, required this.driver});

  @override
  State<AdminDriverEditDialog> createState() => _AdminDriverEditDialogState();
}

class _AdminDriverEditDialogState extends State<AdminDriverEditDialog> {
  final _db = Supabase.instance.client;

  late final String _driverId;
  late final String _userId;

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _photoCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();

  bool _saving = false;
  bool _dirty = false;
  bool _managing = false;
  bool _loadingTrips = false;
  int _tab = 0;
  List<Map<String, dynamic>> _trips = [];
  String _category = 'car_standard';
  String? _provinceId;
  List<Map<String, dynamic>> _provinces = [];
  DateTime? _memberSince;
  String? _provinceName;

  static const _categories = [
    (value: 'moto', label: 'Moto'),
    (value: 'car_standard', label: 'Carro Standard'),
    (value: 'car_comfort', label: 'Carro Comfort'),
    (value: 'car_luxury', label: 'Carro Luxury'),
  ];

  @override
  void initState() {
    super.initState();
    final d = widget.driver;
    final user = d['users'] as Map<String, dynamic>? ?? {};

    _driverId = d['id'] as String;
    _userId = user['id'] as String? ?? '';

    _nameCtrl.text = user['name'] as String? ?? '';
    _emailCtrl.text = user['email'] as String? ?? '';
    _phoneCtrl.text = user['phone'] as String? ?? '';
    _photoCtrl.text = user['photo_url'] as String? ?? '';
    _modelCtrl.text = d['vehicle_model'] as String? ?? '';
    _colorCtrl.text = d['vehicle_color'] as String? ?? '';
    _plateCtrl.text = d['vehicle_plate'] as String? ?? '';
    _yearCtrl.text = d['vehicle_year']?.toString() ?? '';
    _category = d['category'] as String? ?? 'car_standard';
    _provinceId = d['province_id'] as String?;

    _loadProvinces();
    _fetchExtra();
    _loadTrips();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _photoCtrl.dispose();
    _modelCtrl.dispose();
    _colorCtrl.dispose();
    _plateCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProvinces() async {
    try {
      final data = await _db
          .from('provinces')
          .select('id, name')
          .order('name', ascending: true);
      if (mounted) {
        setState(() {
          _provinces = List<Map<String, dynamic>>.from(data as List);
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchExtra() async {
    try {
      final data = await _db
          .from('drivers')
          .select(
            'provinces(name), users!inner(created_at, role)',
          )
          .eq('id', _driverId)
          .single();
      if (!mounted) return;
      setState(() {
        final users = data['users'] as Map<String, dynamic>? ?? {};
        _memberSince =
            DateTime.tryParse(users['created_at'] as String? ?? '');
        final prov = data['provinces'] as Map<String, dynamic>?;
        _provinceName = prov?['name'] as String?;
      });
    } catch (_) {}
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            error ? AppTheme.errorContainer : const Color(0xFF2E7D32),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      _snack('Preencha o nome e o telefone.', error: true);
      return;
    }

    setState(() => _saving = true);
    try {
      if (_userId.isNotEmpty) {
        await _db.from('users').update({
          'name': name,
          'phone': phone,
          'photo_url': _photoCtrl.text.trim().isEmpty
              ? null
              : _photoCtrl.text.trim(),
          'province_id': _provinceId,
        }).eq('id', _userId);
      }

      await _db.from('drivers').update({
        'category': _category,
        'province_id': _provinceId,
        'vehicle_model': _modelCtrl.text.trim(),
        'vehicle_color': _colorCtrl.text.trim(),
        'vehicle_plate': _plateCtrl.text.trim(),
        'vehicle_year': int.tryParse(_yearCtrl.text.trim()),
      }).eq('id', _driverId);

      if (mounted) {
        Navigator.pop(context, true);
        _snack('Perfil atualizado com sucesso');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(
        e is AuthException
            ? e.message
            : 'Falha ao atualizar o perfil.',
        error: true,
      );
    }
  }

  Future<void> _loadTrips() async {
    setState(() => _loadingTrips = true);
    try {
      final trips = await _db
          .from('trips')
          .select(
            'id, status, category, created_at, pickup_name, destination_name, estimated_fare',
          )
          .eq('driver_id', _driverId)
          .order('created_at', ascending: false)
          .limit(40);
      if (mounted) {
        setState(() {
          _trips = List<Map<String, dynamic>>.from(trips as List);
          _loadingTrips = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingTrips = false);
    }
  }

  Future<bool> _confirm(String title, String message, String label) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 13,
            color: AppTheme.onSurfaceVariant,
          ),
        ),
        actions: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(label),
              ),
            ],
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _toggleApproval(bool approve) async {
    if (!approve &&
        !await _confirm(
          'Revogar aprovação',
          'O motorista deixará de receber corridas até ser aprovado '
          'novamente.',
          'Revogar',
        )) {
      return;
    }
    setState(() => _managing = true);
    try {
      await _db
          .from('drivers')
          .update({
            'is_approved': approve,
            if (approve) 'is_blocked': false,
          })
          .eq('id', _driverId);
      widget.driver['is_approved'] = approve;
      if (approve) widget.driver['is_blocked'] = false;
      setState(() {
        _dirty = true;
        _managing = false;
      });
      _snack(approve ? 'Motorista aprovado' : 'Aprovação revogada');
    } catch (e) {
      if (!mounted) return;
      setState(() => _managing = false);
      _snack('Falha ao atualizar a aprovação', error: true);
    }
  }

  Future<void> _toggleBlock(bool block) async {
    if (block &&
        !await _confirm(
          'Bloquear conta',
          'O motorista não poderá ficar online nem aceitar corridas. '
          'O registo não é apagado.',
          'Bloquear',
        )) {
      return;
    }
    setState(() => _managing = true);
    try {
      await _db
          .from('drivers')
          .update({
            'is_blocked': block,
            if (block) 'is_online': false,
          })
          .eq('id', _driverId);
      widget.driver['is_blocked'] = block;
      if (block) widget.driver['is_online'] = false;
      setState(() {
        _dirty = true;
        _managing = false;
      });
      _snack(block ? 'Conta bloqueada' : 'Conta desbloqueada');
    } catch (e) {
      if (!mounted) return;
      setState(() => _managing = false);
      _snack('Falha ao atualizar o estado da conta', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.driver;
    final user = d['users'] as Map<String, dynamic>? ?? {};
    final name = user['name'] as String? ?? 'Motorista';
    final photo = user['photo_url'] as String?;
    final isOnline = d['is_online'] as bool? ?? false;
    final isApproved = d['is_approved'] as bool? ?? false;
    final rating = (d['rating'] as num?)?.toStringAsFixed(1) ?? '–';
    final totalTrips = d['total_trips'] as int? ?? 0;

    return Container(
      width: 540,
      constraints: const BoxConstraints(maxHeight: 640),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.outlineVariant),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 30,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(name, photo, isOnline, isApproved, rating, totalTrips),
          _buildTabs(),
          Expanded(
            child: _tab == 0
                ? SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSectionLabel('DADOS DA CONTA'),
                  const SizedBox(height: 12),
                  _buildField(_nameCtrl, 'Nome completo',
                      icon: Icons.person_outline_rounded),
                  const SizedBox(height: 12),
                  _buildReadOnlyRow(
                    value: _emailCtrl.text,
                    hint: 'Email (início de sessão)',
                  ),
                  const SizedBox(height: 12),
                  _buildField(_phoneCtrl, 'Telefone',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone),
                  const SizedBox(height: 12),
                  _buildField(_photoCtrl, 'URL da foto',
                      icon: Icons.image_outlined),
                  const SizedBox(height: 22),
                  _buildSectionLabel('INFORMAÇÕES'),
                  const SizedBox(height: 12),
                  _buildInfoSection(),
                  const SizedBox(height: 22),
                  _buildSectionLabel('VEÍCULO'),
                  const SizedBox(height: 12),
                  _buildDropdownRow(
                    label: 'Categoria',
                    icon: Icons.directions_car_outlined,
                    value: _categories
                        .firstWhere((c) => c.value == _category)
                        .label,
                    onTap: (v) => setState(() => _category = v),
                    options: _categories
                        .map((c) => (label: c.label, value: c.value))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  _buildProvinceRow(),
                  const SizedBox(height: 12),
                  _buildField(_modelCtrl, 'Modelo do veículo',
                      icon: Icons.model_training_rounded),
                  const SizedBox(height: 12),
                  _buildField(_colorCtrl, 'Cor',
                      icon: Icons.color_lens_outlined),
                  const SizedBox(height: 12),
                  _buildField(_plateCtrl, 'Matrícula',
                      icon: Icons.confirmation_number_outlined),
                  const SizedBox(height: 12),
                  _buildField(_yearCtrl, 'Ano',
                      icon: Icons.calendar_today_outlined,
                      keyboardType: TextInputType.number),
                  const SizedBox(height: 22),
                  _buildSectionLabel('GESTÃO DA CONTA'),
                  const SizedBox(height: 12),
                  _buildManagement(),
                  const SizedBox(height: 24),
                ],
              ),
            )
                : _buildHistoryTab(),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
      child: Row(
        children: [
          _tabItem(0, 'Editar', Icons.edit_outlined),
          const SizedBox(width: 8),
          _tabItem(1, 'Histórico', Icons.history_rounded),
        ],
      ),
    );
  }

  Widget _tabItem(int index, String label, IconData icon) {
    final sel = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: sel
                ? AppTheme.primaryContainer
                : AppTheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(60),
            border: Border.all(
              color: sel
                  ? AppTheme.primaryContainer
                  : AppTheme.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: sel ? Colors.black : AppTheme.onSurfaceVariant,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: sel ? Colors.black : AppTheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManagement() {
    final isApproved = widget.driver['is_approved'] as bool? ?? false;
    final isBlocked = widget.driver['is_blocked'] == true;
    return Row(
      children: [
        Expanded(
          child: _manageButton(
            icon: isApproved
                ? Icons.cancel_outlined
                : Icons.verified_rounded,
            label: isApproved ? 'Revogar Aprovação' : 'Aprovar Motorista',
            color: isApproved
                ? const Color(0xFF93000A)
                : const Color(0xFF4CAF88),
            onTap: () {
              if (isApproved) {
                _toggleApproval(false);
              } else {
                final user =
                    widget.driver['users'] as Map<String, dynamic>? ?? {};
                showDriverApprovalReview(
                  context,
                  driverId: _driverId,
                  userId: user['id'] as String?,
                  driverName: user['name'] as String? ?? 'Motorista',
                  onApprove: () => _toggleApproval(true),
                );
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _manageButton(
            icon: isBlocked ? Icons.lock_open_rounded : Icons.block_rounded,
            label: isBlocked ? 'Desbloquear Conta' : 'Bloquear Conta',
            color: isBlocked
                ? const Color(0xFF4CAF88)
                : const Color(0xFFB3261E),
            onTap: () => _toggleBlock(!isBlocked),
          ),
        ),
      ],
    );
  }

  Widget _manageButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _managing ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: _managing
              ? Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 15, color: color),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_loadingTrips) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppTheme.primaryContainer,
        ),
      );
    }
    if (_trips.isEmpty) {
      return Column(
        children: [
          const SizedBox(height: 48),
          const Icon(
            Icons.history_rounded,
            size: 42,
            color: Color(0xFFE2BFB0),
          ),
          const SizedBox(height: 12),
          Text(
            'Nenhuma viagem registada',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 13,
              color: const Color(0xFFE2BFB0).withValues(alpha: 0.8),
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      itemCount: _trips.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _buildTripTile(_trips[i]),
      ),
    );
  }

  Widget _buildTripTile(Map<String, dynamic> trip) {
    final status = trip['status'] as String? ?? 'pending';
    final category = trip['category'] as String? ?? '–';
    final pickup = trip['pickup_name'] as String? ?? '–';
    final dest = trip['destination_name'] as String? ?? '–';
    final fare = trip['estimated_fare'];
    final date = _fmtTripDate(trip['created_at']);
    final statusColor = _tripStatusColor(status);

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
                      _categoryLabel(category),
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFE5E2E1),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _tripChip(status, statusColor),
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

  Widget _tripChip(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        _tripStatusLabel(status),
        style: GoogleFonts.spaceGrotesk(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Color _tripStatusColor(String s) {
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

  String _tripStatusLabel(String s) {
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

  String _fmtTripDate(dynamic v) {
    if (v is! String || v.isEmpty) return '–';
    final d = DateTime.tryParse(v);
    if (d == null) return '–';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Widget _buildHeader(
    String name,
    String? photo,
    bool isOnline,
    bool isApproved,
    String rating,
    int totalTrips,
  ) {
    final handle = '@${name.toLowerCase().replaceAll(' ', '')}';

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4B2E16), Color(0xFF1C1B1B)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.surfaceContainerHigh,
                  border: Border.all(color: AppTheme.surface, width: 3),
                ),
                child: ClipOval(
                  child: photo != null && photo.isNotEmpty
                      ? Image.network(
                          photo,
                          fit: BoxFit.cover,
                          cacheWidth: 112,
                          cacheHeight: 112,
                          errorBuilder: (_, _, _) => Icon(
                            Icons.person_rounded,
                            size: 26,
                            color: AppTheme.onSurfaceVariant
                                .withValues(alpha: 0.6),
                          ),
                        )
                      : Icon(
                          Icons.person_rounded,
                          size: 26,
                          color: AppTheme.onSurfaceVariant
                              .withValues(alpha: 0.6),
                        ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: isOnline
                        ? const Color(0xFF4CAF88)
                        : AppTheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: AppTheme.surface,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    isOnline ? 'ON' : 'OFF',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.onSurface,
                        ),
                      ),
                    ),
                    if (isApproved) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.verified_rounded,
                        size: 17,
                        color: AppTheme.primaryContainer,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  handle,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    color: AppTheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _headerMeta(Icons.star_rounded, rating,
                        AppTheme.primaryContainer),
                    const SizedBox(width: 14),
                    _headerMeta(
                        Icons.directions_car_rounded, '$totalTrips', null),
                    if (widget.driver['is_blocked'] == true) ...[
                      const SizedBox(width: 14),
                      _blockedChip(),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _blockedChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFB3261E),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.block_rounded, size: 10, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            'BLOQUEADO',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerMeta(IconData icon, String text, Color? color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: color ?? AppTheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.spaceGrotesk(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppTheme.primaryContainer,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildInfoSection() {
    final isApproved = widget.driver['is_approved'] as bool? ?? false;
    final isOnline = widget.driver['is_online'] as bool? ?? false;
    final isBlocked = widget.driver['is_blocked'] == true;
    final category = _categoryLabel(widget.driver['category'] as String? ?? '');
    final province = _provinceName ?? '–';
    final memberSince = _fmtDate(_memberSince);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        children: [
          _infoRow(
            icon: isBlocked
                ? Icons.block_rounded
                : Icons.verified_rounded,
            label: 'ESTADO',
            value: isBlocked
                ? 'Bloqueado'
                : (isApproved ? 'Aprovado' : 'Pendente'),
            valueColor: isBlocked
                ? const Color(0xFFFFB4AB)
                : isApproved
                    ? const Color(0xFF4CAF88)
                    : const Color(0xFFF5C842),
          ),
          _infoDivider(),
          _infoRow(
            icon: Icons.wifi_rounded,
            label: 'ONLINE',
            value: isOnline ? 'Sim' : 'Não',
            valueColor: isOnline
                ? const Color(0xFF4CAF88)
                : AppTheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          _infoDivider(),
          _infoRow(
            icon: Icons.category_rounded,
            label: 'CATEGORIA',
            value: category,
          ),
          _infoDivider(),
          _infoRow(
            icon: Icons.location_city_outlined,
            label: 'PROVÍNCIA',
            value: province,
          ),
          _infoDivider(),
          _infoRow(
            icon: Icons.calendar_today_outlined,
            label: 'MEMBRO DESDE',
            value: memberSince,
          ),
          _infoDivider(),
          _infoRow(
            icon: Icons.fingerprint_rounded,
            label: 'ID',
            value: _shortId(_driverId),
            copyable: _driverId,
          ),
        ],
      ),
    );
  }

  Widget _infoDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Divider(height: 1, color: AppTheme.outlineVariant),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    String? copyable,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFFE2BFB0), size: 15),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: const Color(0xFFE2BFB0).withValues(alpha: 0.5),
                ),
              ),
              Text(
                value,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? const Color(0xFFE5E2E1),
                ),
              ),
            ],
          ),
        ),
        if (copyable != null)
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: copyable));
              _snack('ID copiado');
            },
            child: Icon(
              Icons.copy_rounded,
              size: 15,
              color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
      ],
    );
  }

  String _shortId(String id) {
    if (id.length <= 22) return id;
    return '${id.substring(0, 10)}…${id.substring(id.length - 6)}';
  }

  String _categoryLabel(String c) {
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

  String _fmtDate(DateTime? d) {
    if (d == null) return '–';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Widget _buildField(
    TextEditingController ctrl,
    String hint, {
    IconData? icon,
    bool obscure = false,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: TextField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: GoogleFonts.spaceGrotesk(fontSize: 14, color: AppTheme.onSurface),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.spaceGrotesk(
            fontSize: 14,
            color: AppTheme.onSurfaceVariant.withValues(alpha: 0.45),
          ),
          prefixIcon: icon != null
              ? Icon(
                  icon,
                  size: 18,
                  color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5),
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildReadOnlyRow({required String value, required String hint}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.mail_outline_rounded,
            size: 18,
            color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hint,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    color: AppTheme.onSurfaceVariant.withValues(alpha: 0.45),
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    color: AppTheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.lock_outline_rounded,
            size: 14,
            color: AppTheme.onSurfaceVariant.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownRow({
    required String label,
    required IconData icon,
    required String value,
    required void Function(String) onTap,
    required List<({String label, String value})> options,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                dropdownColor: AppTheme.surfaceContainerLow,
                isExpanded: true,
                icon: Icon(
                  Icons.expand_more_rounded,
                  color: AppTheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  color: AppTheme.onSurface,
                ),
                onChanged: (v) {
                  if (v != null) {
                    onTap(options.firstWhere((o) => o.label == v).value);
                  }
                },
                items: options
                    .map((o) => DropdownMenuItem(
                          value: o.label,
                          child: Text(o.label),
                        ))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProvinceRow() {
    final hasProvince =
        _provinces.any((p) => (p['id'] as String?) == _provinceId);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.location_city_outlined,
            size: 18,
            color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: hasProvince ? _provinceId : null,
                dropdownColor: AppTheme.surfaceContainerLow,
                isExpanded: true,
                hint: Text(
                  'Província',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    color: AppTheme.onSurfaceVariant.withValues(alpha: 0.45),
                  ),
                ),
                icon: Icon(
                  Icons.expand_more_rounded,
                  color: AppTheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  color: AppTheme.onSurface,
                ),
                onChanged: (v) => setState(() => _provinceId = v),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Sem província'),
                  ),
                  ..._provinces.map(
                    (p) => DropdownMenuItem<String?>(
                      value: p['id'] as String?,
                      child: Text(p['name'] as String? ?? ''),
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

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
        border: Border(
          top: BorderSide(color: AppTheme.outlineVariant, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _saving
                  ? null
                  : () => Navigator.pop(context, _dirty),
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.outlineVariant),
                ),
                child: Center(
                  child: Text(
                    'Cancelar',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: _saving ? null : _save,
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryContainer.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: _saving
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : Text(
                          'Guardar Alterações',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}