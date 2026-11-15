import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_icons.dart';
import '../../config/ui_tokens.dart';
import '../../models/office_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/office_provider.dart';
import 'office_switcher_sheet.dart';

class OfficeSelectorHeader extends StatelessWidget {
  const OfficeSelectorHeader({super.key});
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OfficeProvider?>();
    final employee = context.watch<AuthProvider?>()?.currentUser;
    final office =
        provider?.activeOffice ??
        Office(
          id: employee?.organizationId ?? 'local',
          name: employee?.officeName ?? 'Local office',
          role: employee?.role ?? 'employee',
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
            button: provider?.isSupported ?? false,
            label: 'Current office: ${office.name}',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: const ValueKey('office-selector'),
                borderRadius: BorderRadius.circular(8),
                onTap: provider?.isSupported == true
                    ? () => showOfficeSwitcher(context)
                    : null,
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
                      if (provider?.isSupported == true)
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
          if (provider?.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      provider!.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: provider.reload,
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
  });
  final Office office;
  final double size;
  final String fontFamily;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
    return SizedBox.square(
      dimension: size,
      child: ClipOval(
        child: ColoredBox(
          color: colors.surfaceContainerHighest,
          child: office.logoUrl == null
              ? initials
              : Image.network(
                  office.logoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => initials,
                ),
        ),
      ),
    );
  }
}
