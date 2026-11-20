import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config/app_config.dart';
import '../core/utils/xlsx_builder.dart';
import '../models/avatar_config.dart';
import 'auth_service.dart';
import 'gamification_service.dart';

class Classroom {
  final String id;
  final String code;
  final String name;
  final String churchName;
  final String teacherId;
  final String? webhookUrl;
  final DateTime? createdAt;

  const Classroom({
    required this.id,
    required this.code,
    required this.name,
    required this.churchName,
    required this.teacherId,
    this.webhookUrl,
    this.createdAt,
  });

  factory Classroom.fromJson(Map<String, dynamic> json) {
    return Classroom(
      id: (json['id'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      churchName: (json['church_name'] ?? '').toString(),
      teacherId: (json['teacher_id'] ?? '').toString(),
      webhookUrl: json['webhook_url']?.toString(),
      createdAt:
          json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'church_name': churchName,
      'teacher_id': teacherId,
      if (webhookUrl != null) 'webhook_url': webhookUrl,
    };
  }
}

class ClassroomMember {
  final String id;
  final String classroomId;
  final String userId;
  final String studentName;
  final AvatarConfig avatarConfig;
  final DateTime? joinedAt;

  const ClassroomMember({
    required this.id,
    required this.classroomId,
    required this.userId,
    required this.studentName,
    required this.avatarConfig,
    this.joinedAt,
  });

  factory ClassroomMember.fromJson(Map<String, dynamic> json) {
    AvatarConfig avatar;
    try {
      final rawAvatar = json['avatar_config_json'];
      if (rawAvatar != null && rawAvatar.toString().isNotEmpty) {
        avatar = AvatarConfig.fromJson(rawAvatar.toString());
      } else {
        avatar = const AvatarConfig();
      }
    } catch (_) {
      avatar = const AvatarConfig();
    }

    return ClassroomMember(
      id: (json['id'] ?? '').toString(),
      classroomId: (json['classroom_id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      studentName: (json['student_name'] ?? 'Aluno Kairós').toString(),
      avatarConfig: avatar,
      joinedAt:
          json['joined_at'] != null ? DateTime.tryParse(json['joined_at'].toString()) : null,
    );
  }
}

class MemberActivityLog {
  final String userId;
  final String activityDate;
  final int minutesWithGod;
  final int missionsCompleted;
  final bool didDailyQuiz;
  final int quizScore;
  final String streakType; // 'none', 'half', 'full'
  final int totalXp;

  const MemberActivityLog({
    required this.userId,
    required this.activityDate,
    required this.minutesWithGod,
    required this.missionsCompleted,
    required this.didDailyQuiz,
    required this.quizScore,
    required this.streakType,
    required this.totalXp,
  });

  factory MemberActivityLog.fromJson(Map<String, dynamic> json) {
    return MemberActivityLog(
      userId: (json['user_id'] ?? '').toString(),
      activityDate: (json['activity_date'] ?? '').toString(),
      minutesWithGod: (json['minutes_with_god'] as num?)?.toInt() ?? 0,
      missionsCompleted: (json['missions_completed'] as num?)?.toInt() ?? 0,
      didDailyQuiz: json['did_daily_quiz'] == true,
      quizScore: (json['quiz_score'] as num?)?.toInt() ?? 0,
      streakType: (json['streak_type'] ?? 'none').toString(),
      totalXp: (json['total_xp'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'activity_date': activityDate,
      'minutes_with_god': minutesWithGod,
      'missions_completed': missionsCompleted,
      'did_daily_quiz': didDailyQuiz,
      'quiz_score': quizScore,
      'streak_type': streakType,
      'total_xp': totalXp,
    };
  }
}

/// DTO agregado para visualização de desempenho individual, conquistas e diagnósticos
class StudentStatsItem {
  final ClassroomMember member;
  final int totalMinutes;
  final int lessonsStudiedDays;
  final int totalQuizzes;
  final int totalScore;
  final int totalXp;
  final FlameType currentFlame;
  final bool isFullStreakActive;
  final List<String> completedTasksLabels;
  final List<String> improvementPoints;
  final int unlockedBadgesCount;
  final String? featuredBadgeId;

  const StudentStatsItem({
    required this.member,
    required this.totalMinutes,
    required this.lessonsStudiedDays,
    required this.totalQuizzes,
    required this.totalScore,
    required this.totalXp,
    required this.currentFlame,
    required this.isFullStreakActive,
    this.completedTasksLabels = const [],
    this.improvementPoints = const [],
    this.unlockedBadgesCount = 0,
    this.featuredBadgeId,
  });
}

/// Tipos de reação rápida disponíveis no Feed da Turma.
enum ClassroomReactionType {
  amen('🙏', 'Amém'),
  fire('🔥', 'Firmeza'),
  clap('👏', 'Parabéns'),
  heart('💛', 'Louvor');

  final String emoji;
  final String label;
  const ClassroomReactionType(this.emoji, this.label);

  static ClassroomReactionType? fromName(String raw) {
    for (final value in ClassroomReactionType.values) {
      if (value.name == raw) return value;
    }
    return null;
  }
}

/// Publicação de conquista ou marco no Feed da Turma.
class ClassroomFeedPost {
  final String id;
  final String classroomId;
  final String userId;
  final String authorName;
  final String achievementType;
  final String title;
  final String subtitle;
  final DateTime createdAt;
  final Map<ClassroomReactionType, int> reactionCounts;
  final Set<ClassroomReactionType> myReactions;

  const ClassroomFeedPost({
    required this.id,
    required this.classroomId,
    required this.userId,
    required this.authorName,
    required this.achievementType,
    required this.title,
    this.subtitle = '',
    required this.createdAt,
    this.reactionCounts = const {},
    this.myReactions = const {},
  });

  ClassroomFeedPost copyWith({
    Map<ClassroomReactionType, int>? reactionCounts,
    Set<ClassroomReactionType>? myReactions,
  }) {
    return ClassroomFeedPost(
      id: id,
      classroomId: classroomId,
      userId: userId,
      authorName: authorName,
      achievementType: achievementType,
      title: title,
      subtitle: subtitle,
      createdAt: createdAt,
      reactionCounts: reactionCounts ?? this.reactionCounts,
      myReactions: myReactions ?? this.myReactions,
    );
  }

  Map<String, dynamic> toCacheJson() {
    return {
      'id': id,
      'classroom_id': classroomId,
      'user_id': userId,
      'author_name': authorName,
      'achievement_type': achievementType,
      'title': title,
      'subtitle': subtitle,
      'created_at': createdAt.toIso8601String(),
      'reaction_counts': {
        for (final entry in reactionCounts.entries) entry.key.name: entry.value,
      },
      'my_reactions': myReactions.map((e) => e.name).toList(),
    };
  }

  factory ClassroomFeedPost.fromJson(
    Map<String, dynamic> json, {
    Map<ClassroomReactionType, int>? reactionCounts,
    Set<ClassroomReactionType>? myReactions,
  }) {
    final parsedCounts = <ClassroomReactionType, int>{};
    if (reactionCounts != null) {
      parsedCounts.addAll(reactionCounts);
    } else if (json['reaction_counts'] is Map) {
      for (final entry in (json['reaction_counts'] as Map).entries) {
        final type = ClassroomReactionType.fromName(entry.key.toString());
        if (type != null) {
          parsedCounts[type] = (entry.value as num?)?.toInt() ?? 0;
        }
      }
    }

    final parsedMine = <ClassroomReactionType>{};
    if (myReactions != null) {
      parsedMine.addAll(myReactions);
    } else if (json['my_reactions'] is List) {
      for (final raw in (json['my_reactions'] as List)) {
        final type = ClassroomReactionType.fromName(raw.toString());
        if (type != null) parsedMine.add(type);
      }
    }

    return ClassroomFeedPost(
      id: (json['id'] ?? '').toString(),
      classroomId: (json['classroom_id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      authorName: (json['author_name'] ?? 'Colega Kairós').toString(),
      achievementType: (json['achievement_type'] ?? 'milestone').toString(),
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ?? DateTime.now(),
      reactionCounts: parsedCounts,
      myReactions: parsedMine,
    );
  }
}

class ClassroomService extends ChangeNotifier {
  static final ClassroomService _instance = ClassroomService._internal();
  factory ClassroomService() => _instance;
  ClassroomService._internal();

  static const String _prefClassroomCacheKey = 'user_classroom_cache_json';
  static const String _prefClassroomCodeKey = 'user_classroom_code';

  Classroom? _currentClassroom;
  bool _isTeacher = false;
  List<ClassroomMember> _members = [];
  List<MemberActivityLog> _activityLogs = [];
  List<ClassroomFeedPost> _feedPosts = [];
  bool _isLoading = false;
  bool _isLoadingFeed = false;

  Classroom? get currentClassroom => _currentClassroom;
  bool get isTeacher => _isTeacher;
  List<ClassroomMember> get members => _members;
  List<MemberActivityLog> get activityLogs => _activityLogs;
  List<ClassroomFeedPost> get feedPosts => _feedPosts;
  bool get isLoading => _isLoading;
  bool get isLoadingFeed => _isLoadingFeed;

  @visibleForTesting
  void setTestClassroom(
    Classroom? cr, {
    List<ClassroomMember>? members,
    List<MemberActivityLog>? logs,
    bool? isTeacher,
  }) {
    _currentClassroom = cr;
    if (isTeacher != null) {
      _isTeacher = isTeacher;
    } else if (cr != null) {
      final currentUserId = AuthService().currentUser?.id;
      _isTeacher = currentUserId != null && currentUserId.isNotEmpty
          ? cr.teacherId == currentUserId
          : true;
    } else {
      _isTeacher = false;
    }
    if (members != null) _members = members;
    if (logs != null) _activityLogs = logs;
    notifyListeners();
  }

  /// Persiste ou remove o cache local da turma no SharedPreferences.
  Future<void> _saveLocalClassroomCache(Classroom? classroom) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (classroom != null && classroom.id.isNotEmpty) {
        await prefs.setString(_prefClassroomCacheKey, json.encode(classroom.toJson()));
        await prefs.setString(_prefClassroomCodeKey, classroom.code);
      } else {
        await prefs.remove(_prefClassroomCacheKey);
        await prefs.remove(_prefClassroomCodeKey);
      }
    } catch (e) {
      debugPrint('[ClassroomService] Aviso ao atualizar cache local da turma: $e');
    }
  }

  /// Recupera a turma salva localmente em SharedPreferences (se houver).
  Future<Classroom?> getCachedClassroom() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefClassroomCacheKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = json.decode(raw);
        if (decoded is Map<String, dynamic>) {
          final parsed = Classroom.fromJson(decoded);
          if (parsed.id.isNotEmpty) return parsed;
        }
      }
    } catch (e) {
      debugPrint('[ClassroomService] Erro ao ler cache local da turma: $e');
    }
    return null;
  }

  /// Recupera o último código da turma salvo localmente.
  Future<String?> getCachedClassroomCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefClassroomCodeKey);
      return (code != null && code.isNotEmpty) ? code : null;
    } catch (_) {
      return null;
    }
  }

