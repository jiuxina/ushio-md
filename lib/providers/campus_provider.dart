import 'package:flutter/foundation.dart';

import '../models/announcement.dart';
import '../models/community_post.dart';
import '../models/course.dart';
import '../models/leave_request.dart';
import '../models/venue.dart';
import '../models/venue_booking.dart';
import '../services/supabase_service.dart';

/// 校园数据状态提供者
///
/// 管理公告、课程、请假、社区帖子和场馆等校园数据。
class CampusProvider extends ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService.instance;

  static const String _maintenanceMessage = '服务维护中，请稍后再试';

  // ==================== 公告 ====================

  List<Announcement> _announcements = [];
  bool _announcementsLoading = false;
  String? _announcementsError;

  List<Announcement> get announcements => _announcements;
  bool get announcementsLoading => _announcementsLoading;
  String? get announcementsError => _announcementsError;

  /// Fetches announcements from the backend.
  Future<void> fetchAnnouncements() async {
    _announcementsLoading = true;
    _announcementsError = null;
    notifyListeners();

    try {
      final data = await _supabaseService.getAnnouncements();
      _announcements = data.map((j) => Announcement.fromJson(j)).toList();
    } on SupabaseNotConfiguredException {
      _announcementsError = _maintenanceMessage;
    } catch (e) {
      _announcementsError = '获取公告失败，请稍后再试';
    } finally {
      _announcementsLoading = false;
      notifyListeners();
    }
  }

  // ==================== 课程 ====================

  List<Course> _courses = [];
  bool _coursesLoading = false;
  String? _coursesError;

  List<Course> get courses => _courses;
  bool get coursesLoading => _coursesLoading;
  String? get coursesError => _coursesError;

  /// Fetches courses for the given [userId].
  Future<void> fetchCourses(String userId) async {
    _coursesLoading = true;
    _coursesError = null;
    notifyListeners();

    try {
      final data = await _supabaseService.getCoursesForUser(userId);
      _courses = data.map((j) => Course.fromJson(j)).toList();
    } on SupabaseNotConfiguredException {
      _coursesError = _maintenanceMessage;
    } catch (e) {
      _coursesError = '获取课程失败，请稍后再试';
    } finally {
      _coursesLoading = false;
      notifyListeners();
    }
  }

  // ==================== 请假 ====================

  List<LeaveRequest> _leaveRequests = [];
  bool _leaveRequestsLoading = false;
  String? _leaveRequestsError;

  List<LeaveRequest> get leaveRequests => _leaveRequests;
  bool get leaveRequestsLoading => _leaveRequestsLoading;
  String? get leaveRequestsError => _leaveRequestsError;

  /// Fetches leave requests for the given [userId].
  Future<void> fetchLeaveRequests(String userId) async {
    _leaveRequestsLoading = true;
    _leaveRequestsError = null;
    notifyListeners();

    try {
      final data = await _supabaseService.getLeaveRequests(userId);
      _leaveRequests = data.map((j) => LeaveRequest.fromJson(j)).toList();
    } on SupabaseNotConfiguredException {
      _leaveRequestsError = _maintenanceMessage;
    } catch (e) {
      _leaveRequestsError = '获取请假记录失败，请稍后再试';
    } finally {
      _leaveRequestsLoading = false;
      notifyListeners();
    }
  }

  /// Creates a new leave request and refreshes the list.
  Future<void> createLeaveRequest(Map<String, dynamic> data) async {
    _leaveRequestsLoading = true;
    _leaveRequestsError = null;
    notifyListeners();

    try {
      final result = await _supabaseService.createLeaveRequest(data);
      _leaveRequests.insert(0, LeaveRequest.fromJson(result));
    } on SupabaseNotConfiguredException {
      _leaveRequestsError = _maintenanceMessage;
    } catch (e) {
      _leaveRequestsError = '提交请假申请失败，请稍后再试';
    } finally {
      _leaveRequestsLoading = false;
      notifyListeners();
    }
  }

  // ==================== 社区帖子 ====================

  List<CommunityPost> _communityPosts = [];
  bool _communityPostsLoading = false;
  String? _communityPostsError;

  List<CommunityPost> get communityPosts => _communityPosts;
  bool get communityPostsLoading => _communityPostsLoading;
  String? get communityPostsError => _communityPostsError;

  /// Fetches community posts.
  Future<void> fetchCommunityPosts() async {
    _communityPostsLoading = true;
    _communityPostsError = null;
    notifyListeners();

    try {
      final data = await _supabaseService.getCommunityPosts();
      _communityPosts = data.map((j) => CommunityPost.fromJson(j)).toList();
    } on SupabaseNotConfiguredException {
      _communityPostsError = _maintenanceMessage;
    } catch (e) {
      _communityPostsError = '获取社区帖子失败，请稍后再试';
    } finally {
      _communityPostsLoading = false;
      notifyListeners();
    }
  }

  /// Creates a new community post and prepends it to the list.
  Future<void> createCommunityPost(Map<String, dynamic> data) async {
    _communityPostsLoading = true;
    _communityPostsError = null;
    notifyListeners();

    try {
      final result = await _supabaseService.createCommunityPost(data);
      _communityPosts.insert(0, CommunityPost.fromJson(result));
    } on SupabaseNotConfiguredException {
      _communityPostsError = _maintenanceMessage;
    } catch (e) {
      _communityPostsError = '发布帖子失败，请稍后再试';
    } finally {
      _communityPostsLoading = false;
      notifyListeners();
    }
  }

  // ==================== 场馆 ====================

  List<Venue> _venues = [];
  bool _venuesLoading = false;
  String? _venuesError;

  List<Venue> get venues => _venues;
  bool get venuesLoading => _venuesLoading;
  String? get venuesError => _venuesError;

  /// Fetches available venues.
  Future<void> fetchVenues() async {
    _venuesLoading = true;
    _venuesError = null;
    notifyListeners();

    try {
      final data = await _supabaseService.getVenues();
      _venues = data.map((j) => Venue.fromJson(j)).toList();
    } on SupabaseNotConfiguredException {
      _venuesError = _maintenanceMessage;
    } catch (e) {
      _venuesError = '获取场馆信息失败，请稍后再试';
    } finally {
      _venuesLoading = false;
      notifyListeners();
    }
  }

  /// Books a venue by inserting a booking record.
  Future<VenueBooking?> bookVenue(Map<String, dynamic> data) async {
    _venuesLoading = true;
    _venuesError = null;
    notifyListeners();

    try {
      final response = await _supabaseService.createVenueBooking(data);
      return VenueBooking.fromJson(response);
    } on SupabaseNotConfiguredException {
      _venuesError = _maintenanceMessage;
      return null;
    } catch (e) {
      _venuesError = '场馆预约失败，请稍后再试';
      return null;
    } finally {
      _venuesLoading = false;
      notifyListeners();
    }
  }
}
