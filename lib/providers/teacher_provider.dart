import 'package:flutter/foundation.dart';

import '../models/attendance_record.dart';
import '../models/leave_request.dart';
import '../models/student_alert.dart';
import '../services/supabase_service.dart';

/// 教师/管理者数据状态提供者
///
/// 管理待审批请假、学生预警、考勤记录等教师端数据。
class TeacherProvider extends ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService.instance;

  static const String _maintenanceMessage = '服务维护中，请稍后再试';

  // ==================== 教师模式 ====================

  bool _isTeacherMode = false;

  bool get isTeacherMode => _isTeacherMode;

  void toggleTeacherMode() {
    _isTeacherMode = !_isTeacherMode;
    notifyListeners();
  }

  // ==================== 待审批请假 ====================

  List<LeaveRequest> _pendingApprovals = [];
  bool _pendingApprovalsLoading = false;
  String? _pendingApprovalsError;

  List<LeaveRequest> get pendingApprovals => _pendingApprovals;
  bool get pendingApprovalsLoading => _pendingApprovalsLoading;
  String? get pendingApprovalsError => _pendingApprovalsError;

  /// Fetches pending leave requests for approval.
  Future<void> fetchPendingApprovals() async {
    _pendingApprovalsLoading = true;
    _pendingApprovalsError = null;
    notifyListeners();

    try {
      final data = await _supabaseService.getPendingApprovals();
      _pendingApprovals = data.map((j) => LeaveRequest.fromJson(j)).toList();
    } on SupabaseNotConfiguredException {
      _pendingApprovalsError = _maintenanceMessage;
    } catch (e) {
      _pendingApprovalsError = '获取待审批列表失败，请稍后再试';
    } finally {
      _pendingApprovalsLoading = false;
      notifyListeners();
    }
  }

  /// Approves a leave request by [id].
  Future<void> approveRequest(String id) async {
    try {
      await _supabaseService.approveLeaveRequest(id);
      _pendingApprovals.removeWhere((r) => r.id == id);
      notifyListeners();
    } on SupabaseNotConfiguredException {
      _pendingApprovalsError = _maintenanceMessage;
      notifyListeners();
    } catch (e) {
      _pendingApprovalsError = '审批操作失败，请稍后再试';
      notifyListeners();
    }
  }

  /// Rejects a leave request by [id] with an optional [comment].
  Future<void> rejectRequest(String id, String comment) async {
    try {
      await _supabaseService.rejectLeaveRequest(id, comment);
      _pendingApprovals.removeWhere((r) => r.id == id);
      notifyListeners();
    } on SupabaseNotConfiguredException {
      _pendingApprovalsError = _maintenanceMessage;
      notifyListeners();
    } catch (e) {
      _pendingApprovalsError = '审批操作失败，请稍后再试';
      notifyListeners();
    }
  }

  // ==================== 学生预警 ====================

  List<StudentAlert> _studentAlerts = [];
  bool _studentAlertsLoading = false;
  String? _studentAlertsError;

  List<StudentAlert> get studentAlerts => _studentAlerts;
  bool get studentAlertsLoading => _studentAlertsLoading;
  String? get studentAlertsError => _studentAlertsError;

  /// Fetches student alerts.
  Future<void> fetchStudentAlerts() async {
    _studentAlertsLoading = true;
    _studentAlertsError = null;
    notifyListeners();

    try {
      final data = await _supabaseService.getStudentAlerts();
      _studentAlerts = data.map((j) => StudentAlert.fromJson(j)).toList();
    } on SupabaseNotConfiguredException {
      _studentAlertsError = _maintenanceMessage;
    } catch (e) {
      _studentAlertsError = '获取学生预警失败，请稍后再试';
    } finally {
      _studentAlertsLoading = false;
      notifyListeners();
    }
  }

  // ==================== 考勤记录 ====================

  List<AttendanceRecord> _attendanceRecords = [];
  bool _attendanceRecordsLoading = false;
  String? _attendanceRecordsError;

  List<AttendanceRecord> get attendanceRecords => _attendanceRecords;
  bool get attendanceRecordsLoading => _attendanceRecordsLoading;
  String? get attendanceRecordsError => _attendanceRecordsError;

  /// Fetches attendance records for [courseId].
  Future<void> fetchAttendanceRecords(String courseId) async {
    _attendanceRecordsLoading = true;
    _attendanceRecordsError = null;
    notifyListeners();

    try {
      final data = await _supabaseService.getAttendanceRecords(courseId);
      _attendanceRecords =
          data.map((j) => AttendanceRecord.fromJson(j)).toList();
    } on SupabaseNotConfiguredException {
      _attendanceRecordsError = _maintenanceMessage;
    } catch (e) {
      _attendanceRecordsError = '获取考勤记录失败，请稍后再试';
    } finally {
      _attendanceRecordsLoading = false;
      notifyListeners();
    }
  }

  /// Submits attendance records for [courseId].
  Future<void> submitAttendance(
    String courseId,
    List<Map<String, dynamic>> records,
  ) async {
    _attendanceRecordsLoading = true;
    _attendanceRecordsError = null;
    notifyListeners();

    try {
      await _supabaseService.submitAttendanceRecords(records);
    } on SupabaseNotConfiguredException {
      _attendanceRecordsError = _maintenanceMessage;
      _attendanceRecordsLoading = false;
      notifyListeners();
      return;
    } catch (e) {
      _attendanceRecordsError = '提交考勤失败，请稍后再试';
      _attendanceRecordsLoading = false;
      notifyListeners();
      return;
    }

    _attendanceRecordsLoading = false;
    notifyListeners();

    await fetchAttendanceRecords(courseId);
  }
}
