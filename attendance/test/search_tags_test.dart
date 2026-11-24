import 'dart:async';

import 'package:attendance/config/app_theme.dart';
import 'package:attendance/models/employees_model.dart';
import 'package:attendance/models/office_model.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/providers/office_provider.dart';
import 'package:attendance/screens/admin/employee_management_screen.dart';
import 'package:attendance/screens/office/manage_offices_screen.dart';
import 'package:attendance/screens/office/office_roles_screen.dart';
import 'package:attendance/screens/profile/profile_details_screen.dart';
import 'package:attendance/services/company_backend.dart';
import 'package:attendance/services/preview_company_backend.dart';
import 'package:attendance/widgets/admin/employee_discovery_bar.dart';
import 'package:attendance/widgets/office/office_role_sheet.dart';
import 'package:attendance/widgets/user-profile/profile_tag_selection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_fonts.dart';

final _alice = Employee(
  id: 'EMP001',
  name: 'Alice Johnson',
  email: 'alice@example.invalid',
  department: 'Engineering',
  role: 'admin',
  time: '',
  chips: const ['Design'],
);
final _sam = Employee(
  id: 'EMP002',
  name: 'Sam Lee',
  email: 'sam@example.invalid',
  department: 'Product',
  role: 'employee',
  time: '',
  isActive: false,
);

class _Backend extends PreviewCompanyBackend {
  List<Employee> roster = [_alice, _sam];
  Office? office;
  int reads = 0;
  final writes = <(String, bool)>[];
  final removals = <String>[];
  final reinvites = <String>[];
  bool failRead = false;
  @override
  bool get isPreview => false;
  @override
  CompanyBackend forOffice(Employee employee) => this;
  @override
  Future<Employee?> restoreSession() async => office == null
      ? _alice
      : _alice.copyWith(authUserId: 'current-user', organizationId: office!.id);
  @override
  Future<List<Office>> offices() async => [?office];
  @override
  Future<List<Employee>> employees() async {
    reads++;
    if (failRead) throw const CompanyException('Roster unavailable');
    return roster;
  }

  @override
  Future<void> setEmployeeActive(String id, bool active) async {
    writes.add((id, active));
    roster = [
      for (final employee in roster)
        employee.id == id
            ? Employee.fromMap({...employee.toMap(), 'isActive': active})
            : employee,
    ];
  }

  @override
  Future<void> removeOfficeEmployee(String id) async {
    removals.add(id);
    roster = [
      for (final employee in roster)
        employee.id == id
            ? employee.copyWith(isActive: false, isRemoved: true)
            : employee,
    ];
  }

  @override
  Future<String> reinviteRemovedEmployee(String id) async {
    reinvites.add(id);
    return 'ABCD EFGH JKLM NPQR';
  }
}

class _ProfileAuth extends AuthProvider {
  final saves = <List<String>>[];
  bool fail = false;
  Completer<void>? pending;
  @override
  Future<void> updateProfile({
    String? name,
    String? email,
    String? headline,
    List<String>? chips,
  }) async {
    saves.add([...chips!]);
    if (pending != null) await pending!.future;
    if (fail) throw const CompanyException('Try again');
  }
}

const _searchInput = ValueKey('employee-search-input');
Finder _tag(String value, {bool selected = false}) =>
    find.widgetWithText(selected ? InputChip : ActionChip, value);
Finder get _save => find.widgetWithText(FilledButton, 'Save changes');

