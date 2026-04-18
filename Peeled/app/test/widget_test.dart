import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peeled/core/theme/app_colors.dart';
import 'package:peeled/core/theme/app_theme.dart';
import 'package:peeled/shared/widgets/juicy_button.dart';

void main() {
  testWidgets('JuicyButton shows label and fires onPressed', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: JuicyButton(
              label: 'PEEL',
              primary: AppColors.coral,
              onPressed: () => tapped++,
            ),
          ),
        ),
      ),
    );
    expect(find.text('PEEL'), findsOneWidget);
    await tester.tap(find.text('PEEL'));
    await tester.pumpAndSettle();
    expect(tapped, 1);
  });

  testWidgets('JuicyButton disabled when onPressed is null', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(
            body: JuicyButton(
              label: 'PEEL',
              primary: AppColors.coral,
              onPressed: null,
            ),
          ),
        ),
      ),
    );
    final widget =
        tester.widget<JuicyButton>(find.byType(JuicyButton));
    expect(widget.onPressed, isNull);
  });
}
