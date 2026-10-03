# تقرير معالجة المصادقة المؤقتة في تطبيق فلاتر (Temporary Auth Flow)

**التاريخ:** 3 أكتوبر 2026  
**نوع المهمة:** إصلاح خلل حرج (Bug Fix / Critical)  
**المشروع:** Flutter Frontend (`mikrotik_cards_app`)

---

## 1. الملخص والهدف
بعد تطبيق نظام مصادقة JWT وحماية مسارات الـ Backend بـ `authMiddleware`، أصبح الخادم يتطلب ترويسة `Authorization: Bearer <token>` على كافة الـ Routes (`routers`, `packages`, `cards`, `sales`).  
كان تطبيق Flutter يرسل طلبات بدون توكن، مما تسبب في رفض الطلبات برمز `401 Unauthorized` وتوقف تدفق البيانات.  
تم تنفيذ حل وظيفي مؤقت وسريع يضمن استعادة الاتصال الكامل بالـ Backend وحفظ جلسة المستخدم محلياً مع إعادة التوجيه التلقائي عند انتهاء صلاحية الجلسة.

---

## 2. التغييرات المنفذة في الكود

### 2.1 حزمة التخزين المحلي
- تم تثبيت حزمة `shared_preferences: ^2.5.5` لدعم استمرارية التوكن بعد إغلاق التطبيق.

### 2.2 تحديث `lib/services/api_client.dart`
- **إدارة التوكن (In-Memory & Persistent):**
  - إضافة المتغير `static String? _authToken` مع خاصية `isAuthenticated`.
  - دالة `loadSavedToken()`: قراءة التوكن من `SharedPreferences` عند إقلاع التطبيق.
  - دالة `logout()`: مسح التوكن من الذاكرة ومن `SharedPreferences`.
  - دالة `login({required String username, required String password})`: إرسال طلب `POST /api/v1/auth/login`، وتخزين التوكن العائد محلياً وفي الذاكرة.
- **حقن الترويسات التلقائي:**
  - بناء دالة `_buildHeaders({bool isJson = false})` التي تحقن تلقائياً `Authorization: Bearer $_authToken` في كل الطلبات.
- **معالجة رمز 401 UNAUTHORIZED:**
  - تم تحديث كافة استدعاءات الـ API (`testRouterConnection`, `getRouters`, `createRouter`, `deleteRouter`, `getPackages`, `createPackage`, `deletePackage`, `generateCardBatch`, `getCards`, `updateCardStatus`, `createSale`, `getTodaySalesTotal`).
  - عند استقبال استجابة `401`، يتم استدعاء `logout()` فوراً لإلغاء صلاحية التوكن المخزن، وإرجاع خريطة خطأ موحدة: `{'success': false, 'errorCode': 'UNAUTHORIZED', 'errorMessage': '...'}`.

### 2.3 إنشاء شاشة الدخول المؤقتة `lib/screens/temp_login_screen.dart`
- شاشة وظيفية بتصميم Neumorphic متناسق مع هوية التطبيق.
- حقلين إدخال باستخدام `NeumorphicTextField`:
  - اسم المستخدم (Username).
  - كلمة المرور (Password) مع زر إظهار/إخفاء كلمة المرور.
- زر دخول Neumorphic أصفر مع مؤشر تحميل `CircularProgressIndicator`.
- إظهار شريط تنبيه بالأخطاء (مثل "بيانات الدخول غير صحيحة" أو الحقول الفارغة).
- عند نجاح تسجيل الدخول: الانتقال الفوري لشاشة `DashboardScreen` مع تمرير اسم المستخدم.

### 2.4 تحديث نقطة الدخول `lib/main.dart`
- استدعاء `WidgetsFlutterBinding.ensureInitialized()`.
- محاولة استرجاع التوكن المحفوظ مسبقاً عبر `ApiClient.loadSavedToken()`.
- التوجيه التلقائي:
  - إذا كان هناك توكن محفوظ وصالح: الانتقال مباشرة إلى `DashboardScreen`.
  - إذا لم يوجد توكن: عرض `TempLoginScreen`.

### 2.5 تحديث شاشة الداشبورد `lib/screens/dashboard_screen.dart`
- إضافة دالة `_handleUnauthorized()` التي تعيد توجيه المستخدم تلقائياً إلى `TempLoginScreen` عبر `pushAndRemoveUntil`.
- فحص رمز الخطأ `UNAUTHORIZED` في جميع عمليات جلب البيانات وحذف الراوترات لضمان حماية الشاشة فور انتهاء التوكن.

---

## 3. الاختبارات والتحقق (Verification & Testing)

1. **التحليل الساكن للكود (`flutter analyze`):**
   - النتيجة: `No issues found!` (0 أخطاء و 0 تحذيرات).

2. **اختبارات الوحدة والتكامل (`flutter test`):**
   - تم تحديث `test/api_client_test.dart` لاختبار تسجيل الدخول والتخزين وإرسال الترويسات مع السيرفر الحي.
   - تم إنشاء ملف اختبارات شامل `test/auth_test.dart` يغطي:
     - شاشة الدخول المؤقتة وحالات التحقق والخطأ.
     - نجاح الدخول والانتقال إلى الداشبورد.
     - إعادة التوجيه التلقائي من الداشبورد عند تلقي `UNAUTHORIZED`.
     - بدء التطبيق بالتوجيه الصحيح بناءً على حالة التوكن.
   - **النتيجة الإجمالية:** `62 passed` (كل الاختبارات نجحت بنسبة 100% وبدون أي فشل).

3. **بناء نسخة الويب (`flutter build web`):**
   - تم البناء بنجاح وتحديث مجلد `build/web` المعروض عبر سيرفر التطوير المحلي.

---

## 4. قائمة الملفات المتأثرة
- `pubspec.yaml`
- `lib/services/api_client.dart`
- `lib/screens/temp_login_screen.dart`
- `lib/main.dart`
- `lib/screens/dashboard_screen.dart`
- `test/api_client_test.dart`
- `test/auth_test.dart`
- `reports/temp-auth-frontend-report.md`
