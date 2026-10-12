# تقرير التحقق من تسجيل الدخول للأجهزة الجديدة عبر رمز OTP بالبريد الإلكتروني
# New Device Login Verification via Email OTP Report

**المرجع:** Master Prompt (بند 14 - Security Rules، بنية OTP واسترجاع كلمة المرور، خدمة EmailService، بند 26 - Audit Logging)  
**التاريخ:** 2026-10-12  
**الحالة:** مكتمل ومُعتمد بنسبة 100% (اجتياز كامل لاختبارات الـ Backend والـ Frontend وتأكيد حفظ البصمة)

---

## 1. ملخص تنفيذي (Executive Summary)

تم تطبيق نظام أمان متقدم ومحكم للتحقق من تسجيل الدخول من الأجهزة الجديدة لأول مرة (New Device Login Verification) عبر رمز OTP يُرسل إلى البريد الإلكتروني المعتمد لصاحب الحساب، وذلك عبر كل من:
- **الخادم الخلفي (Backend API):** مشروع `mikrotik_cards_backend` مبني بـ Fastify و Prisma ORM و PostgreSQL.
- **تطبيق العميل والواجهات (Frontend App):** تطبيق `mikrotik_cards_app` المبني بـ Flutter بتصميم نيومورفيك متطور وداعم للغة العربية RTL.

### المبادئ الأمنية المعتمدة:
1. **التعرف على الأجهزة (Device Fingerprinting):** توليد وحفظ بصمة فريدة لكل تثبيت (`deviceFingerprint`) مع وصف نوع الجهاز ونظام التشغيل (`deviceLabel`).
2. **عزل التوكن المؤقت (Security Token Isolation):** عند الدخول من جهاز غير موثوق، لا يتم إصدار رمز JWT كامل الصلاحيات، بل يتم إصدار `tempToken` صالح لمدة 10 دقائق فقط محدد الغرض (`purpose: 'DEVICE_VERIFICATION'`) ومجرد من أي صلاحيات إدارية (خالي من حقل `role`)، مما يمنع نهائياً الوصول لأي مسار محمي في النظام.
3. **التجزئة الآمنة للكود (Cryptographic OTP Hashing):** يُخزن رمز التحقق المكون من 6 أرقام في جدول `login_otps` بصيغة مشفرة (`bcrypt`) مع فترة صلاحية 10 دقائق وعلامة استخدام لمرة واحدة (`used: true`).
4. **تسجيل التدقيق الأمني (Audit Logging):** عند نجاح التحقق من الجهاز، يتم إنشاء سجل تدقيق أمني رسمي بنوع `LOGIN` ووصف `"دخول من جهاز جديد تم التحقق منه"` مع توثيق معرّف الجهاز والمستخدم.
5. **المرونة وتجربة المستخدم:** عند تسجيل الدخول من جهاز تم توثيقه سابقاً (`TrustedDevice`)، يتم الدخول مباشرة وإصدار JWT العادي دون طلب OTP مع تحديث تاريخ آخر استخدام `lastUsedAt`.
6. **ثبات بيئة التطوير (Web Persistence):** يتم حفظ البصمة محلياً في `SharedPreferences` بحيث تظل ثابتة تماماً بين عمليات إعادة التحميل (Reload) في المتصفح المحلي `localhost:8080`.

---

## 2. تفاصيل التطبيق في الخادم الخلفي (Backend Implementation)

### 2.1. نموذج البيانات والهجرة (Prisma Models & Migration)
تم تحديث `prisma/schema.prisma` بإضافة نموذجين جديدين:
```prisma
model TrustedDevice {
  id                String    @id @default(uuid())
  userId            String
  deviceFingerprint String    @db.VarChar(255)
  deviceLabel       String?   @db.VarChar(255)
  lastUsedAt        DateTime  @default(now())
  createdAt         DateTime  @default(now())

  user              User      @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@unique([userId, deviceFingerprint])
  @@index([userId])
  @@map("trusted_devices")
}

model LoginOtp {
  id        String   @id @default(uuid())
  userId    String
  otpHash   String
  expiresAt DateTime
  used      Boolean  @default(false)
  createdAt DateTime @default(now())

  user      User     @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@index([userId, used, expiresAt])
  @@map("login_otps")
}
```
- **ملف الهجرة المطبق:** `prisma/migrations/20261011230000_add_trusted_devices_and_login_otps/migration.sql`.
- تم تنفيذ الهجرة بنجاح على قاعدة البيانات المحلية PostgreSQL `mikrotik_dev_test`، وإعادة توليد عميل Prisma مع WASM Patch.

