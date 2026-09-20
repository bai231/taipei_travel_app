import 'package:flutter_test/flutter_test.dart';
import '../../lib/services/route_error_message.dart';

void main() {
  test('network failures do not expose URLs or credentials', () {
    final message = routeErrorMessage(
      Exception(
        'SocketException: Failed host lookup https://example.com?key=secret',
      ),
    );
    expect(message, contains('確認網路'));
    expect(message, isNot(contains('secret')));
    expect(message, isNot(contains('https://')));
  });
  test('unsupported platform is distinct from network failure', () {
    expect(routeErrorMessage(UnsupportedError('Web only')), contains('尚未支援'));
  });
}
