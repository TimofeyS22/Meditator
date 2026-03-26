import 'package:equatable/equatable.dart';

enum PairStatus { pending, active, ended }

PairStatus? _pairStatusFromName(String? v) {
  if (v == null || v.isEmpty) return null;
  for (final s in PairStatus.values) {
    if (s.name == v) return s;
  }
  return null;
}

enum PairMessageType { nudge, cheer, milestone }

extension PairMessageTypeX on PairMessageType {
  static PairMessageType fromString(String? v) {
    if (v == null || v.isEmpty) return PairMessageType.nudge;
    for (final t in PairMessageType.values) {
      if (t.name == v) return t;
    }
    return PairMessageType.nudge;
  }
}

class Partnership extends Equatable {
  const Partnership({
    required this.id,
    required this.myId,
    required this.partnerId,
    this.partnerName,
    this.partnerAvatarUrl,
    this.status = PairStatus.pending,
    this.sharedGoals = const [],
    this.myStreak = 0,
    this.partnerStreak = 0,
    this.sharedSessions = 0,
    required this.createdAt,
  });

  final String id;
  final String myId;
  final String partnerId;
  final String? partnerName;
  final String? partnerAvatarUrl;
  final PairStatus status;
  final List<String> sharedGoals;
  final int myStreak;
  final int partnerStreak;
  final int sharedSessions;
  final DateTime createdAt;

  factory Partnership.fromJson(Map<String, dynamic> json) {
    final goalsRaw = json['sharedGoals'] ?? json['shared_goals'];
    final goals = <String>[];
    if (goalsRaw is List) {
      for (final e in goalsRaw) {
        if (e is String && e.isNotEmpty) goals.add(e);
      }
    }

    return Partnership(
      id: json['id'] as String? ?? '',
      myId: json['myId'] as String? ?? json['my_id'] as String? ?? '',
      partnerId: json['partnerId'] as String? ?? json['partner_id'] as String? ?? '',
      partnerName: json['partnerName'] as String? ?? json['partner_name'] as String?,
      partnerAvatarUrl: json['partnerAvatarUrl'] as String? ?? json['partner_avatar_url'] as String?,
      status: _pairStatusFromName(json['status'] as String?) ?? PairStatus.pending,
      sharedGoals: goals,
      myStreak: (json['myStreak'] ?? json['my_streak']) as int? ?? 0,
      partnerStreak: (json['partnerStreak'] ?? json['partner_streak']) as int? ?? 0,
      sharedSessions: (json['sharedSessions'] ?? json['shared_sessions']) as int? ?? 0,
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'myId': myId,
        'partnerId': partnerId,
        'partnerName': partnerName,
        'partnerAvatarUrl': partnerAvatarUrl,
        'status': status.name,
        'sharedGoals': sharedGoals,
        'myStreak': myStreak,
        'partnerStreak': partnerStreak,
        'sharedSessions': sharedSessions,
        'createdAt': createdAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [
        id,
        myId,
        partnerId,
        partnerName,
        partnerAvatarUrl,
        status,
        sharedGoals,
        myStreak,
        partnerStreak,
        sharedSessions,
        createdAt,
      ];
}

class PairMessage extends Equatable {
  const PairMessage({
    required this.id,
    required this.pairId,
    required this.senderId,
    this.type = PairMessageType.nudge,
    this.content = '',
    required this.createdAt,
  });

  final String id;
  final String pairId;
  final String senderId;
  final PairMessageType type;
  final String content;
  final DateTime createdAt;

  factory PairMessage.fromJson(Map<String, dynamic> json) {
    return PairMessage(
      id: json['id'] as String? ?? '',
      pairId: json['pairId'] as String? ?? json['pair_id'] as String? ?? '',
      senderId: json['senderId'] as String? ?? json['sender_id'] as String? ?? '',
      type: PairMessageTypeX.fromString(json['type'] as String?),
      content: json['content'] as String? ?? '',
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'pairId': pairId,
        'senderId': senderId,
        'type': type.name,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, pairId, senderId, type, content, createdAt];
}
