import 'package:flutter/material.dart';
import 'package:kupon_office_admin/app/theme/app_theme.dart';

class PrivacyPolicyPage extends StatefulWidget {
  const PrivacyPolicyPage({super.key});

  @override
  State<PrivacyPolicyPage> createState() => _PrivacyPolicyPageState();
}

class _PrivacyPolicyPageState extends State<PrivacyPolicyPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  _buildHeaderSection(),
                  const SizedBox(height: 24),
                  _buildDataCollectionSection(),
                  const SizedBox(height: 20),
                  _buildUserRightsSection(),
                  const SizedBox(height: 20),
                  _buildSecuritySection(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        color: AppTheme.surface,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  Icons.arrow_back,
                  color: AppTheme.primaryContainer,
                  size: 24,
                ),
                padding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Informações Legais',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryContainer,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'KupON CORRIDAS COMPARTILHADAS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
            color: AppTheme.primaryContainer,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Política de Privacidade',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Data de Vigência: 24 de Outubro de 2023. Sua privacidade é primordial para nós no KupON. Esta política explica como tratamos seus dados enquanto fornecemos serviços premium de transporte urbano.',
          style: TextStyle(
            fontSize: 14,
            height: 1.6,
            color: AppTheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildDataCollectionSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryContainer.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storage, color: AppTheme.primaryContainer, size: 28),
              const SizedBox(width: 12),
              Text(
                'Coleta de Dados',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Coletamos informações que você nos fornece diretamente, como quando você cria ou modifica sua conta, solicita serviços ou entra em contato com o suporte ao cliente.',
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          _buildBulletItem(
            'Dados de localização precisos para facilitar embarques rápidos e monitoramento de segurança.',
          ),
          const SizedBox(height: 12),
          _buildBulletItem(
            'Detalhes de transações e informações de pagamento processadas através de canais criptografados seguros.',
          ),
          const SizedBox(height: 12),
          _buildBulletItem(
            'Informações do dispositivo e padrões de uso para otimizar o desempenho do aplicativo.',
          ),
        ],
      ),
    );
  }

  Widget _buildBulletItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle, color: AppTheme.onSurfaceVariant, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserRightsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.gavel, color: AppTheme.primaryContainer, size: 28),
              const SizedBox(width: 12),
              Text(
                'Direitos do Usuário',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Os passageiros do KupOn mantêm controle total sobre sua pegada digital. Nossa plataforma é projetada para respeitar sua autonomia e direitos legais sob as regulamentações globais de proteção de dados.',
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildRightCard(
                  title: 'Direito de Acesso',
                  description:
                      'Solicite uma cópia completa de seus dados pessoais armazenados em nossos sistemas a qualquer momento.',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildRightCard(
                  title: 'Direito de Exclusão',
                  description:
                      'Solicite a exclusão permanente de sua conta e do histórico de corridas associado do nosso banco de dados.',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRightCard({required String title, required String description}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecuritySection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.verified_user,
                color: AppTheme.primaryContainer,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'Medidas de Segurança',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            height: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryContainer.withValues(alpha: 0.15),
                  AppTheme.surfaceContainerHigh,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: AppTheme.primaryContainer.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 48,
                    color: AppTheme.primaryContainer.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TLS 1.3',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryContainer,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Encriptação de ponta a ponta',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Utilizamos protocolos de criptografia multicamadas e detecção de ameaças em tempo real para garantir que seus dados permaneçam tão seguros quanto nossos veículos. Nossos servidores utilizam criptografia TLS 1.3 padrão da indústria e são auditados trimestralmente por empresas de segurança independentes.',
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
