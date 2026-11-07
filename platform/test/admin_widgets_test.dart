import 'package:aidvise_platform/admin/plans_screen.dart';
import 'package:aidvise_platform/admin/admin_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('formatPlanPrice', () {
    test('ringgit shown as RM with two decimals', () {
      expect(formatPlanPrice({'currency': 'MYR', 'app_store_price': 9.9}, 'app_store_price'), 'RM 9.90');
    });
    test('other currencies show their code', () {
      expect(formatPlanPrice({'currency': 'SGD', 'play_store_price': 3}, 'play_store_price'), 'SGD 3.00');
    });
    test('missing price reads as not set', () {
      expect(formatPlanPrice({'currency': 'MYR'}, 'app_store_price'), 'Not set');
    });
  });

  test('quota metrics have readable names, unknown ones degrade gracefully', () {
    expect(adminMetricLabel('chat_messages_per_day'), 'Advisor chats per day');
    expect(adminMetricLabel('new_metric_per_week'), 'new metric per week');
  });

  testWidgets('filter chips report the chosen value, including All (null)', (tester) async {
    String? chosen = 'vendor';
    await tester.pumpWidget(_host(AdminFilterChips<String>(
      options: const [(null, 'All'), ('vendor', 'Employers')],
      selected: chosen,
      onSelected: (v) => chosen = v,
    )));
    await tester.tap(find.text('All'));
    expect(chosen, isNull);
  });

  testWidgets('confirm dialog: only an explicit confirm returns true', (tester) async {
    bool? result;
    await tester.pumpWidget(_host(Builder(
      builder: (context) => TextButton(
        onPressed: () async => result = await confirmAdminAction(context,
            title: 'Hide this listing?', message: 'm', confirmLabel: 'Hide', danger: true),
        child: const Text('open'),
      ),
    )));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isFalse);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hide'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('list state shows error with retry, then empty text, then content', (tester) async {
    var retried = false;
    Widget state({String? error, bool empty = false}) => _host(AdminListState(
          loading: false,
          error: error,
          empty: empty,
          emptyText: 'No users match.',
          onRetry: () => retried = true,
          child: const Text('rows'),
        ));

    await tester.pumpWidget(state(error: 'Could not load users.'));
    expect(find.text('Could not load users.'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retried, isTrue);

    await tester.pumpWidget(state(empty: true));
    expect(find.text('No users match.'), findsOneWidget);

    await tester.pumpWidget(state());
    expect(find.text('rows'), findsOneWidget);
  });
}
