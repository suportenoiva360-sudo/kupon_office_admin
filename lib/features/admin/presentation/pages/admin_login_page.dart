import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kupon_office_admin/app/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _rememberMe = false;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      final userId = res.user?.id;
      if (userId == null) throw Exception('Usuário não encontrado');

      // Verifica se tem role admin na tabela users
      final profile = await Supabase.instance.client
          .from('users')
          .select('role')
          .eq('id', userId)
          .maybeSingle();

      if (profile?['role'] != 'admin') {
        await Supabase.instance.client.auth.signOut();
        throw Exception('Acesso restrito a administradores');
      }

      if (mounted) {
        context.go('/dashboard');
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Stack(
        children: [
          // Ambient glows
          Positioned(
            top: -150,
            left: -150,
            child: _glow(const Color(0xFFEA6B1E).withValues(alpha: 0.03), 400),
          ),
          Positioned(
            bottom: -150,
            right: -150,
            child: _glow(const Color(0xFFFF6B00).withValues(alpha: 0.05), 450),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Login card
                  Container(
                    width: double.infinity,
                    constraints: BoxConstraints(maxWidth: 440),
                    padding: const EdgeInsets.all(40),
                    decoration: AppTheme.glassCard,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Logo Section
                        Center(
                          child: Column(
                            children: [
                              SvgPicture.asset(
                                'assets/icons/kupon-logo.svg',
                                width: 90,
                                height: 90,
                              ),
                              const SizedBox(height: 16),
                              RichText(
                                textAlign: TextAlign.center,
                                text: TextSpan(
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                                  children: [
                                    const TextSpan(
                                      text: 'KupON\n',
                                      style: TextStyle(
                                        color: Color(0xFFE5E2E1),
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'Administração',
                                      style: TextStyle(
                                        color: AppTheme.primaryContainer,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Portal Seguro de Operações',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: const Color(
                                    0xFFE2BFB0,
                                  ).withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Email Field Label
                        Text(
                          'E-MAIL DO ADMINISTRADOR',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: const Color(0xFFE2BFB0),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Email Field Input
                        TextField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 14,
                            color: const Color(0xFFE5E2E1),
                          ),
                          decoration: InputDecoration(
                            hintText: 'nome@exemplo.com',
                            prefixIcon: const Icon(
                              Icons.alternate_email_rounded,
                              size: 18,
                            ),
                            fillColor: AppTheme.surfaceContainerLowest,
                            filled: true,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppTheme.outlineVariant,
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppTheme.primaryContainer,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Password Label Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'CREDENCIAIS DE SEGURANÇA',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: const Color(0xFFE2BFB0),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {},
                              child: Text(
                                'RECUPERAR SENHA',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                  color: AppTheme.primaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Password Input
                        TextField(
                          controller: _passCtrl,
                          obscureText: _obscure,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 14,
                            color: const Color(0xFFE5E2E1),
                          ),
                          decoration: InputDecoration(
                            hintText: '••••••••••••',
                            prefixIcon: const Icon(
                              Icons.lock_rounded,
                              size: 18,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_rounded
                                    : Icons.visibility_off_rounded,
                                size: 18,
                                color: const Color(
                                  0xFFE2BFB0,
                                ).withValues(alpha: 0.5),
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                            fillColor: AppTheme.surfaceContainerLowest,
                            filled: true,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppTheme.outlineVariant,
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppTheme.primaryContainer,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Remember Me Checkbox
                        Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: Checkbox(
                                value: _rememberMe,
                                activeColor: AppTheme.primaryContainer,
                                checkColor: Colors.black,
                                side: const BorderSide(
                                  color: AppTheme.outlineVariant,
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                onChanged: (val) =>
                                    setState(() => _rememberMe = val ?? false),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _rememberMe = !_rememberMe),
                              child: Text(
                                'Confiar neste dispositivo por 30 dias',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 12,
                                  color: const Color(
                                    0xFFE2BFB0,
                                  ).withValues(alpha: 0.8),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Error Banner
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF93000A,
                              ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF93000A),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: Color(0xFFFFB4AB),
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 12,
                                      color: const Color(0xFFFFB4AB),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 32),

                        // Glowing Gradient Submit Button
                        GestureDetector(
                          onTap: _loading ? null : _login,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: double.infinity,
                            height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF6B00), Color(0xFFD45900)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFFFF6B00,
                                  ).withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: _loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.black,
                                            ),
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Entrar no Painel',
                                          style: GoogleFonts.spaceGrotesk(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 16,
                                          color: Colors.black,
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Inner card footer
                        Center(
                          child: Text(
                            'Sistema KupON de Gestão de Frota',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 11,
                              color: const Color(
                                0xFFE2BFB0,
                              ).withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Global System Status Footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4CAF50),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF4CAF50),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'TODOS OS SISTEMAS OPERACIONAIS',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: const Color(0xFFE2BFB0).withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _footerLink('POLÍTICA DE PRIVACIDADE'),
                      _footerDivider(),
                      _footerLink('AUDITORIA DE SEGURANÇA'),
                      _footerDivider(),
                      _footerLink('CONTACTAR SUPORTE'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footerLink(String label) {
    return GestureDetector(
      onTap: () {},
      child: Text(
        label,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: const Color(0xFFE2BFB0).withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _footerDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        '|',
        style: TextStyle(
          color: const Color(0xFFE2BFB0).withValues(alpha: 0.2),
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _glow(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color, blurRadius: 120, spreadRadius: size / 2),
        ],
      ),
    );
  }
}
