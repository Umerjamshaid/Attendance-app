import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_icons.dart';
import '../../config/app_theme.dart';
import '../../config/ui_tokens.dart';
import '../../models/attendance_record_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/evidence_location_service.dart';
import '../profile/settings_layout.dart';

class AttendanceEvidenceScreen extends StatefulWidget {
  const AttendanceEvidenceScreen({super.key, required this.record});
  final AttendanceRecord record;
  @override
  State<AttendanceEvidenceScreen> createState() =>
      _AttendanceEvidenceScreenState();
}

class _AttendanceEvidenceScreenState extends State<AttendanceEvidenceScreen> {
  late Future<Map<String, dynamic>> _evidence = context
      .read<AuthProvider>()
      .backend!
      .evidence(widget.record.id);
  NetworkImage? _photo;
  void _reload() {
    _photo?.evict();
    final request = context.read<AuthProvider>().backend!.evidence(
      widget.record.id,
    );
    setState(() {
      _evidence = request;
    });
  }

  @override
  void dispose() {
    _photo?.evict();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SettingsLayout(
    title: 'Check-in evidence',
    children: [
      FutureBuilder(
        future: _evidence,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Column(
              children: [
                Text(snapshot.error.toString()),
                TextButton(onPressed: _reload, child: const Text('Retry')),
              ],
            );
          }
          final evidence = snapshot.data!;
          final url = evidence['photo_url'] as String;
          if (_photo?.url != url) _photo = NetworkImage(url);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Employee ${widget.record.userId}',
                style: AppTypography.title,
              ),
              const SizedBox(height: 16),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: context.colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.colors.outlineVariant),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Image(
                      image: _photo!,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                          ? child
                          : const Center(
                              child: SizedBox.square(
                                dimension: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                      errorBuilder: (_, _, _) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                AppIcons.camera,
                                color: context.colors.onSurfaceVariant,
                                size: 24,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Photo unavailable. Refresh to retry.',
                                textAlign: TextAlign.center,
                              ),
                              TextButton.icon(
                                onPressed: _reload,
                                icon: const Icon(AppIcons.refresh, size: 20),
                                label: const Text('Retry photo'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _EvidenceFact(
                icon: AppIcons.clock,
                label: 'Check-in time',
                value: widget.record.timestamp.toString(),
              ),
              const Divider(height: 24),
              _EvidenceLocation(
                latitude: switch (evidence['latitude']) {
                  num value => value.toDouble(),
                  _ => null,
                },
                longitude: switch (evidence['longitude']) {
                  num value => value.toDouble(),
                  _ => null,
                },
              ),
              Padding(
                padding: const EdgeInsets.only(left: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Latitude: ${evidence['latitude']}',
                      style: AppTypography.label,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Longitude: ${evidence['longitude']}',
                      style: AppTypography.label,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Accuracy: ${evidence['accuracy']} m',
                      style: AppTypography.caption.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 32),
              _EvidenceFact(
                icon: AppIcons.deviceMobile,
                label: 'Device',
                value: widget.record.device,
              ),
            ],
          );
        },
      ),
    ],
  );
}

class _EvidenceFact extends StatelessWidget {
  const _EvidenceFact({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Icon(
          icon,
          size: AppLayout.compactIconSize,
          color: context.colors.onSurfaceVariant,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTypography.body.copyWith(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    ],
  );
}

class _EvidenceLocation extends StatefulWidget {
  const _EvidenceLocation({required this.latitude, required this.longitude});
  final double? latitude;
  final double? longitude;

  @override
  State<_EvidenceLocation> createState() => _EvidenceLocationState();
}

class _EvidenceLocationState extends State<_EvidenceLocation>
    with WidgetsBindingObserver {
  late Locale _locale;
  late Future<EvidenceAddress> _address;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locale =
        WidgetsBinding.instance.platformDispatcher.locales.firstOrNull ??
        const Locale('en');
    _load();
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    final locale = locales?.firstOrNull ?? const Locale('en');
    if (!mounted || _locale == locale) return;
    setState(() {
      _locale = locale;
      _load();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(_EvidenceLocation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude) {
      _load();
    }
  }

  void _load({bool refresh = false}) {
    _address = context.read<EvidenceLocationService>().resolve(
      widget.latitude,
      widget.longitude,
      locale: _locale,
      refresh: refresh,
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(AppIcons.mapPin, size: AppLayout.compactIconSize),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Location', style: AppTypography.label),
              const SizedBox(height: 4),
              FutureBuilder<EvidenceAddress>(
                future: _address,
                builder: (context, snapshot) {
                  final loading =
                      snapshot.connectionState != ConnectionState.done;
                  final address =
                      snapshot.data ??
                      const EvidenceAddress(EvidenceAddressStatus.unavailable);
                  final message = switch (address.status) {
                    EvidenceAddressStatus.found => address.text!,
                    EvidenceAddressStatus.notFound =>
                      'No address found. Coordinates are shown below.',
                    EvidenceAddressStatus.invalid =>
                      'Invalid coordinates. Saved values are shown below.',
                    EvidenceAddressStatus.unsupported =>
                      'Address lookup is unavailable on this platform. Coordinates are shown below.',
                    _ => 'Address unavailable. Coordinates are shown below.',
                  };
                  return Semantics(
                    liveRegion: true,
                    child: AnimatedSwitcher(
                      duration: AppMotion.duration(context, AppMotion.fast),
                      switchInCurve: AppMotion.enterCurve,
                      switchOutCurve: AppMotion.exitCurve,
                      child: loading
                          ? Row(
                              key: const ValueKey('location-loading'),
                              children: [
                                const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Resolving location...',
                                    style: AppTypography.body.copyWith(
                                      color: context.colors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              key: ValueKey((address.status, address.text)),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SelectableText(
                                  message,
                                  style: AppTypography.body,
                                ),
                                if (address.status ==
                                        EvidenceAddressStatus.unavailable ||
                                    address.status ==
                                        EvidenceAddressStatus.notFound)
                                  TextButton(
                                    onPressed: () =>
                                        setState(() => _load(refresh: true)),
                                    child: const Text('Retry location'),
                                  ),
                              ],
                            ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
