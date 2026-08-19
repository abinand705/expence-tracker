import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../services/auth_service.dart';

class SplashLoginScreen extends StatefulWidget {
  const SplashLoginScreen({super.key});

  @override
  State<SplashLoginScreen> createState() => _SplashLoginScreenState();
}

class _SplashLoginScreenState extends State<SplashLoginScreen> {
  final _authService = AuthService();
  
  bool _isLogin = true;
  bool _isLoading = false;
  
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.errorRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.successGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty || (!_isLogin && name.isEmpty)) {
      _showError('Please fill in all fields');
      return;
    }

    setState(() => _isLoading = true);
    
    // Capture the messenger before async operations so it can be used even if unmounted
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (_isLogin) {
        await _authService.login(email: email, password: password);
      } else {
        await _authService.register(
          email: email, 
          password: password, 
          displayName: name,
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError('Please enter your email to reset password');
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      await _authService.resetPassword(email);
      _showSuccess('Password reset email sent');
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildTextField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.labelCaps.copyWith(color: AppColors.onSurfaceVariant)),
        const SizedBox(height: AppSpacing.xs),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceBright,
            borderRadius: BorderRadius.circular(AppRadius.base),
            border: Border.all(color: AppColors.surfaceVariant),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Icon(icon, color: AppColors.outline),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: isPassword,
                  keyboardType: keyboardType,
                  decoration: InputDecoration(
                    hintText: 'Enter your $label'.toLowerCase(),
                    hintStyle: AppTypography.bodyLg.copyWith(color: AppColors.outlineVariant),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
                  ),
                  style: AppTypography.bodyLg,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x1A0D3B2E), // primaryContainer 10%
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -100,
            child: Container(
              width: 250,
              height: 250,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x3388F798), // secondaryContainer 20%
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.containerMargin),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: AppShadows.level1,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.account_balance_wallet, color: AppColors.onPrimary, size: 32),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('MoneyTrack', style: AppTypography.displayCurrency.copyWith(color: AppColors.primary)),
                    const SizedBox(height: AppSpacing.xs),
                    Text(_isLogin ? 'Welcome back' : 'Create an account', style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
                    const SizedBox(height: AppSpacing.xl),
                    
                    if (!_isLogin) ...[
                      _buildTextField(label: 'Name', icon: Icons.person, controller: _nameController),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    
                    _buildTextField(label: 'Email', icon: Icons.email, controller: _emailController, keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: AppSpacing.md),
                    
                    _buildTextField(label: 'Password', icon: Icons.lock, controller: _passwordController, isPassword: true),
                    
                    if (_isLogin)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _isLoading ? null : _resetPassword,
                          child: Text('Forgot Password?', style: AppTypography.labelCaps.copyWith(color: AppColors.primary)),
                        ),
                      )
                    else
                      const SizedBox(height: AppSpacing.xl),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryContainer,
                          foregroundColor: AppColors.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.base)),
                          elevation: 2,
                        ),
                        child: _isLoading 
                          ? const SizedBox(
                              width: 24, height: 24, 
                              child: CircularProgressIndicator(color: AppColors.onPrimary, strokeWidth: 2)
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(_isLogin ? 'Login' : 'Sign Up', style: AppTypography.headlineMd.copyWith(color: AppColors.onPrimary)),
                                const SizedBox(width: AppSpacing.sm),
                                const Icon(Icons.arrow_forward, size: 20),
                              ],
                            ),
                      ),
                    ),
                    
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        const Expanded(child: Divider(color: AppColors.surfaceVariant)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                          child: Text('OR', style: AppTypography.labelMuted.copyWith(color: AppColors.outline)),
                        ),
                        const Expanded(child: Divider(color: AppColors.surfaceVariant)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : () async {
                          setState(() => _isLoading = true);
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await _authService.signInWithGoogle();
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(e.toString()),
                                backgroundColor: AppColors.errorRed,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } finally {
                            if (mounted) setState(() => _isLoading = false);
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.surfaceBright,
                          side: const BorderSide(color: AppColors.surfaceVariant),
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.base)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('G', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 20)),
                            const SizedBox(width: AppSpacing.md),
                            Text('Continue with Google', style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface)),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_isLogin ? 'Don\'t have an account?' : 'Already have an account?', style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
                        const SizedBox(width: AppSpacing.xs),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _isLogin = !_isLogin;
                            });
                          },
                          child: Text(
                            _isLogin ? 'Sign up' : 'Login', 
                            style: AppTypography.headlineMd.copyWith(color: AppColors.primary, decoration: TextDecoration.underline)
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
