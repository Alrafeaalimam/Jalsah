# تقرير إنجاز واجهة توليد واستعراض كروت الهوتسبوت (Card Generation & Cards List Frontend) في Flutter

**تاريخ الإنجاز**: 2026-10-02  
**المشروع**: Commercial MikroTik Network & HotSpot Card Management System (Flutter App)  
**التصنيف**: FRONTEND / FEATURE (Flutter ↔ Card Generation API)  
**المرجع المعماري**: نفس نمط Router & Packages CRUD المعتمد في Flutter (`api_client.dart`، الحالات الأربع Rule 35، `neumorphic_text_field.dart`، `AppColors`، `PressableNeumorphicCard`).

---

## 1. الملخص التنفيذي

تم بحمد الله بناء وتكامل واجهات توليد واستعراض كروت الهوتسبوت بالكامل وربطها مع خادم الـ Backend عبر واجهات REST API:
1. بناء شاشة توليد الدفعات الجديدة (`GenerateCardsScreen`) التي تتيح اختيار باقة حقيقية، تحديد الكمية، إضافة بادئة لاسم المستخدم، وضبط أطوال الحسابات وكلمات المرور، مع عرض قسم نتائج متكامل لمعاينة أول 5 كروت مع إمكانية النسخ الفوري.
2. بناء شاشة استعراض الكروت (`CardsListScreen`) التي تغطي الحالات الأربع للبيانات مع فلاتر حسب الحالة (`GENERATED`, `AVAILABLE`, `ACTIVE`, `SOLD`, `EXPIRED`, `CANCELLED`) وبحث فوري.
3. ربط الشاشتين بسلاسة مع لوحة التحكم الرئيسية (`DashboardScreen`) عبر استبدال الرسالة التجريبية القديمة لزر "توليد كروت جديدة" وإضافة زر تنقل سريع لـ "الكروت" في البانر العلوي.

---

## 2. تفاصيل الملفات المنشأة والمعدلة

