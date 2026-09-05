import 'package:flutter_test/flutter_test.dart';
import 'package:taipei_travel_app/app.dart';

void main() {
  test('TravelApp can be constructed without mounting external services', () {
    expect(const TravelApp(), isA<TravelApp>());
  });
}
