import 'package:flutter/material.dart';
import 'package:kupon_office_admin/app/theme/app_theme.dart';

class TermsOfServicePage extends StatefulWidget {
  const TermsOfServicePage({super.key});

  @override
  State<TermsOfServicePage> createState() => _TermsOfServicePageState();
}

class _TermsOfServicePageState extends State<TermsOfServicePage> {
  bool _agreedToTerms = false;

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
                children: [
                  const SizedBox(height: 16),
                  _buildHeroSection(),
                  const SizedBox(height: 24),
                  _buildUserObligationsSection(),
                  const SizedBox(height: 16),
                  _buildLiabilitySection(),
                  const SizedBox(height: 16),
                  _buildAccountTerminationSection(),
                  const SizedBox(height: 24),
                  _buildAgreementCheckbox(),
                  const SizedBox(height: 24),
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

  Widget _buildHeroSection() {
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
          Text(
            'TERMOS DE\nSERVIÇO',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryContainer,
              height: 1.1,
              letterSpacing: -1.0,
              shadows: [
                Shadow(
                  color: AppTheme.primaryContainer.withValues(alpha: 0.4),
                  blurRadius: 15,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Data de Vigência: 24 de Outubro de 2023',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.05,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserObligationsSection() {
    return _buildSectionCard(
      icon: Icons.assignment_ind,
      title: 'Obrigações do Usuário',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildParagraph(
            'Ao acessar o KupON, você concorda em fornecer informações precisas, atuais e completas durante o processo de registro e em atualizar essas informações para mantê-las precisas, atuais e completas.',
          ),
          const SizedBox(height: 12),
          _buildParagraph(
            'Os usuários são estritamente proibidos de usar o serviço para quaisquer atividades ilegais, incluindo, mas não se limitando, ao transporte não autorizado de substâncias controladas ou ao envolvimento em qualquer forma de assédio a motoristas ou outros passageiros.',
          ),
        ],
      ),
    );
  }

  Widget _buildLiabilitySection() {
    return _buildSectionCard(
      icon: Icons.gavel,
      title: 'Limitação de Responsabilidade',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildParagraph(
            'O KupON fornece uma plataforma que conecta passageiros a motoristas independentes de terceiros. Não empregamos motoristas e não somos responsáveis pelo desempenho ou conduta de qualquer motorista durante o uso do serviço.',
          ),
          const SizedBox(height: 12),
          _buildParagraph(
            'Na máxima extensão permitida por lei, o KupON não será responsável por quaisquer danos indiretos, incidentais, especiais, consequenciais ou punitivos, ou por quaisquer perdas de lucros ou receitas, sejam incorridas direta ou indiretamente.',
          ),
        ],
      ),
    );
  }

  Widget _buildAccountTerminationSection() {
    return _buildSectionCard(
      icon: Icons.no_accounts,
      title: 'Cancelamento da Conta',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildParagraph(
            'O KupON reserva-se o direito de suspender ou encerrar sua conta a qualquer momento, com ou sem aviso prévio, por conduta que acredite violar estes Termos ou ser prejudicial a outros usuários do aplicativo, a nós, ou a terceiros, ou por qualquer outro motivo.',
          ),
          const SizedBox(height: 12),
          _buildParagraph(
            'Após o cancelamento, seu direito de usar o serviço cessará imediatamente. Se deseja encerrar sua conta, você pode simplesmente parar de usar o serviço ou entrar em contato com o suporte para exclusão formal.',
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required Widget content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
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
              Icon(icon, color: AppTheme.primaryContainer, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        height: 1.6,
        color: AppTheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildAgreementCheckbox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryContainer.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: _agreedToTerms,
              onChanged: (value) {
                setState(() {
                  _agreedToTerms = value ?? false;
                });
              },
              activeColor: AppTheme.primaryContainer,
              checkColor: Colors.black,
              side: BorderSide(color: AppTheme.outlineVariant, width: 1),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Concordo com os Termos e Condições',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
