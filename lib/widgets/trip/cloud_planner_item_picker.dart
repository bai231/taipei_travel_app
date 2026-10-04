import 'dart:async';

import 'package:flutter/material.dart';
import '../../services/language_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/place.dart';
import '../../models/planner_favorites.dart';
import '../../services/planner_favorites_service.dart';
import 'planner_item_picker.dart';

/// Each opened sheet refreshes from the current account. No cloud writes.
class CloudPlannerItemPicker extends StatefulWidget {
  final PlaceType type;
  final List<Place> places;
  final Set<String> selectedPlaceIds;
  final ValueChanged<List<Place>> onConfirmed;
  final Map<String, num> candidateScoresByPlaceId;

  const CloudPlannerItemPicker({
    super.key,
    required this.type,
    required this.places,
    required this.selectedPlaceIds,
    required this.onConfirmed,
    this.candidateScoresByPlaceId = const {},
  });

  @override
  State<CloudPlannerItemPicker> createState() => _CloudPlannerItemPickerState();
}

class _CloudPlannerItemPickerState extends State<CloudPlannerItemPicker> {
  StreamSubscription<AuthState>? _authSubscription;
  Future<PlannerFavorites>? _request;
  String? _userId;

  @override
  void initState() {
    super.initState();
    if (widget.type != PlaceType.attraction) return;
    final client = Supabase.instance.client;
    _userId = client.auth.currentUser?.id;
    _refresh();
    _authSubscription = client.auth.onAuthStateChange.listen((_) {
      if (!mounted || _userId == client.auth.currentUser?.id) return;
      setState(() {
        _userId = client.auth.currentUser?.id;
        _refresh();
      });
    });
  }

  void _refresh() {
    _request = _userId == null
        ? null
        : PlannerFavoritesService(Supabase.instance.client).load();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<PlannerFavorites>(
    future: _request,
    builder: (context, snapshot) {
      // Never display retained FutureBuilder data from a prior request/account.
      final data =
          snapshot.connectionState == ConnectionState.done &&
              !snapshot.hasError &&
              _userId != null
          ? snapshot.data
          : null;
      final message = _userId == null
          ? LanguageService.tr(context, 'cloud_favorites_login')
          : snapshot.hasError
          ? LanguageService.tr(context, 'cloud_favorites_failed')
          : LanguageService.tr(context, 'cloud_favorites_loading');
      return Column(
        children: [
          if (snapshot.hasError && _userId != null)
            TextButton.icon(
              onPressed: () => setState(_refresh),
              icon: const Icon(Icons.refresh),
              label: Text(LanguageService.tr(context, 'cloud_favorites_reload')),
            ),
          Expanded(
            child: PlannerItemPicker(
              key: ValueKey(_userId),
              type: widget.type,
              places: widget.places,
              selectedPlaceIds: widget.selectedPlaceIds,
              onConfirmed: widget.onConfirmed,
              candidateScoresByPlaceId: widget.candidateScoresByPlaceId,
              favoritePlaceIds: data?.placeIds,
              favoriteFolders: data?.folders ?? const [],
              favoritesUnavailableMessage: message,
            ),
          ),
        ],
      );
    },
  );
}
