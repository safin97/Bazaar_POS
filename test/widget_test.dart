import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Bazaar_POS/data/pos_store.dart';
import 'package:Bazaar_POS/main.dart';

void main() {
  testWidgets('First run only offers username and password sign-in', (
    tester,
  ) async {
    final store = PosStore.memory();
    addTearDown(store.dispose);
    await tester.pumpWidget(BazaarApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.byKey(const ValueKey('login-submit')), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.byKey(const ValueKey('login-username')), findsOneWidget);
    expect(find.byKey(const ValueKey('login-password')), findsOneWidget);
    expect(find.text('Create my store'), findsNothing);
    expect(find.text('Full name'), findsNothing);
    expect(find.text('Confirm password'), findsNothing);
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(store.currentUser, isNull);
    expect(store.needsSetup, isFalse);
  });

  testWidgets('Login validates both fields and keeps passwords obscured', (
    tester,
  ) async {
    final store = PosStore.memory();
    addTearDown(store.dispose);
    await tester.pumpWidget(BazaarApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('This field is required'), findsNWidgets(2));
    final field = find.descendant(
      of: find.byKey(const ValueKey('login-password')),
      matching: find.byType(EditableText),
    );
    expect(tester.widget<EditableText>(field).obscureText, isTrue);
    expect(store.currentUser, isNull);
  });
}
