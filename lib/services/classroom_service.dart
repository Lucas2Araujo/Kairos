import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/config/app_config.dart';
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
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
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
      joinedAt: json['joined_at'] != null ? DateTime.tryParse(json['joined_at'].toString()) : null,
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

/// DTO agregado para visualização de desempenho individual e pódio de alunos
class StudentStatsItem {
  final ClassroomMember member;
  final int totalMinutes;
  final int lessonsStudiedDays;
  final int totalQuizzes;
  final int totalScore;
  final int totalXp;
  final FlameType currentFlame;
  final bool isFullStreakActive;

  const StudentStatsItem({
    required this.member,
    required this.totalMinutes,
    required this.lessonsStudiedDays,
    required this.totalQuizzes,
    required this.totalScore,
    required this.totalXp,
    required this.currentFlame,
    required this.isFullStreakActive,
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

    // 1. Busca a turma pelo código
    final searchResp = await http.get(
      Uri.parse('${AppConfig.authSupabaseUrl}/rest/v1/classrooms?code=eq.$cleanCode&select=*'),
      headers: _getHeaders(),
    );

    if (searchResp.statusCode != 200) return false;
    final list = json.decode(searchResp.body) as List;
    if (list.isEmpty) return false;

    final classroom = Classroom.fromJson(list.first);

    // 2. Insere ou atualiza o membro (UNIQUE user_id garante 1 turma por aluno)
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
      // Verifica se é professor
      final teacherResp = await http.get(
        Uri.parse('${AppConfig.authSupabaseUrl}/rest/v1/classrooms?teacher_id=eq.${user.id}&select=*'),
        headers: _getHeaders(),
      );

      if (teacherResp.statusCode == 200) {
        final list = json.decode(teacherResp.body) as List;
        if (list.isNotEmpty) {
          _currentClassroom = Classroom.fromJson(list.first);
          _isTeacher = true;
          await fetchClassroomData();
          return;
        }
      }

      // Se não for professor, verifica se é membro de alguma turma
      final memberResp = await http.get(
        Uri.parse('${AppConfig.authSupabaseUrl}/rest/v1/classroom_members?user_id=eq.${user.id}&select=*,classrooms(*)'),
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
      // 1. Busca os membros da turma
      final membersResp = await http.get(
        Uri.parse('${AppConfig.authSupabaseUrl}/rest/v1/classroom_members?classroom_id=eq.${_currentClassroom!.id}&select=*'),
        headers: _getHeaders(),
      );

      if (membersResp.statusCode == 200) {
        final List list = json.decode(membersResp.body);
        _members = list.map((m) => ClassroomMember.fromJson(m as Map<String, dynamic>)).toList();
      }

      if (_members.isEmpty) {
        _activityLogs = [];
        return;
      }

      // 2. Busca os logs de atividade dos membros
      final userIds = _members.map((m) => m.userId).join(',');
      final logsResp = await http.get(
        Uri.parse('${AppConfig.authSupabaseUrl}/rest/v1/member_activity_logs?user_id=in.($userIds)&select=*'),
        headers: _getHeaders(),
      );

      if (logsResp.statusCode == 200) {
        final List list = json.decode(logsResp.body);
        _activityLogs = list.map((l) => MemberActivityLog.fromJson(l as Map<String, dynamic>)).toList();
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
      await http.post(
        Uri.parse('${AppConfig.authSupabaseUrl}/rest/v1/member_activity_logs'),
        headers: {
          ..._getHeaders(),
          'Prefer': 'resolution=merge-duplicates',
        },
        body: body,
      );
    } catch (e) {
      debugPrint('[ClassroomService] Erro ao sincronizar atividade: $e');
    }
  }

  /// Calcula as estatísticas agregadas por aluno no período filtrado
  List<StudentStatsItem> calculateStudentStats({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final startStr = startDate.toIso8601String().split('T').first;
    final endStr = endDate.toIso8601String().split('T').first;

    final filteredLogs = _activityLogs.where((l) {
      return l.activityDate.compareTo(startStr) >= 0 && l.activityDate.compareTo(endStr) <= 0;
    }).toList();

    return _members.map((member) {
      final memberLogs = filteredLogs.where((l) => l.userId == member.userId).toList();
      int totalMinutes = 0;
      int lessonsStudied = 0;
      int quizzes = 0;
      int score = 0;
      int xp = 0;
      bool hasFullStreak = false;
      FlameType flame = FlameType.none;

      for (final log in memberLogs) {
        totalMinutes += log.minutesWithGod;
        if (log.missionsCompleted > 0) lessonsStudied++;
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

      return StudentStatsItem(
        member: member,
        totalMinutes: totalMinutes,
        lessonsStudiedDays: lessonsStudied,
        totalQuizzes: quizzes,
        totalScore: score,
        totalXp: xp,
        currentFlame: flame,
        isFullStreakActive: hasFullStreak,
      );
    }).toList()
      ..sort((a, b) => b.totalXp.compareTo(a.totalXp));
  }

  static int mathMax(int a, int b) => a > b ? a : b;

  /// Atualiza a URL do webhook do Google Apps Script
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

  /// Envia payload completo via Webhook para a planilha do Google Sheets
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
      'total_hours_with_god': (stats.fold<int>(0, (sum, e) => sum + e.totalMinutes) / 60.0).toStringAsFixed(1),
      'students': stats.map((s) => {
        'name': s.member.studentName,
        'flame_status': s.currentFlame.name,
        'minutes_with_god': s.totalMinutes,
        'lessons_studied_days': s.lessonsStudiedDays,
        'quiz_score': s.totalScore,
        'total_xp': s.totalXp,
      }).toList(),
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

  /// Gera relatório CSV com UTF-8 BOM diretamente compatível com Microsoft Excel
  static String generateExcelCsvReport({
    required String classroomName,
    required String periodLabel,
    required List<StudentStatsItem> stats,
  }) {
    final buffer = StringBuffer();
    // UTF-8 BOM para garantir acentos corretos no Excel
    buffer.write('\uFEFF');

    buffer.writeln('Relatório de Desempenho - Escola Sabatina Kairós');
    buffer.writeln('Classe:;$classroomName');
    buffer.writeln('Período:;$periodLabel');
    buffer.writeln('Data de Emissão:;${DateTime.now().toLocal().toString().split('.').first}');
    buffer.writeln('');

    buffer.writeln('Posição;Nome do Aluno;Chama Atual;Minutos com Deus;Dias Lição Estudada;Nota Quizzes;Gotas de Azeite (XP)');

    for (int i = 0; i < stats.length; i++) {
      final s = stats[i];
      final flameDesc = s.currentFlame == FlameType.fullFlame
          ? 'Chama Completa'
          : (s.currentFlame == FlameType.halfFlame ? 'Meia Chama' : 'Apagada');
      buffer.writeln(
        '${i + 1};"${s.member.studentName}";$flameDesc;${s.totalMinutes};${s.lessonsStudiedDays};${s.totalScore};${s.totalXp}',
      );
    }

    return buffer.toString();
  }

  /// Código Google Apps Script pronto para automação no Google Planilhas
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
    
    return ContentService.createTextOutput(JSON.stringify({status: "success", count: students.length}))
      .setMimeType(ContentService.MimeType.JSON);
  } catch (err) {
    return ContentService.createTextOutput(JSON.stringify({status: "error", message: err.toString()}))
      .setMimeType(ContentService.MimeType.JSON);
  }
}
''';
}
