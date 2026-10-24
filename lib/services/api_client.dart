// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System
// File: lib/services/api_client.dart
// Service: Central HTTP API Client for Backend Integration
// Master Reference: Rule 18 (Backend Rule), Rule 23 (Error Handling)
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/card_batch_model.dart';
import '../models/card_model.dart';
import '../models/package_model.dart';
import '../models/router_model.dart';
import '../models/sale_model.dart';
import '../models/staff_user_model.dart';
import '../models/subscription_status_model.dart';
import '../models/admin_tenant_model.dart';
import '../models/license_code_model.dart';
import '../models/platform_settings_model.dart';
import '../models/notification_model.dart';

class ApiClient {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://alrafeerouter.zone.id',
  );
  static const Duration timeoutDuration = Duration(seconds: 25);
  static const Duration loginTimeoutDuration = Duration(seconds: 60);
  static const String tokenStorageKey = 'auth_token';

  static http.Client client = http.Client();
  static String? _authToken;

  /// Returns the current in-memory authorization token.
  static String? get authToken => _authToken;

  /// Whether an authorization token is currently held.
  static bool get isAuthenticated => _authToken != null && _authToken!.isNotEmpty;

  /// Extracts the user's role from the stored auth token without any network request.
  static String? getUserRole() {
    if (_authToken == null || _authToken!.isEmpty) return null;
    try {
      final parts = _authToken!.split('.');
      if (parts.length != 3) return null;
      final normalized = base64Url.normalize(parts[1]);
      final payload = jsonDecode(utf8.decode(base64Url.decode(normalized)));
      return payload['role'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Whether the authenticated user has an administrator role (TENANT_ADMIN or SUPER_ADMIN).
  static bool get isAdmin {
    final role = getUserRole();
    return role == 'TENANT_ADMIN' || role == 'SUPER_ADMIN';
  }

  /// Whether the authenticated user is the platform super administrator (SUPER_ADMIN).
  static bool get isSuperAdmin {
    return getUserRole() == 'SUPER_ADMIN';
  }

  /// Manually set the auth token (useful in tests or when restored).
  static void setAuthToken(String? token) {
    _authToken = token;
  }

  static const String deviceFingerprintStorageKey = 'device_fingerprint';
  static String? _cachedDeviceFingerprint;

  /// Returns a persistent unique device fingerprint stored in SharedPreferences.
  /// If not present, generates a persistent identifier and saves it.
  static Future<String> getDeviceFingerprint() async {
    if (_cachedDeviceFingerprint != null && _cachedDeviceFingerprint!.isNotEmpty) {
      return _cachedDeviceFingerprint!;
    }
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(milliseconds: 300),
      );
      String? stored = prefs.getString(deviceFingerprintStorageKey);
      if (stored == null || stored.isEmpty) {
        final now = DateTime.now().microsecondsSinceEpoch;
        final rand = (100000 + (DateTime.now().millisecond * 899)).toString();
        stored = 'dev_${now}_$rand';
        await prefs.setString(deviceFingerprintStorageKey, stored);
      }
      _cachedDeviceFingerprint = stored;
      return stored;
    } catch (_) {
      _cachedDeviceFingerprint ??= 'dev_local_${DateTime.now().millisecondsSinceEpoch}';
      return _cachedDeviceFingerprint!;
    }
  }

  /// Sets or overrides the device fingerprint in memory (useful in testing).
  static void setDeviceFingerprint(String? fingerprint) {
    _cachedDeviceFingerprint = fingerprint;
  }

  /// Returns a human-friendly device label for audit logs and verification notifications.
  static String getDeviceLabel() {
    try {
      return 'تطبيق جلسة (${Platform.operatingSystem})';
    } catch (_) {
      return 'متصفح الويب (Web Client)';
    }
  }

  /// Resets client and active in-memory token (useful between test cases).
  static void resetClient() {
    client = http.Client();
    _authToken = null;
    _cachedDeviceFingerprint = null;
  }

  /// Builds standard request headers with Authorization Bearer token injected if present.
  static Map<String, String> _buildHeaders({bool isJson = false}) {
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    if (isJson) {
      headers['Content-Type'] = 'application/json';
    }
    if (_authToken != null && _authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  /// Loads the saved JWT token from SharedPreferences if available.
  static Future<String?> loadSavedToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(tokenStorageKey);
      if (token != null && token.isNotEmpty) {
        _authToken = token;
        return token;
      }
    } catch (_) {}
    return null;
  }

  /// Clears the active authentication token and removes it from persistent storage.
  static Future<void> logout() async {
    _authToken = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(tokenStorageKey);
    } catch (_) {}
  }

  /// Authenticates with the backend via username and password,
  /// stores the JWT token in memory and SharedPreferences.
  static Future<Map<String, dynamic>> login({
    required String username,
    String? identifier,
    required String password,
    String? deviceFingerprint,
    String? deviceLabel,
  }) async {
    final effectiveIdentifier = (identifier ?? username).trim();
    final fingerprint = deviceFingerprint ?? await getDeviceFingerprint();
    final label = deviceLabel ?? getDeviceLabel();
    final uri = Uri.parse('$baseUrl/api/v1/auth/login');
    final payload = jsonEncode({
      'identifier': effectiveIdentifier,
      'username': effectiveIdentifier,
      'password': password,
      'deviceFingerprint': fingerprint,
      'deviceLabel': label,
    });

    final stopwatch = Stopwatch()..start();
    try {
      final response = await client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: payload,
          )
          .timeout(loginTimeoutDuration);
      stopwatch.stop();

      final Map<String, dynamic> body = jsonDecode(
        utf8.decode(response.bodyBytes),
      ) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final data = body['data'] as Map<String, dynamic>;
        final requiresDeviceVerification = data['requiresDeviceVerification'] == true;
        debugPrint(
          '[ApiClient.login] status=${response.statusCode} success=true '
          'requiresDeviceVerification=$requiresDeviceVerification '
          'elapsedMs=${stopwatch.elapsedMilliseconds}',
        );

        if (requiresDeviceVerification) {
          return {
            'success': true,
            'requiresDeviceVerification': true,
            'tempToken': data['tempToken'] as String?,
            'emailMasked': data['emailMasked'] as String?,
            'deviceFingerprint': fingerprint,
            'deviceLabel': label,
            'message': data['message'] as String? ?? 'تم إرسال كود تحقق لبريدك لأن هذا جهاز جديد',
            'data': data,
          };
        }

        final token = data['token'] as String?;
        if (token != null && token.isNotEmpty) {
          _authToken = token;
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(tokenStorageKey, token);
          } catch (_) {}
        }
        return {
          'success': true,
          'data': data,
        };
      } else if (response.statusCode == 401) {
        debugPrint(
          '[ApiClient.login] status=401 errorCode=${body['errorCode'] ?? 'UNAUTHORIZED'} '
          'elapsedMs=${stopwatch.elapsedMilliseconds}',
        );
        await logout();
        return {
          'success': false,
          'errorCode': 'UNAUTHORIZED',
          'errorMessage': body['errorMessage'] ?? body['message'] ?? 'بيانات الدخول غير صحيحة',
        };
      } else if (response.statusCode == 429) {
        return {
          'success': false,
          'errorCode': 'RATE_LIMIT_EXCEEDED',
          'errorMessage': body['errorMessage'] ?? body['message'] ?? 'تم تجاوز محاولات تسجيل الدخول المسموح بها مؤقتاً. يرجى الانتظار دقيقة والمحاولة مجدداً.',
        };
      } else {
        debugPrint(
          '[ApiClient.login] status=${response.statusCode} '
          'errorCode=${body['errorCode'] ?? 'SERVER_ERROR'} '
          'elapsedMs=${stopwatch.elapsedMilliseconds}',
        );
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'SERVER_ERROR',
          'errorMessage': body['errorMessage'] ??
              body['message'] ??
              'فشل تسجيل الدخول (${response.statusCode})',
        };
      }
    } on TimeoutException {
      stopwatch.stop();
      debugPrint(
        '[ApiClient.login] TIMEOUT after ${stopwatch.elapsedMilliseconds}ms '
        '(limit=${loginTimeoutDuration.inSeconds}s)',
      );
      return {
        'success': false,
        'errorCode': 'TIMEOUT',
        'errorMessage':
            'انتهت مهلة الاتصال بالخادم (60 ثانية). يرجى التأكد من استجابة السيرفر.',
      };
    } on SocketException {
      return {
        'success': false,
        'errorCode': 'NETWORK_UNREACHABLE',
        'errorMessage':
            'تعذر الاتصال بالخادم. يرجى التأكد من اتصالك بالإنترنت وتوفر الخدمة.',
      };
    } on FormatException {
      return {
        'success': false,
        'errorCode': 'INVALID_RESPONSE',
        'errorMessage': 'استجابة الخادم بتنسيق غير متوافق (ليست JSON صالحة).',
      };
    } catch (e) {
      return {
        'success': false,
        'errorCode': 'UNKNOWN_ERROR',
        'errorMessage': 'حدث خطأ غير متوقع أثناء تسجيل الدخول: $e',
      };
    }
  }

  /// Verifies the OTP sent via email for new device login.
  /// On success, stores the full JWT token in memory & SharedPreferences.
  static Future<Map<String, dynamic>> verifyDeviceOtp({
    required String tempToken,
    required String otpCode,
    String? deviceFingerprint,
    String? deviceLabel,
  }) async {
    final fingerprint = deviceFingerprint ?? await getDeviceFingerprint();
    final label = deviceLabel ?? getDeviceLabel();
    final uri = Uri.parse('$baseUrl/api/v1/auth/verify-device-otp');
    final payload = jsonEncode({
      'tempToken': tempToken,
      'otpCode': otpCode,
      'deviceFingerprint': fingerprint,
      'deviceLabel': label,
    });

    try {
      final response = await client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: payload,
          )
          .timeout(timeoutDuration);

      final Map<String, dynamic> body = jsonDecode(
        utf8.decode(response.bodyBytes),
      ) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final data = body['data'] as Map<String, dynamic>;
        final token = data['token'] as String?;
        if (token != null && token.isNotEmpty) {
          _authToken = token;
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(tokenStorageKey, token);
          } catch (_) {}
        }
        return {
          'success': true,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'INVALID_OR_EXPIRED_OTP',
          'errorMessage': body['errorMessage'] ?? 'كود التحقق غير صحيح أو انتهت صلاحيته',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'errorCode': 'TIMEOUT',
        'errorMessage': 'انتهت مهلة الاتصال بالخادم (${timeoutDuration.inSeconds} ثانية). يرجى التأكد من استجابة السيرفر.',
      };
    } on SocketException {
      return {
        'success': false,
        'errorCode': 'NETWORK_UNREACHABLE',
        'errorMessage': 'تعذر الاتصال بالخادم. يرجى التأكد من اتصالك بالإنترنت وتوفر الخدمة.',
      };
    } catch (e) {
      return {
        'success': false,
        'errorCode': 'UNKNOWN_ERROR',
        'errorMessage': 'حدث خطأ أثناء تأكيد الجهاز: $e',
      };
    }
  }

  /// Requests a new device verification OTP email with rate limit cooldown.
  static Future<Map<String, dynamic>> resendDeviceOtp({
    required String tempToken,
    String? deviceLabel,
  }) async {
    final label = deviceLabel ?? getDeviceLabel();
    final uri = Uri.parse('$baseUrl/api/v1/auth/resend-device-otp');
    final payload = jsonEncode({
      'tempToken': tempToken,
      'deviceLabel': label,
    });

    try {
      final response = await client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: payload,
          )
          .timeout(timeoutDuration);

      final Map<String, dynamic> body = jsonDecode(
        utf8.decode(response.bodyBytes),
      ) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return {
          'success': true,
          'message': body['message'] ?? 'تم إرسال رمز تحقق جديد إلى بريدك الإلكتروني',
        };
      }

      if (response.statusCode == 429) {
        return {
          'success': false,
          'errorCode': 'RATE_LIMIT_EXCEEDED',
          'errorMessage': body['errorMessage'] ?? 'يرجى الانتظار قليلاً قبل طلب رمز جديد',
        };
      }

      return {
        'success': false,
        'errorCode': body['errorCode'] ?? 'RESEND_OTP_FAILED',
        'errorMessage': body['errorMessage'] ?? 'فشل إعادة إرسال رمز التحقق',
      };
    } on SocketException {
      return {
        'success': false,
        'errorCode': 'NETWORK_UNREACHABLE',
        'errorMessage': 'تعذر الاتصال بالخادم. يرجى التأكد من اتصالك بالإنترنت.',
      };
    } catch (e) {
      return {
        'success': false,
        'errorCode': 'UNKNOWN_ERROR',
        'errorMessage': 'حدث خطأ أثناء إعادة إرسال رمز التحقق: $e',
      };
    }
  }

  /// Tests connectivity to a MikroTik router through the backend API.
  static Future<Map<String, dynamic>> testRouterConnection({
    required String host,
    required int port,
    required String username,
    required String password,
    String? connectionMethod,
    String? certificateFingerprint,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/routers/test-connection');
    final Map<String, dynamic> data = {
      'host': host,
      'port': port,
      'username': username,
      'password': password,
    };
    if (connectionMethod != null && connectionMethod.isNotEmpty) {
      data['connectionMethod'] = connectionMethod;
    }
    if (certificateFingerprint != null && certificateFingerprint.isNotEmpty) {
      data['certificateFingerprint'] = certificateFingerprint;
    }
    final payload = jsonEncode(data);

    try {
      final response = await client
          .post(
            uri,
            headers: _buildHeaders(isJson: true),
            body: payload,
          )
          .timeout(timeoutDuration);

      final Map<String, dynamic> body = jsonDecode(
        utf8.decode(response.bodyBytes),
      ) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return body;
      } else if (response.statusCode == 401) {
        await logout();
        return {
          'success': false,
          'errorCode': 'UNAUTHORIZED',
          'errorMessage': body['errorMessage'] ?? body['message'] ?? 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً.',
        };
      } else if (response.statusCode == 403) {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'TRIAL_CARD_GENERATION_LOCKED',
          'errorMessage': body['errorMessage'] ??
              body['message'] ??
              'يمكنك استخدام وظائف Jalsah خلال الفترة التجريبية. لتوليد كروت الإنترنت، يرجى الاشتراك في إحدى الباقات أو طلب تفعيل حسابك من الإدارة.',
        };
      } else if (response.statusCode == 404) {
        final serverMsg = body['errorMessage'] ?? body['message'];
        return {
          'success': false,
          'errorCode': 'ROUTE_NOT_FOUND',
          'errorMessage': serverMsg ?? 'مسار فحص الراوتر غير متوفر على الخادم (404). قد يتطلب تحديث نسخة الخادم السحابي.',
        };
      } else if (response.statusCode == 429) {
        final serverMsg = body['errorMessage'] ?? body['message'];
        return {
          'success': false,
          'errorCode': 'RATE_LIMIT_EXCEEDED',
          'errorMessage': serverMsg ?? 'تم تجاوز الحد الأقصى لمحاولات فحص الراوتر. يرجى الانتظار دقيقة والمحاولة مجدداً.',
        };
      } else if (response.statusCode == 422 || response.statusCode == 400) {
        return body;
      } else {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'SERVER_ERROR',
          'errorMessage':
              body['errorMessage'] ?? body['message'] ?? 'استجاب الخادم برمز خطأ غير متوقع (${response.statusCode})',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'errorCode': 'TIMEOUT',
        'errorMessage':
            'انتهت مهلة الاتصال بالخادم (${timeoutDuration.inSeconds} ثانية). يرجى التأكد من استجابة السيرفر.',
      };
    } on SocketException {
      return {
        'success': false,
        'errorCode': 'NETWORK_UNREACHABLE',
        'errorMessage':
            'تعذر الاتصال بالخادم. يرجى التأكد من اتصالك بالإنترنت وتوفر الخدمة.',
      };
    } on FormatException {
      return {
        'success': false,
        'errorCode': 'INVALID_RESPONSE',
        'errorMessage': 'استجابة الخادم بتنسيق غير متوافق (ليست JSON صالحة).',
      };
    } catch (e) {
      return {
        'success': false,
        'errorCode': 'UNKNOWN_ERROR',
        'errorMessage': 'حدث خطأ غير متوقع أثناء الاتصال: $e',
      };
    }
  }

  /// Fetches all registered routers for the current tenant from the backend.
  static Future<Map<String, dynamic>> getRouters() async {
    final uri = Uri.parse('$baseUrl/api/v1/routers');

    try {
      final response = await client.get(
        uri,
        headers: _buildHeaders(),
      ).timeout(timeoutDuration);

      final Map<String, dynamic> body = jsonDecode(
        utf8.decode(response.bodyBytes),
      ) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> rawList = body['data'] as List<dynamic>? ?? [];
        final List<RouterModel> routers = rawList
            .map((item) => RouterModel.fromJson(item as Map<String, dynamic>))
            .toList();
        return {
          'success': true,
          'data': routers,
        };
      } else if (response.statusCode == 401) {
        await logout();
        return {
          'success': false,
          'errorCode': 'UNAUTHORIZED',
          'errorMessage': body['errorMessage'] ?? 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً.',
        };
      } else {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'SERVER_ERROR',
          'errorMessage': body['errorMessage'] ??
              'استجاب الخادم برمز خطأ (${response.statusCode})',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'errorCode': 'TIMEOUT',
        'errorMessage':
            'انتهت مهلة الاتصال بالخادم (${timeoutDuration.inSeconds} ثانية). يرجى التأكد من استجابة السيرفر.',
      };
    } on SocketException {
      return {
        'success': false,
        'errorCode': 'NETWORK_UNREACHABLE',
        'errorMessage':
            'تعذر الاتصال بالخادم. يرجى التأكد من اتصالك بالإنترنت وتوفر الخدمة.',
      };
    } on FormatException {
      return {
        'success': false,
        'errorCode': 'INVALID_RESPONSE',
        'errorMessage': 'استجابة الخادم بتنسيق غير متوافق (ليست JSON صالحة).',
      };
    } catch (e) {
      return {
        'success': false,
        'errorCode': 'UNKNOWN_ERROR',
        'errorMessage': 'حدث خطأ غير متوقع أثناء جلب الراوترات: $e',
      };
    }
  }

  /// Registers and provisions a new router entity in the backend.
  static Future<Map<String, dynamic>> createRouter({
    required String name,
    required String host,
    required int port,
    required String username,
    required String password,
    String? connectionMethod,
    String? certificateFingerprint,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/routers');
    final Map<String, dynamic> data = {
      'name': name,
      'host': host,
      'port': port,
      'username': username,
      'password': password,
    };
    if (connectionMethod != null && connectionMethod.isNotEmpty) {
      data['connectionMethod'] = connectionMethod;
    }
    if (certificateFingerprint != null && certificateFingerprint.isNotEmpty) {
      data['certificateFingerprint'] = certificateFingerprint;
    }
    final payload = jsonEncode(data);

    try {
      final response = await client
          .post(
            uri,
            headers: _buildHeaders(isJson: true),
            body: payload,
          )
          .timeout(timeoutDuration);

      final Map<String, dynamic> body = jsonDecode(
        utf8.decode(response.bodyBytes),
      ) as Map<String, dynamic>;

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          body['success'] == true) {
        final routerData = body['data'] as Map<String, dynamic>;
        return {
          'success': true,
          'data': RouterModel.fromJson(routerData),
        };
      } else if (response.statusCode == 401) {
        await logout();
        return {
          'success': false,
          'errorCode': 'UNAUTHORIZED',
          'errorMessage': body['errorMessage'] ?? 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً.',
        };
      } else if (response.statusCode == 409) {
        return {
          'success': false,
          'errorCode': 'ROUTER_NAME_EXISTS',
          'errorMessage': body['errorMessage'] ?? body['message'] ?? 'اسم الراوتر مسجل مسبقاً، يرجى اختيار اسم مختلف.',
        };
      } else if (response.statusCode == 429) {
        return {
          'success': false,
          'errorCode': 'RATE_LIMIT_EXCEEDED',
          'errorMessage': body['errorMessage'] ?? body['message'] ?? 'تم تجاوز حد الطلبات المسموح. يرجى الانتظار قليلاً.',
        };
      } else {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'SERVER_ERROR',
          'errorMessage': body['errorMessage'] ??
              body['message'] ??
              'فشل إضافة الراوتر (${response.statusCode})',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'errorCode': 'TIMEOUT',
        'errorMessage':
            'انتهت مهلة الاتصال بالخادم (${timeoutDuration.inSeconds} ثانية). يرجى التأكد من استجابة السيرفر.',
      };
    } on SocketException {
      return {
        'success': false,
        'errorCode': 'NETWORK_UNREACHABLE',
        'errorMessage':
            'تعذر الاتصال بالخادم. يرجى التأكد من اتصالك بالإنترنت وتوفر الخدمة.',
      };
    } on FormatException {
      return {
        'success': false,
        'errorCode': 'INVALID_RESPONSE',
        'errorMessage': 'استجابة الخادم بتنسيق غير متوافق (ليست JSON صالحة).',
      };
    } catch (e) {
      return {
        'success': false,
        'errorCode': 'UNKNOWN_ERROR',
        'errorMessage': 'حدث خطأ غير متوقع أثناء إضافة الراوتر: $e',
      };
    }
  }

  /// Deletes a router by its ID from the backend.
  static Future<Map<String, dynamic>> deleteRouter(String id) async {
    final uri = Uri.parse('$baseUrl/api/v1/routers/$id');

    try {
      final response = await client.delete(
        uri,
        headers: _buildHeaders(),
      ).timeout(timeoutDuration);

      final Map<String, dynamic> body = jsonDecode(
        utf8.decode(response.bodyBytes),
      ) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return {
          'success': true,
          'message': body['message'] ?? 'تم حذف الراوتر بنجاح',
        };
      } else if (response.statusCode == 401) {
        await logout();
        return {
          'success': false,
          'errorCode': 'UNAUTHORIZED',
          'errorMessage': body['errorMessage'] ?? body['message'] ?? 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً.',
        };
      } else if (response.statusCode == 403) {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'TRIAL_CARD_GENERATION_LOCKED',
          'errorMessage': body['errorMessage'] ??
              body['message'] ??
              'يمكنك استخدام وظائف Jalsah خلال الفترة التجريبية. لتوليد كروت الإنترنت، يرجى الاشتراك في إحدى الباقات أو طلب تفعيل حسابك من الإدارة.',
        };
      } else if (response.statusCode == 404) {
        return {
          'success': false,
          'errorCode': 'ROUTER_NOT_FOUND',
          'errorMessage': body['errorMessage'] ?? body['message'] ?? 'الراوتر المطلوب غير موجود أو تم حذفه مسبقاً.',
        };
      } else if (response.statusCode == 429) {
        return {
          'success': false,
          'errorCode': 'RATE_LIMIT_EXCEEDED',
          'errorMessage': body['errorMessage'] ?? body['message'] ?? 'تم تجاوز حد الطلبات. يرجى الانتظار قليلاً.',
        };
      } else {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'SERVER_ERROR',
          'errorMessage':
              body['errorMessage'] ?? body['message'] ?? 'فشل حذف الراوتر (${response.statusCode})',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'errorCode': 'TIMEOUT',
        'errorMessage':
            'انتهت مهلة الاتصال بالخادم (${timeoutDuration.inSeconds} ثانية). يرجى التأكد من استجابة السيرفر.',
      };
    } on SocketException {
      return {
        'success': false,
        'errorCode': 'NETWORK_UNREACHABLE',
        'errorMessage':
            'تعذر الاتصال بالخادم. يرجى التأكد من اتصالك بالإنترنت وتوفر الخدمة.',
      };
    } on FormatException {
      return {
        'success': false,
        'errorCode': 'INVALID_RESPONSE',
        'errorMessage': 'استجابة الخادم بتنسيق غير متوافق (ليست JSON صالحة).',
      };
    } catch (e) {
      return {
        'success': false,
        'errorCode': 'UNKNOWN_ERROR',
        'errorMessage': 'حدث خطأ غير متوقع أثناء حذف الراوتر: $e',
      };
    }
  }

  /// Updates an existing router entity in the backend.
  static Future<Map<String, dynamic>> updateRouter({
    required String id,
    String? name,
    String? host,
    int? port,
    String? username,
    String? password,
    String? connectionMethod,
    String? certificateFingerprint,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/routers/$id');
    final Map<String, dynamic> data = {};
    if (name != null) data['name'] = name;
    if (host != null) data['host'] = host;
    if (port != null) data['port'] = port;
    if (username != null) data['username'] = username;
    if (password != null && password.isNotEmpty) data['password'] = password;
    if (connectionMethod != null && connectionMethod.isNotEmpty) {
      data['connectionMethod'] = connectionMethod;
    }
    if (certificateFingerprint != null && certificateFingerprint.isNotEmpty) {
      data['certificateFingerprint'] = certificateFingerprint;
    }

    try {
      final response = await client
          .patch(
            uri,
            headers: _buildHeaders(isJson: true),
            body: jsonEncode(data),
          )
          .timeout(timeoutDuration);

      final Map<String, dynamic> body = jsonDecode(
        utf8.decode(response.bodyBytes),
      ) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return {
          'success': true,
          'data': RouterModel.fromJson(body['data'] as Map<String, dynamic>),
        };
      } else if (response.statusCode == 401) {
        await logout();
        return {
          'success': false,
          'errorCode': 'UNAUTHORIZED',
          'errorMessage': body['errorMessage'] ?? body['message'] ?? 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً.',
        };
      } else if (response.statusCode == 403) {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'TRIAL_CARD_GENERATION_LOCKED',
          'errorMessage': body['errorMessage'] ??
              body['message'] ??
              'يمكنك استخدام وظائف Jalsah خلال الفترة التجريبية. لتوليد كروت الإنترنت، يرجى الاشتراك في إحدى الباقات أو طلب تفعيل حسابك من الإدارة.',
        };
      } else if (response.statusCode == 404) {
        return {
          'success': false,
          'errorCode': 'ROUTER_NOT_FOUND',
          'errorMessage': body['errorMessage'] ?? body['message'] ?? 'الراوتر المطلوب أو المسار غير متوفر على الخادم (404).',
        };
      } else if (response.statusCode == 429) {
        return {
          'success': false,
          'errorCode': 'RATE_LIMIT_EXCEEDED',
          'errorMessage': body['errorMessage'] ?? body['message'] ?? 'تم تجاوز حد الطلبات. يرجى الانتظار قليلاً.',
        };
      } else {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'SERVER_ERROR',
          'errorMessage': body['errorMessage'] ?? body['message'] ?? 'فشل تحديث بيانات الراوتر (${response.statusCode})',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'errorCode': 'TIMEOUT',
        'errorMessage': 'انتهت مهلة الاتصال بالخادم (${timeoutDuration.inSeconds} ثانية). يرجى التأكد من استجابة السيرفر.',
      };
    } on SocketException {
      return {
        'success': false,
        'errorCode': 'NETWORK_UNREACHABLE',
        'errorMessage': 'تعذر الاتصال بالخادم. يرجى التأكد من اتصالك بالإنترنت وتوفر الخدمة.',
      };
    } catch (e) {
      return {
        'success': false,
        'errorCode': 'UNKNOWN_ERROR',
        'errorMessage': 'حدث خطأ غير متوقع أثناء تحديث الراوتر: $e',
      };
    }
  }

  /// Tests connection to an already stored router entity in the backend.
  static Future<Map<String, dynamic>> testRouterConnectionForId(String id) async {
    final uri = Uri.parse('$baseUrl/api/v1/routers/$id/test-connection');

    try {
      final response = await client
          .post(
            uri,
            headers: _buildHeaders(isJson: true),
            body: jsonEncode({}),
          )
          .timeout(timeoutDuration);

      final Map<String, dynamic> body = jsonDecode(
        utf8.decode(response.bodyBytes),
      ) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return {
          'success': true,
          'data': body['data'],
        };
      } else if (response.statusCode == 401) {
        await logout();
        return {
          'success': false,
          'errorCode': 'UNAUTHORIZED',
          'errorMessage': body['errorMessage'] ?? body['message'] ?? 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً.',
        };
      } else if (response.statusCode == 403) {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'TRIAL_CARD_GENERATION_LOCKED',
          'errorMessage': body['errorMessage'] ??
              body['message'] ??
              'يمكنك استخدام وظائف Jalsah خلال الفترة التجريبية. لتوليد كروت الإنترنت، يرجى الاشتراك في إحدى الباقات أو طلب تفعيل حسابك من الإدارة.',
        };
      } else if (response.statusCode == 404) {
        return {
          'success': false,
          'errorCode': 'ROUTE_NOT_FOUND',
          'errorMessage': body['errorMessage'] ?? body['message'] ?? 'مسار فحص الراوتر غير متوفر على الخادم (404). قد يتطلب تحديث نسخة الخادم السحابي.',
        };
      } else if (response.statusCode == 429) {
        return {
          'success': false,
          'errorCode': 'RATE_LIMIT_EXCEEDED',
          'errorMessage': body['errorMessage'] ?? body['message'] ?? 'تم تجاوز الحد الأقصى لمحاولات فحص الراوتر. يرجى الانتظار دقيقة والمحاولة مجدداً.',
        };
      } else {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'CONNECTION_FAILED',
          'errorMessage': body['errorMessage'] ?? body['message'] ?? 'فشل فحص الاتصال بالراوتر (${response.statusCode})',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'errorCode': 'TIMEOUT',
        'errorMessage': 'انتهت مهلة الاتصال بالخادم (${timeoutDuration.inSeconds} ثانية). يرجى التأكد من استجابة السيرفر.',
      };
    } on SocketException {
      return {
        'success': false,
        'errorCode': 'NETWORK_UNREACHABLE',
        'errorMessage': 'تعذر الاتصال بالخادم. يرجى التأكد من اتصالك بالإنترنت وتوفر الخدمة.',
      };
    } catch (e) {
      return {
        'success': false,
        'errorCode': 'UNKNOWN_ERROR',
        'errorMessage': 'حدث خطأ غير متوقع أثناء فحص الراوتر: $e',
      };
    }
  }

  /// Fetches live HotSpot users configured on a router.
  static Future<Map<String, dynamic>> getRouterHotspotUsers(String routerId) async {
    final uri = Uri.parse('$baseUrl/api/v1/routers/$routerId/hotspot-users');

    try {
      final response = await client
          .get(
            uri,
            headers: _buildHeaders(),
          )
          .timeout(timeoutDuration);

      final Map<String, dynamic> body = jsonDecode(
        utf8.decode(response.bodyBytes),
      ) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> users = body['data'] as List<dynamic>? ?? [];
        return {
          'success': true,
          'data': users,
        };
      } else if (response.statusCode == 401) {
        await logout();
        return {
          'success': false,
          'errorCode': 'UNAUTHORIZED',
          'errorMessage': body['errorMessage'] ?? body['message'] ?? 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً.',
        };
      } else if (response.statusCode == 403) {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'TRIAL_CARD_GENERATION_LOCKED',
          'errorMessage': body['errorMessage'] ??
              body['message'] ??
              'يمكنك استخدام وظائف Jalsah خلال الفترة التجريبية. لتوليد كروت الإنترنت، يرجى الاشتراك في إحدى الباقات أو طلب تفعيل حسابك من الإدارة.',
        };
      } else if (response.statusCode == 404) {
        return {
          'success': false,
          'errorCode': 'ROUTE_NOT_FOUND',
          'errorMessage': body['errorMessage'] ?? body['message'] ?? 'مسار مستخدمي الهوتسبوت غير متوفر على الخادم (404). قد يتطلب تحديث نسخة الخادم السحابي.',
        };
      } else if (response.statusCode == 429) {
        return {
          'success': false,
          'errorCode': 'RATE_LIMIT_EXCEEDED',
          'errorMessage': body['errorMessage'] ?? body['message'] ?? 'تم تجاوز معدل الطلبات للراوتر. يرجى الانتظار قليلاً.',
        };
      } else {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'SERVER_ERROR',
          'errorMessage': body['errorMessage'] ?? body['message'] ?? 'فشل جلب مستخدمي الهوتسبوت (${response.statusCode})',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'errorCode': 'TIMEOUT',
        'errorMessage': 'انتهت مهلة الاتصال بالخادم (${timeoutDuration.inSeconds} ثانية). يرجى التأكد من استجابة السيرفر.',
      };
    } on SocketException {
      return {
        'success': false,
        'errorCode': 'NETWORK_UNREACHABLE',
        'errorMessage': 'تعذر الاتصال بالخادم. يرجى التأكد من اتصالك بالإنترنت وتوفر الخدمة.',
      };
    } catch (e) {
      return {
        'success': false,
        'errorCode': 'UNKNOWN_ERROR',
        'errorMessage': 'حدث خطأ غير متوقع أثناء جلب مستخدمي الهوتسبوت: $e',
      };
    }
  }

  /// Fetches live HotSpot active sessions on a router.
  static Future<Map<String, dynamic>> getRouterHotspotSessions(String routerId) async {
    final uri = Uri.parse('$baseUrl/api/v1/routers/$routerId/hotspot-sessions');

    try {
      final response = await client
          .get(
            uri,
            headers: _buildHeaders(),
          )
          .timeout(timeoutDuration);

      final Map<String, dynamic> body = jsonDecode(
        utf8.decode(response.bodyBytes),
      ) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> sessions = body['data'] as List<dynamic>? ?? [];
        return {
          'success': true,
          'data': sessions,
        };
      } else if (response.statusCode == 401) {
        await logout();
        return {
          'success': false,
          'errorCode': 'UNAUTHORIZED',
          'errorMessage': body['errorMessage'] ?? body['message'] ?? 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً.',
        };
      } else if (response.statusCode == 403) {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'TRIAL_CARD_GENERATION_LOCKED',
          'errorMessage': body['errorMessage'] ??
              body['message'] ??
              'يمكنك استخدام وظائف Jalsah خلال الفترة التجريبية. لتوليد كروت الإنترنت، يرجى الاشتراك في إحدى الباقات أو طلب تفعيل حسابك من الإدارة.',
        };
      } else if (response.statusCode == 404) {
        return {
          'success': false,
          'errorCode': 'ROUTE_NOT_FOUND',
          'errorMessage': body['errorMessage'] ?? body['message'] ?? 'مسار الجلسات النشطة غير متوفر على الخادم (404). قد يتطلب تحديث نسخة الخادم السحابي.',
        };
      } else if (response.statusCode == 429) {
        return {
          'success': false,
          'errorCode': 'RATE_LIMIT_EXCEEDED',
          'errorMessage': body['errorMessage'] ?? body['message'] ?? 'تم تجاوز معدل الطلبات للراوتر. يرجى الانتظار قليلاً.',
        };
      } else {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'SERVER_ERROR',
          'errorMessage': body['errorMessage'] ?? body['message'] ?? 'فشل جلب الجلسات النشطة (${response.statusCode})',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'errorCode': 'TIMEOUT',
        'errorMessage': 'انتهت مهلة الاتصال بالخادم (${timeoutDuration.inSeconds} ثانية). يرجى التأكد من استجابة السيرفر.',
      };
    } on SocketException {
      return {
        'success': false,
        'errorCode': 'NETWORK_UNREACHABLE',
        'errorMessage': 'تعذر الاتصال بالخادم. يرجى التأكد من اتصالك بالإنترنت وتوفر الخدمة.',
      };
    } catch (e) {
      return {
        'success': false,
        'errorCode': 'UNKNOWN_ERROR',
        'errorMessage': 'حدث خطأ غير متوقع أثناء جلب الجلسات النشطة: $e',
      };
    }
  }

  /// Enables or disables a HotSpot user on a router.
  static Future<Map<String, dynamic>> toggleHotspotUser({
    required String routerId,
    required String username,
    required bool isEnabled,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/routers/$routerId/hotspot-users/$username');

    try {
      final response = await client
          .patch(
            uri,
            headers: _buildHeaders(isJson: true),
            body: jsonEncode({'isEnabled': isEnabled}),
          )
          .timeout(timeoutDuration);

      final Map<String, dynamic> body = jsonDecode(
        utf8.decode(response.bodyBytes),
      ) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return {
          'success': true,
          'message': body['message'] ?? 'تم تحديث حالة المستخدم بنجاح',
          'data': body['data'],
        };
      } else if (response.statusCode == 401) {
        await logout();
        return {
          'success': false,
          'errorCode': 'UNAUTHORIZED',
          'errorMessage': body['errorMessage'] ?? body['message'] ?? 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً.',
        };
      } else if (response.statusCode == 403) {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'TRIAL_CARD_GENERATION_LOCKED',
          'errorMessage': body['errorMessage'] ??
              body['message'] ??
              'يمكنك استخدام وظائف Jalsah خلال الفترة التجريبية. لتوليد كروت الإنترنت، يرجى الاشتراك في إحدى الباقات أو طلب تفعيل حسابك من الإدارة.',
        };
      } else if (response.statusCode == 404) {
        return {
          'success': false,
          'errorCode': 'ROUTE_NOT_FOUND',
          'errorMessage': body['errorMessage'] ?? body['message'] ?? 'مسار تعديل المستخدم غير متوفر على الخادم (404). قد يتطلب تحديث نسخة الخادم السحابي.',
        };
      } else if (response.statusCode == 429) {
        return {
          'success': false,
          'errorCode': 'RATE_LIMIT_EXCEEDED',
          'errorMessage': body['errorMessage'] ?? body['message'] ?? 'تم تجاوز معدل الطلبات للراوتر. يرجى الانتظار قليلاً.',
        };
      } else {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'SERVER_ERROR',
          'errorMessage': body['errorMessage'] ?? body['message'] ?? 'فشل تحديث حالة المستخدم (${response.statusCode})',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'errorCode': 'TIMEOUT',
        'errorMessage': 'انتهت مهلة الاتصال بالخادم (${timeoutDuration.inSeconds} ثانية). يرجى التأكد من استجابة السيرفر.',
      };
    } on SocketException {
      return {
        'success': false,
        'errorCode': 'NETWORK_UNREACHABLE',
        'errorMessage': 'تعذر الاتصال بالخادم. يرجى التأكد من اتصالك بالإنترنت وتوفر الخدمة.',
      };
    } catch (e) {
      return {
        'success': false,
        'errorCode': 'UNKNOWN_ERROR',
        'errorMessage': 'حدث خطأ غير متوقع أثناء تحديث حالة المستخدم: $e',
      };
    }
  }

  /// Disconnects an active HotSpot session on a router.
  static Future<Map<String, dynamic>> disconnectHotspotSession({
    required String routerId,
    required String username,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/routers/$routerId/hotspot-sessions/$username/disconnect');

    try {
      final response = await client
          .post(
            uri,
            headers: _buildHeaders(isJson: true),
            body: jsonEncode({}),
          )
          .timeout(timeoutDuration);

      final Map<String, dynamic> body = jsonDecode(
        utf8.decode(response.bodyBytes),
      ) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return {
          'success': true,
          'message': body['message'] ?? 'تم فصل الجلسة بنجاح',
        };
      } else if (response.statusCode == 401) {
        await logout();
        return {
          'success': false,
          'errorCode': 'UNAUTHORIZED',
          'errorMessage': body['errorMessage'] ?? body['message'] ?? 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً.',
        };
      } else if (response.statusCode == 403) {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'TRIAL_CARD_GENERATION_LOCKED',
          'errorMessage': body['errorMessage'] ??
              body['message'] ??
              'يمكنك استخدام وظائف Jalsah خلال الفترة التجريبية. لتوليد كروت الإنترنت، يرجى الاشتراك في إحدى الباقات أو طلب تفعيل حسابك من الإدارة.',
        };
      } else if (response.statusCode == 404) {
        return {
          'success': false,
          'errorCode': 'ROUTE_NOT_FOUND',
          'errorMessage': body['errorMessage'] ?? body['message'] ?? 'مسار فصل الجلسة غير متوفر على الخادم (404). قد يتطلب تحديث نسخة الخادم السحابي.',
        };
      } else if (response.statusCode == 429) {
        return {
          'success': false,
          'errorCode': 'RATE_LIMIT_EXCEEDED',
          'errorMessage': body['errorMessage'] ?? body['message'] ?? 'تم تجاوز معدل الطلبات للراوتر. يرجى الانتظار قليلاً.',
        };
      } else {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'SERVER_ERROR',
          'errorMessage': body['errorMessage'] ?? body['message'] ?? 'فشل فصل الجلسة (${response.statusCode})',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'errorCode': 'TIMEOUT',
        'errorMessage': 'انتهت مهلة الاتصال بالخادم (${timeoutDuration.inSeconds} ثانية). يرجى التأكد من استجابة السيرفر.',
      };
    } on SocketException {
      return {
        'success': false,
        'errorCode': 'NETWORK_UNREACHABLE',
        'errorMessage': 'تعذر الاتصال بالخادم. يرجى التأكد من اتصالك بالإنترنت وتوفر الخدمة.',
      };
    } catch (e) {
      return {
        'success': false,
        'errorCode': 'UNKNOWN_ERROR',
        'errorMessage': 'حدث خطأ غير متوقع أثناء فصل الجلسة: $e',
      };
    }
  }

  /// Fetches all packages for the current tenant from the backend.
  static Future<Map<String, dynamic>> getPackages() async {
    final uri = Uri.parse('$baseUrl/api/v1/packages');

    try {
      final response = await client.get(
        uri,
        headers: _buildHeaders(),
      ).timeout(timeoutDuration);

      final Map<String, dynamic> body = jsonDecode(
        utf8.decode(response.bodyBytes),
      ) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> rawList = body['data'] as List<dynamic>? ?? [];
        final List<PackageModel> packages = rawList
            .map((item) => PackageModel.fromJson(item as Map<String, dynamic>))
            .toList();
        return {
          'success': true,
          'data': packages,
        };
      } else if (response.statusCode == 401) {
        await logout();
        return {
          'success': false,
          'errorCode': 'UNAUTHORIZED',
          'errorMessage': body['errorMessage'] ?? 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً.',
        };
      } else {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'SERVER_ERROR',
          'errorMessage': body['errorMessage'] ??
              'استجاب الخادم برمز خطأ (${response.statusCode})',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'errorCode': 'TIMEOUT',
        'errorMessage':
            'انتهت مهلة الاتصال بالخادم (${timeoutDuration.inSeconds} ثانية). يرجى التأكد من استجابة السيرفر.',
      };
    } on SocketException {
      return {
        'success': false,
        'errorCode': 'NETWORK_UNREACHABLE',
        'errorMessage':
            'تعذر الاتصال بالخادم. يرجى التأكد من اتصالك بالإنترنت وتوفر الخدمة.',
      };
    } on FormatException {
      return {
        'success': false,
        'errorCode': 'INVALID_RESPONSE',
        'errorMessage': 'استجابة الخادم بتنسيق غير متوافق (ليست JSON صالحة).',
      };
    } catch (e) {
      return {
        'success': false,
        'errorCode': 'UNKNOWN_ERROR',
        'errorMessage': 'حدث خطأ غير متوقع أثناء جلب الباقات: $e',
      };
    }
  }

  /// Creates a new internet package in the backend.
  static Future<Map<String, dynamic>> createPackage({
    required String name,
    required String code,
    required String downloadSpeedLimit,
    required String uploadSpeedLimit,
    required int durationMinutes,
    required int validityDays,
    required double price,
    required String hotspotProfileName,
    int? dataLimitBytes,
    bool isActive = true,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/packages');
    final Map<String, dynamic> payloadMap = {
      'name': name,
      'code': code,
      'downloadSpeedLimit': downloadSpeedLimit,
      'uploadSpeedLimit': uploadSpeedLimit,
      'durationMinutes': durationMinutes,
      'validityDays': validityDays,
      'price': price,
      'hotspotProfileName': hotspotProfileName,
      'isActive': isActive,
    };
    if (dataLimitBytes != null) {
      payloadMap['dataLimitBytes'] = dataLimitBytes;
    }
    final payload = jsonEncode(payloadMap);

    try {
      final response = await client
          .post(
            uri,
            headers: _buildHeaders(isJson: true),
            body: payload,
          )
          .timeout(timeoutDuration);

      final Map<String, dynamic> body = jsonDecode(
        utf8.decode(response.bodyBytes),
      ) as Map<String, dynamic>;

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          body['success'] == true) {
        final pkgData = body['data'] as Map<String, dynamic>;
        return {
          'success': true,
          'data': PackageModel.fromJson(pkgData),
        };
      } else if (response.statusCode == 401) {
        await logout();
        return {
          'success': false,
          'errorCode': 'UNAUTHORIZED',
          'errorMessage': body['errorMessage'] ?? 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً.',
        };
      } else if (response.statusCode == 409) {
        return {
          'success': false,
          'errorCode': 'PACKAGE_CODE_EXISTS',
          'errorMessage': 'كود الباقة مسجل مسبقاً، يرجى اختيار كود مختلف.',
        };
      } else if (response.statusCode == 400) {
        return {
          'success': false,
          'errorCode': 'VALIDATION_ERROR',
          'errorMessage': body['errorMessage'] ??
              'بيانات الباقة غير صالحة، يرجى التحقق من صحة المدخلات.',
        };
      } else {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'SERVER_ERROR',
          'errorMessage': body['errorMessage'] ??
              'فشل إضافة الباقة (${response.statusCode})',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'errorCode': 'TIMEOUT',
        'errorMessage':
            'انتهت مهلة الاتصال بالخادم (${timeoutDuration.inSeconds} ثانية). يرجى التأكد من استجابة السيرفر.',
      };
    } on SocketException {
      return {
        'success': false,
        'errorCode': 'NETWORK_UNREACHABLE',
        'errorMessage':
            'تعذر الاتصال بالخادم. يرجى التأكد من اتصالك بالإنترنت وتوفر الخدمة.',
      };
    } on FormatException {
      return {
        'success': false,
        'errorCode': 'INVALID_RESPONSE',
        'errorMessage': 'استجابة الخادم بتنسيق غير متوافق (ليست JSON صالحة).',
      };
    } catch (e) {
      return {
        'success': false,
        'errorCode': 'UNKNOWN_ERROR',
        'errorMessage': 'حدث خطأ غير متوقع أثناء إضافة الباقة: $e',
      };
    }
  }

  /// Deletes a package by its ID from the backend.
  static Future<Map<String, dynamic>> deletePackage(String id) async {
    final uri = Uri.parse('$baseUrl/api/v1/packages/$id');

    try {
      final response = await client.delete(
        uri,
        headers: _buildHeaders(),
      ).timeout(timeoutDuration);

      final Map<String, dynamic> body = jsonDecode(
        utf8.decode(response.bodyBytes),
      ) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return {
          'success': true,
          'message': body['message'] ?? 'تم حذف الباقة بنجاح',
        };
      } else if (response.statusCode == 401) {
        await logout();
        return {
          'success': false,
          'errorCode': 'UNAUTHORIZED',
          'errorMessage': body['errorMessage'] ?? 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً.',
        };
      } else if (response.statusCode == 404) {
        return {
          'success': false,
          'errorCode': 'PACKAGE_NOT_FOUND',
          'errorMessage': 'الباقة المطلوبة غير موجودة أو تم حذفها مسبقاً.',
        };
      } else {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'SERVER_ERROR',
          'errorMessage':
              body['errorMessage'] ?? 'فشل حذف الباقة (${response.statusCode})',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'errorCode': 'TIMEOUT',
        'errorMessage':
            'انتهت مهلة الاتصال بالخادم (${timeoutDuration.inSeconds} ثانية). يرجى التأكد من استجابة السيرفر.',
      };
    } on SocketException {
      return {
        'success': false,
        'errorCode': 'NETWORK_UNREACHABLE',
        'errorMessage':
            'تعذر الاتصال بالخادم. يرجى التأكد من اتصالك بالإنترنت وتوفر الخدمة.',
      };
    } on FormatException {
      return {
        'success': false,
        'errorCode': 'INVALID_RESPONSE',
        'errorMessage': 'استجابة الخادم بتنسيق غير متوافق (ليست JSON صالحة).',
      };
    } catch (e) {
      return {
        'success': false,
        'errorCode': 'UNKNOWN_ERROR',
        'errorMessage': 'حدث خطأ غير متوقع أثناء حذف الباقة: $e',
      };
    }
  }

  /// Generates a new batch of hotspot cards associated with an internet package and router.
  static Future<Map<String, dynamic>> generateCardBatch({
    required String packageId,
    required int quantity,
    String? routerId,
    String? prefix,
    int? userLength,
    int? passwordLength,
    String? generationMode,
    Duration timeoutDuration = const Duration(seconds: 45),
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/cards/generate-batch');
    final Map<String, dynamic> payloadMap = {
      'packageId': packageId,
      'quantity': quantity,
    };
    if (routerId != null && routerId.trim().isNotEmpty) {
      payloadMap['routerId'] = routerId.trim();
    }
    if (prefix != null && prefix.trim().isNotEmpty) {
      payloadMap['prefix'] = prefix.trim();
    }
    if (userLength != null && userLength > 0) {
      payloadMap['userLength'] = userLength;
    }
    if (passwordLength != null && passwordLength >= 0) {
      payloadMap['passwordLength'] = passwordLength;
    }
    if (generationMode != null && generationMode.trim().isNotEmpty) {
      payloadMap['generationMode'] = generationMode.trim();
    }

    try {
      final response = await client
          .post(
            uri,
            headers: _buildHeaders(isJson: true),
            body: jsonEncode(payloadMap),
          )
          .timeout(timeoutDuration);

      final Map<String, dynamic> body = jsonDecode(
        utf8.decode(response.bodyBytes),
      ) as Map<String, dynamic>;

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          body['success'] == true) {
        final data = body['data'] as Map<String, dynamic>;
        final batch =
            CardBatchModel.fromJson(data['batch'] as Map<String, dynamic>);
        final cards = (data['cards'] as List<dynamic>)
            .map((c) => CardModel.fromJson(c as Map<String, dynamic>))
            .toList();

        return {
          'success': true,
          'data': {
            'batch': batch,
            'cards': cards,
          },
        };
      } else if (response.statusCode == 401) {
        await logout();
        return {
          'success': false,
          'errorCode': 'UNAUTHORIZED',
          'errorMessage': body['errorMessage'] ?? body['message'] ?? 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً.',
        };
      } else if (response.statusCode == 403) {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'TRIAL_CARD_GENERATION_LOCKED',
          'errorMessage': body['errorMessage'] ??
              body['message'] ??
              'يمكنك استخدام وظائف Jalsah خلال الفترة التجريبية. لتوليد كروت الإنترنت، يرجى الاشتراك في إحدى الباقات أو طلب تفعيل حسابك من الإدارة.',
        };
      } else if (response.statusCode == 404) {
        final serverMsg = body['errorMessage'] ?? body['message'];
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'PACKAGE_NOT_FOUND',
          'errorMessage': serverMsg ?? 'الباقة المحددة أو المسار غير موجود على الخادم (404).',
        };
      } else if (response.statusCode == 422) {
        return {
          'success': false,
          'errorCode': 'PACKAGE_INACTIVE',
          'errorMessage': body['errorMessage'] ?? body['message'] ?? 'الباقة المحددة غير مفعّلة حالياً، يرجى تفعيلها أولاً.',
        };
      } else if (response.statusCode == 400) {
        return {
          'success': false,
          'errorCode': 'VALIDATION_ERROR',
          'errorMessage': body['errorMessage'] ??
              body['message'] ??
              'بيانات التوليد غير صالحة، يرجى التأكد من الكمية وصحة المدخلات.',
        };
      } else if (response.statusCode == 429) {
        final serverMsg = body['errorMessage'] ?? body['message'];
        return {
          'success': false,
          'errorCode': 'RATE_LIMIT_EXCEEDED',
          'errorMessage': serverMsg ?? 'تم تجاوز معدل طلبات توليد الكروت. يرجى الانتظار قليلاً قبل المحاولة.',
        };
      } else {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'SERVER_ERROR',
          'errorMessage': body['errorMessage'] ??
              body['message'] ??
              'فشل توليد دفعة الكروت (${response.statusCode})',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'errorCode': 'TIMEOUT',
        'errorMessage':
            'انتهت مهلة الاتصال بالخادم أثناء توليد الكروت (${timeoutDuration.inSeconds} ثانية). يرجى مراجعة قائمة الدفعات قبل إعادة المحاولة لتجنب التكرار.',
      };
    } on SocketException {
      return {
        'success': false,
        'errorCode': 'NETWORK_UNREACHABLE',
        'errorMessage':
            'تعذر الاتصال بالخادم. يرجى التأكد من اتصالك بالإنترنت وتوفر الخدمة.',
      };
    } on FormatException {
      return {
        'success': false,
        'errorCode': 'INVALID_RESPONSE',
        'errorMessage': 'استجابة الخادم بتنسيق غير متوافق (ليست JSON صالحة).',
      };
    } catch (e) {
      return {
        'success': false,
        'errorCode': 'UNKNOWN_ERROR',
        'errorMessage': 'حدث خطأ غير متوقع أثناء توليد الكروت: $e',
      };
    }
  }

  /// Retrieves hotspot cards with optional filtering by status and batchId.
  static Future<Map<String, dynamic>> getCards({
    String? status,
    String? batchId,
  }) async {
    final queryParams = <String, String>{};
    if (status != null && status.trim().isNotEmpty) {
      queryParams['status'] = status.trim();
    }
    if (batchId != null && batchId.trim().isNotEmpty) {
      queryParams['batchId'] = batchId.trim();
    }

    final uri = Uri.parse('$baseUrl/api/v1/cards').replace(
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    try {
      final response = await client.get(
        uri,
        headers: _buildHeaders(),
      ).timeout(timeoutDuration);

      final Map<String, dynamic> body = jsonDecode(
        utf8.decode(response.bodyBytes),
      ) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> cardsJson = body['data'] as List<dynamic>? ?? [];
        final cards = cardsJson
            .map((item) => CardModel.fromJson(item as Map<String, dynamic>))
            .toList();

        return {
          'success': true,
          'data': cards,
        };
      } else if (response.statusCode == 401) {
        await logout();
        return {
          'success': false,
          'errorCode': 'UNAUTHORIZED',
          'errorMessage': body['errorMessage'] ?? 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً.',
        };
      } else if (response.statusCode == 400) {
        return {
          'success': false,
          'errorCode': 'VALIDATION_ERROR',
          'errorMessage':
              body['errorMessage'] ?? 'معاملات البحث غير صالحة.',
        };
      } else {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'SERVER_ERROR',
          'errorMessage': body['errorMessage'] ??
              'فشل جلب قائمة الكروت (${response.statusCode})',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'errorCode': 'TIMEOUT',
        'errorMessage':
            'انتهت مهلة الاتصال بالخادم (${timeoutDuration.inSeconds} ثانية). يرجى التأكد من استجابة السيرفر.',
      };
    } on SocketException {
      return {
        'success': false,
        'errorCode': 'NETWORK_UNREACHABLE',
        'errorMessage':
            'تعذر الاتصال بالخادم. يرجى التأكد من اتصالك بالإنترنت وتوفر الخدمة.',
      };
    } on FormatException {
      return {
        'success': false,
        'errorCode': 'INVALID_RESPONSE',
        'errorMessage': 'استجابة الخادم بتنسيق غير متوافق (ليست JSON صالحة).',
      };
    } catch (e) {
      return {
        'success': false,
        'errorCode': 'UNKNOWN_ERROR',
        'errorMessage': 'حدث خطأ غير متوقع أثناء جلب الكروت: $e',
      };
    }
  }

  /// Fetches all card batches for the current tenant from the backend.
  static Future<Map<String, dynamic>> getBatches() async {
    final uri = Uri.parse('$baseUrl/api/v1/cards/batches');

    try {
      final response = await client.get(
        uri,
        headers: _buildHeaders(),
      ).timeout(timeoutDuration);

      final Map<String, dynamic> body = jsonDecode(
        utf8.decode(response.bodyBytes),
      ) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> raw = body['data'] as List<dynamic>? ?? [];
        final batches = raw
            .map((b) => CardBatchModel.fromJson(b as Map<String, dynamic>))
            .toList();
        return {
          'success': true,
          'data': batches,
        };
      } else if (response.statusCode == 401) {
        await logout();
        return {
          'success': false,
          'errorCode': 'UNAUTHORIZED',
          'errorMessage': body['errorMessage'] ?? body['message'] ?? 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً.',
        };
      } else if (response.statusCode == 403) {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'TRIAL_CARD_GENERATION_LOCKED',
          'errorMessage': body['errorMessage'] ??
              body['message'] ??
              'يمكنك استخدام وظائف Jalsah خلال الفترة التجريبية. لتوليد كروت الإنترنت، يرجى الاشتراك في إحدى الباقات أو طلب تفعيل حسابك من الإدارة.',
        };
      } else if (response.statusCode == 404) {
        final serverMsg = body['errorMessage'] ?? body['message'];
        return {
          'success': false,
          'errorCode': 'ROUTE_NOT_FOUND',
          'errorMessage': serverMsg ??
              'المسار غير متوفر على الخادم (404). قد يتطلب تحديث نسخة الخادم السحابي.',
        };
      } else if (response.statusCode == 429) {
        final serverMsg = body['errorMessage'] ?? body['message'];
        return {
          'success': false,
          'errorCode': 'RATE_LIMIT_EXCEEDED',
          'errorMessage': serverMsg ?? 'تم تجاوز معدل الطلبات. يرجى الانتظار قليلاً.',
        };
      } else {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'SERVER_ERROR',
          'errorMessage': body['errorMessage'] ??
              body['message'] ??
              'فشل جلب قائمة الدفعات (${response.statusCode})',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'errorCode': 'TIMEOUT',
        'errorMessage':
            'انتهت مهلة الاتصال بالخادم (${timeoutDuration.inSeconds} ثانية). يرجى التأكد من استجابة السيرفر.',
      };
    } on SocketException {
      return {
        'success': false,
        'errorCode': 'NETWORK_UNREACHABLE',
        'errorMessage':
            'تعذر الاتصال بالخادم. يرجى التأكد من اتصالك بالإنترنت وتوفر الخدمة.',
      };
    } catch (e) {
      return {
        'success': false,
        'errorCode': 'UNKNOWN_ERROR',
        'errorMessage': 'حدث خطأ غير متوقع أثناء جلب الدفعات: $e',
      };
    }
  }

  /// Updates the status of an existing card adhering to CardStateMachine transitions.
  static Future<Map<String, dynamic>> updateCardStatus({
    required String cardId,
    required String newStatus,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/cards/$cardId/status');

    try {
      final response = await client
          .patch(
            uri,
            headers: _buildHeaders(isJson: true),
            body: jsonEncode({'newStatus': newStatus}),
          )
          .timeout(timeoutDuration);

      final Map<String, dynamic> body = jsonDecode(
        utf8.decode(response.bodyBytes),
      ) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return {
          'success': true,
          'data': CardModel.fromJson(body['data'] as Map<String, dynamic>),
        };
      } else if (response.statusCode == 401) {
        await logout();
        return {
          'success': false,
          'errorCode': 'UNAUTHORIZED',
          'errorMessage': body['errorMessage'] ?? 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً.',
        };
      } else if (response.statusCode == 422) {
        return {
          'success': false,
          'errorCode': 'INVALID_CARD_TRANSITION',
          'errorMessage': body['errorMessage'] ??
              'انتقال الحالة غير مسموح به وفق قواعد آلة الحالات.',
        };
      } else if (response.statusCode == 404) {
        return {
          'success': false,
          'errorCode': 'CARD_NOT_FOUND',
          'errorMessage': 'الكرت المطلوب غير موجود.',
        };
      } else {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'SERVER_ERROR',
          'errorMessage': body['errorMessage'] ??
              'فشل تحديث حالة الكرت (${response.statusCode})',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'errorCode': 'TIMEOUT',
        'errorMessage':
            'انتهت مهلة الاتصال بالخادم (${timeoutDuration.inSeconds} ثانية). يرجى التأكد من استجابة السيرفر.',
      };
    } on SocketException {
      return {
        'success': false,
        'errorCode': 'NETWORK_UNREACHABLE',
        'errorMessage':
            'تعذر الاتصال بالخادم. يرجى التأكد من اتصالك بالإنترنت وتوفر الخدمة.',
      };
    } on FormatException {
      return {
        'success': false,
        'errorCode': 'INVALID_RESPONSE',
        'errorMessage': 'استجابة الخادم بتنسيق غير متوافق (ليست JSON صالحة).',
      };
    } catch (e) {
      return {
        'success': false,
        'errorCode': 'UNKNOWN_ERROR',
        'errorMessage': 'حدث خطأ غير متوقع أثناء تحديث حالة الكرت: $e',
      };
    }
  }

  /// Records a sale transaction for one or more available cards.
  static Future<Map<String, dynamic>> createSale({
    required List<String> cardIds,
    required String paymentMethod,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/sales');
    final payload = jsonEncode({
      'cardIds': cardIds,
      'paymentMethod': paymentMethod,
    });

    try {
      final response = await client
          .post(
            uri,
            headers: _buildHeaders(isJson: true),
            body: payload,
          )
          .timeout(timeoutDuration);

      final Map<String, dynamic> body = jsonDecode(
        utf8.decode(response.bodyBytes),
      ) as Map<String, dynamic>;

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          body['success'] == true) {
        return body;
      } else if (response.statusCode == 401) {
        await logout();
        return {
          'success': false,
          'errorCode': 'UNAUTHORIZED',
          'errorMessage': body['errorMessage'] ?? 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً.',
        };
      } else if (response.statusCode == 422) {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'CARD_NOT_AVAILABLE',
          'errorMessage': body['errorMessage'] ??
              'واحد أو أكثر من الكروت المختارة غير متاح للبيع.',
        };
      } else if (response.statusCode == 409) {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'CARD_ALREADY_SOLD',
          'errorMessage': body['errorMessage'] ??
              'تم بيع أحد الكروت المختارة مسبقاً في معاملة أخرى.',
        };
      } else if (response.statusCode == 400) {
        return {
          'success': false,
          'errorCode': 'VALIDATION_ERROR',
          'errorMessage': body['errorMessage'] ??
              'بيانات البيع غير صالحة، يرجى التأكد من اختيار الكروت وطريقة الدفع.',
        };
      } else {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'SERVER_ERROR',
          'errorMessage': body['errorMessage'] ??
              'فشل إتمام عملية البيع (${response.statusCode})',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'errorCode': 'TIMEOUT',
        'errorMessage':
            'انتهت مهلة الاتصال بالخادم أثناء إتمام عملية البيع. يرجى المحاولة ثانية.',
      };
    } on SocketException {
      return {
        'success': false,
        'errorCode': 'NETWORK_UNREACHABLE',
        'errorMessage':
            'تعذر الاتصال بالخادم. يرجى التأكد من اتصالك بالإنترنت وتوفر الخدمة.',
      };
    } on FormatException {
      return {
        'success': false,
        'errorCode': 'INVALID_RESPONSE',
        'errorMessage': 'استجابة الخادم بتنسيق غير متوافق (ليست JSON صالحة).',
      };
    } catch (e) {
      return {
        'success': false,
        'errorCode': 'UNKNOWN_ERROR',
        'errorMessage': 'حدث خطأ غير متوقع أثناء إتمام عملية البيع: $e',
      };
    }
  }

  /// Retrieves the today's aggregated sales total for the tenant.
  static Future<Map<String, dynamic>> getTodaySalesTotal() async {
    final uri = Uri.parse('$baseUrl/api/v1/sales/today-total');

    try {
      final response = await client.get(
        uri,
        headers: _buildHeaders(),
      ).timeout(timeoutDuration);

      final Map<String, dynamic> body = jsonDecode(
        utf8.decode(response.bodyBytes),
      ) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return body;
      } else if (response.statusCode == 401) {
        await logout();
        return {
          'success': false,
          'errorCode': 'UNAUTHORIZED',
          'errorMessage': body['errorMessage'] ?? 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً.',
        };
      } else {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'SERVER_ERROR',
          'errorMessage': body['errorMessage'] ??
              'فشل جلب إجمالي مبيعات اليوم (${response.statusCode})',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'errorCode': 'TIMEOUT',
        'errorMessage':
            'انتهت مهلة الاتصال بالخادم أثناء جلب إجمالي المبيعات.',
      };
    } on SocketException {
      return {
        'success': false,
        'errorCode': 'NETWORK_UNREACHABLE',
        'errorMessage':
            'تعذر الاتصال بالخادم. يرجى التأكد من اتصالك بالإنترنت وتوفر الخدمة.',
      };
    } on FormatException {
      return {
        'success': false,
        'errorCode': 'INVALID_RESPONSE',
        'errorMessage': 'استجابة الخادم بتنسيق غير متوافق (ليست JSON صالحة).',
      };
    } catch (e) {
      return {
        'success': false,
        'errorCode': 'UNKNOWN_ERROR',
        'errorMessage': 'حدث خطأ غير متوقع أثناء جلب إجمالي المبيعات: $e',
      };
    }
  }

  /// Retrieves sales transactions with optional date range filtering.
  static Future<Map<String, dynamic>> getSales({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final queryParams = <String, String>{};
    if (dateFrom != null) {
      queryParams['dateFrom'] = dateFrom.toIso8601String();
    }
    if (dateTo != null) {
      queryParams['dateTo'] = dateTo.toIso8601String();
    }

    final uri = Uri.parse('$baseUrl/api/v1/sales').replace(
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    try {
      final response = await client.get(
        uri,
        headers: _buildHeaders(),
      ).timeout(timeoutDuration);

      final Map<String, dynamic> body = jsonDecode(
        utf8.decode(response.bodyBytes),
      ) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> salesJson = body['data'] as List<dynamic>? ?? [];
        final sales = salesJson
            .map((item) => SaleModel.fromJson(item as Map<String, dynamic>))
            .toList();

        return {
          'success': true,
          'data': sales,
        };
      } else if (response.statusCode == 401) {
        await logout();
        return {
          'success': false,
          'errorCode': 'UNAUTHORIZED',
          'errorMessage': body['errorMessage'] ?? 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً.',
        };
      } else if (response.statusCode == 400) {
        return {
          'success': false,
          'errorCode': 'VALIDATION_ERROR',
          'errorMessage': body['errorMessage'] ?? 'معاملات البحث غير صالحة.',
        };
      } else {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'SERVER_ERROR',
          'errorMessage': body['errorMessage'] ??
              'فشل جلب قائمة المبيعات (${response.statusCode})',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'errorCode': 'TIMEOUT',
        'errorMessage': 'انتهت مهلة الاتصال بالخادم أثناء جلب المبيعات.',
      };
    } on SocketException {
      return {
        'success': false,
        'errorCode': 'NETWORK_UNREACHABLE',
        'errorMessage': 'تعذر الاتصال بالخادم. يرجى التأكد من اتصالك بالإنترنت وتوفر الخدمة.',
      };
    } on FormatException {
      return {
        'success': false,
        'errorCode': 'INVALID_RESPONSE',
        'errorMessage': 'استجابة الخادم بتنسيق غير متوافق (ليست JSON صالحة).',
      };
    } catch (e) {
      return {
        'success': false,
        'errorCode': 'UNKNOWN_ERROR',
        'errorMessage': 'حدث خطأ غير متوقع أثناء جلب المبيعات: $e',
      };
    }
  }

  /// Fetches all staff users for the current tenant (requires TENANT_ADMIN or SUPER_ADMIN).
  static Future<Map<String, dynamic>> getStaffUsers() async {
    final uri = Uri.parse('$baseUrl/api/v1/users');

    try {
      final response = await client.get(
        uri,
        headers: _buildHeaders(),
      ).timeout(timeoutDuration);

      final Map<String, dynamic> body = jsonDecode(
        utf8.decode(response.bodyBytes),
      ) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> usersJson = body['data'] as List<dynamic>? ?? [];
        final users = usersJson
            .map((item) => StaffUserModel.fromJson(item as Map<String, dynamic>))
            .toList();

        return {
          'success': true,
          'data': users,
        };
      } else if (response.statusCode == 401) {
        await logout();
        return {
          'success': false,
          'errorCode': 'UNAUTHORIZED',
          'errorMessage': body['errorMessage'] ?? 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً.',
        };
      } else if (response.statusCode == 403) {
        return {
          'success': false,
          'errorCode': 'FORBIDDEN',
          'errorMessage': body['errorMessage'] ?? 'ليس لديك صلاحية لعرض قائمة الموظفين.',
        };
      } else {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'SERVER_ERROR',
          'errorMessage': body['errorMessage'] ??
              'فشل جلب قائمة الموظفين (${response.statusCode})',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'errorCode': 'TIMEOUT',
        'errorMessage': 'انتهت مهلة الاتصال بالخادم أثناء جلب الموظفين.',
      };
    } on SocketException {
      return {
        'success': false,
        'errorCode': 'NETWORK_UNREACHABLE',
        'errorMessage': 'تعذر الاتصال بالخادم. يرجى التأكد من اتصالك بالإنترنت وتوفر الخدمة.',
      };
    } on FormatException {
      return {
        'success': false,
        'errorCode': 'INVALID_RESPONSE',
        'errorMessage': 'استجابة الخادم بتنسيق غير متوافق (ليست JSON صالحة).',
      };
    } catch (e) {
      return {
        'success': false,
        'errorCode': 'UNKNOWN_ERROR',
        'errorMessage': 'حدث خطأ غير متوقع أثناء جلب الموظفين: $e',
      };
    }
  }

  /// Creates a new staff member under the tenant (requires TENANT_ADMIN or SUPER_ADMIN).
  static Future<Map<String, dynamic>> createStaffUser({
    required String username,
    required String password,
    required String fullName,
    required String role,
    String? email,
    String? phone,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/users');
    final payloadMap = <String, dynamic>{
      'username': username.trim(),
      'password': password,
      'fullName': fullName.trim(),
      'role': role,
    };
    if (email != null && email.trim().isNotEmpty) {
      payloadMap['email'] = email.trim();
    }
    if (phone != null && phone.trim().isNotEmpty) {
      payloadMap['phone'] = phone.trim();
    }

    try {
      final response = await client.post(
        uri,
        headers: _buildHeaders(isJson: true),
        body: jsonEncode(payloadMap),
      ).timeout(timeoutDuration);

      final Map<String, dynamic> body = jsonDecode(
        utf8.decode(response.bodyBytes),
      ) as Map<String, dynamic>;

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          body['success'] == true) {
        return {
          'success': true,
          'data': StaffUserModel.fromJson(body['data'] as Map<String, dynamic>),
        };
      } else if (response.statusCode == 401) {
        await logout();
        return {
          'success': false,
          'errorCode': 'UNAUTHORIZED',
          'errorMessage': body['errorMessage'] ?? 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً.',
        };
      } else if (response.statusCode == 403) {
        return {
          'success': false,
          'errorCode': 'FORBIDDEN',
          'errorMessage': body['errorMessage'] ?? 'ليس لديك صلاحية لإضافة موظف جديد.',
        };
      } else if (response.statusCode == 409) {
        return {
          'success': false,
          'errorCode': 'USERNAME_EXISTS',
          'errorMessage': body['errorMessage'] ?? 'اسم المستخدم مسجل مسبقاً في هذه الشبكة.',
        };
      } else if (response.statusCode == 400) {
        return {
          'success': false,
          'errorCode': 'VALIDATION_ERROR',
          'errorMessage': body['errorMessage'] ?? 'بيانات الموظف المدخلة غير صالحة.',
        };
      } else {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'SERVER_ERROR',
          'errorMessage': body['errorMessage'] ??
              'فشل إضافة الموظف الجديد (${response.statusCode})',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'errorCode': 'TIMEOUT',
        'errorMessage': 'انتهت مهلة الاتصال بالخادم أثناء إضافة الموظف.',
      };
    } on SocketException {
      return {
        'success': false,
        'errorCode': 'NETWORK_UNREACHABLE',
        'errorMessage': 'تعذر الاتصال بالخادم. يرجى التأكد من اتصالك بالإنترنت وتوفر الخدمة.',
      };
    } on FormatException {
      return {
        'success': false,
        'errorCode': 'INVALID_RESPONSE',
        'errorMessage': 'استجابة الخادم بتنسيق غير متوافق (ليست JSON صالحة).',
      };
    } catch (e) {
      return {
        'success': false,
        'errorCode': 'UNKNOWN_ERROR',
        'errorMessage': 'حدث خطأ غير متوقع أثناء إضافة الموظف: $e',
      };
    }
  }

  /// Deactivates a staff member (status becomes INACTIVE, preserving audit trail).
  static Future<Map<String, dynamic>> deactivateStaffUser(String userId) async {
    final uri = Uri.parse('$baseUrl/api/v1/users/$userId/deactivate');

    try {
      final response = await client.patch(
        uri,
        headers: _buildHeaders(),
      ).timeout(timeoutDuration);

      final Map<String, dynamic> body = jsonDecode(
        utf8.decode(response.bodyBytes),
      ) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return {
          'success': true,
          'data': StaffUserModel.fromJson(body['data'] as Map<String, dynamic>),
          'message': body['message'] ?? 'تم تعطيل حساب الموظف بنجاح',
        };
      } else if (response.statusCode == 401) {
        await logout();
        return {
          'success': false,
          'errorCode': 'UNAUTHORIZED',
          'errorMessage': body['errorMessage'] ?? 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً.',
        };
      } else if (response.statusCode == 403) {
        return {
          'success': false,
          'errorCode': 'FORBIDDEN',
          'errorMessage': body['errorMessage'] ?? 'ليس لديك صلاحية لتعطيل الموظفين.',
        };
      } else if (response.statusCode == 400) {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'CANNOT_DEACTIVATE',
          'errorMessage': body['errorMessage'] ?? 'لا يمكن تعطيل هذا الحساب.',
        };
      } else if (response.statusCode == 404) {
        return {
          'success': false,
          'errorCode': 'USER_NOT_FOUND',
          'errorMessage': body['errorMessage'] ?? 'المستخدم المطلوب غير موجود.',
        };
      } else {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'SERVER_ERROR',
          'errorMessage': body['errorMessage'] ??
              'فشل تعطيل حساب الموظف (${response.statusCode})',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'errorCode': 'TIMEOUT',
        'errorMessage': 'انتهت مهلة الاتصال بالخادم أثناء تعطيل الموظف.',
      };
    } on SocketException {
      return {
        'success': false,
        'errorCode': 'NETWORK_UNREACHABLE',
        'errorMessage': 'تعذر الاتصال بالخادم. يرجى التأكد من اتصالك بالإنترنت وتوفر الخدمة.',
      };
    } on FormatException {
      return {
        'success': false,
        'errorCode': 'INVALID_RESPONSE',
        'errorMessage': 'استجابة الخادم بتنسيق غير متوافق (ليست JSON صالحة).',
      };
    } catch (e) {
      return {
        'success': false,
        'errorCode': 'UNKNOWN_ERROR',
        'errorMessage': 'حدث خطأ غير متوقع أثناء تعطيل الموظف: $e',
      };
    }
  }

  /// Fetches tenant subscription status, trial remaining days, and usage limits.
  static Future<Map<String, dynamic>> getSubscriptionStatus() async {
    final uri = Uri.parse('$baseUrl/api/v1/subscription/status');

    try {
      final response = await client
          .get(
            uri,
            headers: _buildHeaders(),
          )
          .timeout(timeoutDuration);

      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        return {
          'success': false,
          'errorCode': 'INVALID_RESPONSE',
          'errorMessage': 'استجابة الخادم بتنسيق غير متوافق.',
        };
      }
      final Map<String, dynamic> body = decoded;

      if (response.statusCode == 200 &&
          body['success'] == true &&
          body['data'] is Map<String, dynamic>) {
        return {
          'success': true,
          'data': SubscriptionStatusModel.fromJson(
            body['data'] as Map<String, dynamic>,
          ),
        };
      } else if (response.statusCode == 401) {
        await logout();
        return {
          'success': false,
          'errorCode': 'UNAUTHORIZED',
          'errorMessage': body['errorMessage'] ?? 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً.',
        };
      } else {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'SERVER_ERROR',
          'errorMessage': body['errorMessage'] ??
              'فشل جلب حالة الاشتراك (${response.statusCode})',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'errorCode': 'TIMEOUT',
        'errorMessage': 'انتهت مهلة الاتصال بالخادم أثناء جلب حالة الاشتراك.',
      };
    } on SocketException {
      return {
        'success': false,
        'errorCode': 'NETWORK_UNREACHABLE',
        'errorMessage': 'تعذر الاتصال بالخادم. يرجى التأكد من اتصالك بالإنترنت وتوفر الخدمة.',
      };
    } on FormatException {
      return {
        'success': false,
        'errorCode': 'INVALID_RESPONSE',
        'errorMessage': 'استجابة الخادم بتنسيق غير متوافق (ليست JSON صالحة).',
      };
    } catch (e) {
      return {
        'success': false,
        'errorCode': 'UNKNOWN_ERROR',
        'errorMessage': 'حدث خطأ غير متوقع أثناء جلب حالة الاشتراك: $e',
      };
    }
  }

  /// Registers a new tenant (network) and initial administrator user.
  static Future<Map<String, dynamic>> registerTenant({
    required String networkName,
    required String adminFullName,
    required String username,
    required String email,
    required String password,
    String? phone,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/auth/register');
    final payload = jsonEncode({
      'networkName': networkName.trim(),
      'adminFullName': adminFullName.trim(),
      'username': username.trim(),
      'email': email.trim(),
      'password': password,
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
    });

    try {
      final response = await client
          .post(
            uri,
            headers: _buildHeaders(isJson: true),
            body: payload,
          )
          .timeout(timeoutDuration);

      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        return {
          'success': false,
          'errorCode': 'INVALID_RESPONSE',
          'errorMessage': 'استجابة الخادم بتنسيق غير متوافق.',
        };
      }
      final Map<String, dynamic> body = decoded;

      if (response.statusCode == 201 && body['success'] == true) {
        final data = body['data'] as Map<String, dynamic>;
        final token = data['token'] as String?;
        if (token != null && token.isNotEmpty) {
          setAuthToken(token);
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(tokenStorageKey, token);
          } catch (_) {}
        }
        return {
          'success': true,
          'data': data,
        };
      } else if (response.statusCode == 409) {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'CONFLICT',
          'errorMessage': body['errorMessage'] ?? 'البيانات المدخلة مستخدمة بالفعل.',
        };
      } else if (response.statusCode == 400) {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'VALIDATION_ERROR',
          'errorMessage': body['errorMessage'] ?? 'يرجى التأكد من صحة البيانات المدخلة.',
          'details': body['details'],
        };
      } else {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'SERVER_ERROR',
          'errorMessage': body['errorMessage'] ??
              'فشل إنشاء الحساب (${response.statusCode})',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'errorCode': 'TIMEOUT',
        'errorMessage': 'انتهت مهلة الاتصال بالخادم أثناء إنشاء الحساب.',
      };
    } on SocketException {
      return {
        'success': false,
        'errorCode': 'NETWORK_UNREACHABLE',
        'errorMessage': 'تعذر الاتصال بالخادم. يرجى التأكد من اتصالك بالإنترنت وتوفر الخدمة.',
      };
    } on FormatException {
      return {
        'success': false,
        'errorCode': 'INVALID_RESPONSE',
        'errorMessage': 'استجابة الخادم بتنسيق غير متوافق (ليست JSON صالحة).',
      };
    } catch (e) {
      return {
        'success': false,
        'errorCode': 'UNKNOWN_ERROR',
        'errorMessage': 'حدث خطأ غير متوقع أثناء إنشاء الحساب: $e',
      };
    }
  }

  // ==========================================================================
  // PASSWORD RESET VIA EMAIL OTP API METHODS (Rule 14 & Rule 19)
  // ==========================================================================

  /// Requests a password reset OTP code to the specified email address.
  /// Anti-enumeration protected: returns generic message regardless of email existence.
  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    final uri = Uri.parse('$baseUrl/api/v1/auth/forgot-password');
    final payload = jsonEncode({
      'email': email.trim().toLowerCase(),
    });

    try {
      final response = await client
          .post(
            uri,
            headers: _buildHeaders(isJson: true),
            body: payload,
          )
          .timeout(const Duration(seconds: 10));

      final body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return {
          'success': true,
          'message': body['data']?['message'] ??
              'إذا كان هذا البريد مسجلاً في النظام، فستصلك رسالة تحتوي على كود التحقق',
        };
      } else {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'SERVER_ERROR',
          'errorMessage': body['errorMessage'] ?? 'فشل طلب استعادة كلمة المرور',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'errorCode': 'TIMEOUT',
        'errorMessage': 'انتهت مهلة الاتصال بالخادم. يرجى المحاولة مرة أخرى.',
      };
    } on SocketException {
      return {
        'success': false,
        'errorCode': 'NETWORK_UNREACHABLE',
        'errorMessage':
            'تعذر الاتصال بالخادم. يرجى التأكد من اتصالك بالإنترنت وتوفر الخدمة.',
      };
    } catch (e) {
      return {
        'success': false,
        'errorCode': 'UNKNOWN_ERROR',
        'errorMessage': 'حدث خطأ غير متوقع: $e',
      };
    }
  }

  /// Verifies OTP code and updates the user's password.
  static Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String otpCode,
    required String newPassword,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/auth/reset-password');
    final payload = jsonEncode({
      'email': email.trim().toLowerCase(),
      'otpCode': otpCode.trim(),
      'newPassword': newPassword,
    });

    try {
      final response = await client
          .post(
            uri,
            headers: _buildHeaders(isJson: true),
            body: payload,
          )
          .timeout(const Duration(seconds: 10));

      final body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return {
          'success': true,
          'message': body['data']?['message'] ??
              'تم إعادة تعيين كلمة المرور بنجاح. يمكنك الآن تسجيل الدخول.',
        };
      } else {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'SERVER_ERROR',
          'errorMessage':
              body['errorMessage'] ?? 'فشل إعادة تعيين كلمة المرور',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'errorCode': 'TIMEOUT',
        'errorMessage': 'انتهت مهلة الاتصال بالخادم. يرجى المحاولة مرة أخرى.',
      };
    } on SocketException {
      return {
        'success': false,
        'errorCode': 'NETWORK_UNREACHABLE',
        'errorMessage':
            'تعذر الاتصال بالخادم. يرجى التأكد من اتصالك بالإنترنت وتوفر الخدمة.',
      };
    } catch (e) {
      return {
        'success': false,
        'errorCode': 'UNKNOWN_ERROR',
        'errorMessage': 'حدث خطأ غير متوقع: $e',
      };
    }
  }

  // ==========================================================================
  // SUBSCRIPTION REDEEM & SUPER ADMIN API METHODS
  // ==========================================================================

  /// Redeems a valid license code to activate or extend subscription.
  /// Available to TENANT_ADMIN and SUPER_ADMIN.
  static Future<Map<String, dynamic>> redeemLicenseCode(String code) async {
    final uri = Uri.parse('$baseUrl/api/v1/subscription/redeem');

    try {
      final response = await client
          .post(
            uri,
            headers: _buildHeaders(isJson: true),
            body: jsonEncode({'code': code.trim().toUpperCase()}),
          )
          .timeout(timeoutDuration);

      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        return {
          'success': false,
          'errorCode': 'INVALID_RESPONSE',
          'errorMessage': 'استجابة الخادم بتنسيق غير متوافق.',
        };
      }
      final Map<String, dynamic> body = decoded;

      if (response.statusCode == 200 && body['success'] == true) {
        return {
          'success': true,
          'data': body['data'],
          'message': body['data']?['message'] ?? 'تم تفعيل كود الترخيص بنجاح!',
        };
      } else if (response.statusCode == 404) {
        return {
          'success': false,
          'errorCode': 'CODE_NOT_FOUND',
          'errorMessage': body['errorMessage'] ?? 'كود الترخيص غير موجود أو غير صالح.',
        };
      } else if (response.statusCode == 400) {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'BAD_REQUEST',
          'errorMessage': body['errorMessage'] ?? 'كود الترخيص غير صالح أو مستخدم مسبقاً.',
        };
      } else if (response.statusCode == 401) {
        await logout();
        return {
          'success': false,
          'errorCode': 'UNAUTHORIZED',
          'errorMessage': 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً.',
        };
      } else if (response.statusCode == 403) {
        return {
          'success': false,
          'errorCode': 'FORBIDDEN',
          'errorMessage': body['errorMessage'] ?? 'ليس لديك الصلاحيات الكافية لتفعيل كود الترخيص.',
        };
      } else {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'SERVER_ERROR',
          'errorMessage': body['errorMessage'] ?? 'فشل تفعيل كود الترخيص (${response.statusCode})',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'errorCode': 'TIMEOUT',
        'errorMessage': 'انتهت مهلة الاتصال بالخادم أثناء تفعيل كود الترخيص.',
      };
    } on SocketException {
      return {
        'success': false,
        'errorCode': 'NETWORK_UNREACHABLE',
        'errorMessage': 'تعذر الاتصال بالخادم. يرجى التأكد من اتصالك بالإنترنت وتوفر الخدمة.',
      };
    } on FormatException {
      return {
        'success': false,
        'errorCode': 'INVALID_RESPONSE',
        'errorMessage': 'استجابة الخادم بتنسيق غير متوافق.',
      };
    } catch (e) {
      return {
        'success': false,
        'errorCode': 'UNKNOWN_ERROR',
        'errorMessage': 'حدث خطأ غير متوقع أثناء تفعيل كود الترخيص: $e',
      };
    }
  }

  /// Lists all registered companies/tenants in the system (SUPER_ADMIN only).
  static Future<Map<String, dynamic>> getAdminTenants() async {
    final uri = Uri.parse('$baseUrl/api/v1/admin/tenants');

    try {
      final response = await client
          .get(
            uri,
            headers: _buildHeaders(),
          )
          .timeout(timeoutDuration);

      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        return {
          'success': false,
          'errorCode': 'INVALID_RESPONSE',
          'errorMessage': 'استجابة الخادم بتنسيق غير متوافق.',
        };
      }
      final Map<String, dynamic> body = decoded;

      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> list = body['data'] as List<dynamic>? ?? [];
        final tenants = list
            .map((item) => AdminTenantModel.fromJson(item as Map<String, dynamic>))
            .toList();
        return {
          'success': true,
          'data': tenants,
        };
      } else if (response.statusCode == 403) {
        return {
          'success': false,
          'errorCode': 'FORBIDDEN',
          'errorMessage': body['errorMessage'] ?? 'هذا القسم مخصص لمدير المنصة العام (SUPER_ADMIN) فقط.',
        };
      } else if (response.statusCode == 401) {
        await logout();
        return {
          'success': false,
          'errorCode': 'UNAUTHORIZED',
          'errorMessage': 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً.',
        };
      } else {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'SERVER_ERROR',
          'errorMessage': body['errorMessage'] ?? 'فشل جلب قائمة الشركات (${response.statusCode})',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'errorCode': 'TIMEOUT',
        'errorMessage': 'انتهت مهلة الاتصال بالخادم أثناء جلب الشركات.',
      };
    } on SocketException {
      return {
        'success': false,
        'errorCode': 'NETWORK_UNREACHABLE',
        'errorMessage': 'تعذر الاتصال بالخادم. يرجى التأكد من اتصالك بالإنترنت وتوفر الخدمة.',
      };
    } catch (e) {
      return {
        'success': false,
        'errorCode': 'UNKNOWN_ERROR',
        'errorMessage': 'حدث خطأ أثناء جلب الشركات: $e',
      };
    }
  }

  /// Lists all generated license codes in the system (SUPER_ADMIN only).
  static Future<Map<String, dynamic>> getAdminLicenseCodes() async {
    final uri = Uri.parse('$baseUrl/api/v1/admin/license-codes');

    try {
      final response = await client
          .get(
            uri,
            headers: _buildHeaders(),
          )
          .timeout(timeoutDuration);

      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        return {
          'success': false,
          'errorCode': 'INVALID_RESPONSE',
          'errorMessage': 'استجابة الخادم بتنسيق غير متوافق.',
        };
      }
      final Map<String, dynamic> body = decoded;

      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> list = body['data'] as List<dynamic>? ?? [];
        final codes = list
            .map((item) => LicenseCodeModel.fromJson(item as Map<String, dynamic>))
            .toList();
        return {
          'success': true,
          'data': codes,
        };
      } else if (response.statusCode == 403) {
        return {
          'success': false,
          'errorCode': 'FORBIDDEN',
          'errorMessage': body['errorMessage'] ?? 'هذا القسم مخصص لمدير المنصة العام (SUPER_ADMIN) فقط.',
        };
      } else if (response.statusCode == 401) {
        await logout();
        return {
          'success': false,
          'errorCode': 'UNAUTHORIZED',
          'errorMessage': 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً.',
        };
      } else {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'SERVER_ERROR',
          'errorMessage': body['errorMessage'] ?? 'فشل جلب قائمة أكواد الترخيص (${response.statusCode})',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'errorCode': 'TIMEOUT',
        'errorMessage': 'انتهت مهلة الاتصال بالخادم أثناء جلب أكواد الترخيص.',
      };
    } on SocketException {
      return {
        'success': false,
        'errorCode': 'NETWORK_UNREACHABLE',
        'errorMessage': 'تعذر الاتصال بالخادم. يرجى التأكد من اتصالك بالإنترنت وتوفر الخدمة.',
      };
    } catch (e) {
      return {
        'success': false,
        'errorCode': 'UNKNOWN_ERROR',
        'errorMessage': 'حدث خطأ أثناء جلب أكواد الترخيص: $e',
      };
    }
  }

  /// Generates a new license code (SUPER_ADMIN only).
  static Future<Map<String, dynamic>> generateLicenseCode({
    required String planName,
    required int durationDays,
    required int maxRoutersLimit,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/admin/license-codes');

    try {
      final response = await client
          .post(
            uri,
            headers: _buildHeaders(isJson: true),
            body: jsonEncode({
              'planName': planName.trim(),
              'durationDays': durationDays,
              'maxRoutersLimit': maxRoutersLimit,
            }),
          )
          .timeout(timeoutDuration);

      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        return {
          'success': false,
          'errorCode': 'INVALID_RESPONSE',
          'errorMessage': 'استجابة الخادم بتنسيق غير متوافق.',
        };
      }
      final Map<String, dynamic> body = decoded;

      if (response.statusCode == 201 &&
          body['success'] == true &&
          body['data'] is Map<String, dynamic>) {
        return {
          'success': true,
          'data': LicenseCodeModel.fromJson(body['data'] as Map<String, dynamic>),
        };
      } else if (response.statusCode == 403) {
        return {
          'success': false,
          'errorCode': 'FORBIDDEN',
          'errorMessage': body['errorMessage'] ?? 'هذا القسم مخصص لمدير المنصة العام (SUPER_ADMIN) فقط.',
        };
      } else if (response.statusCode == 400) {
        return {
          'success': false,
          'errorCode': 'VALIDATION_ERROR',
          'errorMessage': body['errorMessage'] ?? 'بيانات كود الترخيص غير صالحة.',
          'details': body['details'],
        };
      } else {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'SERVER_ERROR',
          'errorMessage': body['errorMessage'] ?? 'فشل توليد كود الترخيص (${response.statusCode})',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'errorCode': 'TIMEOUT',
        'errorMessage': 'انتهت مهلة الاتصال بالخادم أثناء توليد كود الترخيص.',
      };
    } on SocketException {
      return {
        'success': false,
        'errorCode': 'NETWORK_UNREACHABLE',
        'errorMessage': 'تعذر الاتصال بالخادم. يرجى التأكد من اتصالك بالإنترنت وتوفر الخدمة.',
      };
    } catch (e) {
      return {
        'success': false,
        'errorCode': 'UNKNOWN_ERROR',
        'errorMessage': 'حدث خطأ أثناء توليد كود الترخيص: $e',
      };
    }
  }

  /// Approves a pending tenant registration (SUPER_ADMIN only).
  static Future<Map<String, dynamic>> approveTenant(String tenantId) async {
    final uri = Uri.parse('$baseUrl/api/v1/admin/tenants/$tenantId/approve');
    try {
      final response = await client
          .patch(uri, headers: _buildHeaders(isJson: true), body: '{}')
          .timeout(timeoutDuration);
      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final Map<String, dynamic> body = decoded is Map<String, dynamic> ? decoded : {};
      if (response.statusCode == 200 && body['success'] == true) {
        return {'success': true, 'data': body['data']};
      }
      return {
        'success': false,
        'errorCode': body['errorCode'] ?? 'OPERATION_FAILED',
        'errorMessage': body['errorMessage'] ?? body['message'] ?? 'فشل الموافقة على طلب التسجيل',
      };
    } catch (e) {
      return {'success': false, 'errorCode': 'NETWORK_ERROR', 'errorMessage': 'خطأ في الاتصال: $e'};
    }
  }

  /// Rejects a pending tenant registration (SUPER_ADMIN only).
  static Future<Map<String, dynamic>> rejectTenant(String tenantId) async {
    final uri = Uri.parse('$baseUrl/api/v1/admin/tenants/$tenantId/reject');
    try {
      final response = await client
          .patch(uri, headers: _buildHeaders(isJson: true), body: '{}')
          .timeout(timeoutDuration);
      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final Map<String, dynamic> body = decoded is Map<String, dynamic> ? decoded : {};
      if (response.statusCode == 200 && body['success'] == true) {
        return {'success': true, 'data': body['data']};
      }
      return {
        'success': false,
        'errorCode': body['errorCode'] ?? 'OPERATION_FAILED',
        'errorMessage': body['errorMessage'] ?? body['message'] ?? 'فشل رفض طلب التسجيل',
      };
    } catch (e) {
      return {'success': false, 'errorCode': 'NETWORK_ERROR', 'errorMessage': 'خطأ في الاتصال: $e'};
    }
  }

  /// Suspends a tenant subscription (SUPER_ADMIN only).
  static Future<Map<String, dynamic>> suspendTenant(String tenantId) async {
    final uri = Uri.parse('$baseUrl/api/v1/admin/tenants/$tenantId/suspend');
    try {
      final response = await client
          .patch(uri, headers: _buildHeaders(isJson: true), body: '{}')
          .timeout(timeoutDuration);
      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final Map<String, dynamic> body = decoded is Map<String, dynamic> ? decoded : {};
      if (response.statusCode == 200 && body['success'] == true) {
        return {'success': true, 'data': body['data']};
      }
      return {
        'success': false,
        'errorCode': body['errorCode'] ?? 'OPERATION_FAILED',
        'errorMessage': body['errorMessage'] ?? body['message'] ?? 'فشل إيقاف حساب الشبكة',
      };
    } catch (e) {
      return {'success': false, 'errorCode': 'NETWORK_ERROR', 'errorMessage': 'خطأ في الاتصال: $e'};
    }
  }

  /// Reactivates a suspended tenant (SUPER_ADMIN only).
  static Future<Map<String, dynamic>> reactivateTenant(String tenantId) async {
    final uri = Uri.parse('$baseUrl/api/v1/admin/tenants/$tenantId/reactivate');
    try {
      final response = await client
          .patch(uri, headers: _buildHeaders(isJson: true), body: '{}')
          .timeout(timeoutDuration);
      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final Map<String, dynamic> body = decoded is Map<String, dynamic> ? decoded : {};
      if (response.statusCode == 200 && body['success'] == true) {
        return {'success': true, 'data': body['data']};
      }
      return {
        'success': false,
        'errorCode': body['errorCode'] ?? 'OPERATION_FAILED',
        'errorMessage': body['errorMessage'] ?? body['message'] ?? 'فشل إعادة تفعيل حساب الشبكة',
      };
    } catch (e) {
      return {'success': false, 'errorCode': 'NETWORK_ERROR', 'errorMessage': 'خطأ في الاتصال: $e'};
    }
  }

  /// Soft deletes a tenant (SUPER_ADMIN only - Rule 30).
  static Future<Map<String, dynamic>> deleteTenant(String tenantId) async {
    final uri = Uri.parse('$baseUrl/api/v1/admin/tenants/$tenantId/delete');
    try {
      final response = await client
          .patch(uri, headers: _buildHeaders(isJson: true), body: '{}')
          .timeout(timeoutDuration);
      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final Map<String, dynamic> body = decoded is Map<String, dynamic> ? decoded : {};
      if (response.statusCode == 200 && body['success'] == true) {
        return {'success': true, 'data': body['data']};
      }
      return {
        'success': false,
        'errorCode': body['errorCode'] ?? 'OPERATION_FAILED',
        'errorMessage': body['errorMessage'] ?? body['message'] ?? 'فشل حذف الحساب',
      };
    } catch (e) {
      return {'success': false, 'errorCode': 'NETWORK_ERROR', 'errorMessage': 'خطأ في الاتصال: $e'};
    }
  }

  /// Activates direct license for a tenant (SUPER_ADMIN only).
  static Future<Map<String, dynamic>> adminActivateTenant({
    required String tenantId,
    required String planName,
    required int durationDays,
    required int maxRoutersLimit,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/admin/tenants/$tenantId/activate-license');
    final payload = jsonEncode({
      'planName': planName.trim(),
      'durationDays': durationDays,
      'maxRoutersLimit': maxRoutersLimit,
    });
    try {
      final response = await client
          .post(uri, headers: _buildHeaders(isJson: true), body: payload)
          .timeout(timeoutDuration);
      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final Map<String, dynamic> body = decoded is Map<String, dynamic> ? decoded : {};
      if (response.statusCode == 200 && body['success'] == true) {
        return {'success': true, 'data': body['data']};
      }
      return {
        'success': false,
        'errorCode': body['errorCode'] ?? 'OPERATION_FAILED',
        'errorMessage': body['errorMessage'] ?? 'فشل تفعيل الترخيص المباشر',
      };
    } catch (e) {
      return {'success': false, 'errorCode': 'NETWORK_ERROR', 'errorMessage': 'خطأ في الاتصال: $e'};
    }
  }

  /// Lists users of a specific tenant (SUPER_ADMIN only).
  static Future<Map<String, dynamic>> getAdminTenantUsers(String tenantId) async {
    final uri = Uri.parse('$baseUrl/api/v1/admin/tenants/$tenantId/users');
    try {
      final response = await client
          .get(uri, headers: _buildHeaders())
          .timeout(timeoutDuration);
      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final Map<String, dynamic> body = decoded is Map<String, dynamic> ? decoded : {};
      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> list = body['data'] as List<dynamic>? ?? [];
        final users = list
            .map((item) => StaffUserModel.fromJson(item as Map<String, dynamic>))
            .toList();
        return {'success': true, 'data': users};
      }
      return {
        'success': false,
        'errorCode': body['errorCode'] ?? 'OPERATION_FAILED',
        'errorMessage': body['errorMessage'] ?? 'فشل جلب مستخدمي الشبكة',
      };
    } catch (e) {
      return {'success': false, 'errorCode': 'NETWORK_ERROR', 'errorMessage': 'خطأ في الاتصال: $e'};
    }
  }

  /// Updates user role / promotion (SUPER_ADMIN only).
  static Future<Map<String, dynamic>> updateUserRole({
    required String userId,
    required String role,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/admin/users/$userId/role');
    final payload = jsonEncode({'role': role});
    try {
      final response = await client
          .patch(uri, headers: _buildHeaders(isJson: true), body: payload)
          .timeout(timeoutDuration);
      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final Map<String, dynamic> body = decoded is Map<String, dynamic> ? decoded : {};
      if (response.statusCode == 200 && body['success'] == true) {
        return {'success': true, 'data': body['data']};
      }
      return {
        'success': false,
        'errorCode': body['errorCode'] ?? 'OPERATION_FAILED',
        'errorMessage': body['errorMessage'] ?? 'فشل تعديل دور المستخدم',
      };
    } catch (e) {
      return {'success': false, 'errorCode': 'NETWORK_ERROR', 'errorMessage': 'خطأ في الاتصال: $e'};
    }
  }

  /// Creates a new platform SUPER_ADMIN user (SUPER_ADMIN only).
  static Future<Map<String, dynamic>> createSuperAdmin({
    required String fullName,
    required String username,
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/admin/super-admins');
    final payload = jsonEncode({
      'fullName': fullName.trim(),
      'username': username.trim(),
      'email': email.trim().toLowerCase(),
      'password': password,
    });
    try {
      final response = await client
          .post(uri, headers: _buildHeaders(isJson: true), body: payload)
          .timeout(timeoutDuration);
      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final Map<String, dynamic> body = decoded is Map<String, dynamic> ? decoded : {};
      if (response.statusCode == 201 && body['success'] == true) {
        return {'success': true, 'data': body['data']};
      }
      return {
        'success': false,
        'errorCode': body['errorCode'] ?? 'OPERATION_FAILED',
        'errorMessage': body['errorMessage'] ?? 'فشل إنشاء مدير المنصة',
      };
    } catch (e) {
      return {'success': false, 'errorCode': 'NETWORK_ERROR', 'errorMessage': 'خطأ في الاتصال: $e'};
    }
  }

  /// Fetches the profile of the currently authenticated user (Rule 14, Rule 26).
  static Future<Map<String, dynamic>> getCurrentUserProfile() async {
    final uri = Uri.parse('$baseUrl/api/v1/auth/me');
    try {
      final response = await client
          .get(uri, headers: _buildHeaders(isJson: true))
          .timeout(timeoutDuration);
      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final Map<String, dynamic> body = decoded is Map<String, dynamic> ? decoded : {};
      if (response.statusCode == 200 && body['success'] == true) {
        return {'success': true, 'data': body['data']};
      } else if (response.statusCode == 401) {
        await logout();
        return {
          'success': false,
          'errorCode': 'UNAUTHORIZED',
          'errorMessage': 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً.',
        };
      }
      return {
        'success': false,
        'errorCode': body['errorCode'] ?? 'OPERATION_FAILED',
        'errorMessage': body['errorMessage'] ?? body['message'] ?? 'فشل جلب بيانات الملف الشخصي',
      };
    } catch (e) {
      return {'success': false, 'errorCode': 'NETWORK_ERROR', 'errorMessage': 'خطأ في الاتصال: $e'};
    }
  }

  /// Fetches public platform settings (No auth required)
  static Future<PlatformSettingsModel?> getPublicSettings() async {
    final uri = Uri.parse('$baseUrl/api/v1/settings/public');
    try {
      final response = await client.get(uri).timeout(timeoutDuration);
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic> && decoded['data'] != null) {
          return PlatformSettingsModel.fromJson(decoded['data'] as Map<String, dynamic>);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Updates platform settings (Super Admin Only)
  static Future<Map<String, dynamic>> updateAdminSettings({
    String? supportEmail,
    List<String>? whatsappNumbers,
    String? appName,
    String? primaryColorHex,
    String? accentColorHex,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/admin/settings');
    final payload = <String, dynamic>{};
    if (supportEmail != null) payload['supportEmail'] = supportEmail;
    if (whatsappNumbers != null) payload['whatsappNumbers'] = whatsappNumbers;
    if (appName != null) payload['appName'] = appName;
    if (primaryColorHex != null) payload['primaryColorHex'] = primaryColorHex;
    if (accentColorHex != null) payload['accentColorHex'] = accentColorHex;

    try {
      final response = await client
          .patch(uri, headers: _buildHeaders(isJson: true), body: jsonEncode(payload))
          .timeout(timeoutDuration);
      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final Map<String, dynamic> body = decoded is Map<String, dynamic> ? decoded : {};
      if (response.statusCode == 200 && body['success'] == true) {
        final settings = PlatformSettingsModel.fromJson(body['data'] as Map<String, dynamic>);
        return {
          'success': true,
          'data': settings,
          'message': body['message'] ?? 'تم تحديث إعدادات المنصة بنجاح',
        };
      }
      return {
        'success': false,
        'errorCode': body['errorCode'] ?? 'OPERATION_FAILED',
        'errorMessage': body['errorMessage'] ?? body['message'] ?? 'فشل تحديث إعدادات المنصة',
      };
    } catch (e) {
      return {'success': false, 'errorCode': 'NETWORK_ERROR', 'errorMessage': 'خطأ في الاتصال: $e'};
    }
  }

  /// Fetches notifications for current user tenant + broadcast notifications
  static Future<Map<String, dynamic>> getNotifications() async {
    final uri = Uri.parse('$baseUrl/api/v1/notifications');
    try {
      final response = await client
          .get(uri, headers: _buildHeaders(isJson: true))
          .timeout(timeoutDuration);
      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final Map<String, dynamic> body = decoded is Map<String, dynamic> ? decoded : {};
      if (response.statusCode == 200 && body['success'] == true) {
        final List<dynamic> list = body['data'] is List ? body['data'] : [];
        final notifications = list
            .map((item) => AppNotificationModel.fromJson(item as Map<String, dynamic>))
            .toList();
        final unreadCount = body['unreadCount'] is int
            ? body['unreadCount'] as int
            : notifications.where((n) => !n.isRead).length;
        return {
          'success': true,
          'data': notifications,
          'unreadCount': unreadCount,
        };
      }
      return {
        'success': false,
        'errorCode': body['errorCode'] ?? 'OPERATION_FAILED',
        'errorMessage': body['errorMessage'] ?? body['message'] ?? 'فشل جلب الإشعارات',
      };
    } catch (e) {
      return {'success': false, 'errorCode': 'NETWORK_ERROR', 'errorMessage': 'خطأ في الاتصال: $e'};
    }
  }

  /// Marks a specific notification as read
  static Future<bool> markNotificationRead(String notificationId) async {
    final uri = Uri.parse('$baseUrl/api/v1/notifications/$notificationId/read');
    try {
      final response = await client
          .patch(uri, headers: _buildHeaders(isJson: true), body: '{}')
          .timeout(timeoutDuration);
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return decoded is Map<String, dynamic> && decoded['success'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Sends a manual notification or broadcast (Super Admin Only)
  static Future<Map<String, dynamic>> sendAdminNotification({
    required String title,
    required String body,
    String? tenantId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/admin/notifications');
    final payload = <String, dynamic>{
      'title': title,
      'body': body,
      if (tenantId != null && tenantId.isNotEmpty) 'tenantId': tenantId,
    };

    try {
      final response = await client
          .post(uri, headers: _buildHeaders(isJson: true), body: jsonEncode(payload))
          .timeout(timeoutDuration);
      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final Map<String, dynamic> resBody = decoded is Map<String, dynamic> ? decoded : {};
      if (response.statusCode == 201 && resBody['success'] == true) {
        return {
          'success': true,
          'data': resBody['data'],
          'message': resBody['message'] ?? 'تم إرسال الإشعار بنجاح',
        };
      }
      return {
        'success': false,
        'errorCode': resBody['errorCode'] ?? 'OPERATION_FAILED',
        'errorMessage': resBody['errorMessage'] ?? resBody['message'] ?? 'فشل إرسال الإشعار',
      };
    } catch (e) {
      return {'success': false, 'errorCode': 'NETWORK_ERROR', 'errorMessage': 'خطأ في الاتصال: $e'};
    }
  }

  /// Fetches active subscription plans for user to choose and subscribe.
  static Future<Map<String, dynamic>> getSubscriptionPlans() async {
    final uri = Uri.parse('$baseUrl/api/v1/subscription/plans');
    try {
      final response = await client
          .get(uri, headers: _buildHeaders())
          .timeout(timeoutDuration);

      final Map<String, dynamic> body = jsonDecode(
        utf8.decode(response.bodyBytes),
      ) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return {
          'success': true,
          'data': body['data'],
        };
      }

      return {
        'success': false,
        'errorCode': body['errorCode'] ?? 'FETCH_PLANS_FAILED',
        'errorMessage': body['errorMessage'] ?? 'فشل جلب باقات الاشتراك',
      };
    } catch (e) {
      return {
        'success': false,
        'errorCode': 'NETWORK_ERROR',
        'errorMessage': 'تعذر الاتصال بالخادم لجلب باقات الاشتراك',
      };
    }
  }

  /// Submits an activation request for a selected commercial plan.
  static Future<Map<String, dynamic>> requestSubscriptionActivation({
    required String planId,
    String? notes,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/subscription/request-activation');
    final payload = jsonEncode({
      'planId': planId,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    });

    try {
      final response = await client
          .post(uri, headers: _buildHeaders(isJson: true), body: payload)
          .timeout(timeoutDuration);

      final Map<String, dynamic> body = jsonDecode(
        utf8.decode(response.bodyBytes),
      ) as Map<String, dynamic>;

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          body['success'] == true) {
        return {
          'success': true,
          'data': body['data'],
          'message': body['message'] ?? 'تم إرسال طلب التفعيل بنجاح',
        };
      }

      if (response.statusCode == 409) {
        return {
          'success': false,
          'errorCode': 'PENDING_REQUEST_EXISTS',
          'errorMessage': body['errorMessage'] ?? 'يوجد طلب تفعيل قيد المراجعة بالفعل لهذا الحساب',
        };
      }

      return {
        'success': false,
        'errorCode': body['errorCode'] ?? 'REQUEST_ACTIVATION_FAILED',
        'errorMessage': body['errorMessage'] ?? 'فشل إرسال طلب التفعيل',
      };
    } catch (e) {
      return {
        'success': false,
        'errorCode': 'NETWORK_ERROR',
        'errorMessage': 'تعذر الاتصال بالخادم لإرسال طلب التفعيل',
      };
    }
  }

  /// Fetches tenant activation requests history.
  static Future<Map<String, dynamic>> getMySubscriptionRequests() async {
    final uri = Uri.parse('$baseUrl/api/v1/subscription/my-requests');
    try {
      final response = await client
          .get(uri, headers: _buildHeaders())
          .timeout(timeoutDuration);

      final Map<String, dynamic> body = jsonDecode(
        utf8.decode(response.bodyBytes),
      ) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return {
          'success': true,
          'data': body['data'],
        };
      }

      return {
        'success': false,
        'errorCode': body['errorCode'] ?? 'FETCH_REQUESTS_FAILED',
        'errorMessage': body['errorMessage'] ?? 'فشل جلب طلبات التفعيل',
      };
    } catch (e) {
      return {
        'success': false,
        'errorCode': 'NETWORK_ERROR',
        'errorMessage': 'تعذر الاتصال بالخادم لجلب طلبات التفعيل',
      };
    }
  }

  /// Cancels a pending activation request submitted by the tenant.
  static Future<Map<String, dynamic>> cancelSubscriptionRequest(String requestId) async {
    final uri = Uri.parse('$baseUrl/api/v1/subscription/my-requests/$requestId/cancel');
    try {
      final response = await client
          .post(uri, headers: _buildHeaders(isJson: true))
          .timeout(timeoutDuration);

      final Map<String, dynamic> body = jsonDecode(
        utf8.decode(response.bodyBytes),
      ) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return {
          'success': true,
          'data': body['data'],
          'message': body['message'] ?? 'تم إلغاء طلب التفعيل بنجاح',
        };
      }

      return {
        'success': false,
        'errorCode': body['errorCode'] ?? 'CANCEL_FAILED',
        'errorMessage': body['errorMessage'] ?? 'فشل إلغاء طلب التفعيل',
      };
    } catch (e) {
      return {
        'success': false,
        'errorCode': 'NETWORK_ERROR',
        'errorMessage': 'تعذر الاتصال بالخادم لإلغاء طلب التفعيل: $e',
      };
    }
  }

  /// Updates authenticated user profile details (full name, phone, avatarUrl).
  static Future<Map<String, dynamic>> updateUserProfile({
    String? fullName,
    String? phone,
    String? avatarUrl,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/auth/profile');
    final Map<String, dynamic> payloadMap = {};
    if (fullName != null) payloadMap['fullName'] = fullName.trim();
    if (phone != null) payloadMap['phone'] = phone.trim();
    if (avatarUrl != null) payloadMap['avatarUrl'] = avatarUrl.trim();

    try {
      final response = await client
          .put(uri, headers: _buildHeaders(isJson: true), body: jsonEncode(payloadMap))
          .timeout(timeoutDuration);

      final Map<String, dynamic> body = jsonDecode(
        utf8.decode(response.bodyBytes),
      ) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return {
          'success': true,
          'data': body['data'],
          'message': body['message'] ?? 'تم تحديث بيانات الملف الشخصي بنجاح',
        };
      }

      return {
        'success': false,
        'errorCode': body['errorCode'] ?? 'UPDATE_PROFILE_FAILED',
        'errorMessage': body['errorMessage'] ?? 'فشل تحديث بيانات الملف الشخصي',
      };
    } catch (e) {
      return {
        'success': false,
        'errorCode': 'NETWORK_ERROR',
        'errorMessage': 'تعذر الاتصال بالخادم لتحديث الملف الشخصي',
      };
    }
  }
}


