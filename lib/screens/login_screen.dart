
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'signup_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final SupabaseClient supabase =
      Supabase.instance.client;

  bool isPasswordVisible = false;
  bool isLoading = false;

  final TextEditingController emailController =
      TextEditingController();

  final TextEditingController passwordController =
      TextEditingController();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOGIN
  // ============================================================

  Future<void> login() async {
    final input =
        emailController.text.trim();

    final password =
        passwordController.text.trim();

    // ----------------------------------------------------------
    // VALIDATION
    // ----------------------------------------------------------

    if (input.isEmpty) {
      showMessage(
        'Please enter your email or phone number',
      );
      return;
    }

    if (password.isEmpty) {
      showMessage(
        'Please enter your password',
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      AuthResponse response;

      // ========================================================
      // EMAIL LOGIN
      // ========================================================

      if (input.contains('@')) {
        response =
            await supabase.auth.signInWithPassword(
          email: input,
          password: password,
        );
      }

      // ========================================================
      // PHONE LOGIN
      // ========================================================

      else {
        String phoneNumber =
            input.replaceAll(
          ' ',
          '',
        );

        // ------------------------------------------------------
        // Indian number
        // 9876543210
        // becomes
        // +919876543210
        // ------------------------------------------------------

        if (RegExp(r'^[6-9]\d{9}$')
            .hasMatch(phoneNumber)) {
          phoneNumber =
              '+91$phoneNumber';
        }

        // ------------------------------------------------------
        // Number entered as 919876543210
        // ------------------------------------------------------

        else if (RegExp(r'^91[6-9]\d{9}$')
            .hasMatch(phoneNumber)) {
          phoneNumber =
              '+$phoneNumber';
        }

        // ------------------------------------------------------
        // Already +91...
        // ------------------------------------------------------

        else if (RegExp(
          r'^\+91[6-9]\d{9}$',
        ).hasMatch(phoneNumber)) {
          // Already correct.
        }

        // ------------------------------------------------------
        // Invalid phone
        // ------------------------------------------------------

        else {
          showMessage(
            'Enter a valid 10-digit Indian phone number',
          );

          setState(() {
            isLoading = false;
          });

          return;
        }

        // ------------------------------------------------------
        // SUPABASE PHONE LOGIN
        // ------------------------------------------------------

        response =
            await supabase.auth.signInWithPassword(
          phone: phoneNumber,
          password: password,
        );
      }

      // ========================================================
      // LOGIN SUCCESS
      // ========================================================

      if (!mounted) return;

      if (response.user != null &&
          response.session != null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) =>
                const HomeScreen(),
          ),
          (route) => false,
        );
      } else {
        showMessage(
          'Login was not completed. Please try again.',
        );
      }
    }

    // ==========================================================
    // SUPABASE AUTH ERROR
    // ==========================================================

    on AuthException catch (error) {
      showMessage(
        error.message,
      );
    }

    // ==========================================================
    // OTHER ERROR
    // ==========================================================

    catch (error) {
      showMessage(
        'Something went wrong: $error',
      );
    }

    // ==========================================================
    // STOP LOADING
    // ==========================================================

    finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void showMessage(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 25,
            vertical: 30,
          ),

          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              const SizedBox(height: 40),

              // =================================================
              // LOGO
              // =================================================

              Center(
                child: Container(
                  height: 100,
                  width: 100,

                  decoration:
                      BoxDecoration(
                    color:
                        Colors.blue.shade50,
                    shape:
                        BoxShape.circle,
                  ),

                  child: const Icon(
                    Icons.lock_outline,
                    size: 50,
                    color: Colors.blue,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // =================================================
              // TITLE
              // =================================================

              const Text(
                'Welcome Back!',

                style: TextStyle(
                  fontSize: 30,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                'Sign in using your email or phone number',

                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 35),

              // =================================================
              // EMAIL / PHONE
              // =================================================

              const Text(
                'Email or Phone Number',

                style: TextStyle(
                  fontSize: 16,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),

              const SizedBox(height: 8),

              TextField(
                controller:
                    emailController,

                keyboardType:
                    TextInputType.emailAddress,

                decoration:
                    InputDecoration(
                  hintText:
                      'Email or Phone ',

                  prefixIcon:
                      const Icon(
                    Icons.person_outline,
                  ),

                  border:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // =================================================
              // PASSWORD
              // =================================================

              const Text(
                'Password',

                style: TextStyle(
                  fontSize: 16,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),

              const SizedBox(height: 8),

              TextField(
                controller:
                    passwordController,

                obscureText:
                    !isPasswordVisible,

                decoration:
                    InputDecoration(
                  hintText:
                      'Enter your password',

                  prefixIcon:
                      const Icon(
                    Icons.lock_outline,
                  ),

                  suffixIcon:
                      IconButton(
                    icon: Icon(
                      isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),

                    onPressed: () {
                      setState(() {
                        isPasswordVisible =
                            !isPasswordVisible;
                      });
                    },
                  ),

                  border:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // =================================================
              // FORGOT PASSWORD
              // =================================================

              Align(
                alignment:
                    Alignment.centerRight,

                child: TextButton(
                  onPressed: () {
                    showMessage(
                      'Forgot password will be added next.',
                    );
                  },

                  child:
                      const Text(
                    'Forgot Password?',
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // =================================================
              // LOGIN BUTTON
              // =================================================

              SizedBox(
                width:
                    double.infinity,

                height: 55,

                child:
                    ElevatedButton(
                  onPressed:
                      isLoading
                          ? null
                          : login,

                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        Colors.blue,

                    foregroundColor:
                        Colors.white,

                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                    ),
                  ),

                  child: isLoading
                      ? const SizedBox(
                          height: 25,
                          width: 25,

                          child:
                              CircularProgressIndicator(
                            color:
                                Colors.white,
                            strokeWidth:
                                2,
                          ),
                        )
                      : const Text(
                          'Login',

                          style:
                              TextStyle(
                            fontSize: 18,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 25),

              // =================================================
              // SIGN UP
              // =================================================

              Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,

                children: [
                  const Text(
                    "Don't have an account?",
                  ),

                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,

                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  const SignupScreen(),
                        ),
                      );
                    },

                    child:
                        const Text(
                      'Sign Up',

                      style:
                          TextStyle(
                        fontWeight:
                            FontWeight.bold,
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