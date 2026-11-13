import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_provider.dart';
import '../../providers/attendance_history_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/office_provider.dart';
import '../../services/attendance_service.dart';
import '../../services/employees_service.dart';
import '../../services/evidence_location_service.dart';

/// Account-level access to the current office navigator without retaining old routes.
class OfficeNavigatorController {
  GlobalKey<NavigatorState>? _key;
  NavigatorState? get navigator => _key?.currentState;
  void attach(GlobalKey<NavigatorState> key) => _key = key;
  void detach(GlobalKey<NavigatorState> key) {
    if (identical(_key, key)) _key = null;
  }
}

/// Keeps office routes disposable while account-level switcher routes stay mounted.
class OfficeScope extends StatelessWidget {
  const OfficeScope({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final backend = auth.backend;
    return MultiProvider(
      key: ValueKey(auth.officeScopeKey),
      providers: [
        Provider(
          create: (_) => EvidenceLocationService(),
          dispose: (_, service) => service.dispose(),
        ),
        ChangeNotifierProvider(
          create: (_) => AttendanceProvider(backend: backend),
        ),
        ChangeNotifierProvider(
          create: (_) => AttendanceHistoryProvider(
            service: AttendanceService(backend: backend),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => AdminProvider(
            attendanceService: AttendanceService(backend: backend),
            employeeService: EmployeeService(backend: backend),
          ),
        ),
      ],
      child: _OfficeNavigator(child: child),
    );
  }
}

class _OfficeNavigator extends StatefulWidget {
  const _OfficeNavigator({required this.child});
  final Widget child;
  @override
  State<_OfficeNavigator> createState() => _OfficeNavigatorState();
}

class _OfficeNavigatorState extends State<_OfficeNavigator> {
  final _navigator = GlobalKey<NavigatorState>();
  final _heroes = MaterialApp.createMaterialHeroController();
  OfficeNavigatorController? _navigation;
  @override
  void initState() {
    super.initState();
    _navigation = context.read<OfficeNavigatorController?>();
    _navigation?.attach(_navigator);
  }

  @override
  void dispose() {
    _navigation?.detach(_navigator);
    _heroes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final switching = context.watch<OfficeProvider?>()?.isSwitching ?? false;
    return Stack(
      children: [
        ExcludeSemantics(
          excluding: switching,
          child: AbsorbPointer(
            absorbing: switching,
            child: NavigatorPopHandler<Object?>(
              onPopWithResult: (result) => _navigator.currentState!.pop(result),
              child: HeroControllerScope(
                controller: _heroes,
                child: Navigator(
                  key: _navigator,
                  onGenerateRoute: (settings) => MaterialPageRoute<void>(
                    settings: settings,
                    builder: (_) => widget.child,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (switching)
          Positioned.fill(
            child: ColoredBox(
              key: const ValueKey('office-loading-overlay'),
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Center(
                child: Semantics(
                  label: 'Loading office',
                  child: const CircularProgressIndicator(),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
