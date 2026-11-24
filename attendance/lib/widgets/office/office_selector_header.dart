import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_icons.dart';
import '../../config/ui_tokens.dart';
import '../../models/office_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/office_provider.dart';
import '../profile_image.dart';
import 'office_switcher_sheet.dart';

class OfficeSelectorHeader extends StatelessWidget {
  const OfficeSelectorHeader({super.key});
  @override
  Widget build(BuildContext context) {
    final (activeOffice, supported, error) = context.select(
      (OfficeProvider? provider) => (
        provider?.activeOffice,
        provider?.isSupported ?? false,
        provider?.error,
      ),
    );
    final (officeId, officeName, role) = context.select((AuthProvider? auth) {
      final employee = auth?.currentUser;
      return (employee?.organizationId, employee?.officeName, employee?.role);
    });
    final office =
        activeOffice ??
        Office(
          id: officeId ?? 'local',
          name: officeName ?? 'Local office',
          role: role ?? 'employee',
        );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppLayout.gutter,
        vertical: 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: supported,
            label: 'Current office: ${office.name}',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: const ValueKey('office-selector'),
                borderRadius: BorderRadius.circular(8),
                onTap: supported ? () => showOfficeSwitcher(context) : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      OfficeAvatar(office: office, size: 48),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          office.name,
                          style: AppTypography.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (supported)
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(AppIcons.chevronDown, size: 20),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.read<OfficeProvider>().reload(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class OfficeAvatar extends StatelessWidget {
  const OfficeAvatar({
    super.key,
    required this.office,
    this.size = 104,
    this.fontFamily = AppTypography.fontFamily,
    this.outlineLogo = false,
  });
  final Office office;
  final double size;
  final String fontFamily;
  final bool outlineLogo;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (viewer, backend) = context.select(
      (AuthProvider? auth) =>
          (auth?.currentUser?.authUserId, auth?.accountBackend),
    );
    final initials = Center(
      child: Text(
        office.initials,
        maxLines: 1,
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: size > 60 ? 32 : 18,
          fontWeight: FontWeight.w600,
          color: colors.onSurface,
        ),
      ),
    );
    final logo = office.logoUrl;
    final image = logo == null
        ? null
        : profileImageProvider(
            logo,
            viewer: viewer,
            office: office.id,
            width: 240,
            refresh: backend?.refreshOfficeLogo,
          );
    final avatar = ClipOval(
      child: ColoredBox(
        color: colors.surfaceContainerHighest,
        child: image == null
            ? initials
            : Image(
                key: ValueKey(profileImageIdentity(logo!, viewer: viewer)),
                image: image,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                frameBuilder: profileImageFrame(initials),
                errorBuilder: (_, _, _) => initials,
              ),
      ),
    );
    return SizedBox.square(
      dimension: size,
      child: outlineLogo && image != null
          ? DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.outlineVariant,
              ),
              child: Padding(padding: const EdgeInsets.all(2), child: avatar),
            )
          : avatar,
    );
  }
}
