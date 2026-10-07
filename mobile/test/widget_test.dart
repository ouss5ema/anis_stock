import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_management/app.dart';

void main() {
  testWidgets('app boots into splash or login', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: StockApp()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            (widget.data == 'anis_stock' || widget.data == 'Connexion'),
      ),
      findsWidgets,
    );
  });
}
