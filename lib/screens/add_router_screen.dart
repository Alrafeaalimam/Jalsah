// ============================================================================
// Platform: Commercial MikroTik Network & HotSpot Card Management System
// File: lib/screens/add_router_screen.dart
// Screen: Add Router Form with Diagnostic Test and Validation
// Master Reference: Rule 18 (API Only), Rule 23 (Error Handling), Rule 35 (State)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_client.dart';
import '../theme/app_colors.dart';
import '../widgets/neumorphic_text_field.dart';
import '../widgets/pressable_neumorphic_card.dart';

class AddRouterScreen extends StatefulWidget {
  const AddRouterScreen({super.key});

  @override
  State<AddRouterScreen> createState() => _AddRouterScreenState();
}

class _AddRouterScreenState extends State<AddRouterScreen> {
  final _nameController = TextEditingController();
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '8728');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _nameError;
  String? _hostError;
  String? _portError;
  String? _usernameError;
  String? _passwordError;

  bool _isTesting = false;
  bool _isSaving = false;
  String? _serverErrorMessage;
  String? _testSuccessMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
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
      if (username.isEmpty) {
        _usernameError = 'يرجى إدخال اسم المستخدم';
        isValid = false;
      }

      final password = _passwordController.text;
      if (password.isEmpty) {
        _passwordError = 'يرجى إدخال كلمة المرور';
        isValid = false;
      }
    });

    return isValid;
  }

  Future<void> _testConnection() async {
    if (_isTesting || _isSaving) return;

    final host = _hostController.text.trim();
    final portStr = _portController.text.trim();
    final portVal = int.tryParse(portStr);
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    // Check credentials required for test
    setState(() {
      _hostError = host.isEmpty ? 'يرجى إدخال عنوان الـ Host للاختبار' : null;
      _portError = (portVal == null || portVal < 1 || portVal > 65535)
          ? 'منفذ غير صالح (1-65535)'
          : null;
      _usernameError = username.isEmpty ? 'يرجى إدخال اسم المستخدم' : null;
      _passwordError = password.isEmpty ? 'يرجى إدخال كلمة المرور' : null;
      _serverErrorMessage = null;
      _testSuccessMessage = null;
    });

    if (host.isEmpty ||
        portVal == null ||
        portVal < 1 ||
        portVal > 65535 ||
        username.isEmpty ||
        password.isEmpty) {
      return;
    }

    setState(() {
      _isTesting = true;
    });

    final result = await ApiClient.testRouterConnection(
      host: host,
      port: portVal,
      username: username,
      password: password,
    );

    if (!mounted) return;

    setState(() {
      _isTesting = false;
    });

    if (result['success'] == true) {
      final data = result['data'] as Map<String, dynamic>?;
      final identity = data?['identity'] ?? 'راوتر';
      final version = data?['version'] ?? '';
      final board = data?['boardName'] ?? '';
      final details = [identity, board, version]
          .where((e) => (e as String).isNotEmpty)
          .join(' - ');

      setState(() {
        _testSuccessMessage = 'تم الاتصال بنجاح بنظام MikroTik ($details)';
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

    final result = await ApiClient.createRouter(
      name: _nameController.text.trim(),
      host: _hostController.text.trim(),
      port: int.parse(_portController.text.trim()),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    if (result['success'] == true) {
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
                'تم حفظ الراوتر وإضافته للنظام بنجاح',
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
      final err = result['errorMessage'] ?? 'حدث خطأ أثناء حفظ الراوتر';
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
                  Text(
                    'إضافة راوتر جديد',
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
            children: [
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

                    // API Port
                    NeumorphicTextField(
                      label: 'منفذ RouterOS API',
                      hintText: '8728 (الافتراضي)',
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
                      hintText: 'أدخل كلمة مرور الراوتر',
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
                            _isSaving ? 'جارٍ الحفظ...' : 'حفظ الراوتر',
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
