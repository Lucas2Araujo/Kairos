import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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

class ClassroomService extends ChangeNotifier {
  static final ClassroomService _instance = ClassroomService._internal();
  factory ClassroomService() => _instance;
  ClassroomService._internal();

  Classroom? _currentClassroom;
  bool _isTeacher = false;
  List<ClassroomMember> _members = [];
  List<MemberActivityLog> _activityLogs = [];
  bool _isLoading = false;

  Classroom? get currentClassroom => _currentClassroom;
  bool get isTeacher => _isTeacher;
  List<ClassroomMember> get members => _members;
  List<MemberActivityLog> get activityLogs => _activityLogs;
  bool get isLoading => _isLoading;

  @visibleForTesting
  void setTestClassroom(Classroom? cr, {List<ClassroomMember>? members, List<MemberActivityLog>? logs}) {
    _currentClassroom = cr;
    if (members != null) _members = members;
    if (logs != null) _activityLogs = logs;
    notifyListeners();
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
      final data = json.decode(resp.body);
      final created = Classroom.fromJson(data is List ? data.first : data);
      _currentClassroom = created;
      _isTeacher = true;

      unawaited(GamificationService().unlockCommunityAchievement('membro_turma'));

      try {
        final avatarJson = GamificationService().avatarConfig.toJson();
        await http.post(
          Uri.parse('${AppConfig.authSupabaseUrl}/rest/v1/classroom_members'),
          headers: {
            ..._getHeaders(),
            'Prefer': 'resolution=merge-duplicates',
          },
          body: json.encode({
            'classroom_id': created.id,
            'user_id': user.id,
            'student_name': '${user.displayName} (Professor)',
            'avatar_config_json': avatarJson,
          }),
        );
      } catch (e) {
        debugPrint('[ClassroomService] Aviso ao vincular professor como membro: $e');
      }

      await fetchClassroomData();
      notifyListeners();
      return created;
    } else {
      debugPrint('[ClassroomService] Erro ao criar turma (${resp.statusCode}): ${resp.body}');
      String errorMsg = 'Falha ao criar turma (${resp.statusCode})';
      try {
        final errJson = json.decode(resp.body);
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

    final searchResp = await http.get(
      Uri.parse('${AppConfig.authSupabaseUrl}/rest/v1/classrooms?code=eq.$cleanCode&select=*'),
      headers: _getHeaders(),
    );

    if (searchResp.statusCode != 200) return false;
    final list = json.decode(searchResp.body) as List;
    if (list.isEmpty) return false;

    final classroom = Classroom.fromJson(list.first);

    final avatarJson = GamificationService().avatarConfig.toJson();
    final memberBody = json.encode({
      'classroom_id': classroom.id,
      'user_id': user.id,
      'student_name': user.displayName,
      'avatar_config_json': avatarJson,
    });

    final memberResp = await http.post(
      Uri.parse('${AppConfig.authSupabaseUrl}/rest/v1/classroom_members'),
      headers: {
        ..._getHeaders(),
        'Prefer': 'resolution=merge-duplicates,return=representation',
      },
      body: memberBody,
    );

    if (memberResp.statusCode == 201 || memberResp.statusCode == 200) {
      _currentClassroom = classroom;
      _isTeacher = classroom.teacherId == user.id;
      unawaited(GamificationService().unlockCommunityAchievement('membro_turma'));
      await fetchClassroomData();
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Carrega a turma do usuário atual (seja ele aluno ou professor)
  Future<void> loadUserClassroom() async {
    final user = AuthService().currentUser;
    if (user == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final teacherResp = await http.get(
        Uri.parse(
            '${AppConfig.authSupabaseUrl}/rest/v1/classrooms?teacher_id=eq.${user.id}&select=*'),
        headers: _getHeaders(),
      );

      if (teacherResp.statusCode == 200) {
        final list = json.decode(teacherResp.body) as List;
        if (list.isNotEmpty) {
          _currentClassroom = Classroom.fromJson(list.first);
          _isTeacher = true;
          unawaited(GamificationService().unlockCommunityAchievement('membro_turma'));
          await fetchClassroomData();
          return;
        }
      }

      final memberResp = await http.get(
        Uri.parse(
            '${AppConfig.authSupabaseUrl}/rest/v1/classroom_members?user_id=eq.${user.id}&select=*,classrooms(*)'),
        headers: _getHeaders(),
      );

      if (memberResp.statusCode == 200) {
        final list = json.decode(memberResp.body) as List;
        if (list.isNotEmpty) {
          final memberItem = list.first as Map<String, dynamic>;
          final crJson = memberItem['classrooms'];
          if (crJson is Map<String, dynamic>) {
            _currentClassroom = Classroom.fromJson(crJson);
            _isTeacher = false;
            unawaited(GamificationService().unlockCommunityAchievement('membro_turma'));
            await fetchClassroomData();
            return;
          }
        }
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
        final List list = json.decode(membersResp.body);
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
            await http.post(
              Uri.parse('${AppConfig.authSupabaseUrl}/rest/v1/classroom_members'),
              headers: {
                ..._getHeaders(),
                'Prefer': 'resolution=merge-duplicates',
              },
              body: json.encode({
                'classroom_id': _currentClassroom!.id,
                'user_id': user.id,
                'student_name': '${user.displayName} (Professor)',
                'avatar_config_json': GamificationService().avatarConfig.toJson(),
              }),
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
        final List list = json.decode(logsResp.body);
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
