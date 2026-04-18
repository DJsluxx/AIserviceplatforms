import 'package:flutter_test/flutter_test.dart';
import 'package:peeled/data/models/package_model.dart';

void main() {
  group('PackageModel', () {
    test('parses required fields and computes progress', () {
      final m = PackageModel.fromJson({
        'id': 'pkg1',
        'rarity': 'rare',
        'status': 'held',
        'total_layers': 10,
        'peeled_layers': 4,
        'hops': 2,
        'hold_deadline': '2026-06-01T00:00:00Z',
        'current_holder_id': 'u1',
      });
      expect(m.id, 'pkg1');
      expect(m.progress, 0.4);
      expect(m.isFinalLayerNext, false);
    });

    test('isFinalLayerNext true for peeledLayers == total-1', () {
      final m = PackageModel.fromJson({
        'id': 'pkg2',
        'rarity': 'mythic',
        'status': 'held',
        'total_layers': 5,
        'peeled_layers': 4,
        'hops': 1,
        'current_holder_id': 'u1',
      });
      expect(m.isFinalLayerNext, true);
      expect(m.progress, closeTo(0.8, 0.0001));
    });
  });

  test('InboxModel parses items', () {
    final m = InboxModel.fromJson({
      'concurrent_slots_used': 1,
      'max_concurrent_slots': 3,
      'items': [
        {
          'seconds_remaining': 12,
          'package': {
            'id': 'p1',
            'rarity': 'common',
            'status': 'held',
            'total_layers': 5,
            'peeled_layers': 0,
            'hops': 0,
            'current_holder_id': 'u1',
          }
        }
      ],
    });
    expect(m.items, hasLength(1));
    expect(m.items.first.secondsRemaining, 12);
  });
}
