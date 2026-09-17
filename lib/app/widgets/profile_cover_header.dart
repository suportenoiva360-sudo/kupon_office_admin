import 'package:flutter/material.dart';
import 'package:kupon_office_admin/app/theme/app_theme.dart';

class ProfileMetaItem {
  final IconData icon;
  final String text;
  final bool highlight;

  const ProfileMetaItem({
    required this.icon,
    required this.text,
    this.highlight = false,
  });
}

class ProfileCoverHeader extends StatelessWidget {
  final String name;
  final String handle;
  final String? photoUrl;
  final VoidCallback onEdit;
  final List<ProfileMetaItem> meta;
  final Widget? avatarBadge;
  final bool verified;

  const ProfileCoverHeader({
    super.key,
    required this.name,
    required this.handle,
    required this.onEdit,
    this.photoUrl,
    this.meta = const [],
    this.avatarBadge,
    this.verified = true,
  });

  static const double _bannerHeight = 132;
  static const double _avatarSize = 88;
  static const double _overlap = 44;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: _bannerHeight + _overlap + 8,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: _bannerHeight,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primaryContainer.withValues(alpha: 0.85),
                        const Color(0xFF3A1F0A),
                        AppTheme.surfaceContainerHigh,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(left: 16, bottom: 8, child: _buildAvatar()),
              Positioned(right: 16, bottom: 12, child: _buildEditButton(tt)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
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
                      style: tt.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.onSurface,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  if (verified) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.verified_rounded,
                      size: 20,
                      color: AppTheme.primaryContainer,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                handle,
                style: tt.bodyMedium?.copyWith(
                  color: AppTheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: meta.map(_buildMeta).toList(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: _avatarSize,
          height: _avatarSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.surfaceContainerHigh,
            border: Border.all(color: AppTheme.surface, width: 4),
          ),
          child: ClipOval(
            child: photoUrl != null && photoUrl!.isNotEmpty
                ? Image.network(
                    photoUrl!,
                    fit: BoxFit.cover,
                    cacheWidth: 180,
                    cacheHeight: 180,
                    errorBuilder: (_, _, _) => _placeholder(),
                  )
                : _placeholder(),
          ),
        ),
        if (avatarBadge != null)
          Positioned(bottom: 2, right: 2, child: avatarBadge!),
      ],
    );
  }

  Widget _placeholder() {
    return ColoredBox(
      color: AppTheme.surfaceContainerHigh,
      child: Icon(
        Icons.person_rounded,
        color: AppTheme.onSurfaceVariant,
        size: 42,
      ),
    );
  }

  Widget _buildEditButton(TextTheme tt) {
    return GestureDetector(
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: AppTheme.primaryContainer, width: 1.2),
        ),
        child: Text(
          'Editar perfil',
          style: tt.labelLarge?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryContainer,
          ),
        ),
      ),
    );
  }

  Widget _buildMeta(ProfileMetaItem item) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(item.icon, size: 15, color: AppTheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          item.text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: item.highlight ? FontWeight.w600 : FontWeight.w400,
            color: item.highlight
                ? AppTheme.primaryContainer
                : AppTheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