### 2.1 نماذج البيانات (Data Models)
* [**`lib/models/card_model.dart`**](file:///data/data/com.termux/files/home/mikrotik_cards_app/lib/models/card_model.dart):
  * يمثل كرت الهوتسبوت (`id`, `username`, `password`, `status`, `batchId`, `packageId`, `price`, `createdAt`, `updatedAt`).
  * دعم دالتي `fromJson` و `toJson` ومعادلة الكائنات `==` و `hashCode`.
  * ترجمة حالات آلة الحالات إلى العربية عبر `statusTextArabic` (`تم التوليد`, `متاح للبيع`, `تم البيع`, `نشط`, `منتهي`, `ملغي`, `معلق`, `مسحوب`).
  * تخصيص لون متوافق مع الهوية لكل حالة عبر `statusColor`.
  * مساعدة تنسيق السعر `formattedPrice`.

* [**`lib/models/card_batch_model.dart`**](file:///data/data/com.termux/files/home/mikrotik_cards_app/lib/models/card_batch_model.dart):
  * يمثل دفعة الكروت المولّدة (`id`, `batchNumber`, `name`, `quantity`, `packageId`, `prefix`, `unitPrice`, `totalPrice`, `createdAt`).
  * دعم دالتي `fromJson` و `toJson` وتنسيق القيمة الإجمالية `formattedTotalPrice`.

### 2.2 توسيع عميل الخادم (ApiClient)
* [**`lib/services/api_client.dart`**](file:///data/data/com.termux/files/home/mikrotik_cards_app/lib/services/api_client.dart):
  * تمت إضافة دوال الكروت دون المساس بدوال الراوتر أو الباقات:
    * `generateCardBatch({required String packageId, required int quantity, String? prefix, int? userLength, int? passwordLength})`:
      * يرسل طلب `POST /api/v1/cards/generate-batch` مع مهلة 15 ثانية لاستيعاب الدفعات الكبيرة.
      * معالجة حالات الخطأ العربية: 404 (باقة غير موجودة)، 422 (باقة غير نشطة)، 400 (أخطاء التحقق)، أخطاء الشبكة والمهلة.
      * إرجاع كائن الدفعة `CardBatchModel` وقائمة الكروت `List<CardModel>`.
    * `getCards({String? status, String? batchId})`:
      * يرسل طلب `GET /api/v1/cards` مع دعم تمرير معاملات الاستعلام الاختيارية (`status`, `batchId`).
      * إرجاع قائمة الكروت كموديلات جاهزة للعرض.
    * `updateCardStatus({required String cardId, required String newStatus})`:
      * يرسل طلب `PATCH /api/v1/cards/:id/status` مع معالجة استثناءات الانتقال الممنوعة (422 `INVALID_CARD_TRANSITION`).

### 2.3 شاشة توليد الكروت (GenerateCardsScreen)
* [**`lib/screens/generate_cards_screen.dart`**](file:///data/data/com.termux/files/home/mikrotik_cards_app/lib/screens/generate_cards_screen.dart):
  * **شريط علوي متدرج (Hero Banner)**: بهوية `AppColors` وزر رجوع وعنوان معبّر.
  * **جلب الباقات ديناميكياً**: استدعاء `ApiClient.getPackages()` تلقائياً عند الفتح.
  * **معالجة الحالات الاستثنائية**:
    * إذا لم توجد باقات معرّفة: عرض كرت توجيهي أنيق يوضح ضرورة وجود باقة إنترنت أولاً مع زر ينقل مباشرة إلى شاشة الباقات `PackagesScreen`.
    * حالة فشل الاتصال مع زر إعادة المحاولة.
  * **عناصر نموذج التوليد**:
    1. قائمة منسدلة نيومورفية لاختيار الباقة مع عرض اسم الباقة وسرعتها وسعرها.
    2. حقل الكمية (`NeumorphicTextField`) يقبل أرقاماً بين 1 و 1000، مع شرائح سريعة لاختيار الكميات الشائعة (+10, +25, +50, +100, +200).
    3. حقل بادئة اختياري (`prefix`) مثل "VIP" أو "NET".
    4. قسم إعدادات متقدمة قابل للطي لتحديد طول اسم المستخدم وكلمة المرور.
    5. زر توليد تفاعلي يعرض مؤشر تحميل نيومورفي أثناء المعالجة ويمنع الضغط المتكرر.
  * **قسم النتائج عند النجاح**:
    * كارت إنجاز أخضر مع ملخص الدفعة (رقم الدفعة، الكمية المولدة، القيمة الإجمالية).
    * معاينة أول 5 كروت مع إمكانية نسخ اسم المستخدم وكلمة المرور بضغطة زر وتنبيه فوري.
    * زر رئيسي "عرض كل الكروت" ينقل إلى `CardsListScreen` مع تصفية الدفعة.
    * زر ثانوي "دفعة أخرى" لإعادة تهيئة النموذج لتوليد دفعة جديدة.

### 2.4 شاشة استعراض الكروت (CardsListScreen)
* [**`lib/screens/cards_list_screen.dart`**](file:///data/data/com.termux/files/home/mikrotik_cards_app/lib/screens/cards_list_screen.dart):
  * **تطبيق الحالات الأربع (Master Rule 35)**:
    1. `Loading State`: مؤشر تحميل أنيق مع رسالة توضيحية.
    2. `Error State`: كارت خطأ مع خيار إعادة المحاولة.
    3. `Empty State`: كارت جذاب يتيح الانتقال مباشرة لتوليد كروت جديدة.
    4. `Data State`: قائمة كروت تفاعلية مبنية بواسطة `PressableNeumorphicCard`.
  * **شريط الفلاتر والبحث**:
    * حقل بحث فوري نيومورفي بالاسم أو كلمة المرور.
    * شرائح تصفية أفقية حسب الحالة (الكل / تم التوليد / متاح للبيع / نشط / تم البيع / منتهي / ملغي).
  * **تصميم كارت الكرت**:
    * بادج ملون يعكس حالة الكرت المعتمدة في آلة الحالات.
    * اسم المستخدم وكلمة المرور مع أزرار نسخ فورية إلى الحافظة.
    * عرض سعر الكرت بالعملة المحلية.
  * إحصائيات سريعة في الشريط العلوي (إجمالي الكروت، الكروت المولدة، الكروت المتاحة).

### 2.5 تحديث لوحة التحكم الرئيسية (DashboardScreen)
* [**`lib/screens/dashboard_screen.dart`**](file:///data/data/com.termux/files/home/mikrotik_cards_app/lib/screens/dashboard_screen.dart):
  * ربط دالة `_onGenerateCardsPressed()` بشاشة `GenerateCardsScreen()` بدلاً من الـ SnackBar المؤقت.
  * إضافة زر تنقل سريع "الكروت" بأيقونة البطاقة في شريط البانر العلوي بجوار زر "الباقات".

---

## 3. نتائج الفحص والاختبارات الآلية

### 3.1 فحص الكود (Flutter Analyze)
```text
Analyzing mikrotik_cards_app...                                 
No issues found! (ran in 3.2s)
```
**0 أخطاء و 0 تحذيرات.**

### 3.2 الاختبارات الآلية (Flutter Test)
تم إنشاء ملف اختبارات شامل [**`test/cards_test.dart`**](file:///data/data/com.termux/files/home/mikrotik_cards_app/test/cards_test.dart) يغطي:
- اختبارات نماذج البيانات والتحويل لـ JSON وحساب الألوان والنصوص العربية لكافة حالات `CardStateMachine`.
- اختبارات Mock لـ `ApiClient.generateCardBatch` و `ApiClient.getCards` و `ApiClient.updateCardStatus` وكافة أكواد الأخطاء (400, 404, 422).
- اختبارات Widget لشاشة `GenerateCardsScreen` بحالاتها المختلفة (عدم وجود باقات، ملء النموذج والتوليد، معاينة أول 5 كروت، الانتقال).
- اختبارات Widget لشاشة `CardsListScreen` (الحالات الأربع، الفلاتر، أزرار النسخ).
- اختبارات التكامل لشاشة `DashboardScreen` والتنقل لشاشتي الكروت والتوليد.

```text
00:15 +43: All tests passed!
```
**إجمالي الاختبارات التي اجتازت بنجاح: 43 اختباراً في التطبيق ككل.**

---

## 4. المراجعة والتشغيل

- التطبيق جاهز للمعاينة عبر المتصفح على:
  **`http://localhost:8080`** (خادم الويب قيد التشغيل).
- خادم الـ Backend قيد التشغيل على:
  **`http://127.0.0.1:3000`** مع قاعدة بيانات PostgreSQL حقيقية.