### 2.2. عزل التوكن المؤقت في `src/infrastructure/security/jwt.ts`
- دالة `signTempToken({ userId, tenantId })`: تولد توكن مشفر بخوارزمية HS256 ومدّة صلاحية 10 دقائق فقط (`10m`). يحتوي الحمولة على `purpose: 'DEVICE_VERIFICATION'` ولا يحتوي على `role`.
- دالة `verifyTempToken(token)`: تفك التشفير وتتحقق من وجود `purpose: 'DEVICE_VERIFICATION'`. بما أن `authMiddleware` يرفض أي توكن لا يحتوي على `role`، فإن أي محاولة لاستخدام `tempToken` كتوكن عادي تقابل فوراً بـ `401 UNAUTHORIZED`.

### 2.3. قالب البريد في `src/infrastructure/email/EmailService.ts`
- إضافة الدالة `sendDeviceVerificationOtpEmail(toEmail, otpCode, deviceLabel)` مع قالب بريد HTML متناسق مع هوية منصة "جلسة" وقسم حماية أمني ينبه المستخدم إلى عدم مشاركة الرمز مع أي شخص.

### 2.4. حالة الاستخدام `LoginUseCase`
- استقبال اختياري لمعاملي `deviceFingerprint` و `deviceLabel`.
- التحقق من جدول `TrustedDevice`:
  - إذا كان الجهاز موثوقاً: تحديث `lastUsedAt` وإصدار رمز JWT كامل الصلاحيات والدخول المباشر.
  - إذا كان الجهاز جديداً: توليد OTP مكون من 6 أرقام، حفظ التجزئة في `login_otps`، إرسال البريد، وإرجاع استجابة خاصة:
    ```json
    {
      "requiresDeviceVerification": true,
      "tempToken": "<10-minute verification token>",
      "emailMasked": "a***n@domain.com",
      "message": "تم إرسال كود تحقق لبريدك لأن هذا جهاز جديد"
    }
    ```

### 2.5. حالة الاستخدام `VerifyDeviceOtpUseCase`
- التحقق من صلاحية `tempToken`.
- التحقق من وجود كود OTP غير منتهي وغير مستخدم يتطابق تجزئته مع الكود المدخل.
- وسم الكود بأنه مستخدم (`used: true`).
- تسجيل الجهاز الجديد أو تحديثه عبر `upsert` في جدول `TrustedDevice`.
- تحديث `lastLoginAt` للمستخدم.
- تدوين العملية في سجل التدقيق الأمني (Audit Log):
  - `action: "LOGIN"`
  - `description: "دخول من جهاز جديد تم التحقق منه"`
- إصدار التوكن النهائي الكامل (JWT صالح لمدة 24 ساعة).

### 2.6. نقطة النهاية والتحقق (Route & Validation)
- `POST /api/v1/auth/verify-device-otp` في `src/presentation/http/routes/auth.routes.ts`.
- التحقق باستخدام Zod schema (`verifyDeviceOtpSchema`) في `src/presentation/validators/auth.validator.ts`.

---

## 3. تفاصيل التطبيق في واجهة Flutter (Frontend Implementation)

### 3.1. إدارة البصمة في `lib/services/api_client.dart`
- ثابت مفتاح التخزين: `deviceFingerprintStorageKey = 'device_fingerprint'`.
- الدالة `getDeviceFingerprint()`: تسترجع البصمة المحفوظة في `SharedPreferences` أو تولد بصمة جديدة فريدة وتبقيها محفوظة دائماً.
- الدالة `getDeviceLabel()`: توليد وصف تلقائي للجهاز ونظام التشغيل (`تطبيق جلسة (android / linux / web)`).
- تعديل `ApiClient.login`: إرسال `deviceFingerprint` و `deviceLabel` تلقائياً مع طلب الدخول ومعالجة الرد الخاص عند الحاجة للتحقق.
- إضافة `ApiClient.verifyDeviceOtp`: إرسال الكود والتوكن المؤقت، وعند النجاح حفظ التوكن في الذاكرة و `SharedPreferences`.

### 3.2. شاشة التحقق `lib/screens/verify_device_otp_screen.dart`
- شاشة مصممة بنمط Neumorphic أنيق، وتحتوي على:
  - أيقونة أمان ناعمة (Security Badge).
  - عنوان الشاشة "تأكيد الجهاز الجديد".
  - صندوق إرشادي أزرق واضح بالنص المطلوب: `"تم إرسال كود تحقق لبريدك لأن هذا جهاز جديد"`.
  - إظهار البريد الإلكتروني المموه (Masked Email).
  - حقل إدخال الكود المكون من 6 أرقام مع تقييد الإدخال للأرقام فقط (`inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)]`).
  - زر التحقق والدخول مع مؤشر تحميل.
  - إمكانية العودة لشاشة تسجيل الدخول.
  - الانتقال التلقائي للداشبورد المخصص (`DashboardScreen` أو `SuperAdminDashboardScreen`) فور اكتمال التحقق.

