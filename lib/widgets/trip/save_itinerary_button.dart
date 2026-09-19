import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/route_planning/models/route_itinerary.dart';
import '../../services/itinerary_snapshot.dart';
import '../../services/saved_itinerary_service.dart';

class SaveItineraryButton extends StatefulWidget {
  final RouteItinerary itinerary;
  final bool enabled;
  final SavedItineraryGateway? gateway;
  const SaveItineraryButton({
    super.key,
    required this.itinerary,
    this.enabled = true,
    this.gateway,
  });
  @override
  State<SaveItineraryButton> createState() => _SaveItineraryButtonState();
}

class _SaveItineraryButtonState extends State<SaveItineraryButton> {
  final _idsByUser = <String, String>{};
  bool _saving = false;

  Future<void> _save() async {
    if (_saving || !widget.enabled) return;
    void message(String text) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(text)));
      }
    }

    try {
      final gateway =
          widget.gateway ?? SavedItineraryService(Supabase.instance.client);
      final userId = gateway.currentUserId;
      if (userId == null) {
        message('請先登入，再儲存行程');
        return;
      }
      setState(() => _saving = true);
      final random = Random.secure();
      final id = _idsByUser.putIfAbsent(
        userId,
        () => List.generate(
          16,
          (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join(),
      );
      // Capture a detached snapshot at click time, not after network completion.
      final snapshot =
          jsonDecode(jsonEncode(itinerarySnapshot(widget.itinerary)))
              as Map<String, dynamic>;
      final title = widget.itinerary.request.title.trim();
      await gateway.save(
        id: id,
        userId: userId,
        title: title.isEmpty ? '我的行程' : title,
        snapshot: snapshot,
      );
      if (gateway.currentUserId != userId) {
        message('帳號已變更，請在原帳號確認儲存結果');
      } else {
        message('已儲存按下按鈕時的完整行程；後續修改請再次儲存');
      }
    } catch (_) {
      message('儲存失敗，請確認網路、登入及資料表設定後重試');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: _saving ? '儲存中…' : '儲存行程',
    onPressed: _saving || !widget.enabled ? null : _save,
    icon: _saving
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.save_outlined),
  );
}