void main() {
  setUpAll(loadTestFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    AuthProvider? auth,
    OfficeProvider? offices,
    bool dark = false,
    double width = 390,
    double scale = 1,
    bool reducedMotion = false,
    TextDirection direction = TextDirection.ltr,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 844);
    addTearDown(tester.view.reset);
    if (auth != null) addTearDown(auth.dispose);
    if (offices != null) addTearDown(offices.dispose);
    final app = MaterialApp(
      theme: dark ? AppTheme.darkTheme : AppTheme.theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: reducedMotion,
        ),
        child: Directionality(textDirection: direction, child: child!),
      ),
      home: child,
    );
    await tester.pumpWidget(
      auth == null
          ? app
          : MultiProvider(
              providers: [
                ChangeNotifierProvider<AuthProvider>.value(value: auth),
                if (offices != null)
                  ChangeNotifierProvider<OfficeProvider>.value(value: offices),
              ],
              child: app,
            ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openSearch(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Search employees'));
    await tester.pumpAndSettle();
  }

  Future<(AuthProvider, OfficeProvider)> officeSession(
    _Backend backend, {
    required bool owner,
  }) async {
    backend.office = Office(
      id: 'office-a',
      name: 'Studio',
      role: 'admin',
      createdBy: owner ? 'current-user' : 'another-user',
    );
    backend.roster = [
      _alice.copyWith(authUserId: 'current-user'),
      _sam.copyWith(authUserId: 'another-employee'),
    ];
    final auth = AuthProvider(backend: backend);
    await auth.refreshSession();
    return (auth, OfficeProvider(auth));
  }

  testWidgets('live employee search matches all fields without new requests', (
    tester,
  ) async {
    final backend = _Backend();
    await mount(
      tester,
      const EmployeeManagementScreen(),
      auth: AuthProvider(backend: backend),
    );
    expect(find.byKey(_searchInput), findsNothing);
    expect(tester.testTextInput.isVisible, isFalse);
    expect(find.byType(ListTile), findsNWidgets(2));
    await openSearch(tester);
    expect(tester.testTextInput.isVisible, isTrue);
    for (final query in [
      ' ALICE ',
      'emp001',
      'engineering',
      'alice@example.invalid',
      'johnson engineering',
    ]) {
      await tester.enterText(find.byKey(_searchInput), query);
      await tester.pump();
      expect(find.widgetWithText(ListTile, 'Alice Johnson'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Sam Lee'), findsNothing);
    }
    await tester.enterText(find.byKey(_searchInput), 'not-found');
    await tester.pump();
    expect(find.text('No employees found'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byKey(_searchInput)).controller!.text,
      '',
    );
    expect(find.byType(ListTile), findsNWidgets(2));
    expect(backend.reads, 1);
    expect(backend.writes, isEmpty);
  });

  testWidgets(
    'removed employees stay off the current roster and receive a new code',
    (tester) async {
      final backend = _Backend();
      await mount(
        tester,
        const EmployeeManagementScreen(),
        auth: AuthProvider(backend: backend),
      );
      expect(find.byType(Switch), findsNothing);
      await tester.tap(find.text('Removed'));
      await tester.pumpAndSettle();
      expect(find.text('No removed employees'), findsOneWidget);
      await openSearch(tester);
      await tester.enterText(find.byKey(_searchInput), 'sam');
      await tester.pump();
      expect(find.text('No employees found'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(find.byKey(_searchInput), findsOneWidget);
      expect(find.text('No removed employees'), findsOneWidget);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.tap(find.byTooltip('Close search'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Current'));
      await tester.pumpAndSettle();
      expect(find.text('Sam Lee'), findsOneWidget);
      for (final cancel in [true, false]) {
        await tester.tap(find.text('Sam Lee'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Remove from office'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Past check-ins stay on record'),
          findsOneWidget,
        );
        await tester.tap(find.text(cancel ? 'Cancel' : 'Remove from office'));
        await tester.pumpAndSettle();
        expect(backend.removals, cancel ? [] : ['EMP002']);
      }
      expect(find.text('Sam Lee'), findsNothing);
      expect(backend.reads, 2);
      await tester.tap(find.text('Removed'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sam Lee'));
      await tester.pumpAndSettle();
      expect(find.text('Restore access'), findsNothing);
      await tester.tap(find.text('Reinvite'));
      await tester.pumpAndSettle();
      expect(find.text('Office code ready'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('reveal_copy_action_button')),
        findsOneWidget,
      );
      expect(find.text('ABCD EFGH JKLM NPQR'), findsNothing);
      expect(backend.reinvites, ['EMP002']);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Sam Lee'), findsOneWidget);
      expect(backend.writes, isEmpty);
      expect(backend.reads, 2);
      await tester.tap(find.byTooltip('Invite employee'));
      await tester.pumpAndSettle();
      expect(find.byType(InviteEmployeeScreen), findsOneWidget);
    },
  );

  for (final owner in [true, false]) {
    testWidgets('Manage Offices shows Roles beside Employees: owner=$owner', (
      tester,
    ) async {
      final (auth, offices) = await officeSession(_Backend(), owner: owner);
      await mount(
        tester,
        const ManageOfficesScreen(),
        auth: auth,
        offices: offices,
      );

      expect(find.text('Employees'), findsOneWidget);
      final roles = find.ancestor(
        of: find.text('Roles'),
        matching: find.byWidgetPredicate((widget) => widget is TextButton),
      );
      expect(
        tester.widget<TextButton>(roles).onPressed,
        owner ? isNotNull : isNull,
      );
      if (owner) {
        await tester.tap(roles);
        await tester.pumpAndSettle();
        expect(find.byType(OfficeRolesScreen), findsOneWidget);
      } else {
        expect(
          find.text('Only the office owner can change roles.'),
          findsOneWidget,
        );
      }
    });

    testWidgets(
      'Employees shows Roles only to the active office owner: $owner',
      (tester) async {
        final backend = _Backend();
        final (auth, offices) = await officeSession(backend, owner: owner);
        await mount(
          tester,
          const EmployeeManagementScreen(),
          auth: auth,
          offices: offices,
        );
        final shortcut = find.byTooltip('Roles');
        expect(shortcut, owner ? findsOneWidget : findsNothing);
        if (!owner) return;
        await tester.tap(shortcut);
        await tester.pumpAndSettle();
        expect(find.byType(OfficeRolesScreen), findsOneWidget);
        await tester.tap(find.text('Employee'));
        await tester.pumpAndSettle();
        expect(find.byType(OfficeRoleSheet), findsOneWidget);
        expect(backend.writes, isEmpty);
      },
    );
  }

  testWidgets('paused access can still be restored without a new invitation', (
    tester,
  ) async {
    final backend = _Backend();
    await mount(
      tester,
      const EmployeeManagementScreen(),
      auth: AuthProvider(backend: backend),
    );
    await tester.tap(find.text('Alice Johnson'));
    await tester.pumpAndSettle();
    expect(find.text('Remove from office'), findsNothing);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sam Lee'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore access'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore access'));
    await tester.pumpAndSettle();
    expect(backend.writes, [('EMP002', true)]);
    expect(backend.reinvites, isEmpty);
    expect(find.textContaining('Paused'), findsNothing);
    expect(find.text('Sam Lee'), findsOneWidget);
  });

  testWidgets('employee loading failure still retries the existing fetch', (
    tester,
  ) async {
    final backend = _Backend()..failRead = true;
    await mount(
      tester,
      const EmployeeManagementScreen(),
      auth: AuthProvider(backend: backend),
    );
    expect(find.textContaining('Roster unavailable'), findsOneWidget);
    backend.failRead = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsNWidgets(2));
    expect(backend.reads, 2);
  });

  testWidgets('tag toggling is controlled, reversible and saves custom tags', (
    tester,
  ) async {
    final auth = _ProfileAuth();
    await mount(tester, ProfileDetailsScreen(user: _alice), auth: auth);
    expect(tester.widget<FilledButton>(_save).onPressed, isNull);
    await tester.tap(_tag('Mentor'));
    await tester.pumpAndSettle();
    expect(_tag('Mentor', selected: true), findsOneWidget);
    expect(tester.widget<FilledButton>(_save).onPressed, isNotNull);
    await tester.tap(find.byTooltip('Remove Mentor'));
    await tester.pumpAndSettle();
    expect(_tag('Mentor'), findsOneWidget);
    expect(tester.widget<FilledButton>(_save).onPressed, isNull);
    final field = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == 'Add a tag',
    );
    await tester.enterText(field, 'design, Custom skill');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Add tag'));
    await tester.tap(find.byTooltip('Add tag'));
    await tester.pumpAndSettle();
    expect(find.byType(InputChip), findsNWidgets(2));
    await tester.ensureVisible(find.byTooltip('Remove Custom skill'));
    await tester.tap(find.byTooltip('Remove Custom skill'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(_tag('Custom skill'));
    await tester.tap(_tag('Custom skill'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(_save);
    await tester.tap(_save);
    await tester.pumpAndSettle();
    expect(auth.saves.single, ['Design', 'Custom skill']);
  });

  testWidgets('tag capacity prevents suggestions but still allows removal', (
    tester,
  ) async {
    final auth = _ProfileAuth();
    await mount(
      tester,
      ProfileDetailsScreen(
        user: _alice.copyWith(chips: List.generate(12, (i) => 'Tag $i')),
      ),
      auth: auth,
    );
    expect(tester.widget<ActionChip>(_tag('Mentor')).onPressed, isNull);
    await tester.ensureVisible(find.byTooltip('Remove Tag 0'));
    await tester.tap(find.byTooltip('Remove Tag 0'));
    await tester.pumpAndSettle();
    expect(tester.widget<ActionChip>(_tag('Mentor')).onPressed, isNotNull);
    await tester.ensureVisible(_tag('Mentor'));
    await tester.tap(_tag('Mentor'));
    await tester.pumpAndSettle();
    expect(find.byType(InputChip), findsNWidgets(12));
    expect(tester.widget<ActionChip>(_tag('Teamwork')).onPressed, isNull);
  });

  testWidgets(
    'tag save failure is inline and saving disables both tag groups',
    (tester) async {
      final auth = _ProfileAuth()
        ..fail = true
        ..pending = Completer<void>();
      await mount(tester, ProfileDetailsScreen(user: _alice), auth: auth);
      await tester.tap(_tag('Mentor'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(_save);
      await tester.tap(_save);
      await tester.pump();
      expect(
        tester.widget<InputChip>(_tag('Design', selected: true)).onDeleted,
        isNull,
      );
      expect(tester.widget<ActionChip>(_tag('Teamwork')).onPressed, isNull);
      auth.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Could not save changes. Try again.'), findsOneWidget);
      expect(tester.widget<ActionChip>(_tag('Teamwork')).onPressed, isNotNull);
      expect(auth.saves.single, ['Design', 'Mentor']);
    },
  );

  testWidgets('new tag selection keeps the existing discard confirmation', (
    tester,
  ) async {
    final auth = _ProfileAuth();
    await mount(tester, const Scaffold(body: Text('Profile')), auth: auth);
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push<void>(
          MaterialPageRoute(builder: (_) => ProfileDetailsScreen(user: _alice)),
        );
    await tester.pumpAndSettle();
    await tester.tap(_tag('Mentor'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(_tag('Mentor', selected: true), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileDetailsScreen), findsNothing);
    expect(auth.saves, isEmpty);
  });

  for (final dark in [false, true]) {
    testWidgets('employee roster preview ${dark ? "dark" : "light"}', (
      tester,
    ) async {
      final (auth, offices) = await officeSession(_Backend(), owner: true);
      await mount(
        tester,
        const EmployeeManagementScreen(),
        auth: auth,
        offices: offices,
        dark: dark,
      );
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile(
          'goldens/employee_search_${dark ? "dark" : "light"}.png',
        ),
      );
    });
    testWidgets('profile tag screen preview ${dark ? "dark" : "light"}', (
      tester,
    ) async {
      await mount(
        tester,
        ProfileDetailsScreen(user: _alice),
        auth: _ProfileAuth(),
        dark: dark,
      );
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile(
          'goldens/tag_selection_${dark ? "dark" : "light"}.png',
        ),
      );
    });
    testWidgets(
      'component preview ${dark ? "dark" : "light"} and selection motion',
      (tester) async {
        var tags = <String>['Design'];
        var query = '';
        var filter = EmployeeAccessFilter.all;
        await mount(
          tester,
          Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: StatefulBuilder(
                  builder: (context, update) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Employees',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 20),
                      EmployeeDiscoveryBar(
                        query: query,
                        filter: filter,
                        onQueryChanged: (v) => update(() => query = v),
                        onFilterChanged: (v) => update(() => filter = v),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Profile details',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 20),
                      ProfileTagSelection(
                        choices: const [
                          'Design',
                          'Teamwork',
                          'Mentor',
                          'Communication',
                        ],
                        selected: tags,
                        onToggle: (tag) => update(() {
                          tags = tags.contains(tag)
                              ? tags.where((value) => value != tag).toList()
                              : [...tags, tag];
                        }),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          dark: dark,
        );
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile(
            'goldens/search_tags_${dark ? "dark" : "light"}.png',
          ),
        );
        final key = find.byKey(const ValueKey('profile-tag:mentor'));
        final before = tester.getTopLeft(key);
        await tester.tap(_tag('Mentor'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        expect(tester.getTopLeft(key), isNot(before));
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();
        expect(_tag('Mentor', selected: true), findsOneWidget);
        final search = find.byKey(_searchInput);
        final bounds = tester.getRect(search);
        await tester.tap(search);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        expect(tester.getRect(search), bounds);
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      '320dp, large text, RTL and reduced motion ${dark ? "dark" : "light"}',
      (tester) async {
        await mount(
          tester,
          const EmployeeManagementScreen(),
          auth: AuthProvider(backend: _Backend()),
          width: 320,
          scale: 2,
          direction: TextDirection.rtl,
          dark: dark,
          reducedMotion: true,
        );
        await openSearch(tester);
        expect(tester.testTextInput.isVisible, isTrue);
        expect(find.text('Removed').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await mount(
          tester,
          ProfileDetailsScreen(user: _alice.copyWith(chips: ['A' * 40])),
          auth: _ProfileAuth(),
          width: 320,
          scale: 2,
          direction: TextDirection.rtl,
          dark: dark,
          reducedMotion: true,
        );
        for (final animated in tester.widgetList<AnimatedPositioned>(
          find.byType(AnimatedPositioned),
        )) {
          expect(animated.duration, Duration.zero);
        }
        await tester.ensureVisible(_tag('Teamwork'));
        await tester.tap(_tag('Teamwork'));
        await tester.pumpAndSettle();
        expect(_tag('Teamwork', selected: true), findsOneWidget);
        await tester.ensureVisible(_save);
        expect(_save.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