### 3.3. التوجيه التلقائي في `lib/screens/temp_login_screen.dart`
- عند استقبال `requiresDeviceVerification == true`، يتم الانتقال فوراً إلى `VerifyDeviceOtpScreen` مع تمرير `tempToken` و `emailMasked` و `deviceFingerprint`.

---

## 4. نتائج الاختبارات الآلية (Automated Test Results)

### 4.1. اختبارات الـ Backend (`npm test`)
تم تنفيذ كامل حزمة الاختبارات في `mikrotik_cards_backend` والتي تشمل اختبارات الوحدة واختبارات التكامل لكافة المسارات وحالات الاستخدام، بالإضافة لاختبارات مسار التحقق الجديد `DeviceVerificationRoutes.test.ts`:
- **عدد الاختبارات الكلي:** 248 اختباراً.
- **عدد الاختبارات الناجحة:** 248 اختباراً.
- **عدد الاختبارات الفاشلة:** 0.
- **مدة التنفيذ:** ~38 ثانية.
- **النتيجة:**
  ```text
  ℹ tests 248
  ℹ suites 68
  ℹ pass 248
  ℹ fail 0
  ℹ cancelled 0
  ℹ skipped 0
  ℹ todo 0
  ```

### 4.2. اختبارات الـ Frontend (`flutter test`)
تم تنفيذ حزمة الاختبارات الشاملة في `mikrotik_cards_app` والتي تشمل اختبارات الواجهات والشاشات والتحقق من تدفقات تسجيل الدخول والبصمة:
- **عدد الاختبارات الكلي:** 185 اختباراً.
- **عدد الاختبارات الناجحة:** 185 اختباراً.
- **عدد الاختبارات الفاشلة:** 0.
- **النتيجة:**
  ```text
  00:43 +185: All tests passed!
  ```

---

## 5. الملفات المضافة والمعدلة (Files Added & Modified)

### مستودع الخادم (`mikrotik_cards_backend`):
1. `prisma/schema.prisma` (معدل: إضافة `TrustedDevice` و `LoginOtp`)
2. `prisma/migrations/20261011230000_add_trusted_devices_and_login_otps/migration.sql` (جديد: كود إنشاء الجداول وفهارسها)
3. `src/infrastructure/security/jwt.ts` (معدل: دوال `signTempToken` و `verifyTempToken`)
4. `src/infrastructure/email/EmailService.ts` (معدل: إضافة `sendDeviceVerificationOtpEmail`)
5. `src/application/use-cases/auth/LoginUseCase.ts` (معدل: فحص الجهاز الموثوق وتوليد OTP وإرجاع التوكن المؤقت)
6. `src/application/use-cases/auth/VerifyDeviceOtpUseCase.ts` (جديد: التحقق من OTP وتوثيق الجهاز وإصدار JWT والتدقيق)
7. `src/presentation/validators/auth.validator.ts` (معدل: إضافة `verifyDeviceOtpSchema` ومعاملات البصمة)
8. `src/presentation/http/routes/auth.routes.ts` (معدل: تسجيل مسار `POST /api/v1/auth/verify-device-otp`)
9. `tests/presentation/DeviceVerificationRoutes.test.ts` (جديد: 9 اختبارات تكاملية شاملة لجميع سيناريوهات الجهاز الموثوق)

### مستودع التطبيق (`mikrotik_cards_app`):
1. `lib/services/api_client.dart` (معدل: توليد وحفظ `deviceFingerprint`، واستدعاء مسارات الدخول وتأكيد الجهاز)
2. `lib/widgets/neumorphic_text_field.dart` (معدل: دعم خاصية `inputFormatters`)
3. `lib/screens/verify_device_otp_screen.dart` (جديد: شاشة إدخال OTP وتأكيد الجهاز الجديد)
4. `lib/screens/temp_login_screen.dart` (معدل: التوجيه التلقائي لشاشة التحقق عند اكتشاف جهاز جديد)
5. `test/device_verification_test.dart` (جديد: 10 اختبارات وحدة وودجات للتحقق من الجهاز الجديد)
6. `test/admin_actions_and_login_test.dart` (معدل: تهيئة `SharedPreferences` mock)
7. `test/api_client_test.dart` (معدل: ربط MockBackend للاختبارات المستقلة)

---

## 6. تأكيد الالتزام بالمعايير والـ Git Commits

تم الالتزام بصيغة الـ Commit المطلوبة بحذافيرها:
`feat(auth): add new-device login verification via email OTP`

- مستودع Backend: جاهز ومؤكد.
- مستودع Frontend: جاهز ومؤكد.
