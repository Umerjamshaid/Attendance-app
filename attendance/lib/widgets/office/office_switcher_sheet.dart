import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/app_icons.dart';
import '../../config/ui_tokens.dart';
import '../../providers/office_provider.dart';
import '../../screens/office/manage_offices_screen.dart';
import 'office_selector_header.dart';

Future<void> showOfficeSwitcher(BuildContext context) async {
  final offices = context.read<OfficeProvider>();
  unawaited(offices.reload());
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    barrierColor: Colors.black54,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppLayout.sheetRadius),
      ),
    ),
    sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (_) => ChangeNotifierProvider.value(
      value: offices,
      child: const OfficeSwitcherSheet(),
    ),
  );
}

class OfficeSwitcherSheet extends StatelessWidget {
  const OfficeSwitcherSheet({super.key});
  @override
  Widget build(BuildContext context) => Theme(
    data: AppTypography.themeOf(context),
    child: Builder(builder: _content),
  );

  Widget _content(BuildContext context) {
    final provider = context.watch<OfficeProvider>();
    final colors = Theme.of(context).colorScheme;
    void manage() {
      final navigator = Navigator.of(context);
      navigator.pop();
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => const ManageOfficesScreen()),
      );
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .58,
      minChildSize: .32,
      maxChildSize: .9,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Switch Office', style: AppTypography.title),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(AppIcons.x),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (provider.isLoading && provider.offices.isEmpty)
            const Center(child: CircularProgressIndicator()),
          if (provider.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                provider.error!,
                style: TextStyle(color: colors.error),
              ),
            ),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = (constraints.maxWidth / 124).floor().clamp(1, 4);
              final width = math.min(
                140.0,
                (constraints.maxWidth - (columns - 1) * 12) / columns,
              );
              return Wrap(
                spacing: 12,
                runSpacing: 24,
                alignment: WrapAlignment.spaceEvenly,
                children: [
                  for (final office in provider.offices)
                    SizedBox(
                      width: width,
                      child: Semantics(
                        button: true,
                        selected: office.id == provider.activeOfficeId,
                        label: office.name,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: provider.isSwitching
                              ? null
                              : () {
                                  HapticFeedback.selectionClick();
                                  Navigator.pop(context);
                                  if (office.id != provider.activeOfficeId) {
                                    unawaited(provider.switchOffice(office.id));
                                  }
                                },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    OfficeAvatar(office: office),
                                    if (office.id == provider.activeOfficeId)
                                      Positioned(
                                        right: -1,
                                        bottom: -1,
                                        child: Container(
                                          padding: const EdgeInsets.all(5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF018044),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: colors.surface,
                                              width: 3,
                                            ),
                                          ),
                                          child: const Icon(
                                            AppIcons.check,
                                            size: 18,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  office.name,
                                  textAlign: TextAlign.center,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  SizedBox(
                    width: width,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: manage,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          children: [
                            Container(
                              width: 104,
                              height: 104,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colors.surfaceContainerHighest,
                              ),
                              child: const Icon(AppIcons.plus, size: 32),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Add Office',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          if (provider.canManage)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: TextButton.icon(
                onPressed: manage,
                icon: const Icon(AppIcons.settings, size: 20),
                label: const Text('Manage Offices'),
              ),
            ),
          if (provider.invitations.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: TextButton(
                onPressed: manage,
                child: Text(
                  '${provider.invitations.length} pending office invitation(s)',
                ),
              ),
            ),
        ],
      ),
    );
  }
}
