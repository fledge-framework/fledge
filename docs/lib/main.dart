import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app/router.dart';
import 'app/theme.dart';

void main() {
  // Use path-based URLs instead of hash-based (e.g., /docs/guides instead of /#/docs/guides)
  usePathUrlStrategy();
  runApp(const FledgeDocsApp());
}

class FledgeDocsApp extends StatelessWidget {
  const FledgeDocsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Fledge Documentation',
      debugShowCheckedModeBanner: false,
      theme: FledgeTheme.light,
      darkTheme: FledgeTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
