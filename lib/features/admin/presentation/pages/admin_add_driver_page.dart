import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kupon_office_admin/app/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<bool?> showAddDriverDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AdminAddDriverDialog(),
  );
}

class AdminAddDriverDialog extends StatefulWidget {
  const AdminAddDriverDialog({super.key});

  @override
  State<AdminAddDriverDialog> createState() => _AdminAddDriverDialogState();
}

class _AdminAddDriverDialogState extends State<AdminAddDriverDialog> {
  final _db = Supabase.instance.client;
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();

  bool _saving = false;
  String _category = 'car_standard';
  String? _provinceId;

  List<Map<String, dynamic>> _provinces = [];

  static const _categories = [
    (value: 'moto', label: 'Moto'),
    (value: 'car_standard', label: 'Carro Standard'),
    (value: 'car_comfort', label: 'Carro Comfort'),
    (value: 'car_luxury', label: 'Carro Luxury'),
  ];

  @override
  void initState() {
    super.initState();
    _loadProvinces();
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

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _modelCtrl.dispose();
    _colorCtrl.dispose();
    _plateCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
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

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (name.isEmpty || email.isEmpty || phone.isEmpty || password.length < 6) {
      _snack('Preencha nome, email, telefone e uma palavra-passe (mín. 6).',
          error: true);
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _snack('Email inválido.', error: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final adminSession = _db.auth.currentSession;
      if (adminSession == null) {
        _snack('Sessão expirada. Inicie sessão novamente.', error: true);
        return;
      }

      // 1. Criar a conta (confirmações desativadas → a sessão passa a ser do
      // novo utilizador momentaneamente; restauramos o admin no fim).
      final resp = await _db.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': name,
          'phone': phone,
          'role': 'driver',
          if (_provinceId != null) 'province_id': _provinceId,
        },
      );
      final newUserId = resp.user?.id;
      if (newUserId == null) {
        throw Exception('Não foi possível criar a conta');
      }

      // 2. Linha em users (como o novo utilizador — RLS permite a própria).
      await _db.from('users').insert({
        'id': newUserId,
        'name': name,
        'email': email,
        'phone': phone,
        'role': 'driver',
        if (_provinceId != null) 'province_id': _provinceId,
      });

      // 3. Linha em drivers (como o novo utilizador).
      await _db.from('drivers').insert({
        'user_id': newUserId,
        'category': _category,
        'vehicle_model': _modelCtrl.text.trim(),
        'vehicle_color': _colorCtrl.text.trim(),
        'vehicle_plate': _plateCtrl.text.trim(),
        'vehicle_year': int.tryParse(_yearCtrl.text.trim()),
        'province_id': _provinceId,
        'is_online': false,
        'is_approved': false,
        'status': 'pending',
      });

      // 4. Restaurar sessão do admin.
      await _db.auth.setSession(
        adminSession.refreshToken ?? '',
        accessToken: adminSession.accessToken,
      );

      // 5. Aprovar como admin.
      await _db
          .from('drivers')
          .update({'is_approved': true, 'status': 'approved'})
          .eq('user_id', newUserId);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      final adminSession = _db.auth.currentSession;
      if (adminSession != null) {
        try {
          await _db.auth.setSession(
            adminSession.refreshToken ?? '',
            accessToken: adminSession.accessToken,
          );
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() => _saving = false);
      final msg = e is AuthException
          ? e.message
          : (e.toString().contains('already')
              ? 'Já existe uma conta com este email.'
              : 'Falha ao criar o motorista.');
      _snack(msg, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_add_rounded,
                    color: AppTheme.primaryContainer,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Adicionar Motorista',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryContainer.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              AppTheme.primaryContainer.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: AppTheme.primaryContainer,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'A conta será criada com aprovação imediata. O '
                              'motorista autentica-se com este email e palavra-passe.',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 12,
                                color: AppTheme.onSurfaceVariant.withValues(
                                  alpha: 0.8,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _sectionLabel('DADOS DA CONTA'),
                    const SizedBox(height: 10),
                    _buildField(_nameCtrl, 'Nome completo',
                        icon: Icons.person_outline_rounded),
                    const SizedBox(height: 10),
                    _buildField(_emailCtrl, 'Email',
                        icon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 10),
                    _buildField(_phoneCtrl, 'Telefone',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone),
                    const SizedBox(height: 10),
                    _buildField(_passwordCtrl, 'Palavra-passe inicial',
                        icon: Icons.lock_outline_rounded, obscure: true),
                    const SizedBox(height: 20),
                    _sectionLabel('VEÍCULO'),
                    const SizedBox(height: 10),
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
                    const SizedBox(height: 10),
                    _buildProvinceRow(),
                    const SizedBox(height: 10),
                    _buildField(_modelCtrl, 'Modelo do veículo',
                        icon: Icons.model_training_rounded),
                    const SizedBox(height: 10),
                    _buildField(_colorCtrl, 'Cor',
                        icon: Icons.color_lens_outlined),
                    const SizedBox(height: 10),
                    _buildField(_plateCtrl, 'Matrícula',
                        icon: Icons.confirmation_number_outlined),
                    const SizedBox(height: 10),
                    _buildField(_yearCtrl, 'Ano',
                        icon: Icons.calendar_today_outlined,
                        keyboardType: TextInputType.number),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving
                                ? null
                                : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.onSurfaceVariant,
                              side: BorderSide(
                                color: AppTheme.outlineVariant,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              'Cancelar',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: GestureDetector(
                            onTap: _saving ? null : _submit,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryContainer
                                        .withValues(alpha: 0.3),
                                    blurRadius: 14,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: _saving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.black,
                                        ),
                                      )
                                    : Text(
                                        'Criar Motorista',
                                        style: GoogleFonts.spaceGrotesk(
                                          fontSize: 14,
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
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.spaceGrotesk(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppTheme.primaryContainer,
        letterSpacing: 0.8,
      ),
    );
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
              ? Icon(icon, size: 18, color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5))
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5)),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.location_city_outlined,
              size: 18, color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5)),
          const SizedBox(width: 14),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _provinceId,
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
                style: GoogleFonts.spaceGrotesk(fontSize: 14, color: AppTheme.onSurface),
                onChanged: (v) => setState(() => _provinceId = v),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Sem província'),
                  ),
                  ..._provinces.map((p) => DropdownMenuItem<String?>(
                        value: p['id'] as String?,
                        child: Text(p['name'] as String? ?? ''),
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}