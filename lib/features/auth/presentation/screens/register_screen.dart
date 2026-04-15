import 'package:flutter/material.dart';

import '../../data/auth_storage.dart';
import '../../data/user_api.dart';
import '../../../staff/presentation/screens/staff_establishments_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final UserApi _userApi = UserApi();

  bool _loading = false;
  bool _showPassword = false;
  bool _showPasswordConfirm = false;
  String? _error;

  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _fullNameController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(
    String label, {
    String? hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE5E8F2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: Color(0xFF7D63FF),
          width: 1.4,
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final phone = _phoneController.text.trim();
    final fullName = _fullNameController.text.trim();
    final password = _passwordController.text;
    final passwordConfirm = _passwordConfirmController.text;

    if (phone.isEmpty) {
      setState(() => _error = 'Введите номер телефона');
      return;
    }

    if (password.length < 6) {
      setState(() => _error = 'Пароль должен быть не короче 6 символов');
      return;
    }

    if (password != passwordConfirm) {
      setState(() => _error = 'Пароли не совпадают');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await _userApi.register(
      phone: phone,
      password: password,
      passwordConfirm: passwordConfirm,
      fullName: fullName,
      deviceId: 'staff-web',
      platform: 'web',
    );

    if (!mounted) return;

    if (!result.ok) {
      setState(() {
        _loading = false;
        _error = result.message;
      });
      return;
    }

    await AuthStorage.saveAccessToken(result.accessToken);
    await AuthStorage.saveRefreshToken(result.refreshToken);

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const StaffEstablishmentsScreen()),
      (route) => false,
    );
  }

  Widget _card() {
    return Container(
      width: 460,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.90),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.95)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 22,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/flowru_logo.png',
            width: 56,
            height: 56,
          ),
          const SizedBox(height: 18),
          const Text(
            'Регистрация сотрудника',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Color(0xFF20243A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Введите телефон, который уже добавлен владельцем в админке, и придумайте пароль',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.45,
              fontWeight: FontWeight.w700,
              color: Color(0xFF7A829A),
            ),
          ),
          const SizedBox(height: 22),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: _inputDecoration('Телефон', hint: '+79781234567'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _fullNameController,
            decoration: _inputDecoration('Имя', hint: 'Иван'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _passwordController,
            obscureText: !_showPassword,
            decoration: _inputDecoration(
              'Пароль',
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() => _showPassword = !_showPassword);
                },
                icon: Icon(
                  _showPassword ? Icons.visibility_off : Icons.visibility,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _passwordConfirmController,
            obscureText: !_showPasswordConfirm,
            decoration: _inputDecoration(
              'Повторите пароль',
              suffixIcon: IconButton(
                onPressed: () {
                  setState(
                    () => _showPasswordConfirm = !_showPasswordConfirm,
                  );
                },
                icon: Icon(
                  _showPasswordConfirm
                      ? Icons.visibility_off
                      : Icons.visibility,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFE74C5E),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [Color(0xFF6E8BFF), Color(0xFFE77AC6)],
              ),
            ),
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Зарегистрироваться',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Регистрация'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF20243A),
      ),
      body: Stack(
        children: [
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(150),
                color: const Color(0xFFE77AC6).withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            left: -40,
            top: 180,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(140),
                color: const Color(0xFF6E8BFF).withOpacity(0.08),
              ),
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _card(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}