import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../domain/assistant_quick_query.dart';

const _favoritesSettingKey = 'assistant_query_favorites_v1';

class AssistantQueryFavorite {
  const AssistantQueryFavorite({
    required this.id,
    required this.name,
    required this.query,
  });

  final String id;
  final String name;
  final AssistantQuickQuery query;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'query': query.toJson(),
  };

  factory AssistantQueryFavorite.fromJson(Map<String, Object?> json) {
    return AssistantQueryFavorite(
      id: json['id']! as String,
      name: json['name']! as String,
      query: AssistantQuickQuery.fromJson(
        (json['query']! as Map).cast<String, Object?>(),
      ),
    );
  }
}

final assistantQueryFavoritesProvider =
    AsyncNotifierProvider<
      AssistantQueryFavoritesNotifier,
      List<AssistantQueryFavorite>
    >(AssistantQueryFavoritesNotifier.new);

class AssistantQueryFavoritesNotifier
    extends AsyncNotifier<List<AssistantQueryFavorite>> {
  AppDatabase get _database => ref.read(appDatabaseProvider);

  @override
  Future<List<AssistantQueryFavorite>> build() async {
    final row =
        await (_database.select(_database.appSettings)..where(
              (setting) => setting.settingKey.equals(_favoritesSettingKey),
            ))
            .getSingleOrNull();
    final encoded = row?.settingValue;
    if (encoded == null || encoded.isEmpty) return const [];

    final decoded = jsonDecode(encoded) as List;
    return decoded
        .map(
          (item) => AssistantQueryFavorite.fromJson(
            (item as Map).cast<String, Object?>(),
          ),
        )
        .toList(growable: false);
  }

  Future<AssistantQueryFavorite> add(
    String name,
    AssistantQuickQuery query,
  ) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Must not be empty.');
    }

    final favorites = await future;
    final identity = _queryIdentity(query);
    if (favorites.any(
      (favorite) => _queryIdentity(favorite.query) == identity,
    )) {
      throw StateError('This query is already saved as a favorite.');
    }

    final favorite = AssistantQueryFavorite(
      id: _newId(),
      name: normalizedName,
      query: query,
    );
    final next = [...favorites, favorite];
    await _save(next);
    state = AsyncData(next);
    return favorite;
  }

  Future<void> remove(String id) async {
    final favorites = await future;
    final next = favorites.where((favorite) => favorite.id != id).toList();
    if (next.length == favorites.length) return;
    await _save(next);
    state = AsyncData(next);
  }

  Future<void> rename(String id, String name) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Must not be empty.');
    }

    final favorites = await future;
    final index = favorites.indexWhere((favorite) => favorite.id == id);
    if (index < 0) throw StateError('Favorite $id does not exist.');
    final current = favorites[index];
    final next = [...favorites];
    next[index] = AssistantQueryFavorite(
      id: current.id,
      name: normalizedName,
      query: current.query,
    );
    await _save(next);
    state = AsyncData(next);
  }

  Future<void> _save(List<AssistantQueryFavorite> favorites) async {
    final encoded = jsonEncode(
      favorites.map((favorite) => favorite.toJson()).toList(),
    );
    await _database
        .into(_database.appSettings)
        .insert(
          AppSettingsCompanion.insert(
            settingKey: _favoritesSettingKey,
            settingValue: Value(encoded),
          ),
          onConflict: DoUpdate(
            (_) => AppSettingsCompanion(settingValue: Value(encoded)),
            target: [_database.appSettings.settingKey],
          ),
        );
  }

  String _queryIdentity(AssistantQuickQuery query) =>
      jsonEncode(query.toJson());

  String _newId() {
    final random = Random.secure();
    final suffix = List.generate(
      16,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
    return '${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}-$suffix';
  }
}
