// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System
// File: lib/screens/add_router_screen.dart
// Screen: Add Router Form with Diagnostic Test and Validation
// Master Reference: Rule 18 (API Only), Rule 23 (Error Handling), Rule 35 (State)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/router_model.dart';
import '../models/discovered_router_model.dart';
import '../services/api_client.dart';
import '../services/mikrotik_discovery_service.dart';
import '../theme/app_colors.dart';
import '../widgets/neumorphic_text_field.dart';
import '../widgets/pressable_neumorphic_card.dart';

class AddRouterScreen extends StatefulWidget {
  final RouterModel? routerToEdit;

  const AddRouterScreen({super.key, this.routerToEdit});

  @override
  State<AddRouterScreen> createState() => _AddRouterScreenState();
}

class _AddRouterScreenState extends State<AddRouterScreen> {
  final _nameController = TextEditingController();
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '8729');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fingerprintController = TextEditingController();
  String _connectionMethod = 'ROUTEROS_API_SSL';

  String? _nameError;
  String? _hostError;
  String? _portError;
  String? _usernameError;
  String? _passwordError;

  bool _isTesting = false;
  bool _isSaving = false;
  bool _isDiscovering = false;
  DiscoveredRouterModel? _discoveredRouter;
  String? _discoveryMessage;
  String? _serverErrorMessage;
  String? _testSuccessMessage;

  String? _verifiedVersion;
  String? _verifiedBoardModel;
  int? _verifiedCpuLoad;
  int? _verifiedUptime;
  String? _testedHost;
  int? _testedPort;
  String? _testedUsername;
  String? _testedPassword;
  String? _testedMethod;

  @override
  void initState() {
    super.initState();
    if (widget.routerToEdit != null) {
      final r = widget.routerToEdit!;
      _nameController.text = r.name;
      _hostController.text = r.host;
      _portController.text = r.apiPort.toString();
      _verifiedVersion = r.routerOsVersion;
      _verifiedBoardModel = r.boardModel;
      _verifiedCpuLoad = r.cpuLoadPercentage;
      _verifiedUptime = r.uptimeSeconds;
      const validMethods = ['ROUTEROS_API_SSL', 'REST_API_HTTPS', 'ROUTEROS_API_PLAIN', 'REST_API_PLAIN'];
      if (validMethods.contains(r.connectionMethod)) {
        _connectionMethod = r.connectionMethod;
      } else if (r.connectionMethod == 'ROUTEROS_API') {
        _connectionMethod = 'ROUTEROS_API_PLAIN';
      } else {
        _connectionMethod = 'ROUTEROS_API_SSL';
      }
      MikrotikDiscoveryService.getRouterCredentials(r.id).then((creds) {
        if (mounted && creds != null && creds['username'] != null && creds['username']!.isNotEmpty) {
          if (_usernameController.text.trim().isEmpty) {
            _usernameController.text = creds['username']!;
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _fingerprintController.dispose();
    super.dispose();
  }

  bool _validateInputs() {
    bool isValid = true;
    setState(() {
      _nameError = null;
      _hostError = null;
      _portError = null;
      _usernameError = null;
      _passwordError = null;
      _serverErrorMessage = null;

      final name = _nameController.text.trim();
      if (name.isEmpty) {
        _nameError = 'يرجى إدخال اسم الراوتر';
        isValid = false;
      }

      final host = _hostController.text.trim();
      if (host.isEmpty) {
        _hostError = 'يرجى إدخال عنوان الـ Host أو الـ IP';
        isValid = false;
      }

      final portStr = _portController.text.trim();
      final portVal = int.tryParse(portStr);
      if (portStr.isEmpty) {
        _portError = 'يرجى إدخال رقم المنفذ';
        isValid = false;
      } else if (portVal == null || portVal < 1 || portVal > 65535) {
        _portError = 'رقم المنفذ يجب أن يكون بين 1 و 65535';
        isValid = false;
      }

      final username = _usernameController.text.trim();
      if (widget.routerToEdit == null && username.isEmpty) {
        _usernameError = 'يرجى إدخال اسم المستخدم';
        isValid = false;
      }

      final password = _passwordController.text;
      if (widget.routerToEdit == null && password.isEmpty) {
        _passwordError = 'يرجى إدخال كلمة المرور';
        isValid = false;
      }
    });

    return isValid;
  }

  Future<void> _discoverLocalRouter() async {
    if (_isDiscovering || _isTesting || _isSaving) return;

    setState(() {
      _isDiscovering = true;
      _discoveryMessage = null;
      _serverErrorMessage = null;
      _testSuccessMessage = null;
    });

    try {
      final username = _usernameController.text.trim().isNotEmpty
          ? _usernameController.text.trim()
          : null;
      final password = _passwordController.text.isNotEmpty
          ? _passwordController.text
          : null;

      final discovered = await MikrotikDiscoveryService.discoverOnLocalNetwork(
        username: username,
        password: password,
      );

      if (!mounted) return;

      setState(() {
        _isDiscovering = false;
        _discoveredRouter = discovered;
      });

      if (discovered != null && discovered.isMikrotik) {
        _hostController.text = discovered.host;
        if (_nameController.text.trim().isEmpty && discovered.identity != null && discovered.identity!.isNotEmpty) {
          _nameController.text = discovered.identity!;
        }
        if (discovered.port == 80 || discovered.port == 8080) {
          _portController.text = discovered.port.toString();
          _connectionMethod = 'REST_API_PLAIN';
        } else if (discovered.port == 443) {
          _portController.text = '443';
          _connectionMethod = 'REST_API_HTTPS';
        } else if (discovered.port == 8729) {
          _portController.text = '8729';
          _connectionMethod = 'ROUTEROS_API_SSL';
        } else {
          _portController.text = discovered.port.toString();
          _connectionMethod = 'ROUTEROS_API_PLAIN';
        }

        // If credentials were provided during discovery AND management was reached with credentials:
        if (username != null && password != null && discovered.managementReachable && !discovered.authRequired) {
          _verifiedVersion = discovered.version;
          _verifiedBoardModel = discovered.boardName;
          _testSuccessMessage = 'تم التحقق من الاتصال وبيانات الاعتماد أثناء الاكتشاف';
          _testedHost = discovered.host;
          _testedPort = int.tryParse(_portController.text.trim());
          _testedUsername = username;
          _testedPassword = password;
          _testedMethod = _connectionMethod;
        }

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
                    'تم اكتشاف راوتر MikroTik بنجاح: ${discovered.host}',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        setState(() {
          _discoveryMessage =
              'لم يتم اكتشاف راوتر MikroTik متاح على الشبكة المحلية.\n\n'
              'توضيح فني: الاتصال بالـ Wi-Fi وحده لا يضمن إمكانية قراءة بيانات الراوتر؛ يجب تفعيل إحدى خدمات الإدارة التالية في RouterOS (/ip service):\n'
              '• خدمة www (المنفذ 80 أو 8080) لدعم REST API\n'
              '• خدمة api (المنفذ 8728) أو api-ssl (المنفذ 8729)\n'
              'مع التأكد من السماح لعنوان جهازك بالوصول دون جدار ناري مانع.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDiscovering = false;
        _discoveryMessage = 'خطأ أثناء البحث عن الراوتر: $e';
      });
    }
  }

  Future<void> _testConnection() async {
    if (_isTesting || _isSaving) return;

    final host = _hostController.text.trim();
    final portStr = _portController.text.trim();
    final portVal = int.tryParse(portStr);
    final username = _usernameController.text.trim();
    String passwordToUse = _passwordController.text;

    if (widget.routerToEdit != null && passwordToUse.isEmpty) {
      final creds = await MikrotikDiscoveryService.getRouterCredentials(widget.routerToEdit!.id);
      if (creds != null && creds['password'] != null && creds['password']!.isNotEmpty) {
        passwordToUse = creds['password']!;
      }
    }

    // Check credentials required for test
    setState(() {
      _hostError = host.isEmpty ? 'يرجى إدخال عنوان الـ Host للاختبار' : null;
      _portError = (portVal == null || portVal < 1 || portVal > 65535)
          ? 'منفذ غير صالح (1-65535)'
          : null;
      _usernameError = username.isEmpty ? 'يرجى إدخال اسم المستخدم' : null;
      _passwordError = passwordToUse.isEmpty ? 'يرجى إدخال كلمة المرور' : null;
      _serverErrorMessage = null;
      _testSuccessMessage = null;
    });

    if (host.isEmpty ||
        portVal == null ||
        portVal < 1 ||
        portVal > 65535 ||
        username.isEmpty ||
        passwordToUse.isEmpty) {
      return;
    }

    setState(() {
      _isTesting = true;
    });

    final result = await ApiClient.testRouterConnection(
      host: host,
      port: portVal,
      username: username,
      password: passwordToUse,
      connectionMethod: _connectionMethod,
      certificateFingerprint: _fingerprintController.text.trim().isNotEmpty
          ? _fingerprintController.text.trim()
          : null,
    );

    if (!mounted) return;

    setState(() {
      _isTesting = false;
    });

    if (result['success'] == true) {
      final data = result['data'] as Map<String, dynamic>?;
      final identity = (data?['identity'] as String?)?.trim() ?? 'راوتر MikroTik';
      final version = (data?['version'] as String?)?.trim() ?? '';
      final board = (data?['boardName'] as String?)?.trim() ?? '';
      _verifiedVersion = version.isNotEmpty ? version : null;
      _verifiedBoardModel = board.isNotEmpty ? board : null;
      _verifiedCpuLoad = (data?['cpuLoad'] as num?)?.toInt();
      _verifiedUptime = (data?['uptimeSeconds'] as num?)?.toInt();
      final details = [identity, board, version]
          .where((e) => e.isNotEmpty)
          .join(' - ');

      setState(() {
        _testSuccessMessage = 'تم الاتصال بنجاح بنظام MikroTik ($details)';
        _testedHost = host;
        _testedPort = portVal;
        _testedUsername = username;
        _testedPassword = passwordToUse;
        _testedMethod = _connectionMethod;
        if (_nameController.text.trim().isEmpty && identity.isNotEmpty && identity != 'راوتر MikroTik') {
          _nameController.text = identity;
        }
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
                  'تم الاتصال بنجاح: $details',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      final err = result['errorMessage'] ?? 'فشل الاتصال بالراوتر';
      setState(() {
        _serverErrorMessage = err;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.statusOffline,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  err,
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _submitForm() async {
    if (_isSaving || _isTesting) return;

    if (!_validateInputs()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _serverErrorMessage = null;
    });

    final host = _hostController.text.trim();
    final portVal = int.parse(_portController.text.trim());
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    final isEditing = widget.routerToEdit != null;
    final bool isTestedAndMatching = _testSuccessMessage != null &&
        _testedHost == host &&
        _testedPort == portVal &&
        _testedUsername == username &&
        (_testedPassword == password || (isEditing && password.isEmpty)) &&
        _testedMethod == _connectionMethod;

    bool isOnline = isTestedAndMatching;

    // Requirement:
    // When editing:
    //   - If password is empty: user is retaining current password. DO NOT test connection with empty password!
    //   - If password is not empty: user entered a new password, so verify it!
    // When adding:
    //   - Verify connection with credentials before saving.
    final shouldTestBeforeSave = !isOnline && username.isNotEmpty &&
        (isEditing ? password.isNotEmpty : password.isNotEmpty);

    if (shouldTestBeforeSave) {
      try {
        final testResult = await ApiClient.testRouterConnection(
          host: host,
          port: portVal,
          username: username,
          password: password,
          connectionMethod: _connectionMethod,
          certificateFingerprint: _fingerprintController.text.trim().isNotEmpty
              ? _fingerprintController.text.trim()
              : null,
        );

        if (testResult['success'] == true) {
          isOnline = true;
          final data = testResult['data'] as Map<String, dynamic>?;
          final version = (data?['version'] as String?)?.trim();
          final board = (data?['boardName'] as String?)?.trim();
          if (version != null && version.isNotEmpty) _verifiedVersion = version;
          if (board != null && board.isNotEmpty) _verifiedBoardModel = board;
          _verifiedCpuLoad = (data?['cpuLoad'] as num?)?.toInt() ?? _verifiedCpuLoad;
          _verifiedUptime = (data?['uptimeSeconds'] as num?)?.toInt() ?? _verifiedUptime;
          _testSuccessMessage = 'تم التحقق من الاتصال بنجاح';
          _testedHost = host;
          _testedPort = portVal;
          _testedUsername = username;
          _testedPassword = password;
          _testedMethod = _connectionMethod;
        } else {
          // If credentials failed explicitly (invalid user or password):
          if (testResult['errorCode'] == 'INVALID_CREDENTIALS') {
            if (!mounted) return;
            setState(() {
              _isSaving = false;
              _passwordError = isEditing
                  ? 'كلمة المرور الجديدة غير صحيحة لنظام MikroTik'
                  : (testResult['errorMessage'] ?? 'بيانات الاعتماد غير صحيحة (اسم المستخدم أو كلمة المرور)');
              _serverErrorMessage = isEditing
                  ? 'فشلت المصادقة: كلمة المرور الجديدة غير صالحة للراوتر'
                  : 'فشل الاتصال: اسم المستخدم أو كلمة المرور غير صحيحة لنظام MikroTik';
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.statusOffline,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                content: Row(
                  children: [
                    const Icon(Icons.lock_clock_rounded, color: Colors.white),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isEditing
                            ? 'فشلت المصادقة: كلمة المرور الجديدة غير صالحة للراوتر'
                            : 'فشل المصادقة: اسم المستخدم أو كلمة المرور غير صحيحة للراوتر',
                        style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            );
            return;
          }
          // If port is unreachable or connection timed out, save as OFFLINE with error recorded
          isOnline = false;
        }
      } catch (_) {
        isOnline = false;
      }
    }

    final result = widget.routerToEdit != null
        ? await ApiClient.updateRouter(
            id: widget.routerToEdit!.id,
            name: _nameController.text.trim(),
            host: _hostController.text.trim(),
            port: int.parse(_portController.text.trim()),
            username: _usernameController.text.trim().isNotEmpty
                ? _usernameController.text.trim()
                : null,
            password: _passwordController.text.isNotEmpty
                ? _passwordController.text
                : null,
            connectionMethod: _connectionMethod,
            certificateFingerprint: _fingerprintController.text.trim().isNotEmpty
                ? _fingerprintController.text.trim()
                : null,
            status: isOnline ? 'ONLINE' : null,
            routerOsVersion: _verifiedVersion,
            boardModel: _verifiedBoardModel,
            cpuLoadPercentage: _verifiedCpuLoad,
            uptimeSeconds: _verifiedUptime,
          )
        : await ApiClient.createRouter(
            name: _nameController.text.trim(),
            host: _hostController.text.trim(),
            port: int.parse(_portController.text.trim()),
            username: _usernameController.text.trim(),
            password: _passwordController.text,
            connectionMethod: _connectionMethod,
            certificateFingerprint: _fingerprintController.text.trim().isNotEmpty
                ? _fingerprintController.text.trim()
                : null,
            status: isOnline ? 'ONLINE' : 'OFFLINE',
            routerOsVersion: _verifiedVersion,
            boardModel: _verifiedBoardModel,
            cpuLoadPercentage: _verifiedCpuLoad,
            uptimeSeconds: _verifiedUptime,
          );

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    if (result['success'] == true) {
      final successMsg = widget.routerToEdit != null
          ? 'تم تحديث بيانات الراوتر بنجاح'
          : 'تم حفظ الراوتر وإضافته للنظام بنجاح';

      // Securely cache credentials locally for on-device diagnostics without exposing secrets
      final dynamic resData = result['data'];
      final targetRouterId = widget.routerToEdit?.id ??
          (resData is RouterModel
              ? resData.id
              : (resData is Map ? resData['id'] as String? : null));
      if (targetRouterId != null) {
        final existing = await MikrotikDiscoveryService.getRouterCredentials(targetRouterId);
        final effectiveUser = username.isNotEmpty ? username : (existing?['username'] ?? '');

        if (password.isNotEmpty && effectiveUser.isNotEmpty) {
          await MikrotikDiscoveryService.saveRouterCredentials(
            routerId: targetRouterId,
            username: effectiveUser,
            password: password,
          );
        } else if (effectiveUser.isNotEmpty && existing != null) {
          await MikrotikDiscoveryService.saveRouterCredentials(
            routerId: targetRouterId,
            username: effectiveUser,
            password: existing['password'] ?? '',
          );
        }

        // If direct authentication succeeded on creation, explicitly sync status ONLINE and specs
        if (isOnline && widget.routerToEdit == null) {
          try {
            await ApiClient.updateRouter(
              id: targetRouterId,
              name: _nameController.text.trim(),
              host: host,
              port: portVal,
              status: 'ONLINE',
              routerOsVersion: _verifiedVersion,
              boardModel: _verifiedBoardModel,
              cpuLoadPercentage: _verifiedCpuLoad,
              uptimeSeconds: _verifiedUptime,
            );
          } catch (_) {}
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.statusOnline,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Text(
                successMsg,
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );

      // Return true to indicate a refresh is needed in Dashboard
      Navigator.of(context).pop(true);
    } else {
      String err = result['errorMessage'] ?? 'حدث خطأ أثناء حفظ الراوتر';
      if (result['details'] is Map) {
        final detailsMap = result['details'] as Map;
        final parts = <String>[];
        detailsMap.forEach((k, v) {
          if (v is List) {
            parts.add('$k: ${v.join(", ")}');
          } else if (v != null) {
            parts.add('$k: $v');
          }
        });
        if (parts.isNotEmpty) {
          err = '$err (${parts.join(" | ")})';
        }
      }
      if (err.toLowerCase().contains('invalid request payload')) {
        err = 'بيانات إعدادات الراوتر غير صالحة. يرجى التأكد من رقم المنفذ واختيار بروتوكول اتصال متوافق (مثل RouterOS API المنفذ 8728).';
      }

      setState(() {
        _serverErrorMessage = err;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.statusOffline,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  err,
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  Expanded(
                    child: Center(
                      child: Text(
                        widget.routerToEdit != null ? 'تعديل الراوتر' : 'إضافة راوتر جديد',
                        style: GoogleFonts.cairo(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  PressableNeumorphicCard(
                    onTap: _isDiscovering ? null : _discoverLocalRouter,
                    borderRadius: BorderRadius.circular(14),
                    padding: const EdgeInsets.all(10),
                    child: _isDiscovering
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.heroGradientStart,
                            ),
                          )
                        : const Icon(
                            Icons.radar_rounded,
                            size: 20,
                            color: AppColors.heroGradientStart,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
            children: [
              // Local MikroTik Discovery Card
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.heroGradientStart.withValues(alpha: 0.2),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadowDark.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.heroGradientStart.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.wifi_find_rounded,
                            color: AppColors.heroGradientStart,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'اكتشاف راوتر MikroTik في الشبكة المحلية',
                                style: GoogleFonts.cairo(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textDark,
                                ),
                              ),
                              Text(
                                'فحص البوابة المحلية (Default Gateway) تلقائياً',
                                style: GoogleFonts.cairo(
                                  fontSize: 11.5,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.heroGradientStart,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      onPressed: _isDiscovering ? null : _discoverLocalRouter,
                      icon: _isDiscovering
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.radar_rounded, size: 18),
                      label: Text(
                        _isDiscovering
                            ? 'جاري فحص الشبكة المحلية...'
                            : 'بحث واكتشاف الراوتر تلقائياً',
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (_discoveredRouter != null && _discoveredRouter!.isMikrotik) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.statusOnline.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.statusOnline.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.verified_rounded,
                                  color: AppColors.statusOnline,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'تم التحقق: راوتر MikroTik فعلي',
                                  style: GoogleFonts.cairo(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.statusOnline,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 14),
                            Text(
                              '• الاسم: ${_discoveredRouter!.identity ?? "راوتر MikroTik"}',
                              style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textDark),
                            ),
                            if (_discoveredRouter!.boardName != null)
                              Text(
                                '• الموديل: ${_discoveredRouter!.boardName}',
                                style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textDark),
                              ),
                            if (_discoveredRouter!.version != null)
                              Text(
                                '• إصدار RouterOS: ${_discoveredRouter!.version}',
                                style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textDark),
                              ),
                            Text(
                              '• العنوان المكتشف: ${_discoveredRouter!.host}:${_discoveredRouter!.port}',
                              style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textDark),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_discoveryMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              color: Color(0xFFD97706),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _discoveryMessage!,
                                style: GoogleFonts.cairo(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF92400E),
                                  height: 1.4,
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

              // Server / Test Info Banner
              if (_serverErrorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.statusOffline.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.statusOffline.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.statusOffline,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _serverErrorMessage!,
                          style: GoogleFonts.cairo(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.statusOffline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              if (_testSuccessMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.statusOnline.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.statusOnline.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.statusOnline,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _testSuccessMessage!,
                          style: GoogleFonts.cairo(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.statusOnline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Form Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.pageBg,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    const BoxShadow(
                      color: AppColors.shadowLight,
                      offset: Offset(-5, -5),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: AppColors.shadowDark.withValues(alpha: 0.8),
                      offset: const Offset(5, 5),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Router Name
                    NeumorphicTextField(
                      label: 'اسم الراوتر / الموقع',
                      hintText: 'مثال: راوتر الصالة الرئيسية',
                      controller: _nameController,
                      errorText: _nameError,
                      prefixIcon: const Icon(
                        Icons.router_rounded,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Host / IP
                    NeumorphicTextField(
                      label: 'عنوان الـ Host أو الـ IP',
                      hintText: 'مثال: 192.168.88.1',
                      controller: _hostController,
                      errorText: _hostError,
                      keyboardType: TextInputType.url,
                      textDirection: TextDirection.ltr,
                      prefixIcon: const Icon(
                        Icons.settings_ethernet_rounded,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Protocol / Connection Method Selector
                    Text(
                      'بروتوكول الاتصال والتشفير',
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.cardSurface,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          const BoxShadow(
                            color: AppColors.shadowLight,
                            offset: Offset(-2, -2),
                            blurRadius: 4,
                          ),
                          BoxShadow(
                            color: AppColors.shadowDark.withValues(alpha: 0.5),
                            offset: const Offset(2, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _connectionMethod,
                          dropdownColor: AppColors.cardSurface,
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'ROUTEROS_API_SSL',
                              child: Text('API-SSL المشفر (منفذ 8729 - موصى به لـ v6 و v7)'),
                            ),
                            DropdownMenuItem(
                              value: 'REST_API_HTTPS',
                              child: Text('REST API عبر HTTPS (منفذ 443 - خاص بـ v7)'),
                            ),
                            DropdownMenuItem(
                              value: 'ROUTEROS_API_PLAIN',
                              child: Text('API غير مشفر (منفذ 8728 - شبكة محلية/VPN فقط)'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val == null) return;
                            setState(() {
                              _connectionMethod = val;
                              if (val == 'ROUTEROS_API_SSL') {
                                _portController.text = '8729';
                              } else if (val == 'REST_API_HTTPS') {
                                _portController.text = '443';
                              } else if (val == 'ROUTEROS_API_PLAIN') {
                                _portController.text = '8728';
                              }
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // API Port
                    NeumorphicTextField(
                      label: 'منفذ RouterOS API',
                      hintText: '8729 (الافتراضي المشفر)',
                      controller: _portController,
                      errorText: _portError,
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.ltr,
                      prefixIcon: const Icon(
                        Icons.numbers_rounded,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Certificate Fingerprint (Optional)
                    if (_connectionMethod == 'ROUTEROS_API_SSL' || _connectionMethod == 'REST_API_HTTPS') ...[
                      NeumorphicTextField(
                        label: 'بصمة شهادة SSL (اختياري - SHA-256)',
                        hintText: 'للشهادات ذاتية التوقيع (Self-Signed Pinning)',
                        controller: _fingerprintController,
                        textDirection: TextDirection.ltr,
                        prefixIcon: const Icon(
                          Icons.verified_user_rounded,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    const SizedBox(height: 16),

                    // Username
                    NeumorphicTextField(
                      label: 'اسم المستخدم للراوتر',
                      hintText: 'مثال: admin',
                      controller: _usernameController,
                      errorText: _usernameError,
                      textDirection: TextDirection.ltr,
                      prefixIcon: const Icon(
                        Icons.person_outline_rounded,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Password
                    NeumorphicTextField(
                      label: 'كلمة المرور',
                      hintText: widget.routerToEdit != null
                          ? 'اتركها فارغة للإبقاء على كلمة المرور الحالية'
                          : 'أدخل كلمة مرور الراوتر',
                      controller: _passwordController,
                      isPassword: true,
                      errorText: _passwordError,
                      textDirection: TextDirection.ltr,
                      textInputAction: TextInputAction.done,
                      prefixIcon: const Icon(
                        Icons.lock_outline_rounded,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons Row
              Row(
                children: [
                  // Test Connection Button
                  Expanded(
                    flex: 4,
                    child: PressableNeumorphicCard(
                      onTap: (_isTesting || _isSaving) ? null : _testConnection,
                      borderRadius: BorderRadius.circular(16),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isTesting)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.heroGradientStart,
                              ),
                            )
                          else
                            const Icon(
                              Icons.wifi_tethering_rounded,
                              size: 18,
                              color: AppColors.heroGradientStart,
                            ),
                          const SizedBox(width: 8),
                          Text(
                            _isTesting ? 'جارٍ الفحص...' : 'اختبار الاتصال',
                            style: GoogleFonts.cairo(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.heroGradientStart,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Save / Submit Button
                  Expanded(
                    flex: 6,
                    child: PressableNeumorphicCard(
                      onTap: (_isSaving || _isTesting) ? null : _submitForm,
                      backgroundColor: AppColors.accentYellow,
                      borderRadius: BorderRadius.circular(16),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isSaving)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.textDark,
                              ),
                            )
                          else
                            const Icon(
                              Icons.save_rounded,
                              size: 18,
                              color: AppColors.textDark,
                            ),
                          const SizedBox(width: 8),
                          Text(
                            _isSaving
                                ? 'جارٍ الحفظ...'
                                : (widget.routerToEdit != null
                                    ? 'حفظ التعديلات'
                                    : 'حفظ الراوتر'),
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
