import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/domain.dart';

void main() {
  group('Domain model', () {
    test('copyWith updates properties', () {
      const domain = Domain(id: 1, name: 'Test', url: 'https://test.com');
      final updated = domain.copyWith(name: 'Updated');

      expect(updated.id, 1);
      expect(updated.name, 'Updated');
      expect(updated.url, 'https://test.com');
    });

    test('toMap and fromMap work correctly', () {
      const domain = Domain(id: 1, name: 'Test', url: 'https://test.com');
      final map = domain.toMap();
      final fromMap = Domain.fromMap(map);

      expect(fromMap.id, domain.id);
      expect(fromMap.name, domain.name);
      expect(fromMap.url, domain.url);
    });
  });
}
