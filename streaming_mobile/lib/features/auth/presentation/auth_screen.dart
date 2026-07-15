import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:streaming_mobile/core/core.dart';
import 'package:streaming_mobile/features/auth/domain/domain.dart';

/// Halaman login dan registrasi terpadu dengan desain gelap bioskop premium.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSignUpMode = false;

  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final username = _isSignUpMode ? _usernameController.text.trim() : email.split('@')[0];

    // Lakukan login mock / update Riverpod state
    if (_isSignUpMode) {
      ref.read(authProvider.notifier).signUp(username, email);
    } else {
      ref.read(authProvider.notifier).login(username, email);
    }

    // Tampilkan snackbar sukses
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isSignUpMode ? 'Successfully signed up as $username!' : 'Welcome back, $username!'),
        backgroundColor: Colors.green.shade800,
      ),
    );

    // Kembali ke beranda
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  void _handleGoogleSignIn() {
    // Simulasi Google Sign In dengan data profil default
    ref.read(authProvider.notifier).login('havilz lating', 'havilzlating05@gmail.com');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Successfully logged in with Google Account!'),
        backgroundColor: Colors.green.shade800,
      ),
    );

    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Ambient Glow Background
          Positioned(
            top: -120,
            left: -50,
            right: -50,
            child: Container(
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // AppBar Kustom dengan tombol kembali
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: AppColors.textPrimary,
                            size: 24,
                          ),
                          onPressed: () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go('/');
                            }
                          },
                        ),
                        Text(
                          _isSignUpMode ? 'CREATE ACCOUNT' : 'WELCOME BACK',
                          style: AppTypography.title.copyWith(
                            letterSpacing: 2.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 48), // Spacer simetri
                      ],
                    ),
                  ),
                ),

                // Form & Content Section
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Spacer(flex: 1),

                          // Brand Logo Placeholder
                          Center(
                            child: Text(
                              'SV',
                              style: AppTypography.logo.copyWith(
                                color: AppColors.primary,
                                fontSize: 64,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                                shadows: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.5),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),

                          // Username Field (Hanya saat Sign Up)
                          if (_isSignUpMode) ...[
                            TextFormField(
                              controller: _usernameController,
                              style: const TextStyle(color: AppColors.textPrimary),
                              decoration: _buildInputDecoration(
                                labelText: 'Username',
                                prefixIcon: Icons.person_outline,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter username';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],

                          // Email / Phone Number Field
                          TextFormField(
                            controller: _emailController,
                            style: const TextStyle(color: AppColors.textPrimary),
                            keyboardType: TextInputType.emailAddress,
                            decoration: _buildInputDecoration(
                              labelText: 'Email or Phone Number',
                              prefixIcon: Icons.email_outlined,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter email or phone number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // Password Field
                          TextFormField(
                            controller: _passwordController,
                            style: const TextStyle(color: AppColors.textPrimary),
                            obscureText: true,
                            decoration: _buildInputDecoration(
                              labelText: 'Password',
                              prefixIcon: Icons.lock_outline,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter password';
                              }
                              if (value.length < 6) {
                                    return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.xl),

                          // Submit Button (SIGN IN / SIGN UP)
                          ElevatedButton(
                            onPressed: _submitForm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.textPrimary,
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              elevation: 5,
                              shadowColor: AppColors.primary.withOpacity(0.4),
                            ),
                            child: Text(
                              _isSignUpMode ? 'SIGN UP' : 'SIGN IN',
                              style: AppTypography.body.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // Google Sign-In Button
                          OutlinedButton.icon(
                            onPressed: _handleGoogleSignIn,
                            icon: Image.network(
                              'https://img.icons8.com/color/48/000000/google-logo.png',
                              height: 20,
                            ),
                            label: const Text(
                              'Continue with Google',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                              side: BorderSide(
                                color: AppColors.primary.withOpacity(0.4),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),

                          // Toggle Mode Teks Button (Flat text style)
                          Center(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isSignUpMode = !_isSignUpMode;
                                });
                              },
                              child: Text(
                                _isSignUpMode
                                    ? 'Already have an account? Sign In'
                                    : "Don't have an account? Sign Up",
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),

                          const Spacer(flex: 2),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String labelText,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(color: AppColors.textMuted),
      prefixIcon: Icon(prefixIcon, color: AppColors.primary, size: 20),
      filled: true,
      fillColor: AppColors.surface.withOpacity(0.5),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.borderSubtle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.md,
      ),
    );
  }
}
