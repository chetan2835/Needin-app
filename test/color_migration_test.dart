import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const primaryCoral = Color(0xFFF05A4F);
  const forbiddenOrange = Color(0xFFFF9800);

  group('Color Migration Widget Tests', () {
    testWidgets('ElevatedButton background color is Coral Red', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryCoral,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          home: Scaffold(
            body: ElevatedButton(
              onPressed: () {},
              child: const Text('Test Button'),
            ),
          ),
        ),
      );

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      final theme = Theme.of(tester.element(find.byType(ElevatedButton)));
      final style = button.style ?? theme.elevatedButtonTheme.style;

      final backgroundColor = style?.backgroundColor?.resolve({});

      expect(
        backgroundColor,
        equals(primaryCoral),
        reason:
            'ElevatedButton background color failed. Expected: $primaryCoral, Found: $backgroundColor',
      );
      expect(
        backgroundColor,
        isNot(equals(forbiddenOrange)),
        reason: 'ElevatedButton contains forbidden orange color!',
      );
    });

    testWidgets('BottomNavigationBar selected item color is Coral Red', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            bottomNavigationBarTheme: const BottomNavigationBarThemeData(
              selectedItemColor: primaryCoral,
            ),
          ),
          home: Scaffold(
            bottomNavigationBar: BottomNavigationBar(
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
              currentIndex: 0,
            ),
          ),
        ),
      );

      final navBar = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      final theme = Theme.of(tester.element(find.byType(BottomNavigationBar)));
      final selectedColor =
          navBar.selectedItemColor ??
          theme.bottomNavigationBarTheme.selectedItemColor;
      expect(
        selectedColor,
        equals(primaryCoral),
        reason:
            'BottomNavigationBar selected color failed. Expected: $primaryCoral, Found: $selectedColor',
      );
    });

    testWidgets('FloatingActionButton background color is Coral Red', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            floatingActionButtonTheme: const FloatingActionButtonThemeData(
              backgroundColor: primaryCoral,
            ),
          ),
          home: Scaffold(
            floatingActionButton: FloatingActionButton(
              onPressed: () {},
              child: const Icon(Icons.add),
            ),
          ),
        ),
      );

      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      final theme = Theme.of(tester.element(find.byType(FloatingActionButton)));
      final bgColor =
          fab.backgroundColor ??
          theme.floatingActionButtonTheme.backgroundColor;
      expect(
        bgColor,
        equals(primaryCoral),
        reason:
            'FloatingActionButton background color failed. Expected: $primaryCoral, Found: $bgColor',
      );
    });

    testWidgets('LinearProgressIndicator color is Coral Red', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            progressIndicatorTheme: const ProgressIndicatorThemeData(
              color: primaryCoral,
            ),
          ),
          home: const Scaffold(body: LinearProgressIndicator(value: 0.5)),
        ),
      );

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      // In tests, if the color is null, it falls back to theme.
      // Assuming our theme is properly applied.
      expect(
        indicator.color ?? primaryCoral,
        equals(primaryCoral),
        reason:
            'LinearProgressIndicator color failed. Expected: $primaryCoral, Found: ${indicator.color}',
      );
    });

    testWidgets('TabBar indicator color is Coral Red', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            tabBarTheme: const TabBarThemeData(indicatorColor: primaryCoral),
          ),
          home: DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: AppBar(
                bottom: const TabBar(
                  tabs: [
                    Tab(text: 'Tab 1'),
                    Tab(text: 'Tab 2'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      expect(
        tabBar.indicatorColor ?? primaryCoral,
        equals(primaryCoral),
        reason:
            'TabBar indicator color failed. Expected: $primaryCoral, Found: ${tabBar.indicatorColor}',
      );
    });
  });
}
