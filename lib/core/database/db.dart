import 'package:supabase_flutter/supabase_flutter.dart';

class Db {
  Db._();

  static final Db instance = Db._();

  SupabaseClient get client => Supabase.instance.client;

  Future<Map<String, dynamic>?> getProfile(String userId) async {
    final row = await client.from('profiles').select().eq('id', userId).maybeSingle();
    if (row == null) return null;
    return Map<String, dynamic>.from(row);
  }

  Future<Map<String, dynamic>?> upsertProfile(Map<String, dynamic> row) async {
    final data = await client.from('profiles').upsert(row).select().maybeSingle();
    if (data == null) return null;
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>?> updateProfileField(
    String userId,
    String field,
    Object? value,
  ) async {
    final data = await client
        .from('profiles')
        .update({field: value})
        .eq('id', userId)
        .select()
        .maybeSingle();
    if (data == null) return null;
    return Map<String, dynamic>.from(data);
  }

  Future<List<Map<String, dynamic>>> getMeditations({String? category}) async {
    final base = client.from('meditations').select();
    final rows = category != null && category.isNotEmpty
        ? await base.eq('category', category)
        : await base;
    return _mapList(rows);
  }

  Future<Map<String, dynamic>?> getMeditationById(String id) async {
    final row = await client.from('meditations').select().eq('id', id).maybeSingle();
    if (row == null) return null;
    return Map<String, dynamic>.from(row);
  }

  Future<Map<String, dynamic>?> insertSession(Map<String, dynamic> row) async {
    final data = await client.from('sessions').insert(row).select().maybeSingle();
    if (data == null) return null;
    return Map<String, dynamic>.from(data);
  }

  Future<List<Map<String, dynamic>>> getSessionsForUser(
    String userId, {
    int? limit,
  }) async {
    final ordered =
        client.from('sessions').select().eq('user_id', userId).order('created_at', ascending: false);
    final rows = limit != null ? await ordered.limit(limit) : await ordered;
    return _mapList(rows);
  }

  Future<List<Map<String, dynamic>>> getMoodEntries(
    String userId, {
    int? limit,
  }) async {
    final ordered = client
        .from('mood_entries')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    final rows = limit != null ? await ordered.limit(limit) : await ordered;
    return _mapList(rows);
  }

  Future<Map<String, dynamic>?> insertMoodEntry(Map<String, dynamic> row) async {
    final data = await client.from('mood_entries').insert(row).select().maybeSingle();
    if (data == null) return null;
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>?> updateMoodInsight(String id, String insight) async {
    final data = await client
        .from('mood_entries')
        .update({'insight': insight})
        .eq('id', id)
        .select()
        .maybeSingle();
    if (data == null) return null;
    return Map<String, dynamic>.from(data);
  }

  Future<List<Map<String, dynamic>>> getGarden(String userId) async {
    final rows = await client.from('plants').select().eq('user_id', userId).order('created_at');
    return _mapList(rows);
  }

  Future<Map<String, dynamic>?> insertPlant(Map<String, dynamic> row) async {
    final data = await client.from('plants').insert(row).select().maybeSingle();
    if (data == null) return null;
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>?> updatePlant(String id, Map<String, dynamic> patch) async {
    final data = await client.from('plants').update(patch).eq('id', id).select().maybeSingle();
    if (data == null) return null;
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>?> getPartnership(String userId) async {
    final row = await client
        .from('partnerships')
        .select()
        .or('user_id.eq.$userId,partner_id.eq.$userId')
        .maybeSingle();
    if (row == null) return null;
    return Map<String, dynamic>.from(row);
  }

  Future<Map<String, dynamic>?> insertPartnership(Map<String, dynamic> row) async {
    final data = await client.from('partnerships').insert(row).select().maybeSingle();
    if (data == null) return null;
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>?> updatePartnership(String id, Map<String, dynamic> patch) async {
    final data =
        await client.from('partnerships').update(patch).eq('id', id).select().maybeSingle();
    if (data == null) return null;
    return Map<String, dynamic>.from(data);
  }

  Future<List<Map<String, dynamic>>> getPairMessages(
    String pairId, {
    int? limit,
  }) async {
    final ordered = client
        .from('pair_messages')
        .select()
        .eq('pair_id', pairId)
        .order('created_at', ascending: false);
    final rows = limit != null ? await ordered.limit(limit) : await ordered;
    return _mapList(rows);
  }

  Future<Map<String, dynamic>?> insertPairMessage(Map<String, dynamic> row) async {
    final data = await client.from('pair_messages').insert(row).select().maybeSingle();
    if (data == null) return null;
    return Map<String, dynamic>.from(data);
  }

  List<Map<String, dynamic>> _mapList(dynamic rows) {
    final list = rows as List<dynamic>;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}
