/// Short, user-facing route errors. Never expose request URLs or credentials.
String routeErrorMessage(Object error) {
  final message = error.toString();
  if (message.contains('尚未設定 Android Routes')) {
    return '尚未設定手機路線金鑰，暫用估計時間。';
  }
  if (message.contains('Google Routes HTTP 403') ||
      message.contains('Google Routes HTTP 401')) {
    return 'Google 路線授權失敗，請檢查 Routes API、金鑰與 Android 限制。';
  }
  if (message.contains('Google Routes HTTP 429')) {
    return 'Google 路線額度或請求頻率受限，請稍後再試。';
  }
  if (error is UnsupportedError || message.contains('只支援 Web')) {
    return '此平台尚未支援此路線查詢，暫用估計時間。';
  }
  if (message.contains('Failed host lookup') ||
      message.contains('SocketException')) {
    return '無法連線至交通服務，請確認網路或切換 Wi-Fi／行動網路後重新查詢。暫用估計時間。';
  }
  if (message.contains('TimeoutException')) {
    return '交通服務回應逾時，請稍後再試。暫用估計時間。';
  }
  return '交通服務暫時無法提供路線，請稍後再試。暫用估計時間。';
}
