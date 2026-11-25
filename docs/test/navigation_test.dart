// Keeps the docs navigation, the markdown assets, the legacy redirects and
// web/sitemap.xml consistent.
//
// After changing DocNavigation, regenerate the sitemap with:
//   UPDATE_SITEMAP=1 flutter test test/navigation_test.dart

import 'dart:io';

import 'package:fledge_docs/app/router.dart';
import 'package:flutter_test/flutter_test.dart';

const _site = 'https://fledge-framework.dev';

String buildSitemap() {
  final buffer = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln('<!-- Generated from DocNavigation by test/navigation_test.dart.')
    ..writeln(
      '     Regenerate: UPDATE_SITEMAP=1 flutter test '
      'test/navigation_test.dart -->',
    )
    ..writeln('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">');
  void url(String location, String changefreq, String priority) {
    buffer
      ..writeln('  <url>')
      ..writeln('    <loc>$_site$location</loc>')
      ..writeln('    <changefreq>$changefreq</changefreq>')
      ..writeln('    <priority>$priority</priority>')
      ..writeln('  </url>');
  }

  url('/', 'weekly', '1.0');
  for (final (section, page) in DocNavigation.routedPages) {
    final first = section.pages.first == page;
    url(section.locationOf(page)!, 'monthly', first ? '0.9' : '0.8');
  }
  buffer.writeln('</urlset>');
  return buffer.toString();
}

void main() {
  test('every markdown page in the nav has an asset', () {
    for (final (section, page) in DocNavigation.markdownPages) {
      final file = File('assets/docs/${section.path}/${page.path}.md');
      expect(file.existsSync(), isTrue, reason: '${file.path} is missing');
    }
  });

  test('every markdown asset is in the nav', () {
    final routed = {
      for (final (section, page) in DocNavigation.markdownPages)
        'assets/docs/${section.path}/${page.path}.md',
    };
    final assets = Directory('assets/docs')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.md'))
        .map((f) => f.path.replaceAll(r'\', '/'));
    for (final asset in assets) {
      expect(routed, contains(asset), reason: '$asset is not in the nav');
    }
  });

  test('pubspec lists every markdown section as an asset directory', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final section in DocNavigation.sections.where((s) => s.isMarkdown)) {
      if (!section.pages.any((p) => p.externalUrl == null)) continue;
      expect(
        pubspec,
        contains('- assets/docs/${section.path}/'),
        reason: 'add assets/docs/${section.path}/ to flutter.assets',
      );
    }
  });

  test('page paths are unique within a section', () {
    for (final section in DocNavigation.sections) {
      final paths = section.pages.map((p) => p.path).toList();
      expect(paths.toSet(), hasLength(paths.length), reason: section.path);
    }
  });

  test('every legacy URL redirects to a page that exists', () {
    final locations = {
      for (final (section, page) in DocNavigation.routedPages)
        section.locationOf(page)!,
    };
    for (final MapEntry(:key, :value) in legacyRedirects.entries) {
      expect(locations, contains(value), reason: '$key -> $value');
      expect(docsRedirect(key), value);
    }
  });

  test('section roots and /docs redirect to a first page', () {
    expect(docsRedirect('/docs'), '/docs/getting-started/introduction');
    expect(docsRedirect('/docs/ecs'), '/docs/ecs/entities-components');
    expect(docsRedirect('/docs/networking/'), '/docs/networking/overview');
    expect(docsRedirect('/docs/ecs/queries'), isNull);
    expect(docsRedirect('/'), isNull);
  });

  test('web/sitemap.xml matches the nav', () {
    final file = File('web/sitemap.xml');
    final expected = buildSitemap();
    if (Platform.environment['UPDATE_SITEMAP'] == '1') {
      file.writeAsStringSync(expected);
    }
    expect(
      file.readAsStringSync(),
      expected,
      reason:
          'Regenerate: UPDATE_SITEMAP=1 flutter test '
          'test/navigation_test.dart',
    );
  });
}
