import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Enregistrement local d'une course terminée par Green Hornet.
class RaceResultRecord {
  const RaceResultRecord({
    required this.id,
    required this.playedAtIso,
    required this.trackName,
    required this.playerName,
    required this.playerCount,
    required this.totalLaps,
    required this.startPosition,
    required this.finalRank,
    required this.roundsCount,
    required this.finishLineDistance,
    required this.includeStartingUpgrades,
    required this.includeBonusCards,
  });

  final String id;
  final String playedAtIso;
  final String trackName;
  final String playerName;
  final int playerCount;
  final int totalLaps;
  final int startPosition;
  final int finalRank;
  final int roundsCount;

  /// Nombre de cases parcourues AU-DELÀ de la ligne d'arrivée finale.
  final int finishLineDistance;
  final bool includeStartingUpgrades;
  final bool includeBonusCards;

  bool get isTop3 => finalRank <= 3;
  bool get isWin => finalRank == 1;

  Map<String, dynamic> toJson() => {
        'id': id,
        'playedAtIso': playedAtIso,
        'trackName': trackName,
        'playerName': playerName,
        'playerCount': playerCount,
        'totalLaps': totalLaps,
        'startPosition': startPosition,
        'finalRank': finalRank,
        'roundsCount': roundsCount,
        'finishLineDistance': finishLineDistance,
        'includeStartingUpgrades': includeStartingUpgrades,
        'includeBonusCards': includeBonusCards,
      };

  factory RaceResultRecord.fromJson(Map<String, dynamic> json) {
    return RaceResultRecord(
      id: (json['id'] as String?) ?? '',
      playedAtIso: (json['playedAtIso'] as String?) ?? '',
      trackName: (json['trackName'] as String?) ?? 'Deutschland',
      playerName: (json['playerName'] as String?) ?? 'Green Hornet',
      playerCount: (json['playerCount'] as int?) ?? 1,
      totalLaps: (json['totalLaps'] as int?) ?? 2,
      startPosition: (json['startPosition'] as int?) ?? 1,
      finalRank: (json['finalRank'] as int?) ?? 1,
      roundsCount: (json['roundsCount'] as int?) ?? 1,
      finishLineDistance: (json['finishLineDistance'] as int?) ?? 0,
      includeStartingUpgrades:
          (json['includeStartingUpgrades'] as bool?) ?? false,
      includeBonusCards: (json['includeBonusCards'] as bool?) ?? false,
    );
  }
}

/// Synthèse des records max atteints localement.
class RaceHistorySummary {
  const RaceHistorySummary({
    required this.totalRaces,
    required this.winsCount,
    required this.top3Count,
    required this.bestRank,
    required this.bestRankPlayerCount,
    required this.bestRoundsTwoLaps,
    required this.bestRoundsOneLap,
    required this.maxFinishLineDistance,
    required this.bestStartPosition,
  });

  final int totalRaces;
  final int winsCount;
  final int top3Count;
  final int? bestRank;
  final int? bestRankPlayerCount;
  final int? bestRoundsTwoLaps;
  final int? bestRoundsOneLap;
  final int maxFinishLineDistance;
  final int? bestStartPosition;
}

/// Stockage 100 % local (SharedPreferences) de l'historique des courses.
class RaceHistoryService {
  RaceHistoryService._();

  static const String _storageKey = 'heat_race_history_v1';

  static Future<List<RaceResultRecord>> loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(RaceResultRecord.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<RaceResultRecord>> addRecord(
    RaceResultRecord record,
  ) async {
    final current = await loadHistory();
    final updated = [record, ...current];
    if (updated.length > 100) {
      updated.removeRange(100, updated.length);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey,
        jsonEncode(updated.map((r) => r.toJson()).toList()),
      );
    } catch (_) {
      // Ignore storage error
    }
    return updated;
  }

  static Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (_) {}
  }

  static RaceHistorySummary computeSummary(List<RaceResultRecord> records) {
    if (records.isEmpty) {
      return const RaceHistorySummary(
        totalRaces: 0,
        winsCount: 0,
        top3Count: 0,
        bestRank: null,
        bestRankPlayerCount: null,
        bestRoundsTwoLaps: null,
        bestRoundsOneLap: null,
        maxFinishLineDistance: 0,
        bestStartPosition: null,
      );
    }

    var wins = 0;
    var top3 = 0;
    int? bestRank;
    int? bestRankPlayers;
    int? bestTwoLaps;
    int? bestOneLap;
    var maxDist = 0;
    int? bestStart;

    for (final r in records) {
      if (r.isWin) wins++;
      if (r.isTop3) top3++;

      if (bestRank == null ||
          r.finalRank < bestRank ||
          (r.finalRank == bestRank &&
              r.playerCount > (bestRankPlayers ?? 0))) {
        bestRank = r.finalRank;
        bestRankPlayers = r.playerCount;
      }

      if (r.totalLaps == 2) {
        bestTwoLaps = bestTwoLaps == null
            ? r.roundsCount
            : min(bestTwoLaps, r.roundsCount);
      } else if (r.totalLaps == 1) {
        bestOneLap = bestOneLap == null
            ? r.roundsCount
            : min(bestOneLap, r.roundsCount);
      }

      if (r.finishLineDistance > maxDist) {
        maxDist = r.finishLineDistance;
      }

      bestStart = bestStart == null
          ? r.startPosition
          : min(bestStart, r.startPosition);
    }

    return RaceHistorySummary(
      totalRaces: records.length,
      winsCount: wins,
      top3Count: top3,
      bestRank: bestRank,
      bestRankPlayerCount: bestRankPlayers,
      bestRoundsTwoLaps: bestTwoLaps,
      bestRoundsOneLap: bestOneLap,
      maxFinishLineDistance: maxDist,
      bestStartPosition: bestStart,
    );
  }
}
