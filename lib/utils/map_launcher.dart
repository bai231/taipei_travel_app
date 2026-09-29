import 'package:url_launcher/url_launcher.dart';
import '../models/place.dart';

class MapLauncher {
  /// 開啟 Google Maps 定位並導航至指定景點
  static Future<void> openGoogleMaps(Place place) async {
    final String query = Uri.encodeComponent('${place.name} ${place.address}');
    
    // 優先使用經緯度精確定位，若無則依名稱/地址搜尋
    final Uri googleMapsUrl = (place.latitude != 0.0 && place.longitude != 0.0)
        ? Uri.parse('https://www.google.com/maps/search/?api=1&query=${place.latitude},${place.longitude}')
        : Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');

    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(
        googleMapsUrl,
        mode: LaunchMode.externalApplication, // 強制以外部 Google Maps App 或瀏覽器開啟
      );
    } else {
      throw '無法開啟 Google Maps: $googleMapsUrl';
    }
  }
}