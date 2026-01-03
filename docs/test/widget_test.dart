import 'package:flutter_test/flutter_test.dart';

import 'package:fledge_docs/main.dart';

void main() {
  testWidgets('App builds successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const FledgeDocsApp());

    // Verify the app renders the title
    expect(find.text('Fledge'), findsOneWidget);
  });
}
