# Dynamic Platform Settings & Notifications System Report

**Date:** 2026-10-11  
**Classification:** BACKEND + FRONTEND / FEATURE  
**Status:** Completed & Verified  

---

## 1. Executive Summary

This release introduces two foundational architectural capabilities to the Jalsah MikroTik Platform:
1. **Dynamic Platform Settings**: Full database-driven runtime configuration of platform identity, support channels (support email, multiple WhatsApp numbers), and brand hex colors without requiring code changes or redeployments. All user-facing views dynamically reflect these parameters while maintaining robust offline/fallback resilience.
2. **Notifications System (Manual & Automated)**: A comprehensive tenant notification system supporting Super Admin broadcast or targeted notifications, user-level read tracking, unread count badges, relative Arabic timestamping, and automatic system alerts triggered when a tenant's trial is within 2 days of expiration.

---

## 2. Architecture & Implementation Details

### Part 1: Dynamic Platform Settings

#### 1. Backend (`mikrotik_cards_backend`)
- **Prisma Schema (`prisma/schema.prisma`)**:
  - Added singleton model `PlatformSettings`:
    - `id` (String `@id @default(uuid())`)
    - `supportEmail` (String)
    - `whatsappNumbers` (String[])
    - `primaryColorHex` (String?)
    - `accentColorHex` (String?)
    - `appName` (String `@default("Jalsah")`)
    - `updatedAt` (DateTime `@updatedAt`)
  - Initial seed populated with platform defaults:
    - `supportEmail`: `jalsahnetwork@gmail.com`
    - `whatsappNumbers`: `["0115715672", "0115715651"]`
    - `appName`: `جلسة`
    - `primaryColorHex`: `#3B2FA0`
    - `accentColorHex`: `#F5C94B`
- **Application Layer Use Cases**:
  - `GetPublicSettingsUseCase` (`src/application/use-cases/settings/GetPublicSettingsUseCase.ts`): Publicly accessible without authentication, returns current platform identity and support parameters.
  - `UpdatePlatformSettingsUseCase` (`src/application/use-cases/settings/UpdatePlatformSettingsUseCase.ts`): Restricted strictly to `SUPER_ADMIN`. Validates email format, phone numbers, and color hex strings. Automatically persists an audit log record with previous and updated values.
- **HTTP Presentation Layer**:
  - `GET /api/v1/settings/public` (`src/presentation/http/routes/settings.routes.ts`)
  - `PATCH /api/v1/admin/settings` (`src/presentation/http/routes/admin.routes.ts`)

#### 2. Frontend (`mikrotik_cards_app`)
- **Centralized Configuration Singleton (`lib/services/app_settings.dart`)**:
  - Implements singleton pattern holding loaded settings with hardcoded safe defaults.
  - Initialized on launch in `main.dart` via `AppSettings.instance.loadSettings()`. Failures default seamlessly without blocking user experience.
- **Dynamic Views Updated**:
  - `lib/utils/whatsapp_helper.dart`: Dynamically pulls `AppSettings.instance.whatsappNumbers` and `AppSettings.instance.appName` for direct WhatsApp launch URLs.
  - `lib/screens/pending_approval_screen.dart`: Renders dynamic support email and company name.
  - `lib/screens/user_profile_screen.dart`: Renders dynamic support email and company name.
  - `lib/screens/admin/super_admin_dashboard.dart`:
    - Added dedicated tab: **"الإعدادات العامة"** (`_buildSettingsTab()`).
    - Provides interactive form to edit platform name, support email, and dynamically add or remove WhatsApp phone numbers with instant validation.
    - Saves changes through `ApiClient.updateAdminSettings()`.

---

### Part 2: Notifications System

#### 1. Backend (`mikrotik_cards_backend`)
- **Prisma Schema (`prisma/schema.prisma`)**:
  - Added enum `NotificationType` (`MANUAL`, `SYSTEM`).
  - Added model `Notification`:
    - `id` (UUID)
    - `tenantId` (String? `@db.Uuid`) — `null` represents broadcast to all tenants.
    - `title` (String)
    - `body` (String)
    - `type` (NotificationType)
    - `createdAt` (DateTime)
  - Added model `NotificationRead`:
    - `id` (UUID)
    - `notificationId` (UUID)
    - `userId` (UUID)
    - `readAt` (DateTime)
    - Unique constraint `@@unique([notificationId, userId])`.