  /// Limpa os dados locais e em memória da turma ao encerrar a sessão (signOut).
  Future<void> clearLocalClassroomOnSignOut() async {
    _currentClassroom = null;
    _isTeacher = false;
    _members = [];
    _activityLogs = [];
    _isLoading = false;
    await _saveLocalClassroomCache(null);
    notifyListeners();
  }

  @visibleForTesting
  Future<void> resetForTesting() async {
    await clearLocalClassroomOnSignOut();
  }

  Map<String, String> _getHeaders({String? token}) {
    final auth = AuthService();
    final jwt = token ?? auth.accessToken ?? AppConfig.authSupabaseAnonKey;
    return {
      'apikey': AppConfig.authSupabaseAnonKey,
      'Authorization': 'Bearer $jwt',
      'Content-Type': 'application/json',
      'Prefer': 'return=representation',
    };
  }

  /// Gera um código alfanumérico aleatório de 6 caracteres (ex: KAI777)
  static String generateClassCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = DateTime.now().microsecondsSinceEpoch;
    final buffer = StringBuffer();
    var val = rand;
    for (int i = 0; i < 6; i++) {
      buffer.write(chars[val % chars.length]);
      val = val ~/ 7;
    }
    return buffer.toString().toUpperCase();
  }

  /// Sincroniza silenciosamente o Avatar 2.0 e conquistas desbloqueadas no registro do membro
  Future<void> syncMemberAvatarSilently() async {
    final user = AuthService().currentUser;
    if (user == null || _currentClassroom == null) return;

    final currentAvatar = GamificationService().avatarConfig;
    final idx = _members.indexWhere((m) => m.userId == user.id);
    if (idx >= 0) {
      final old = _members[idx];
      _members[idx] = ClassroomMember(
        id: old.id,
        classroomId: old.classroomId,
        userId: old.userId,
        studentName: old.studentName,
        avatarConfig: currentAvatar,
        joinedAt: old.joinedAt,
      );
      notifyListeners();
    }

    try {
      await http.patch(
        Uri.parse(
          '${AppConfig.authSupabaseUrl}/rest/v1/classroom_members?classroom_id=eq.${_currentClassroom!.id}&user_id=eq.${user.id}',
        ),
        headers: _getHeaders(),
        body: json.encode({'avatar_config_json': currentAvatar.toJson()}),
      );
    } catch (e) {
      debugPrint('[ClassroomService] Erro ao sincronizar avatar na turma: $e');
    }
  }

  /// Executa upsert seguro na tabela `classroom_members` resolvendo conflitos em `user_id`.
  Future<http.Response> _upsertClassroomMember({
    required String classroomId,
    required String userId,
    required String studentName,
    String prefer = 'resolution=merge-duplicates,return=minimal',
  }) {
    final avatarJson = GamificationService().avatarConfig.toJson();
    return http.post(
      Uri.parse('${AppConfig.authSupabaseUrl}/rest/v1/classroom_members?on_conflict=user_id'),
      headers: {
        ..._getHeaders(),
        'Prefer': prefer,
      },
      body: json.encode({
        'classroom_id': classroomId,
        'user_id': userId,
        'student_name': studentName,
        'avatar_config_json': avatarJson,
      }),
    );
  }

  /// Tenta hidratar o objeto Classroom a partir do cache local ou metadata em nuvem.
  Future<void> _hydrateFromFallback({
    Map<String, dynamic>? fallbackClassroomJson,
    String? userId,
  }) async {
    if (_currentClassroom != null) return;
    Classroom? hydrated = await getCachedClassroom();
    if (hydrated == null && fallbackClassroomJson != null) {
      final candidate = Classroom.fromJson(fallbackClassroomJson);
      if (candidate.id.isNotEmpty) {
        hydrated = candidate;
        await _saveLocalClassroomCache(hydrated);
      }
    }
    if (hydrated != null) {
      _currentClassroom = hydrated;
      _isTeacher = userId != null && hydrated.teacherId == userId;
      notifyListeners();
    }
  }

  /// Cria uma nova turma como professor
  Future<Classroom?> createClassroom({
    required String name,
    required String churchName,
    String? webhookUrl,
  }) async {
    final user = AuthService().currentUser;
    if (user == null) throw Exception('Usuário precisa estar autenticado para criar uma turma.');

    final code = generateClassCode();
    final body = json.encode({
      'code': code,
      'name': name,
      'church_name': churchName,
      'teacher_id': user.id,
      'webhook_url': webhookUrl,
    });

    final resp = await http.post(
      Uri.parse('${AppConfig.authSupabaseUrl}/rest/v1/classrooms'),
      headers: _getHeaders(),
      body: body,
    );

    if (resp.statusCode == 201 || resp.statusCode == 200) {
      final data = json.decode(utf8.decode(resp.bodyBytes));
      final created = Classroom.fromJson(data is List ? data.first : data);
      _currentClassroom = created;
      _isTeacher = true;
      await _saveLocalClassroomCache(created);

      unawaited(GamificationService().unlockCommunityAchievement('membro_turma'));

      try {
        await _upsertClassroomMember(
          classroomId: created.id,
          userId: user.id,
          studentName: '${user.displayName} (Professor)',
        );
      } catch (e) {
        debugPrint('[ClassroomService] Aviso ao vincular professor como membro: $e');
      }

      await syncCurrentActivitySilently();
      await fetchClassroomData();
      unawaited(AuthService().syncPreferencesToCloud());
      notifyListeners();
      return created;
    } else {
      debugPrint('[ClassroomService] Erro ao criar turma (${resp.statusCode}): ${resp.body}');
      String errorMsg = 'Falha ao criar turma (${resp.statusCode})';
      try {
        final errJson = json.decode(utf8.decode(resp.bodyBytes));
        if (errJson is Map && errJson['message'] != null) {
          errorMsg = errJson['message'].toString();
        }
      } catch (_) {}
      throw Exception(errorMsg);
    }
  }

  /// Aluno entra em uma turma usando o código de 6 caracteres
  Future<bool> joinClassroom(String code) async {
    final user = AuthService().currentUser;
    if (user == null) throw Exception('Faça login para entrar em uma turma.');

    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) return false;

    final searchResp = await http.get(
      Uri.parse('${AppConfig.authSupabaseUrl}/rest/v1/classrooms?code=eq.$cleanCode&select=*'),
      headers: _getHeaders(),
    );

    if (searchResp.statusCode != 200) return false;
    final list = json.decode(utf8.decode(searchResp.bodyBytes)) as List;
    if (list.isEmpty) return false;

    final classroom = Classroom.fromJson(list.first as Map<String, dynamic>);
    final isTeacherUser = classroom.teacherId == user.id;

    final memberResp = await _upsertClassroomMember(
      classroomId: classroom.id,
      userId: user.id,
      studentName: isTeacherUser ? '${user.displayName} (Professor)' : user.displayName,
      prefer: 'resolution=merge-duplicates,return=representation',
    );

    if (memberResp.statusCode >= 200 && memberResp.statusCode < 300) {
      _currentClassroom = classroom;
      _isTeacher = isTeacherUser;
      await _saveLocalClassroomCache(classroom);
      unawaited(GamificationService().unlockCommunityAchievement('membro_turma'));
      await syncCurrentActivitySilently();
      await fetchClassroomData();
      unawaited(AuthService().syncPreferencesToCloud());
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Carrega a turma do usuário atual (seja ele aluno ou professor) com cache local e auto-cura.
  Future<void> loadUserClassroom({
    String? fallbackCode,
    Map<String, dynamic>? fallbackClassroomJson,
  }) async {
    final user = AuthService().currentUser;
    await _hydrateFromFallback(
      fallbackClassroomJson: fallbackClassroomJson,
      userId: user?.id,
    );

    if (user == null) return;
    if (_isLoading) return;

    _isLoading = true;
    notifyListeners();

    try {
      // 1. Prioriza o vínculo ativo em `classroom_members` (regra UNIQUE(user_id))
      final memberResp = await http.get(
        Uri.parse(
            '${AppConfig.authSupabaseUrl}/rest/v1/classroom_members?user_id=eq.${user.id}&select=*,classrooms(*)'),
        headers: _getHeaders(),
      );

      if (memberResp.statusCode == 200) {
        final list = json.decode(utf8.decode(memberResp.bodyBytes)) as List;
        if (list.isNotEmpty) {
          final memberItem = list.first as Map<String, dynamic>;
          final rawJoined = memberItem['classrooms'];
          Map<String, dynamic>? crJson;
          if (rawJoined is Map<String, dynamic>) {
            crJson = rawJoined;
          } else if (rawJoined is List && rawJoined.isNotEmpty && rawJoined.first is Map<String, dynamic>) {
            crJson = rawJoined.first as Map<String, dynamic>;
          } else {
            final crId = memberItem['classroom_id']?.toString();
            if (crId != null && crId.isNotEmpty) {
              final crResp = await http.get(
                Uri.parse('${AppConfig.authSupabaseUrl}/rest/v1/classrooms?id=eq.$crId&select=*'),
                headers: _getHeaders(),
              );
              if (crResp.statusCode == 200) {
                final crList = json.decode(utf8.decode(crResp.bodyBytes)) as List;
                if (crList.isNotEmpty && crList.first is Map<String, dynamic>) {
                  crJson = crList.first as Map<String, dynamic>;
                }
              }
            }
          }

          if (crJson != null) {
            final loaded = Classroom.fromJson(crJson);
            _currentClassroom = loaded;
            _isTeacher = loaded.teacherId == user.id;
            await _saveLocalClassroomCache(loaded);
            unawaited(GamificationService().unlockCommunityAchievement('membro_turma'));
            await syncCurrentActivitySilently();
            await fetchClassroomData();
            if (fallbackCode == null || fallbackCode != loaded.code) {
              unawaited(AuthService().syncPreferencesToCloud());
            }
            return;
          }
        }
      }

      // 2. Auto-cura: verifica se o usuário é professor criador de alguma turma
      final teacherResp = await http.get(
        Uri.parse(
            '${AppConfig.authSupabaseUrl}/rest/v1/classrooms?teacher_id=eq.${user.id}&order=created_at.desc&limit=1&select=*'),
        headers: _getHeaders(),
      );

      if (teacherResp.statusCode == 200) {
        final list = json.decode(utf8.decode(teacherResp.bodyBytes)) as List;
        if (list.isNotEmpty) {
          final loaded = Classroom.fromJson(list.first as Map<String, dynamic>);
          _currentClassroom = loaded;
          _isTeacher = true;
          await _saveLocalClassroomCache(loaded);
          unawaited(GamificationService().unlockCommunityAchievement('membro_turma'));
          await syncCurrentActivitySilently();
          await fetchClassroomData();
          if (fallbackCode == null || fallbackCode != loaded.code) {
            unawaited(AuthService().syncPreferencesToCloud());
          }
          return;
        }
      }

      // 3. Auto-cura para aluno: recria vínculo se houver código salvo em metadata ou cache local
      final healCode = (fallbackCode != null && fallbackCode.trim().isNotEmpty)
          ? fallbackCode.trim().toUpperCase()
          : await getCachedClassroomCode();
      if (healCode != null && healCode.isNotEmpty) {
        final healed = await joinClassroom(healCode);
        if (healed) return;
      }
    } catch (e) {
      debugPrint('[ClassroomService] Erro ao carregar turma: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Atualiza a lista de membros e logs de atividade da turma atual
  Future<void> fetchClassroomData() async {
    if (_currentClassroom == null) return;

    try {
      final membersResp = await http.get(
        Uri.parse(
            '${AppConfig.authSupabaseUrl}/rest/v1/classroom_members?classroom_id=eq.${_currentClassroom!.id}&select=*'),
        headers: _getHeaders(),
      );

      if (membersResp.statusCode == 200) {
        final List list = json.decode(utf8.decode(membersResp.bodyBytes));
        _members = list.map((m) => ClassroomMember.fromJson(m as Map<String, dynamic>)).toList();
      }

      final user = AuthService().currentUser;
      if (_isTeacher && user != null && !_members.any((m) => m.userId == user.id)) {
        final teacherMember = ClassroomMember(
          id: 'teacher_${user.id}',
          classroomId: _currentClassroom!.id,
          userId: user.id,
          studentName: '${user.displayName} (Professor)',
          avatarConfig: GamificationService().avatarConfig,
        );
        _members.insert(0, teacherMember);

        unawaited(() async {
          try {
            await _upsertClassroomMember(
              classroomId: _currentClassroom!.id,
              userId: user.id,
              studentName: '${user.displayName} (Professor)',
            );
          } catch (_) {}
        }());
      }

      if (_members.isEmpty) {
        _activityLogs = [];
        return;
      }

      final userIds = _members.map((m) => m.userId).join(',');
      final logsResp = await http.get(
        Uri.parse(
            '${AppConfig.authSupabaseUrl}/rest/v1/member_activity_logs?user_id=in.($userIds)&select=*'),
        headers: _getHeaders(),
      );

      if (logsResp.statusCode == 200) {
        final List list = json.decode(utf8.decode(logsResp.bodyBytes));
        _activityLogs =
            list.map((l) => MemberActivityLog.fromJson(l as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('[ClassroomService] Erro ao buscar dados da classe: $e');
    } finally {
      notifyListeners();
    }
  }

  /// Sincronização em background do progresso diário do usuário logado
  Future<void> syncCurrentActivitySilently({
    int? quizScore,
    bool didQuiz = false,
  }) async {
    final user = AuthService().currentUser;
    if (user == null) return;

    final gamification = GamificationService();
    if (_currentClassroom != null && gamification.isFullFlameActive) {
      unawaited(gamification.unlockCommunityAchievement('chama_comunidade'));
    }

    final todayStr = DateTime.now().toIso8601String().split('T').first;

    final streakTypeStr = gamification.streakFlameType == FlameType.fullFlame
        ? 'full'
        : (gamification.streakFlameType == FlameType.halfFlame ? 'half' : 'none');

    final log = MemberActivityLog(
      userId: user.id,
      activityDate: todayStr,
      minutesWithGod: gamification.todayFocusMinutes,
      missionsCompleted: gamification.completedMissionsCount,
      didDailyQuiz: didQuiz || gamification.mission4LessonQuiz,
      quizScore: quizScore ?? 0,
      streakType: streakTypeStr,
      totalXp: gamification.totalXp,
    );

    try {
      final body = json.encode(log.toJson());
      final resp = await http.post(
        Uri.parse(
            '${AppConfig.authSupabaseUrl}/rest/v1/member_activity_logs?on_conflict=user_id,activity_date'),
        headers: {
          ..._getHeaders(),
          'Prefer': 'resolution=merge-duplicates',
        },
        body: body,
      );
      if (resp.statusCode >= 400) {
        debugPrint(
            '[ClassroomService] Erro ao sincronizar atividade (${resp.statusCode}): ${resp.body}');
      }
    } catch (e) {
      debugPrint('[ClassroomService] Erro ao sincronizar atividade: $e');
    }
  }

  /// Recupera o log de atividade do usuário para a data de hoje diretamente da nuvem
  Future<MemberActivityLog?> fetchTodayUserActivity() async {
    final user = AuthService().currentUser;
    if (user == null) return null;
    final todayStr = DateTime.now().toIso8601String().split('T').first;
    try {
      final resp = await http.get(
        Uri.parse(
            '${AppConfig.authSupabaseUrl}/rest/v1/member_activity_logs?user_id=eq.${user.id}&activity_date=eq.$todayStr&select=*'),
        headers: _getHeaders(),
      );
      if (resp.statusCode == 200) {
        final list = json.decode(utf8.decode(resp.bodyBytes)) as List;
        if (list.isNotEmpty) {
          return MemberActivityLog.fromJson(list.first as Map<String, dynamic>);
        }
      }
    } catch (e) {
      debugPrint('[ClassroomService] Erro ao buscar atividade do usuário: $e');
    }
    return null;
  }

  /// Calcula as estatísticas agregadas por aluno no período filtrado, incluindo
  /// tarefas realizadas, conquistas desbloqueadas e diagnósticos de melhoria.
  List<StudentStatsItem> calculateStudentStats({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final startStr = startDate.toIso8601String().split('T').first;
    final endStr = endDate.toIso8601String().split('T').first;

    final filteredLogs = _activityLogs.where((l) {
      return l.activityDate.compareTo(startStr) >= 0 && l.activityDate.compareTo(endStr) <= 0;
    }).toList();

    final result = _members.map((member) {
      final memberLogs = filteredLogs.where((l) => l.userId == member.userId).toList();
      int totalMinutes = 0;
      int lessonsStudied = 0;
      int quizzes = 0;
      int score = 0;
      int xp = 0;
      int maxMissions = 0;
      bool hasFullStreak = false;
      FlameType flame = FlameType.none;

      for (final log in memberLogs) {
        totalMinutes += log.minutesWithGod;
        if (log.missionsCompleted > 0) lessonsStudied++;
        maxMissions = mathMax(maxMissions, log.missionsCompleted);
        if (log.didDailyQuiz) quizzes++;
        score += log.quizScore;
        xp = mathMax(xp, log.totalXp);
        if (log.streakType == 'full') {
          hasFullStreak = true;
          flame = FlameType.fullFlame;
        } else if (log.streakType == 'half' && flame != FlameType.fullFlame) {
          flame = FlameType.halfFlame;
        }
      }

      // Diagnóstico automático de tarefas concluídas e pontos onde melhorar
      final tasks = <String>[];
      final improvements = <String>[];

      if (lessonsStudied > 0) {
        tasks.add('Estudo ($lessonsStudied d)');
      } else {
        improvements.add('Iniciar leitura diária da lição');
      }

      if (quizzes > 0) {
        tasks.add('Quizzes ($quizzes)');
      } else {
        improvements.add('Realizar o Quiz da Lição');
      }

      if (totalMinutes >= 30) {
        tasks.add('Foco (${totalMinutes}m)');
      } else {
        improvements.add('Dedicar +tempo com Deus (meta 30m+)');
      }

      if (hasFullStreak) {
        tasks.add('Chama Completa');
      } else if (flame == FlameType.halfFlame && maxMissions < 4) {
        improvements.add('Completar Quiz para Chama Completa');
      } else if (flame == FlameType.none) {
        improvements.add('Acender ofensiva na semana');
      }

      final avatar = member.avatarConfig;

      return StudentStatsItem(
        member: member,
        totalMinutes: totalMinutes,
        lessonsStudiedDays: lessonsStudied,
        totalQuizzes: quizzes,
        totalScore: score,
        totalXp: xp,
        currentFlame: flame,
        isFullStreakActive: hasFullStreak,
        completedTasksLabels: tasks,
        improvementPoints: improvements,
        unlockedBadgesCount: avatar.unlockedTrophies.length,
        featuredBadgeId: avatar.featuredBadge,
      );
    }).toList()
      ..sort((a, b) => b.totalXp.compareTo(a.totalXp));

    // Verifica conquista de Top 3 para o usuário atual
    final currentUserId = AuthService().currentUser?.id;
    if (currentUserId != null) {
      for (int i = 0; i < result.length && i < 3; i++) {
        if (result[i].member.userId == currentUserId && result[i].totalXp > 0) {
          unawaited(GamificationService().unlockCommunityAchievement('destaque_turma'));
          break;
        }
      }
    }

    return result;
  }

  static int mathMax(int a, int b) => a > b ? a : b;

  Future<bool> updateWebhookUrl(String url) async {
    if (_currentClassroom == null) return false;

    final resp = await http.patch(
      Uri.parse('${AppConfig.authSupabaseUrl}/rest/v1/classrooms?id=eq.${_currentClassroom!.id}'),
      headers: _getHeaders(),
      body: json.encode({'webhook_url': url}),
    );

    if (resp.statusCode == 200 || resp.statusCode == 204) {
      _currentClassroom = Classroom(
        id: _currentClassroom!.id,
        code: _currentClassroom!.code,
        name: _currentClassroom!.name,
        churchName: _currentClassroom!.churchName,
        teacherId: _currentClassroom!.teacherId,
        webhookUrl: url,
        createdAt: _currentClassroom!.createdAt,
      );
      await _saveLocalClassroomCache(_currentClassroom);
      unawaited(AuthService().syncPreferencesToCloud());
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> leaveClassroom() async {
    final user = AuthService().currentUser;
    if (user == null || _currentClassroom == null) return false;

    try {
      final resp = await http.delete(
        Uri.parse(
            '${AppConfig.authSupabaseUrl}/rest/v1/classroom_members?classroom_id=eq.${_currentClassroom!.id}&user_id=eq.${user.id}'),
        headers: _getHeaders(),
      );

      if (resp.statusCode == 200 || resp.statusCode == 204) {
        _currentClassroom = null;
        _isTeacher = false;
        _members = [];
        _activityLogs = [];
        await _saveLocalClassroomCache(null);
        unawaited(AuthService().syncPreferencesToCloud());
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('[ClassroomService] Erro ao sair da turma: $e');
    }
    return false;
  }

  Future<bool> deleteClassroom() async {
    final user = AuthService().currentUser;
    if (user == null || _currentClassroom == null || !_isTeacher) return false;

    try {
      final resp = await http.delete(
        Uri.parse(
            '${AppConfig.authSupabaseUrl}/rest/v1/classrooms?id=eq.${_currentClassroom!.id}&teacher_id=eq.${user.id}'),
        headers: _getHeaders(),
      );

      if (resp.statusCode == 200 || resp.statusCode == 204) {
        _currentClassroom = null;
        _isTeacher = false;
        _members = [];
        _activityLogs = [];
        await _saveLocalClassroomCache(null);
        unawaited(AuthService().syncPreferencesToCloud());
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('[ClassroomService] Erro ao excluir turma: $e');
    }
    return false;
  }

  Future<bool> updateClassroomDetails({
    required String name,
    required String churchName,
  }) async {
    if (_currentClassroom == null || !_isTeacher) return false;

    try {
      final resp = await http.patch(
        Uri.parse('${AppConfig.authSupabaseUrl}/rest/v1/classrooms?id=eq.${_currentClassroom!.id}'),
        headers: _getHeaders(),
        body: json.encode({
          'name': name.trim(),
          'church_name': churchName.trim(),
        }),
      );

      if (resp.statusCode == 200 || resp.statusCode == 204) {
        _currentClassroom = Classroom(
          id: _currentClassroom!.id,
          code: _currentClassroom!.code,
          name: name.trim(),
          churchName: churchName.trim(),
          teacherId: _currentClassroom!.teacherId,
          webhookUrl: _currentClassroom!.webhookUrl,
          createdAt: _currentClassroom!.createdAt,
        );
        await _saveLocalClassroomCache(_currentClassroom);
        unawaited(AuthService().syncPreferencesToCloud());
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('[ClassroomService] Erro ao atualizar turma: $e');
    }
    return false;
  }

  String getInviteUrl() {
    if (_currentClassroom == null) return '';
    final code = _currentClassroom!.code;
    const officialBase = 'https://lucas2araujo.github.io/Kairos/';
    if (kIsWeb) {
      try {
        final origin = Uri.base.origin;
        var path = Uri.base.path;
        if (!path.endsWith('/')) path = '$path/';
        if (origin.contains('github.io') ||
            origin.contains('localhost') ||
            origin.contains('127.0.0.1')) {
          return '$origin$path?join=$code';
        }
      } catch (_) {}
    }
    return '$officialBase?join=$code';
  }

  String getInviteMessage() {
    if (_currentClassroom == null) return '';
    final cr = _currentClassroom!;
    final link = getInviteUrl();
    return '📖 *Convite para a Classe da Escola Sabatina Kairós!*\n\n'
        'Turma: *${cr.name}*\n'
        'Igreja: *${cr.churchName}*\n'
        'Código da Turma: *${cr.code}*\n\n'
        '👉 Para participar, clique no link abaixo:\n'
        '$link\n\n'
        'Ou abra o app Kairós, acesse a aba "Turmas" e informe o código *${cr.code}*.';
  }

  Future<bool> syncWithGoogleSheetsWebhook({
    required List<StudentStatsItem> stats,
    required String periodName,
  }) async {
    if (_currentClassroom?.webhookUrl == null || _currentClassroom!.webhookUrl!.isEmpty) {
      return false;
    }

    final payload = {
      'timestamp': DateTime.now().toIso8601String(),
      'classroom_name': _currentClassroom!.name,
      'church_name': _currentClassroom!.churchName,
      'code': _currentClassroom!.code,
      'period': periodName,
      'total_students': stats.length,
      'total_hours_with_god':
          (stats.fold<int>(0, (sum, e) => sum + e.totalMinutes) / 60.0).toStringAsFixed(1),
      'students': stats
          .map((s) => {
                'name': s.member.studentName,
                'flame_status': s.currentFlame.name,
                'minutes_with_god': s.totalMinutes,
                'lessons_studied_days': s.lessonsStudiedDays,
                'quiz_score': s.totalScore,
                'total_xp': s.totalXp,
                'completed_tasks': s.completedTasksLabels.join(', '),
                'improvement_points': s.improvementPoints.join(', '),
                'unlocked_badges': s.unlockedBadgesCount,
              })
          .toList(),
    };

    try {
      final resp = await http.post(
        Uri.parse(_currentClassroom!.webhookUrl!),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );
      return resp.statusCode == 200 || resp.statusCode == 302;
    } catch (e) {
      debugPrint('[ClassroomService] Erro ao sincronizar webhook: $e');
      return false;
    }
  }

  /// Gera planilha binária real `.xlsx` (OpenXML) pronta para download direto
  static Uint8List generateExcelXlsxReport({
    required String classroomName,
    required String periodLabel,
    required List<StudentStatsItem> stats,
  }) {
    final headers = [
      'Posição',
      'Nome do Aluno',
      'Chama Atual',
      'Minutos com Deus',
      'Dias Lição Estudada',
      'Quizzes Feitos',
      'Nota Quizzes',
      'Gotas de Azeite (XP)',
      'Conquistas',
      'Tarefas Realizadas',
      'Pontos a Melhorar',
    ];

    final rows = <List<Object?>>[];
    for (int i = 0; i < stats.length; i++) {
      final s = stats[i];
      final flameDesc = s.currentFlame == FlameType.fullFlame
          ? 'Chama Completa'
          : (s.currentFlame == FlameType.halfFlame ? 'Meia Chama' : 'Apagada');
      rows.add([
        i + 1,
        s.member.studentName,
        flameDesc,
        s.totalMinutes,
        s.lessonsStudiedDays,
        s.totalQuizzes,
        s.totalScore,
        s.totalXp,
        s.unlockedBadgesCount,
        s.completedTasksLabels.isEmpty ? 'Nenhuma registrada' : s.completedTasksLabels.join(', '),
        s.improvementPoints.isEmpty ? 'Excelente ritmo!' : s.improvementPoints.join(' | '),
      ]);
    }

    return XlsxBuilder.buildWorkbook(
      sheetName: classroomName,
      metadataLines: [
        'Relatório de Desempenho - Escola Sabatina Kairós',
        'Classe: $classroomName | Período: $periodLabel',
        'Emitido em: ${DateTime.now().toLocal().toString().split('.').first}',
      ],
      headers: headers,
      rows: rows,
    );
  }

  /// Gera relatório CSV com UTF-8 BOM diretamente compatível com Microsoft Excel
  static String generateExcelCsvReport({
    required String classroomName,
    required String periodLabel,
    required List<StudentStatsItem> stats,
  }) {
    final buffer = StringBuffer();
    buffer.write('\uFEFF');

    buffer.writeln('Relatório de Desempenho - Escola Sabatina Kairós');
    buffer.writeln('Classe:;$classroomName');
    buffer.writeln('Período:;$periodLabel');
    buffer.writeln('Data de Emissão:;${DateTime.now().toLocal().toString().split('.').first}');
    buffer.writeln('');

    buffer.writeln(
      'Posição;Nome do Aluno;Chama Atual;Minutos com Deus;Dias Lição Estudada;Quizzes Feitos;Nota Quizzes;Gotas de Azeite (XP);Conquistas;Tarefas Realizadas;Pontos a Melhorar',
    );

    for (int i = 0; i < stats.length; i++) {
      final s = stats[i];
      final flameDesc = s.currentFlame == FlameType.fullFlame
          ? 'Chama Completa'
          : (s.currentFlame == FlameType.halfFlame ? 'Meia Chama' : 'Apagada');
      final tasks =
          s.completedTasksLabels.isEmpty ? '-' : s.completedTasksLabels.join(', ');
      final improve =
          s.improvementPoints.isEmpty ? 'Excelente ritmo' : s.improvementPoints.join(' | ');
      buffer.writeln(
        '${i + 1};"${s.member.studentName}";$flameDesc;${s.totalMinutes};${s.lessonsStudiedDays};${s.totalQuizzes};${s.totalScore};${s.totalXp};${s.unlockedBadgesCount};"$tasks";"$improve"',
      );
    }

    return buffer.toString();
  }

  String _feedCacheKey(String classroomId) => 'classroom_feed_cache_$classroomId';

  Future<void> _saveFeedCache(String classroomId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = json.encode(_feedPosts.map((p) => p.toCacheJson()).toList());
      await prefs.setString(_feedCacheKey(classroomId), encoded);
    } catch (e) {
      debugPrint('[ClassroomService] Aviso ao salvar cache do feed: $e');
    }
  }

  /// Carrega as publicações e reações do Feed da Turma atual (cache local + Supabase).
  Future<void> loadFeed() async {
    final classroom = _currentClassroom;
    if (classroom == null || classroom.id.isEmpty) {
      _feedPosts = [];
      notifyListeners();
      return;
    }

    _isLoadingFeed = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedRaw = prefs.getString(_feedCacheKey(classroom.id));
      if (cachedRaw != null && cachedRaw.isNotEmpty) {
        final decoded = json.decode(cachedRaw);
        if (decoded is List) {
          _feedPosts = decoded
              .whereType<Map>()
              .map((m) => ClassroomFeedPost.fromJson(Map<String, dynamic>.from(m)))
              .toList();
          notifyListeners();
        }
      }
    } catch (_) {}

    final auth = AuthService();
    final supabaseUrl = AppConfig.authSupabaseUrl;
    final supabaseKey = AppConfig.authSupabaseAnonKey;
    final token = auth.accessToken;
    final myUserId = auth.currentUser?.id ?? '';

    if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty && token != null && token.isNotEmpty) {
      try {
        final headers = {
          'apikey': supabaseKey,
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        };
        final postsUri = Uri.parse(
          '$supabaseUrl/rest/v1/classroom_feed_posts?classroom_id=eq.${classroom.id}&order=created_at.desc&limit=40',
        );
        final postsRes = await http.get(postsUri, headers: headers).timeout(const Duration(seconds: 6));
        if (postsRes.statusCode == 200) {
          final rawPosts = json.decode(utf8.decode(postsRes.bodyBytes));
          if (rawPosts is List) {
            final postIds = rawPosts
                .whereType<Map>()
                .map((m) => (m['id'] ?? '').toString())
                .where((id) => id.isNotEmpty)
                .toList();

            final countsByPost = <String, Map<ClassroomReactionType, int>>{};
            final mineByPost = <String, Set<ClassroomReactionType>>{};

            if (postIds.isNotEmpty) {
              final inFilter = postIds.join(',');
              final reactUri = Uri.parse(
                '$supabaseUrl/rest/v1/classroom_feed_reactions?post_id=in.($inFilter)',
              );
              final reactRes = await http.get(reactUri, headers: headers).timeout(const Duration(seconds: 6));
              if (reactRes.statusCode == 200) {
                final rawReacts = json.decode(utf8.decode(reactRes.bodyBytes));
                if (rawReacts is List) {
                  for (final item in rawReacts.whereType<Map>()) {
                    final postId = (item['post_id'] ?? '').toString();
                    final rType = ClassroomReactionType.fromName((item['reaction_type'] ?? '').toString());
                    final uid = (item['user_id'] ?? '').toString();
                    if (postId.isEmpty || rType == null) continue;
                    countsByPost.putIfAbsent(postId, () => {});
                    countsByPost[postId]![rType] = (countsByPost[postId]![rType] ?? 0) + 1;
                    if (myUserId.isNotEmpty && uid == myUserId) {
                      mineByPost.putIfAbsent(postId, () => {});
                      mineByPost[postId]!.add(rType);
                    }
                  }
                }
              }
            }

            _feedPosts = rawPosts.whereType<Map>().map((m) {
              final map = Map<String, dynamic>.from(m);
              final pid = (map['id'] ?? '').toString();
              return ClassroomFeedPost.fromJson(
                map,
                reactionCounts: countsByPost[pid] ?? const {},
                myReactions: mineByPost[pid] ?? const {},
              );
            }).toList();
            await _saveFeedCache(classroom.id);
          }
        }
      } catch (e) {
        debugPrint('[ClassroomService] Aviso ao carregar feed do Supabase: $e');
      }
    }

    _isLoadingFeed = false;
    notifyListeners();
  }

  /// Publica uma conquista ou marco no Feed da Turma atual.
  Future<bool> publishFeedPost({
    required String title,
    String subtitle = '',
    String achievementType = 'milestone',
  }) async {
    final classroom = _currentClassroom;
    if (classroom == null || classroom.id.isEmpty) return false;

    final auth = AuthService();
    final user = auth.currentUser;
    final userId = user?.id ?? 'local_user';
    final authorName = (user?.name != null && user!.name!.trim().isNotEmpty)
        ? user.name!.trim()
        : (user?.email.split('@').first ?? 'Colega Kairós');

    final localPost = ClassroomFeedPost(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      classroomId: classroom.id,
      userId: userId,
      authorName: authorName,
      achievementType: achievementType,
      title: title.trim(),
      subtitle: subtitle.trim(),
      createdAt: DateTime.now(),
    );

    _feedPosts = [localPost, ..._feedPosts];
    notifyListeners();
    await _saveFeedCache(classroom.id);

    final supabaseUrl = AppConfig.authSupabaseUrl;
    final supabaseKey = AppConfig.authSupabaseAnonKey;
    final token = auth.accessToken;
    if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty && token != null && token.isNotEmpty) {
      try {
        final uri = Uri.parse('$supabaseUrl/rest/v1/classroom_feed_posts');
        final res = await http.post(
          uri,
          headers: {
            'apikey': supabaseKey,
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Prefer': 'return=representation',
          },
          body: json.encode({
            'classroom_id': classroom.id,
            'user_id': userId,
            'author_name': authorName,
            'achievement_type': achievementType,
            'title': title.trim(),
            'subtitle': subtitle.trim(),
          }),
        ).timeout(const Duration(seconds: 6));

        if (res.statusCode == 200 || res.statusCode == 201) {
          final decoded = json.decode(utf8.decode(res.bodyBytes));
          if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
            final synced = ClassroomFeedPost.fromJson(Map<String, dynamic>.from(decoded.first as Map));
            _feedPosts = [synced, ..._feedPosts.where((p) => p.id != localPost.id)];
            notifyListeners();
            await _saveFeedCache(classroom.id);
          }
        }
      } catch (e) {
        debugPrint('[ClassroomService] Aviso ao publicar post no Supabase: $e');
      }
    }
    return true;
  }

  /// Alterna uma reação rápida em um post do Feed da Turma.
  Future<void> toggleReaction(String postId, ClassroomReactionType reaction) async {
    final idx = _feedPosts.indexWhere((p) => p.id == postId);
    if (idx == -1) return;

    final post = _feedPosts[idx];
    final nextCounts = Map<ClassroomReactionType, int>.from(post.reactionCounts);
    final nextMine = Set<ClassroomReactionType>.from(post.myReactions);
    final wasActive = nextMine.contains(reaction);

    if (wasActive) {
      nextMine.remove(reaction);
      final updated = (nextCounts[reaction] ?? 1) - 1;
      if (updated <= 0) {
        nextCounts.remove(reaction);
      } else {
        nextCounts[reaction] = updated;
      }
    } else {
      nextMine.add(reaction);
      nextCounts[reaction] = (nextCounts[reaction] ?? 0) + 1;
    }

    _feedPosts[idx] = post.copyWith(
      reactionCounts: nextCounts,
      myReactions: nextMine,
    );
    notifyListeners();

    final classroom = _currentClassroom;
    if (classroom != null) {
      await _saveFeedCache(classroom.id);
    }

    if (postId.startsWith('local_')) return;

    final auth = AuthService();
    final supabaseUrl = AppConfig.authSupabaseUrl;
    final supabaseKey = AppConfig.authSupabaseAnonKey;
    final token = auth.accessToken;
    final userId = auth.currentUser?.id;

    if (supabaseUrl.isNotEmpty &&
        supabaseKey.isNotEmpty &&
        token != null &&
        token.isNotEmpty &&
        userId != null &&
        userId.isNotEmpty) {
      try {
        final headers = {
          'apikey': supabaseKey,
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        };
        if (wasActive) {
          final uri = Uri.parse(
            '$supabaseUrl/rest/v1/classroom_feed_reactions?post_id=eq.$postId&user_id=eq.$userId&reaction_type=eq.${reaction.name}',
          );
          await http.delete(uri, headers: headers).timeout(const Duration(seconds: 5));
        } else {
          final uri = Uri.parse('$supabaseUrl/rest/v1/classroom_feed_reactions');
          await http.post(
            uri,
            headers: headers,
            body: json.encode({
              'post_id': postId,
              'user_id': userId,
              'reaction_type': reaction.name,
            }),
          ).timeout(const Duration(seconds: 5));
        }
      } catch (e) {
        debugPrint('[ClassroomService] Aviso ao sincronizar reação: $e');
      }
    }
  }

  static const String googleAppsScriptTemplate = r'''
function doPost(e) {
  try {
    var data = JSON.parse(e.postData.contents);
    var ss = SpreadsheetApp.getActiveSpreadsheet();
    var sheet = ss.getSheetByName("Relatorio_Kairos");
    
    if (!sheet) {
      sheet = ss.insertSheet("Relatorio_Kairos");
      sheet.appendRow(["Data/Hora", "Classe", "Período", "Aluno", "Status da Chama", "Minutos com Deus", "Dias de Lição", "Nota no Quiz", "Total XP"]);
      sheet.getRange(1, 1, 1, 9).setFontWeight("bold").setBackground("#4A148C").setFontColor("#FFFFFF");
    }
    
    var timestamp = new Date();
    var students = data.students || [];
    
    for (var i = 0; i < students.length; i++) {
      var s = students[i];
      sheet.appendRow([
        timestamp,
        data.classroom_name,
        data.period,
        s.name,
        s.flame_status,
        s.minutes_with_god,
        s.lessons_studied_days,
        s.quiz_score,
        s.total_xp
      ]);
    }
    
    return ContentService.createTextOutput(JSON.stringify({ status: "ok", inserted: students.length }))
      .setMimeType(ContentService.MimeType.JSON);
  } catch (err) {
    return ContentService.createTextOutput(JSON.stringify({ status: "error", message: err.toString() }))
      .setMimeType(ContentService.MimeType.JSON);
  }
}
''';
}
