import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meditator/core/auth/auth_service.dart';
import 'package:meditator/core/database/db.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final authStateProvider = StreamProvider<AuthState>((ref) {
  return AuthService.instance.onAuthChange;
});

final currentUserProvider = Provider<User?>((ref) {
  final auth = ref.watch(authStateProvider);
  return auth.when(
    data: (state) => state.session?.user,
    loading: () => AuthService.instance.currentUser,
    error: (_, _) => AuthService.instance.currentUser,
  );
});

final profileProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, userId) {
  return Db.instance.getProfile(userId);
});

final meditationsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String?>((ref, category) {
  return Db.instance.getMeditations(category: category);
});

final moodEntriesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, userId) {
  return Db.instance.getMoodEntries(userId);
});

final gardenProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, userId) {
  return Db.instance.getGarden(userId);
});

final partnershipProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, userId) {
  return Db.instance.getPartnership(userId);
});
