// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System
// File: lib/services/api_client.dart
// Service: Central HTTP API Client for Backend Integration
// Master Reference: Rule 18 (Backend Rule), Rule 23 (Error Handling)
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/card_batch_model.dart';
import '../models/card_model.dart';
import '../models/package_model.dart';
import '../models/router_model.dart';
import '../models/sale_model.dart';
import '../models/staff_user_model.dart';
import '../models/subscription_status_model.dart';

class ApiClient {
  static const String baseUrl = 'http://127.0.0.1:3000';
  static const Duration timeoutDuration = Duration(seconds: 5);
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

  /// Manually set the auth token (useful in tests or when restored).
  static void setAuthToken(String? token) {
    _authToken = token;
  }

  /// Resets client and active in-memory token (useful between test cases).
  static void resetClient() {
    client = http.Client();
    _authToken = null;
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
    required String password,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/auth/login');
    final payload = jsonEncode({
      'username': username.trim(),
      'password': password,
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
      } else if (response.statusCode == 401) {
        await logout();
        return {
          'success': false,
          'errorCode': 'UNAUTHORIZED',
          'errorMessage': body['errorMessage'] ?? 'بيانات الدخول غير صحيحة',
        };
      } else {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'SERVER_ERROR',
          'errorMessage': body['errorMessage'] ??
              'فشل تسجيل الدخول (${response.statusCode})',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'errorCode': 'TIMEOUT',
        'errorMessage':
            'انتهت مهلة الاتصال بالخادم (5 ثوانٍ). يرجى التأكد من استجابة السيرفر.',
      };
    } on SocketException {
      return {
        'success': false,
        'errorCode': 'NETWORK_UNREACHABLE',
        'errorMessage':
            'تعذر الاتصال بخادم الـ Backend على المنفذ 3000 (تأكد من تشغيل السيرفر).',
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

  /// Tests connectivity to a MikroTik router through the backend API.
  static Future<Map<String, dynamic>> testRouterConnection({
    required String host,
    required int port,
    required String username,
    required String password,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/routers/test-connection');
    final payload = jsonEncode({
      'host': host,
      'port': port,
      'username': username,
      'password': password,
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

      if (response.statusCode == 200) {
        return body;
      } else if (response.statusCode == 401) {
        await logout();
        return {
          'success': false,
          'errorCode': 'UNAUTHORIZED',
          'errorMessage': body['errorMessage'] ?? 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً.',
        };
      } else if (response.statusCode == 422 || response.statusCode == 400) {
        return body;
      } else {
        return {
          'success': false,
          'errorCode': 'SERVER_ERROR',
          'errorMessage':
              'استجاب الخادم برمز خطأ غير متوقع (${response.statusCode})',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'errorCode': 'TIMEOUT',
        'errorMessage':
            'انتهت مهلة الاتصال بالخادم (5 ثوانٍ). يرجى التأكد من استجابة السيرفر.',
      };
    } on SocketException {
      return {
        'success': false,
        'errorCode': 'NETWORK_UNREACHABLE',
        'errorMessage':
            'تعذر الاتصال بخادم الـ Backend على المنفذ 3000 (تأكد من تشغيل السيرفر).',
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
            'انتهت مهلة الاتصال بالخادم (5 ثوانٍ). يرجى التأكد من استجابة السيرفر.',
      };
    } on SocketException {
      return {
        'success': false,
        'errorCode': 'NETWORK_UNREACHABLE',
        'errorMessage':
            'تعذر الاتصال بخادم الـ Backend على المنفذ 3000 (تأكد من تشغيل السيرفر).',
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
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/routers');
    final payload = jsonEncode({
      'name': name,
      'host': host,
      'port': port,
      'username': username,
      'password': password,
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
          'errorMessage': 'اسم الراوتر مسجل مسبقاً، يرجى اختيار اسم مختلف.',
        };
      } else {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'SERVER_ERROR',
          'errorMessage': body['errorMessage'] ??
              'فشل إضافة الراوتر (${response.statusCode})',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'errorCode': 'TIMEOUT',
        'errorMessage':
            'انتهت مهلة الاتصال بالخادم (5 ثوانٍ). يرجى التأكد من استجابة السيرفر.',
      };
    } on SocketException {
      return {
        'success': false,
        'errorCode': 'NETWORK_UNREACHABLE',
        'errorMessage':
            'تعذر الاتصال بخادم الـ Backend على المنفذ 3000 (تأكد من تشغيل السيرفر).',
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
          'errorMessage': body['errorMessage'] ?? 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً.',
        };
      } else if (response.statusCode == 404) {
        return {
          'success': false,
          'errorCode': 'ROUTER_NOT_FOUND',
          'errorMessage': 'الراوتر المطلوب غير موجود أو تم حذفه مسبقاً.',
        };
      } else {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'SERVER_ERROR',
          'errorMessage':
              body['errorMessage'] ?? 'فشل حذف الراوتر (${response.statusCode})',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'errorCode': 'TIMEOUT',
        'errorMessage':
            'انتهت مهلة الاتصال بالخادم (5 ثوانٍ). يرجى التأكد من استجابة السيرفر.',
      };
    } on SocketException {
      return {
        'success': false,
        'errorCode': 'NETWORK_UNREACHABLE',
        'errorMessage':
            'تعذر الاتصال بخادم الـ Backend على المنفذ 3000 (تأكد من تشغيل السيرفر).',
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
            'انتهت مهلة الاتصال بالخادم (5 ثوانٍ). يرجى التأكد من استجابة السيرفر.',
      };
    } on SocketException {
      return {
        'success': false,
        'errorCode': 'NETWORK_UNREACHABLE',
        'errorMessage':
            'تعذر الاتصال بخادم الـ Backend على المنفذ 3000 (تأكد من تشغيل السيرفر).',
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
            'انتهت مهلة الاتصال بالخادم (5 ثوانٍ). يرجى التأكد من استجابة السيرفر.',
      };
    } on SocketException {
      return {
        'success': false,
        'errorCode': 'NETWORK_UNREACHABLE',
        'errorMessage':
            'تعذر الاتصال بخادم الـ Backend على المنفذ 3000 (تأكد من تشغيل السيرفر).',
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
            'انتهت مهلة الاتصال بالخادم (5 ثوانٍ). يرجى التأكد من استجابة السيرفر.',
      };
    } on SocketException {
      return {
        'success': false,
        'errorCode': 'NETWORK_UNREACHABLE',
        'errorMessage':
            'تعذر الاتصال بخادم الـ Backend على المنفذ 3000 (تأكد من تشغيل السيرفر).',
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

  /// Generates a new batch of hotspot cards associated with an internet package.
  static Future<Map<String, dynamic>> generateCardBatch({
    required String packageId,
    required int quantity,
    String? prefix,
    int? userLength,
    int? passwordLength,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/cards/generate-batch');
    final Map<String, dynamic> payloadMap = {
      'packageId': packageId,
      'quantity': quantity,
    };
    if (prefix != null && prefix.trim().isNotEmpty) {
      payloadMap['prefix'] = prefix.trim();
    }
    if (userLength != null && userLength > 0) {
      payloadMap['userLength'] = userLength;
    }
    if (passwordLength != null && passwordLength > 0) {
      payloadMap['passwordLength'] = passwordLength;
    }

    try {
      final response = await client
          .post(
            uri,
            headers: _buildHeaders(isJson: true),
            body: jsonEncode(payloadMap),
          )
          .timeout(const Duration(seconds: 15));

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
          'errorMessage': body['errorMessage'] ?? 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً.',
        };
      } else if (response.statusCode == 404) {
        return {
          'success': false,
          'errorCode': 'PACKAGE_NOT_FOUND',
          'errorMessage': 'الباقة المحددة غير موجودة في النظام.',
        };
      } else if (response.statusCode == 422) {
        return {
          'success': false,
          'errorCode': 'PACKAGE_INACTIVE',
          'errorMessage': 'الباقة المحددة غير مفعّلة حالياً، يرجى تفعيلها أولاً.',
        };
      } else if (response.statusCode == 400) {
        return {
          'success': false,
          'errorCode': 'VALIDATION_ERROR',
          'errorMessage': body['errorMessage'] ??
              'بيانات التوليد غير صالحة، يرجى التأكد من الكمية وصحة المدخلات.',
        };
      } else {
        return {
          'success': false,
          'errorCode': body['errorCode'] ?? 'SERVER_ERROR',
          'errorMessage': body['errorMessage'] ??
              'فشل توليد دفعة الكروت (${response.statusCode})',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'errorCode': 'TIMEOUT',
        'errorMessage':
            'انتهت مهلة الاتصال بالخادم أثناء توليد الكروت. يرجى المحاولة لاحقاً.',
      };
    } on SocketException {
      return {
        'success': false,
        'errorCode': 'NETWORK_UNREACHABLE',
        'errorMessage':
            'تعذر الاتصال بخادم الـ Backend على المنفذ 3000 (تأكد من تشغيل السيرفر).',
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
            'انتهت مهلة الاتصال بالخادم (5 ثوانٍ). يرجى التأكد من استجابة السيرفر.',
      };
    } on SocketException {
      return {
        'success': false,
        'errorCode': 'NETWORK_UNREACHABLE',
        'errorMessage':
            'تعذر الاتصال بخادم الـ Backend على المنفذ 3000 (تأكد من تشغيل السيرفر).',
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
            'انتهت مهلة الاتصال بالخادم (5 ثوانٍ). يرجى التأكد من استجابة السيرفر.',
      };
    } on SocketException {
      return {
        'success': false,
        'errorCode': 'NETWORK_UNREACHABLE',
        'errorMessage':
            'تعذر الاتصال بخادم الـ Backend على المنفذ 3000 (تأكد من تشغيل السيرفر).',
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
            'تعذر الاتصال بخادم الـ Backend على المنفذ 3000 (تأكد من تشغيل السيرفر).',
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
            'تعذر الاتصال بخادم الـ Backend على المنفذ 3000 (تأكد من تشغيل السيرفر).',
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
        'errorMessage': 'تعذر الاتصال بخادم الـ Backend على المنفذ 3000 (تأكد من تشغيل السيرفر).',
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
        'errorMessage': 'تعذر الاتصال بخادم الـ Backend على المنفذ 3000 (تأكد من تشغيل السيرفر).',
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
        'errorMessage': 'تعذر الاتصال بخادم الـ Backend على المنفذ 3000 (تأكد من تشغيل السيرفر).',
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
        'errorMessage': 'تعذر الاتصال بخادم الـ Backend على المنفذ 3000 (تأكد من تشغيل السيرفر).',
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
        'errorMessage': 'تعذر الاتصال بخادم الـ Backend على المنفذ 3000 (تأكد من تشغيل السيرفر).',
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
}