- **Application Layer Use Cases**:
  - `SendNotificationUseCase` (`src/application/use-cases/notifications/SendNotificationUseCase.ts`): `SUPER_ADMIN` use case supporting broadcast (`tenantId: null`) or targeted tenant delivery. Records `NOTIFICATION_SENT` audit log.
  - `ListMyNotificationsUseCase` (`src/application/use-cases/notifications/ListMyNotificationsUseCase.ts`): Lists notifications belonging to the requester's tenant or broadcast, ordered newest first, mapping `isRead` per user and total `unreadCount`.
  - `MarkNotificationReadUseCase` (`src/application/use-cases/notifications/MarkNotificationReadUseCase.ts`): Records read status via upsert in `NotificationRead`.
  - `GenerateTrialEndingNotificationUseCase` (`src/application/use-cases/notifications/GenerateTrialEndingNotificationUseCase.ts`): Automatically creates system notification when trial expiration is within `<= 2 days`. Features 24-hour deduplication to prevent repeated alerts.
- **Security & Middleware Integration**:
  - Connected `GenerateTrialEndingNotificationUseCase` directly inside `SubscriptionGuard.ts` so active tenant interactions proactively trigger notification generation when nearing trial end.
- **HTTP Presentation Layer**:
  - `GET /api/v1/notifications`
  - `PATCH /api/v1/notifications/:id/read`
  - `POST /api/v1/admin/notifications` (Super Admin campaign route)

#### 2. Frontend (`mikrotik_cards_app`)
- **Notification Screen (`lib/screens/notifications_screen.dart`)**:
  - Clean Neumorphic card list with unread accent badges and blue indicator dots.
  - Supports marking individual notifications as read on tap and "تحديد الكل كمقروء".
  - Arabic relative time formatting (`منذ ٥ دقائق`, `منذ ساعتين`, `أمس`, etc.).
- **Dashboard Bell Integration (`lib/screens/dashboard_screen.dart`)**:
  - Bell icon in dashboard top bar reflects live unread notifications counter badge.
  - Tapping navigates to `NotificationsScreen` and reloads unread count on return.
- **Super Admin Broadcast Action (`lib/screens/admin/super_admin_dashboard.dart`)**:
  - Added notification action button (`Icons.campaign_rounded`) in top bar.
  - Displays modal bottom sheet allowing selection between all tenants (broadcast) or a specific tenant, inputting title and body, and sending via `ApiClient.sendAdminNotification()`.

---

## 3. Verification & Test Results

### 1. Backend Verification (`mikrotik_cards_backend`)
- Executed full test suite covering all unit and HTTP integration routes:
```
ℹ tests 239
ℹ suites 67
ℹ pass 239
ℹ fail 0
ℹ cancelled 0
ℹ skipped 0
ℹ todo 0
ℹ duration_ms 45265.608629
```

### 2. Frontend Verification (`mikrotik_cards_app`)
- Created dedicated test suite `test/dynamic_settings_notifications_test.dart` (9 comprehensive unit and widget tests).
- Executed full test suite across all screens:
```
All tests passed! (175 tests, 0 failures)
```

---

## 4. Modified & Created Files Summary

### Backend (`mikrotik_cards_backend`)
- `prisma/schema.prisma`
- `prisma/migrations/20261011150000_add_platform_settings_and_notifications/migration.sql`
- `src/infrastructure/database/seed.ts`
- `src/application/use-cases/settings/GetPublicSettingsUseCase.ts` (New)
- `src/application/use-cases/settings/UpdatePlatformSettingsUseCase.ts` (New)
- `src/application/use-cases/notifications/SendNotificationUseCase.ts` (New)
- `src/application/use-cases/notifications/ListMyNotificationsUseCase.ts` (New)
- `src/application/use-cases/notifications/MarkNotificationReadUseCase.ts` (New)
- `src/application/use-cases/notifications/GenerateTrialEndingNotificationUseCase.ts` (New)
- `src/infrastructure/security/SubscriptionGuard.ts`
- `src/presentation/http/routes/settings.routes.ts` (New)
- `src/presentation/http/routes/notification.routes.ts` (New)
- `src/presentation/http/routes/admin.routes.ts`
- `src/presentation/http/server.ts`
- `tests/presentation/SettingsAndNotificationsRoutes.test.ts` (New)

### Frontend (`mikrotik_cards_app`)
- `lib/models/platform_settings_model.dart` (New)
- `lib/models/notification_model.dart` (New)
- `lib/services/app_settings.dart` (New)
- `lib/services/api_client.dart`
- `lib/utils/whatsapp_helper.dart`
- `lib/main.dart`
- `lib/screens/notifications_screen.dart` (New)
- `lib/screens/dashboard_screen.dart`
- `lib/screens/pending_approval_screen.dart`
- `lib/screens/user_profile_screen.dart`
- `lib/screens/admin/super_admin_dashboard.dart`
- `test/dynamic_settings_notifications_test.dart` (New)
- `test/widget_test.dart`
- `reports/dynamic-settings-notifications-report.md` (New)
