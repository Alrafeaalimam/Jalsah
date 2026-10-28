// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System
// File: lib/screens/router_detail_screen.dart
// Screen: Router Details, Live Diagnostics, HotSpot Users & Active Sessions
// Master Reference: Rule 16 (Clean Architecture), Rule 23 (Error Handling)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/router_model.dart';
import '../services/api_client.dart';
import '../services/mikrotik_discovery_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_error_state.dart';
import '../widgets/app_loading_state.dart';
import '../widgets/pressable_neumorphic_card.dart';
import '../widgets/pulsing_dot.dart';
import 'add_router_screen.dart';

class RouterDetailScreen extends StatefulWidget {
  final RouterModel router;

  const RouterDetailScreen({super.key, required this.router});

  @override
  State<RouterDetailScreen> createState() => _RouterDetailScreenState();
}

class _RouterDetailScreenState extends State<RouterDetailScreen>
    with SingleTickerProviderStateMixin {
  late RouterModel _router;
  late TabController _tabController;

  // Diagnostics state
  bool _isTestingConnection = false;
  String? _testSuccessMessage;
  String? _testErrorMessage;

  // HotSpot Users state
  bool _isLoadingUsers = true;
  String? _usersError;
  List<Map<String, dynamic>> _hotspotUsers = [];
  String _userSearchQuery = '';

  // Active Sessions state
  bool _isLoadingSessions = true;
  String? _sessionsError;
  List<Map<String, dynamic>> _activeSessions = [];

  @override
  void initState() {
    super.initState();
    _router = widget.router;
    _tabController = TabController(length: 2, vsync: this);
    _initScreen();
  }

  Future<void> _initScreen() async {
    if (MikrotikDiscoveryService.isLocalPrivateIp(_router.host)) {
      await _verifyInitialConnectionOnOpen();
    }
    _loadHotspotUsers();
    _loadActiveSessions();
  }

  /// Automatically probes and verifies local router connection when screen opens.
  Future<void> _verifyInitialConnectionOnOpen() async {
    final creds = await MikrotikDiscoveryService.getRouterCredentials(_router.id);
    if (creds == null ||
        creds['username'] == null ||
        creds['username']!.isEmpty ||
        creds['password'] == null ||
        creds['password']!.isEmpty) {
      return;
    }

    try {
      final testResult = await MikrotikDiscoveryService.testDirectConnection(
        host: _router.host,
        port: _router.apiPort,
        username: creds['username']!,
        password: creds['password']!,
        connectionMethod: _router.connectionMethod,
      );

      if (!mounted) return;

      if (testResult['success'] == true) {
        final data = testResult['data'] as Map<String, dynamic>?;
        final newVersion = (data?['version'] as String?)?.trim() ?? _router.routerOsVersion;
        final newBoard = (data?['boardName'] as String?)?.trim() ?? _router.boardModel;
        final cpu = (data?['cpuLoad'] as num?)?.toInt() ?? _router.cpuLoadPercentage;
        final uptime = (data?['uptimeSeconds'] as num?)?.toInt() ?? _router.uptimeSeconds;
        final identity = (data?['identity'] as String?)?.trim();
        final resolvedName = (identity != null && identity.isNotEmpty) ? identity : _router.name;

        setState(() {
          _router = _router.copyWith(
            name: resolvedName,
            status: 'ONLINE',
            boardModel: newBoard,
            routerOsVersion: newVersion,
            cpuLoadPercentage: cpu,
            uptimeSeconds: uptime,
            lastSeenAt: DateTime.now(),
            lastErrorMessage: null,
          );
        });

        // Sync verified online status to backend
        try {
          await ApiClient.updateRouter(
            id: _router.id,
            name: resolvedName,
            host: _router.host,
            port: _router.apiPort,
            status: 'ONLINE',
            routerOsVersion: newVersion,
            boardModel: newBoard,
            cpuLoadPercentage: cpu,
            uptimeSeconds: uptime,
          );
        } catch (_) {}
      } else {
        final isAuthError = testResult['errorCode'] == 'INVALID_CREDENTIALS';
        final err = testResult['errorMessage'] ??
            (isAuthError
                ? 'فشلت المصادقة: اسم المستخدم أو كلمة المرور غير صحيحة'
                : 'تعذر الاتصال بالراوتر على الشبكة المحلية (${_router.host}:${_router.apiPort})');
        setState(() {
          _router = _router.copyWith(
            status: isAuthError ? 'ERROR' : 'OFFLINE',
            lastErrorMessage: err,
          );
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    if (_isTestingConnection) return;

    setState(() {
      _isTestingConnection = true;
      _testSuccessMessage = null;
      _testErrorMessage = null;
    });

    final isLocal = MikrotikDiscoveryService.isLocalPrivateIp(_router.host);

    if (isLocal) {
      // Requirement 1 & 3: Direct on-device authentication & diagnostics for private LAN addresses
      try {
        final creds = await MikrotikDiscoveryService.getRouterCredentials(_router.id);

        if (creds == null ||
            creds['username'] == null ||
            creds['username']!.isEmpty ||
            creds['password'] == null ||
            creds['password']!.isEmpty) {
          if (!mounted) return;
          const msg =
              'تعذر التحقق من الاتصال: بيانات اعتماد الراوتر (اسم المستخدم أو كلمة المرور) غير متوفرة محلياً على هذا الجهاز لإجراء المصادقة المباشرة. يرجى تعديل الراوتر وتأكيد كلمة المرور.';
          setState(() {
            _isTestingConnection = false;
            _testErrorMessage = msg;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFD97706),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              content: Text(
                msg,
                style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          );
          return;
        }

        final testResult = await MikrotikDiscoveryService.testDirectConnection(
          host: _router.host,
          port: _router.apiPort,
          username: creds['username']!,
          password: creds['password']!,
          connectionMethod: _router.connectionMethod,
        );

        if (!mounted) return;

        setState(() {
          _isTestingConnection = false;
        });

        if (testResult['success'] == true) {
          final data = testResult['data'] as Map<String, dynamic>?;
          final newVersion = (data?['version'] as String?)?.trim() ?? _router.routerOsVersion;
          final newBoard = (data?['boardName'] as String?)?.trim() ?? _router.boardModel;
          final cpu = (data?['cpuLoad'] as num?)?.toInt() ?? _router.cpuLoadPercentage;
          final uptime = (data?['uptimeSeconds'] as num?)?.toInt() ?? _router.uptimeSeconds;
          final identity = (data?['identity'] as String?)?.trim();
          final resolvedName = (identity != null && identity.isNotEmpty) ? identity : _router.name;

          // Sync verified online status to backend and check update result explicitly
          final updateResult = await ApiClient.updateRouter(
            id: _router.id,
            name: resolvedName,
            host: _router.host,
            port: _router.apiPort,
            status: 'ONLINE',
            routerOsVersion: newVersion,
            boardModel: newBoard,
            cpuLoadPercentage: cpu,
            uptimeSeconds: uptime,
          );

          if (!mounted) return;

          if (updateResult['success'] == true) {
            setState(() {
              _router = RouterModel(
                id: _router.id,
                name: resolvedName,
                host: _router.host,
                apiPort: _router.apiPort,
                connectionMethod: _router.connectionMethod,
                status: 'ONLINE',
                boardModel: newBoard,
                routerOsVersion: newVersion,
                cpuLoadPercentage: cpu,
                uptimeSeconds: uptime,
                lastSeenAt: DateTime.now(),
                lastErrorMessage: null,
              );
              _testSuccessMessage = 'تم الاتصال بالراوتر بنجاح ومصادقة البيانات عبر الشبكة المحلية (منفذ ${_router.apiPort})';
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.statusOnline,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                content: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.white),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'الاتصال بالراوتر والمصادقة ناجحة ومستقرة محلياً',
                        style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            );
          } else {
            // updateRouter failed on server - do NOT display status saved successfully
            final saveErr = updateResult['errorMessage'] ?? 'فشل حفظ حالة الراوتر على الخادم السحابي';
            setState(() {
              _testErrorMessage = 'نجح الاتصال بالراوتر محلياً، لكن فشل حفظ الحالة على السيرفر: $saveErr';
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: Colors.orange.shade800,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                content: Text(
                  'نجح فحص الراوتر محلياً، لكن تعذر حفظ الحالة في السيرفر: $saveErr',
                  style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            );
          }
        } else {
          final isAuthError = testResult['errorCode'] == 'INVALID_CREDENTIALS';
          final err = testResult['errorMessage'] ??
              (isAuthError
                  ? 'فشلت المصادقة: اسم المستخدم أو كلمة المرور غير صحيحة لنظام MikroTik'
                  : 'تعذر الوصول إلى الراوتر على الشبكة المحلية (${_router.host}:${_router.apiPort}). يرجى التأكد من اتصال هاتفك بنفس الشبكة وتفعيل خدمة API.');
          final newStatus = isAuthError ? 'ERROR' : 'OFFLINE';

          setState(() {
            _router = RouterModel(
              id: _router.id,
              name: _router.name,
              host: _router.host,
              apiPort: _router.apiPort,
              connectionMethod: _router.connectionMethod,
              status: newStatus,
              boardModel: _router.boardModel,
              routerOsVersion: _router.routerOsVersion,
              cpuLoadPercentage: _router.cpuLoadPercentage,
              uptimeSeconds: _router.uptimeSeconds,
              lastSeenAt: _router.lastSeenAt,
              lastErrorMessage: err,
            );
            _testErrorMessage = err;
          });

          // Sync offline or error status to backend
          await ApiClient.updateRouter(
            id: _router.id,
            name: _router.name,
            host: _router.host,
            port: _router.apiPort,
            status: newStatus,
            lastErrorMessage: err,
          );

          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.statusOffline,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              content: Text(
                err,
                style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        final err = 'خطأ أثناء فحص الراوتر على الشبكة المحلية: $e';
        setState(() {
          _isTestingConnection = false;
          _testErrorMessage = err;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.statusOffline,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            content: Text(
              err,
              style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        );
      }
      return;
    }

    // Remote / Public IP testing via cloud server:
    final result = await ApiClient.testRouterConnectionForId(_router.id);

    if (!mounted) return;

    setState(() {
      _isTestingConnection = false;
    });

    if (result['success'] == true) {
      final data = result['data'] as Map<String, dynamic>?;
      final identity = data?['identity'] ?? _router.name;
      final version = data?['version'] ?? _router.routerOsVersion;
      final board = data?['boardName'] ?? _router.boardModel;
      final cpu = data?['cpuLoad'] as num?;
      final uptime = data?['uptimeSeconds'] as num?;

      setState(() {
        _router = RouterModel(
          id: _router.id,
          name: _router.name,
          host: _router.host,
          apiPort: _router.apiPort,
          connectionMethod: _router.connectionMethod,
          status: 'ONLINE',
          boardModel: board?.toString(),
          routerOsVersion: version?.toString(),
          cpuLoadPercentage: cpu?.toInt(),
          uptimeSeconds: uptime?.toInt(),
          lastSeenAt: DateTime.now(),
          lastErrorMessage: null,
        );
        _testSuccessMessage = 'تم الاتصال بالراوتر بنجاح ($identity - $board - $version)';
      });

      // Reload users and sessions on successful live probe
      _loadHotspotUsers();
      _loadActiveSessions();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.statusOnline,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Text(
            'الاتصال بالراوتر ناجح ومستقر',
            style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
      );
    } else {
      final err = result['errorMessage'] ?? 'فشل الاتصال بالراوتر';
      setState(() {
        _router = RouterModel(
          id: _router.id,
          name: _router.name,
          host: _router.host,
          apiPort: _router.apiPort,
          connectionMethod: _router.connectionMethod,
          status: 'ERROR',
          boardModel: _router.boardModel,
          routerOsVersion: _router.routerOsVersion,
          cpuLoadPercentage: _router.cpuLoadPercentage,
          uptimeSeconds: _router.uptimeSeconds,
          lastSeenAt: _router.lastSeenAt,
          lastErrorMessage: err,
        );
        _testErrorMessage = err;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.statusOffline,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Text(
            err,
            style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }
  }

  Future<void> _loadHotspotUsers() async {
    setState(() {
      _isLoadingUsers = true;
      _usersError = null;
    });

    final isLocal = MikrotikDiscoveryService.isLocalPrivateIp(_router.host);

    if (isLocal) {
      final creds = await MikrotikDiscoveryService.getRouterCredentials(_router.id);
      if (creds != null &&
          creds['username'] != null &&
          creds['username']!.isNotEmpty &&
          creds['password'] != null) {
        final directResult = await MikrotikDiscoveryService.getHotspotUsersDirect(
          host: _router.host,
          port: _router.apiPort,
          username: creds['username']!,
          password: creds['password']!,
          connectionMethod: _router.connectionMethod,
        );

        if (!mounted) return;

        if (directResult['success'] == true) {
          final rawList = directResult['data'] as List<dynamic>? ?? [];
          setState(() {
            _hotspotUsers = rawList.map((e) => e as Map<String, dynamic>).toList();
            _isLoadingUsers = false;
            _usersError = null;
          });
          return;
        }
      }
    }

    final result = await ApiClient.getRouterHotspotUsers(_router.id);

    if (!mounted) return;

    if (result['success'] == true) {
      final rawList = result['data'] as List<dynamic>? ?? [];
      setState(() {
        _hotspotUsers = rawList.map((e) => e as Map<String, dynamic>).toList();
        _isLoadingUsers = false;
        _usersError = null;
      });
    } else {
      String err = result['errorMessage'] ?? 'تعذر جلب مستخدمي الهوتسبوت';
      if (isLocal &&
          (err.contains('SSRF') || err.contains('INVALID_ROUTER_TARGET') || err.contains('Private IP') || result['errorCode'] == 'ROUTER_UNREACHABLE')) {
        err = 'ملاحظة: الراوتر يعمل على الشبكة المحلية (${_router.host}). يرجى التحقق من اتصال هاتفك بنفس الشبكة وصحة بيانات اعتماد الراوتر لجلب المستخدمين مباشرة.';
      }
      setState(() {
        _isLoadingUsers = false;
        _usersError = err;
      });
    }
  }

  Future<void> _loadActiveSessions() async {
    setState(() {
      _isLoadingSessions = true;
      _sessionsError = null;
    });

    final isLocal = MikrotikDiscoveryService.isLocalPrivateIp(_router.host);

    if (isLocal) {
      final creds = await MikrotikDiscoveryService.getRouterCredentials(_router.id);
      if (creds != null &&
          creds['username'] != null &&
          creds['username']!.isNotEmpty &&
          creds['password'] != null) {
        final directResult = await MikrotikDiscoveryService.getHotspotActiveSessionsDirect(
          host: _router.host,
          port: _router.apiPort,
          username: creds['username']!,
          password: creds['password']!,
          connectionMethod: _router.connectionMethod,
        );

        if (!mounted) return;

        if (directResult['success'] == true) {
          final rawList = directResult['data'] as List<dynamic>? ?? [];
          setState(() {
            _activeSessions = rawList.map((e) => e as Map<String, dynamic>).toList();
            _isLoadingSessions = false;
            _sessionsError = null;
          });
          return;
        }
      }
    }

    final result = await ApiClient.getRouterHotspotSessions(_router.id);

    if (!mounted) return;

    if (result['success'] == true) {
      final rawList = result['data'] as List<dynamic>? ?? [];
      setState(() {
        _activeSessions = rawList.map((e) => e as Map<String, dynamic>).toList();
        _isLoadingSessions = false;
        _sessionsError = null;
      });
    } else {
      String err = result['errorMessage'] ?? 'تعذر جلب الجلسات النشطة';
      if (isLocal &&
          (err.contains('SSRF') || err.contains('INVALID_ROUTER_TARGET') || err.contains('Private IP') || result['errorCode'] == 'ROUTER_UNREACHABLE')) {
        err = 'ملاحظة: الراوتر يعمل على الشبكة المحلية (${_router.host}). يرجى التحقق من اتصال الهاتف بنفس الشبكة لعرض الجلسات النشطة مباشرة.';
      }
      setState(() {
        _isLoadingSessions = false;
        _sessionsError = err;
      });
    }
  }

  Future<void> _toggleUser(String username, bool currentEnabled) async {
    final newEnabled = !currentEnabled;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.heroGradientStart,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text(
          newEnabled ? 'جارٍ تفعيل المستخدم...' : 'جارٍ تعطيل المستخدم...',
          style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );

    final isLocal = MikrotikDiscoveryService.isLocalPrivateIp(_router.host);

    if (isLocal) {
      final creds = await MikrotikDiscoveryService.getRouterCredentials(_router.id);
      if (creds != null &&
          creds['username'] != null &&
          creds['username']!.isNotEmpty &&
          creds['password'] != null) {
        final directResult = await MikrotikDiscoveryService.toggleHotspotUserDirect(
          host: _router.host,
          port: _router.apiPort,
          username: creds['username']!,
          password: creds['password']!,
          targetUsername: username,
          isEnabled: newEnabled,
          connectionMethod: _router.connectionMethod,
        );

        if (!mounted) return;

        if (directResult['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.statusOnline,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              content: Text(
                newEnabled ? 'تم تفعيل المستخدم $username بنجاح على الراوتر' : 'تم تعطيل المستخدم $username بنجاح على الراوتر',
                style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          );
          _loadHotspotUsers();
          return;
        }
      }
    }

    final result = await ApiClient.toggleHotspotUser(
      routerId: _router.id,
      username: username,
      isEnabled: newEnabled,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.statusOnline,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Text(
            newEnabled ? 'تم تفعيل المستخدم $username بنجاح' : 'تم تعطيل المستخدم $username بنجاح',
            style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      );
      _loadHotspotUsers();
    } else {
      final err = result['errorMessage'] ?? 'فشل تعديل حالة المستخدم';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.statusOffline,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Text(
            err,
            style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }
  }

  Future<void> _disconnectSession(String username) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.pageBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'تأكيد فصل الجلسة',
            style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark),
          ),
          content: Text(
            'هل تريد فصل جلسة الاتصال النشطة للمستخدم "$username" فوراً من الراوتر؟',
            style: GoogleFonts.cairo(fontSize: 13.5, color: AppColors.textDark),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: Text('إلغاء', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, color: AppColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusOffline,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('نعم، فصل الجلسة', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    final isLocal = MikrotikDiscoveryService.isLocalPrivateIp(_router.host);

    if (isLocal) {
      final creds = await MikrotikDiscoveryService.getRouterCredentials(_router.id);
      if (creds != null &&
          creds['username'] != null &&
          creds['username']!.isNotEmpty &&
          creds['password'] != null) {
        final directResult = await MikrotikDiscoveryService.disconnectHotspotSessionDirect(
          host: _router.host,
          port: _router.apiPort,
          username: creds['username']!,
          password: creds['password']!,
          targetUsername: username,
          connectionMethod: _router.connectionMethod,
        );

        if (!mounted) return;

        if (directResult['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.statusOnline,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              content: Text(
                'تم فصل جلسة المستخدم $username بنجاح من الراوتر',
                style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          );
          _loadActiveSessions();
          return;
        }
      }
    }

    final result = await ApiClient.disconnectHotspotSession(
      routerId: _router.id,
      username: username,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.statusOnline,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Text(
            'تم فصل جلسة المستخدم $username بنجاح',
            style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      );
      _loadActiveSessions();
    } else {
      final err = result['errorMessage'] ?? 'فشل فصل الجلسة';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.statusOffline,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Text(
            err,
            style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }
  }

  Future<void> _editRouter() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => AddRouterScreen(routerToEdit: _router),
      ),
    );

    if (updated == true) {
      final res = await ApiClient.getRouters();
      if (!mounted) return;
      if (res['success'] == true) {
        final list = (res['data'] as List<dynamic>).cast<RouterModel>();
        final current = list.firstWhere((r) => r.id == _router.id, orElse: () => _router);
        setState(() {
          _router = current;
        });
      }
    }
  }

  Future<void> _deleteRouter() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.pageBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'تأكيد حذف الراوتر',
            style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark),
          ),
          content: Text(
            'هل أنت متأكد من حذف راوتر "${_router.name}" نهائياً من حسابك؟',
            style: GoogleFonts.cairo(fontSize: 13.5, color: AppColors.textDark),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: Text('إلغاء', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, color: AppColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusOffline,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('نعم، حذف', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    final result = await ApiClient.deleteRouter(_router.id);
    if (!mounted) return;

    if (result['success'] == true) {
      Navigator.of(context).pop(true);
    } else {
      final err = result['errorMessage'] ?? 'فشل حذف الراوتر';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.statusOffline,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Text(err, style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      );
    }
  }

  String _formatBytes(dynamic bytes) {
    if (bytes == null) return '0 B';
    final num b = bytes is num ? bytes : num.tryParse(bytes.toString()) ?? 0;
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    if (b < 1024 * 1024 * 1024) return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _formatUptime(int? seconds) {
    if (seconds == null || seconds <= 0) return '0 ثانية';
    final days = seconds ~/ 86400;
    final hours = (seconds % 86400) ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    final parts = <String>[];
    if (days > 0) parts.add('$days يوم');
    if (hours > 0) parts.add('$hours س');
    if (minutes > 0) parts.add('$minutes د');
    if (secs > 0 && days == 0) parts.add('$secs ث');
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = _router.isOnline;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.pageBg,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  PressableNeumorphicCard(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(14),
                    padding: const EdgeInsets.all(10),
                    child: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 18,
                      color: AppColors.textDark,
                    ),
                  ),
                  Text(
                    _router.name,
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  Row(
                    children: [
                      PressableNeumorphicCard(
                        onTap: _editRouter,
                        borderRadius: BorderRadius.circular(14),
                        padding: const EdgeInsets.all(10),
                        child: const Icon(
                          Icons.edit_rounded,
                          size: 18,
                          color: AppColors.heroGradientStart,
                        ),
                      ),
                      const SizedBox(width: 8),
                      PressableNeumorphicCard(
                        onTap: _deleteRouter,
                        borderRadius: BorderRadius.circular(14),
                        padding: const EdgeInsets.all(10),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: AppColors.statusOffline,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            // Router Overview Header Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.pageBg,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    const BoxShadow(
                      color: AppColors.shadowLight,
                      offset: Offset(-3, -3),
                      blurRadius: 6,
                    ),
                    BoxShadow(
                      color: AppColors.shadowDark.withValues(alpha: 0.6),
                      offset: const Offset(3, 3),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            PulsingDot(
                              color: isOnline ? AppColors.statusOnline : AppColors.statusOffline,
                              size: 12,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isOnline ? 'الراوتر متصل ومستجيب' : 'الراوتر غير متصل',
                              style: GoogleFonts.cairo(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isOnline ? AppColors.statusOnline : AppColors.statusOffline,
                              ),
                            ),
                          ],
                        ),
                        // Live Test Button
                        PressableNeumorphicCard(
                          onTap: _isTestingConnection ? null : _testConnection,
                          borderRadius: BorderRadius.circular(12),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          backgroundColor: AppColors.heroGradientStart.withValues(alpha: 0.12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isTestingConnection)
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.heroGradientStart,
                                  ),
                                )
                              else
                                const Icon(
                                  Icons.sync_rounded,
                                  size: 16,
                                  color: AppColors.heroGradientStart,
                                ),
                              const SizedBox(width: 6),
                              Text(
                                _isTestingConnection ? 'جارٍ الفحص...' : 'فحص الاتصال',
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.heroGradientStart,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    // Router Specs Grid
                    Row(
                      children: [
                        Expanded(
                          child: _buildSpecItem(
                            icon: Icons.lan_rounded,
                            label: 'العنوان والمنفذ',
                            value: '${_router.host}:${_router.apiPort}',
                          ),
                        ),
                        Expanded(
                          child: _buildSpecItem(
                            icon: Icons.security_rounded,
                            label: 'البروتوكول',
                            value: _router.connectionMethod,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSpecItem(
                            icon: Icons.memory_rounded,
                            label: 'الموديل والنظام',
                            value: '${_router.boardModel ?? "غير محدد"} (${_router.routerOsVersion ?? "v7"})',
                          ),
                        ),
                        Expanded(
                          child: _buildSpecItem(
                            icon: Icons.timer_outlined,
                            label: 'مدة التشغيل / المعالج',
                            value: '${_formatUptime(_router.uptimeSeconds)} | ${_router.cpuLoadPercentage != null ? "${_router.cpuLoadPercentage}%" : "0%"}',
                          ),
                        ),
                      ],
                    ),
                    if ((_testErrorMessage != null && _testErrorMessage!.isNotEmpty) ||
                        (_router.lastErrorMessage != null && _router.lastErrorMessage!.isNotEmpty)) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.statusOffline.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.statusOffline.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppColors.statusOffline, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _testErrorMessage ?? _router.lastErrorMessage!,
                                style: GoogleFonts.cairo(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.statusOffline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_testSuccessMessage != null && _testSuccessMessage!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.statusOnline.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.statusOnline.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: AppColors.statusOnline, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _testSuccessMessage!,
                                style: GoogleFonts.cairo(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.statusOnline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Tab Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.pageBg,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    const BoxShadow(color: AppColors.shadowLight, offset: Offset(-2, -2), blurRadius: 4),
                    BoxShadow(color: AppColors.shadowDark.withValues(alpha: 0.5), offset: const Offset(2, 2), blurRadius: 4),
                  ],
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.heroGradientStart,
                  indicatorWeight: 3,
                  labelColor: AppColors.heroGradientStart,
                  unselectedLabelColor: AppColors.textMuted,
                  labelStyle: GoogleFonts.cairo(fontSize: 13.5, fontWeight: FontWeight.w800),
                  unselectedLabelStyle: GoogleFonts.cairo(fontSize: 13.5, fontWeight: FontWeight.w600),
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.people_outline_rounded, size: 18),
                          const SizedBox(width: 6),
                          Text('مستخدمو الهوتسبوت (${_hotspotUsers.length})'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.wifi_tethering_rounded, size: 18),
                          const SizedBox(width: 6),
                          Text('الجلسات النشطة (${_activeSessions.length})'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildHotspotUsersTab(),
                  _buildActiveSessionsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.heroGradientStart),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted),
              ),
              Text(
                value,
                style: GoogleFonts.cairo(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHotspotUsersTab() {
    if (_isLoadingUsers) {
      return const Center(child: AppLoadingState(message: 'جارٍ جلب مستخدمي الهوتسبوت من الراوتر...'));
    }

    if (_usersError != null) {
      return Center(
        child: AppErrorState(
          title: 'تعذر جلب المستخدمين',
          errorMessage: _usersError!,
          onRetry: _loadHotspotUsers,
        ),
      );
    }

    final filteredUsers = _hotspotUsers.where((u) {
      final name = (u['username'] ?? '').toString().toLowerCase();
      final profile = (u['profile'] ?? '').toString().toLowerCase();
      final q = _userSearchQuery.toLowerCase();
      return name.contains(q) || profile.contains(q);
    }).toList();

    if (_hotspotUsers.isEmpty) {
      return const Center(
        child: AppEmptyState(
          icon: Icons.person_off_rounded,
          title: 'لا يوجد مستخدمو هوتسبوت',
          description: 'لم يتم العثور على أي مستخدمين معرّفين على هذا الراوتر حالياً.',
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: TextField(
            onChanged: (val) => setState(() => _userSearchQuery = val),
            style: GoogleFonts.cairo(fontSize: 13, color: AppColors.textDark),
            decoration: InputDecoration(
              hintText: 'بحث باسم المستخدم أو البروفايل...',
              hintStyle: GoogleFonts.cairo(fontSize: 13, color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.pageBg,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.shadowDark.withValues(alpha: 0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.shadowDark.withValues(alpha: 0.3)),
              ),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadHotspotUsers,
            color: AppColors.heroGradientStart,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              itemCount: filteredUsers.length,
              itemBuilder: (context, index) {
                final user = filteredUsers[index];
                final username = user['username'] ?? '';
                final profile = user['profile'] ?? 'default';
                final isEnabled = user['isEnabled'] == true;
                final uptimeSec = (user['uptimeSeconds'] as num?)?.toInt() ?? 0;
                final bytesIn = user['bytesIn'];
                final bytesOut = user['bytesOut'];
                final dbStatus = user['dbStatus'] as String?;
                final verifiedOnRouter = user['verifiedOnRouter'] == true;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: PressableNeumorphicCard(
                    borderRadius: BorderRadius.circular(16),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isEnabled
                                ? AppColors.statusOnline.withValues(alpha: 0.12)
                                : AppColors.statusOffline.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isEnabled ? Icons.person_rounded : Icons.person_off_rounded,
                            size: 20,
                            color: isEnabled ? AppColors.statusOnline : AppColors.statusOffline,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    username,
                                    style: GoogleFonts.cairo(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (verifiedOnRouter)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.heroGradientStart.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'مؤكد على الراوتر',
                                        style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.heroGradientStart),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'البروفايل: $profile | مدة الاتصال: ${_formatUptime(uptimeSec)} | الاستخدام: ${_formatBytes(bytesIn)} استلام / ${_formatBytes(bytesOut)} إرسال',
                                style: GoogleFonts.cairo(fontSize: 11.5, color: AppColors.textMuted),
                              ),
                              if (dbStatus != null && dbStatus != 'ROUTER_ONLY')
                                Text(
                                  'حالة الكرت بالنظام: $dbStatus',
                                  style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.heroGradientStart),
                                ),
                            ],
                          ),
                        ),
                        // Toggle Switch / Action
                        IconButton(
                          icon: Icon(
                            isEnabled ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                            size: 34,
                            color: isEnabled ? AppColors.statusOnline : AppColors.textMuted,
                          ),
                          tooltip: isEnabled ? 'تعطيل المستخدم' : 'تفعيل المستخدم',
                          onPressed: () => _toggleUser(username, isEnabled),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveSessionsTab() {
    if (_isLoadingSessions) {
      return const Center(child: AppLoadingState(message: 'جارٍ جلب الجلسات النشطة من الراوتر...'));
    }

    if (_sessionsError != null) {
      return Center(
        child: AppErrorState(
          title: 'تعذر جلب الجلسات',
          errorMessage: _sessionsError!,
          onRetry: _loadActiveSessions,
        ),
      );
    }

    if (_activeSessions.isEmpty) {
      return const Center(
        child: AppEmptyState(
          icon: Icons.wifi_off_rounded,
          title: 'لا توجد جلسات متصلة',
          description: 'لا يوجد أي مستخدم متصل بالإنترنت عبر الهوتسبوت حالياً.',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadActiveSessions,
      color: AppColors.heroGradientStart,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        itemCount: _activeSessions.length,
        itemBuilder: (context, index) {
          final session = _activeSessions[index];
          final username = session['username'] ?? '';
          final ip = session['ipAddress'] ?? 'غير معروف';
          final mac = session['macAddress'] ?? '';
          final uptime = (session['uptimeSeconds'] as num?)?.toInt() ?? 0;
          final bytesIn = session['bytesIn'];
          final bytesOut = session['bytesOut'];

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: PressableNeumorphicCard(
              borderRadius: BorderRadius.circular(16),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.statusOnline.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.wifi_rounded, size: 20, color: AppColors.statusOnline),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          username,
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'IP: $ip ${mac.isNotEmpty ? "| MAC: $mac" : ""}',
                          style: GoogleFonts.cairo(fontSize: 11.5, color: AppColors.textMuted),
                        ),
                        Text(
                          'مدة الاتصال: ${_formatUptime(uptime)} | استهلاك: ${_formatBytes(bytesIn)} / ${_formatBytes(bytesOut)}',
                          style: GoogleFonts.cairo(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.heroGradientStart),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.power_settings_new_rounded,
                      color: AppColors.statusOffline,
                      size: 22,
                    ),
                    tooltip: 'فصل الجلسة',
                    onPressed: () => _disconnectSession(username),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
