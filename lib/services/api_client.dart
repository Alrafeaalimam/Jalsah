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

import '../models/card_batch_model.dart';
import '../models/card_model.dart';
import '../models/package_model.dart';
import '../models/router_model.dart';

class ApiClient {
  static const String baseUrl = 'http://127.0.0.1:3000';
  static const Duration timeoutDuration = Duration(seconds: 5);
  static http.Client client = http.Client();

  static void resetClient() {
    client = http.Client();
  }

  /// Tests connectivity to a MikroTik router through the backend API.
  /// 
  /// Guarantees a normalized result map adhering to backend contract:
  /// Success: {'success': true, 'data': {...}}
  /// Failure: {'success': false, 'errorCode': '...', 'errorMessage': '...'}
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

      if (response.statusCode == 200) {
        return body;
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
  ///
  /// Returns:
  /// Success: {'success': true, 'data': `List<RouterModel>`}
  /// Failure: {'success': false, 'errorCode': '...', 'errorMessage': '...'}
  static Future<Map<String, dynamic>> getRouters() async {
    final uri = Uri.parse('$baseUrl/api/v1/routers');

    try {
      final response = await client.get(
        uri,
        headers: {
          'Accept': 'application/json',
        },
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
  ///
  /// Returns:
  /// Success: {'success': true, 'data': RouterModel}
  /// Failure: {'success': false, 'errorCode': '...', 'errorMessage': '...'}
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

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          body['success'] == true) {
        final routerData = body['data'] as Map<String, dynamic>;
        return {
          'success': true,
          'data': RouterModel.fromJson(routerData),
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
  ///
  /// Returns:
  /// Success: {'success': true, 'message': '...'}
  /// Failure: {'success': false, 'errorCode': '...', 'errorMessage': '...'}
  static Future<Map<String, dynamic>> deleteRouter(String id) async {
    final uri = Uri.parse('$baseUrl/api/v1/routers/$id');

    try {
      final response = await client.delete(
        uri,
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(timeoutDuration);

      final Map<String, dynamic> body = jsonDecode(
        utf8.decode(response.bodyBytes),
      ) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return {
          'success': true,
          'message': body['message'] ?? 'تم حذف الراوتر بنجاح',
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
  ///
  /// Returns:
  /// Success: {'success': true, 'data': `List<PackageModel>`}
  /// Failure: {'success': false, 'errorCode': '...', 'errorMessage': '...'}
  static Future<Map<String, dynamic>> getPackages() async {
    final uri = Uri.parse('$baseUrl/api/v1/packages');

    try {
      final response = await client.get(
        uri,
        headers: {
          'Accept': 'application/json',
        },
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
  ///
  /// Returns:
  /// Success: {'success': true, 'data': PackageModel}
  /// Failure: {'success': false, 'errorCode': '...', 'errorMessage': '...'}
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

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          body['success'] == true) {
        final pkgData = body['data'] as Map<String, dynamic>;
        return {
          'success': true,
          'data': PackageModel.fromJson(pkgData),
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
  ///
  /// Returns:
  /// Success: {'success': true, 'message': '...'}
  /// Failure: {'success': false, 'errorCode': '...', 'errorMessage': '...'}
  static Future<Map<String, dynamic>> deletePackage(String id) async {
    final uri = Uri.parse('$baseUrl/api/v1/packages/$id');

    try {
      final response = await client.delete(
        uri,
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(timeoutDuration);

      final Map<String, dynamic> body = jsonDecode(
        utf8.decode(response.bodyBytes),
      ) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        return {
          'success': true,
          'message': body['message'] ?? 'تم حذف الباقة بنجاح',
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
  ///
  /// Parameters:
  /// - [packageId]: Required UUID of the package.
  /// - [quantity]: Number of cards to generate (1 to 1000).
  /// - [prefix]: Optional alphanumeric prefix for generated usernames.
  /// - [userLength]: Optional length of username random suffix (default 6).
  /// - [passwordLength]: Optional length of PIN / password (default 4).
  ///
  /// Returns:
  /// Success: {'success': true, 'data': {'batch': CardBatchModel, 'cards': `List<CardModel>`}}
  /// Failure: {'success': false, 'errorCode': '...', 'errorMessage': '...'}
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
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
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
  ///
  /// Returns:
  /// Success: {'success': true, 'data': `List<CardModel>`}
  /// Failure: {'success': false, 'errorCode': '...', 'errorMessage': '...'}
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
        headers: {
          'Accept': 'application/json',
        },
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
  ///
  /// Returns:
  /// Success: {'success': true, 'data': CardModel}
  /// Failure: {'success': false, 'errorCode': '...', 'errorMessage': '...'}
  static Future<Map<String, dynamic>> updateCardStatus({
    required String cardId,
    required String newStatus,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/cards/$cardId/status');

    try {
      final response = await client
          .patch(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
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
}
