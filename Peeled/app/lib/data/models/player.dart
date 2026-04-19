import 'package:flutter/foundation.dart';

/// A player in the PEELED universe. The real user has [isUser] = true,
/// everyone else is an AI placeholder so the live-feed/globe feel alive
/// while the real player base is still small.
@immutable
class Player {
  const Player({
    required this.id,
    required this.name,
    required this.avatar,
    required this.city,
    required this.country,
    required this.flag,
    required this.lat,
    required this.lon,
    this.isUser = false,
  });

  final String id;
  final String name;
  final String avatar; // emoji used as an avatar glyph
  final String city;
  final String country;
  final String flag; // country flag emoji
  final double lat;
  final double lon;
  final bool isUser;

  String get cityFlag => '$city $flag';

  Player copyWith({String? name, String? avatar}) => Player(
        id: id,
        name: name ?? this.name,
        avatar: avatar ?? this.avatar,
        city: city,
        country: country,
        flag: flag,
        lat: lat,
        lon: lon,
        isUser: isUser,
      );
}

/// The 10 AI placeholders we ship with. Names/cities are fictional.
class AiPlayers {
  AiPlayers._();

  static const List<Player> all = [
    Player(
      id: 'ai_sophie',
      name: 'Sophie Lune',
      avatar: '🌙',
      city: 'Paris',
      country: 'France',
      flag: '🇫🇷',
      lat: 48.8566,
      lon: 2.3522,
    ),
    Player(
      id: 'ai_yuki',
      name: 'Yuki Aoki',
      avatar: '🍣',
      city: 'Tokyo',
      country: 'Japan',
      flag: '🇯🇵',
      lat: 35.6762,
      lon: 139.6503,
    ),
    Player(
      id: 'ai_diego',
      name: 'Diego Vega',
      avatar: '🔥',
      city: 'São Paulo',
      country: 'Brazil',
      flag: '🇧🇷',
      lat: -23.5505,
      lon: -46.6333,
    ),
    Player(
      id: 'ai_amara',
      name: 'Amara Okafor',
      avatar: '🦁',
      city: 'Lagos',
      country: 'Nigeria',
      flag: '🇳🇬',
      lat: 6.5244,
      lon: 3.3792,
    ),
    Player(
      id: 'ai_noa',
      name: 'Noa Bar',
      avatar: '🌊',
      city: 'Tel Aviv',
      country: 'Israel',
      flag: '🇮🇱',
      lat: 32.0853,
      lon: 34.7818,
    ),
    Player(
      id: 'ai_liam',
      name: 'Liam Walsh',
      avatar: '🍀',
      city: 'Dublin',
      country: 'Ireland',
      flag: '🇮🇪',
      lat: 53.3498,
      lon: -6.2603,
    ),
    Player(
      id: 'ai_aria',
      name: 'Aria Patel',
      avatar: '💎',
      city: 'Mumbai',
      country: 'India',
      flag: '🇮🇳',
      lat: 19.0760,
      lon: 72.8777,
    ),
    Player(
      id: 'ai_mateo',
      name: 'Mateo Ruiz',
      avatar: '⚡',
      city: 'Mexico City',
      country: 'Mexico',
      flag: '🇲🇽',
      lat: 19.4326,
      lon: -99.1332,
    ),
    Player(
      id: 'ai_kaia',
      name: 'Kaia Smith',
      avatar: '🏄‍♀️',
      city: 'Sydney',
      country: 'Australia',
      flag: '🇦🇺',
      lat: -33.8688,
      lon: 151.2093,
    ),
    Player(
      id: 'ai_olu',
      name: 'Olu Johansson',
      avatar: '❄️',
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
