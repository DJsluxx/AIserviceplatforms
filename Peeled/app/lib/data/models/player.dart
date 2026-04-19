import 'package:flutter/foundation.dart';

/// A player in the PEELED universe. Real user has [isUser]=true; the
/// 10 AI placeholders are baked-in constants below.
///
/// [avatarUrl] points to a stable real-portrait photo (we use
/// pravatar.cc which serves CC-licensed real-people photos by integer
/// id). [avatarEmoji] is the offline-safe fallback used when the
/// photo hasn't loaded yet, when we're offline, or in places where a
/// network image would be too heavy (small chips, list rows).
@immutable
class Player {
  const Player({
    required this.id,
    required this.name,
    required this.avatarEmoji,
    required this.avatarUrl,
    required this.city,
    required this.country,
    required this.flag,
    required this.lat,
    required this.lon,
    this.isUser = false,
  });

  final String id;
  final String name;
  final String avatarEmoji;
  final String avatarUrl;
  final String city;
  final String country;
  final String flag;
  final double lat;
  final double lon;
  final bool isUser;

  String get cityFlag => '$city $flag';

  /// Compatibility shim — old call sites used `.avatar` for the emoji.
  String get avatar => avatarEmoji;

  Player copyWith({
    String? name,
    String? avatarEmoji,
    String? avatarUrl,
  }) =>
      Player(
        id: id,
        name: name ?? this.name,
        avatarEmoji: avatarEmoji ?? this.avatarEmoji,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        city: city,
        country: country,
        flag: flag,
        lat: lat,
        lon: lon,
        isUser: isUser,
      );
}

/// pravatar.cc image ids hand-picked to feel like a believable
/// international cast. Each AI player is bound to one id so the
/// portrait stays stable across launches.
String _pravatar(int id) => 'https://i.pravatar.cc/200?img=$id';

/// The 10 AI placeholders we ship with. Names/cities are fictional;
/// portraits come from pravatar (CC-licensed real photos).
class AiPlayers {
  AiPlayers._();

  static final List<Player> all = [
    Player(
      id: 'ai_sophie',
      name: 'Sophie Lune',
      avatarEmoji: '🌙',
      avatarUrl: _pravatar(47),
      city: 'Paris',
      country: 'France',
      flag: '🇫🇷',
      lat: 48.8566,
      lon: 2.3522,
    ),
    Player(
      id: 'ai_yuki',
      name: 'Yuki Aoki',
      avatarEmoji: '🍣',
      avatarUrl: _pravatar(26),
      city: 'Tokyo',
      country: 'Japan',
      flag: '🇯🇵',
      lat: 35.6762,
      lon: 139.6503,
    ),
    Player(
      id: 'ai_diego',
      name: 'Diego Vega',
      avatarEmoji: '🔥',
      avatarUrl: _pravatar(13),
      city: 'São Paulo',
      country: 'Brazil',
      flag: '🇧🇷',
      lat: -23.5505,
      lon: -46.6333,
    ),
    Player(
      id: 'ai_amara',
      name: 'Amara Okafor',
      avatarEmoji: '🦁',
      avatarUrl: _pravatar(49),
      city: 'Lagos',
      country: 'Nigeria',
      flag: '🇳🇬',
      lat: 6.5244,
      lon: 3.3792,
    ),
    Player(
      id: 'ai_noa',
      name: 'Noa Bar',
      avatarEmoji: '🌊',
      avatarUrl: _pravatar(32),
      city: 'Tel Aviv',
      country: 'Israel',
      flag: '🇮🇱',
      lat: 32.0853,
      lon: 34.7818,
    ),
    Player(
      id: 'ai_liam',
      name: 'Liam Walsh',
      avatarEmoji: '🍀',
      avatarUrl: _pravatar(12),
      city: 'Dublin',
      country: 'Ireland',
      flag: '🇮🇪',
      lat: 53.3498,
      lon: -6.2603,
    ),
    Player(
      id: 'ai_aria',
      name: 'Aria Patel',
      avatarEmoji: '💎',
      avatarUrl: _pravatar(45),
      city: 'Mumbai',
      country: 'India',
      flag: '🇮🇳',
      lat: 19.0760,
      lon: 72.8777,
    ),
    Player(
      id: 'ai_mateo',
      name: 'Mateo Ruiz',
      avatarEmoji: '⚡',
      avatarUrl: _pravatar(33),
      city: 'Mexico City',
      country: 'Mexico',
      flag: '🇲🇽',
      lat: 19.4326,
      lon: -99.1332,
    ),
    Player(
      id: 'ai_kaia',
      name: 'Kaia Smith',
      avatarEmoji: '🏄‍♀️',
      avatarUrl: _pravatar(20),
      city: 'Sydney',
      country: 'Australia',
      flag: '🇦🇺',
      lat: -33.8688,
      lon: 151.2093,
    ),
    Player(
      id: 'ai_olu',
      name: 'Olu Johansson',
      avatarEmoji: '❄️',
      avatarUrl: _pravatar(15),
      city: 'Stockholm',
      country: 'Sweden',
      flag: '🇸🇪',
      lat: 59.3293,
      lon: 18.0686,
    ),
  ];

  static Player byId(String id) =>
      all.firstWhere((p) => p.id == id, orElse: () => all.first);
}

/// pravatar ids the player can pick from on first launch.
List<String> kUserAvatarChoices = List.unmodifiable([
  for (final i in [1, 5, 8, 14, 16, 25, 31, 36, 44, 51, 60, 65])
    'https://i.pravatar.cc/200?img=$i',
]);
