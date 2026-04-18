import 'package:flutter/foundation.dart';

@immutable
class PackageModel {
  const PackageModel({
    required this.id,
    required this.rarity,
    required this.status,
    required this.totalLayers,
    required this.peeledLayers,
    required this.hops,
    this.holdDeadline,
    this.currentHolderId,
    this.theme,
    this.currentLat,
    this.currentLng,
    this.originLat,
    this.originLng,
  });

  final String id;
  final String rarity;
  final String status;
  final int totalLayers;
  final int peeledLayers;
  final int hops;
  final DateTime? holdDeadline;
  final String? currentHolderId;
  final String? theme;
  final double? currentLat;
  final double? currentLng;
  final double? originLat;
  final double? originLng;

  double get progress =>
      totalLayers == 0 ? 0 : (peeledLayers / totalLayers).clamp(0.0, 1.0);
  bool get isFinalLayerNext => peeledLayers == totalLayers - 1;

  factory PackageModel.fromJson(Map<String, dynamic> j) => PackageModel(
        id: j['id'] as String,
        rarity: j['rarity'] as String,
        status: j['status'] as String,
        totalLayers: j['total_layers'] as int,
        peeledLayers: j['peeled_layers'] as int,
        hops: j['hops'] as int,
        holdDeadline: j['hold_deadline'] != null
            ? DateTime.parse(j['hold_deadline'] as String)
            : null,
        currentHolderId: j['current_holder_id'] as String?,
        theme: j['theme'] as String?,
        currentLat: (j['current_lat'] as num?)?.toDouble(),
        currentLng: (j['current_lng'] as num?)?.toDouble(),
        originLat: (j['origin_lat'] as num?)?.toDouble(),
        originLng: (j['origin_lng'] as num?)?.toDouble(),
      );
}

@immutable
class PeeledLayerModel {
  const PeeledLayerModel({
    required this.index,
    required this.layerType,
    required this.payload,
  });
  final int index;
  final String layerType;
  final Map<String, dynamic> payload;

  factory PeeledLayerModel.fromJson(Map<String, dynamic> j) => PeeledLayerModel(
        index: j['index'] as int,
        layerType: j['layer_type'] as String,
        payload: Map<String, dynamic>.from(j['payload'] as Map),
      );
}

@immutable
class InboxItemModel {
  const InboxItemModel({required this.package, required this.secondsRemaining});
  final PackageModel package;
  final int secondsRemaining;

  factory InboxItemModel.fromJson(Map<String, dynamic> j) => InboxItemModel(
        package: PackageModel.fromJson(j['package'] as Map<String, dynamic>),
        secondsRemaining: j['seconds_remaining'] as int,
      );
}

@immutable
class InboxModel {
  const InboxModel({
    required this.items,
    required this.concurrentSlotsUsed,
    required this.maxConcurrentSlots,
  });
  final List<InboxItemModel> items;
  final int concurrentSlotsUsed;
  final int maxConcurrentSlots;

  factory InboxModel.fromJson(Map<String, dynamic> j) => InboxModel(
        items: (j['items'] as List)
            .map((e) => InboxItemModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        concurrentSlotsUsed: j['concurrent_slots_used'] as int,
        maxConcurrentSlots: j['max_concurrent_slots'] as int,
      );
}
