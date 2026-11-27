import 'package:fledge_net/fledge_net.dart';
import 'package:test/test.dart';

void main() {
  test('total counts every bump across chunks', () {
    final versions = ChunkVersions();
    expect(versions.total, 0);
    versions
      ..bump(3)
      ..bump(0)
      ..bump(3);
    expect(versions.of(3), 2);
    expect(versions.total, 3);
    versions.bumpAll(4);
    expect(versions.total, 7);
  });
}
