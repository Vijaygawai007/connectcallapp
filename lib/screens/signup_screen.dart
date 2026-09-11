
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  bool isPasswordVisible = false;
  bool isLoading = false;

  // false = Email
  // true = Phone
  bool isPhoneSignup = false;

  final TextEditingController emailController =
      TextEditingController();

  final TextEditingController phoneController =
      TextEditingController();

  final TextEditingController passwordController =
      TextEditingController();

  final TextEditingController confirmPasswordController =
      TextEditingController();

  @override
  void dispose() {
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  // =========================
  // FORMAT PHONE NUMBER
  // =========================

  String formatPhoneNumber(String phone) {
    phone = phone.replaceAll(RegExp(r'\s+'), '');

    // 10 digit Indian number
    if (phone.length == 10 && RegExp(r'^[0-9]+$').hasMatch(phone)) {
      return '+91$phone';
    }

    // 91XXXXXXXXXX
    if (phone.length == 12 &&
        phone.startsWith('91') &&
        RegExp(r'^[0-9]+$').hasMatch(phone)) {
      return '+$phone';
    }

    // Already +91XXXXXXXXXX
    if (phone.startsWith('+91') && phone.length == 13) {
      return phone;
    }

    return '';
  }

  // =========================
  // SIGN UP FUNCTION
  // =========================

  Future<void> signup() async {
    final email = emailController.text.trim();
    final phone = phoneController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    // =========================
    // BASIC VALIDATION
    // =========================

    if (password.isEmpty || confirmPassword.isEmpty) {
      showMessage('Please fill all fields');
      return;
    }

    if (password != confirmPassword) {
      showMessage('Passwords do not match');
      return;
    }

    if (password.length < 6) {
      showMessage('Password must be at least 6 characters');
      return;
    }

    // =========================
    // EMAIL SIGNUP
    // =========================

    if (!isPhoneSignup) {
      if (email.isEmpty) {
        showMessage('Please enter your email');
        return;
      }

      if (!email.contains('@') || !email.contains('.')) {
        showMessage('Please enter a valid email address');
        return;
      }
    }

    // =========================
    // PHONE SIGNUP
    // =========================

    String formattedPhone = '';

    if (isPhoneSignup) {
      if (phone.isEmpty) {
        showMessage('Please enter your phone number');
        return;
      }

      formattedPhone = formatPhoneNumber(phone);

      if (formattedPhone.isEmpty) {
        showMessage(
          'Please enter a valid 10-digit Indian phone number',
        );
        return;
      }
    }

    setState(() {
      isLoading = true;
    });

    try {
      AuthResponse response;

      // =========================
      // CREATE EMAIL ACCOUNT
      // =========================

      if (!isPhoneSignup) {
        response = await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
        );
      }

      // =========================
      // CREATE PHONE ACCOUNT
      // =========================

      else {
        response = await Supabase.instance.client.auth.signUp(
          phone: formattedPhone,
          password: password,
        );
      }

      if (!mounted) return;

      // =========================
      // SUCCESS
      // =========================

      if (response.user != null) {
        if (isPhoneSignup && response.session == null) {
          showMessage(
            'Account created. Please verify your phone number.',
          );
        } else {
          showMessage(
            'Account created successfully',
          );
        }

        Navigator.pop(context);
      }
    } on AuthException catch (error) {
      showMessage(error.message);
    } catch (error) {
      showMessage(
        'Something went wrong. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // =========================
  // SHOW MESSAGE
  // =========================

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // =========================
  // BUILD UI
  // =========================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text('Create Account'),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 25,
            vertical: 20,
          ),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              const SizedBox(height: 20),

              // =========================
              // LOGO
              // =========================

              Center(
                child: Container(
                  height: 90,
                  width: 90,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_add_outlined,
                    size: 45,
                    color: Colors.blue,
                  ),
                ),
              ),

              const SizedBox(height: 30),

              const Text(
                'Create Account',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                'Create an account to get started',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 30),

              // =========================
              // EMAIL / PHONE SWITCH
              // =========================

              Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [

                    // EMAIL BUTTON
                    Expanded(
                      child: GestureDetector(
                        onTap: isLoading
                            ? null
                            : () {
                                setState(() {
                                  isPhoneSignup = false;
                                });
                              },
                        child: Container(
                          decoration: BoxDecoration(
                            color: !isPhoneSignup
                                ? Colors.blue
                                : Colors.transparent,
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              'Email',
                              style: TextStyle(
                                color: !isPhoneSignup
                                    ? Colors.white
                                    : Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // PHONE BUTTON
                    Expanded(
                      child: GestureDetector(
                        onTap: isLoading
                            ? null
                            : () {
                                setState(() {
                                  isPhoneSignup = true;
                                });
                              },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isPhoneSignup
                                ? Colors.blue
                                : Colors.transparent,
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              'Phone',
                              style: TextStyle(
                                color: isPhoneSignup
                                    ? Colors.white
                                    : Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // =========================
              // EMAIL FIELD
              // =========================

              if (!isPhoneSignup) ...[
                const Text(
                  'Email Address',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 8),

                TextField(
                  controller: emailController,
                  keyboardType:
                      TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'Enter your email',
                    prefixIcon: const Icon(
                      Icons.email_outlined,
                    ),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],

              // =========================
              // PHONE FIELD
              // =========================

              if (isPhoneSignup) ...[
                const Text(
                  'Phone Number',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 8),

                TextField(
                  controller: phoneController,
                  keyboardType:
                      TextInputType.phone,
                  maxLength: 13,
                  decoration: InputDecoration(
                    hintText: 'Enter 10-digit phone number',
                    prefixIcon: const Icon(
                      Icons.phone_outlined,
                    ),
                    prefixText: '+91 ',
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // =========================
              // PASSWORD
              // =========================

              const Text(
                'Password',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 8),

              TextField(
                controller: passwordController,
                obscureText: !isPasswordVisible,
                decoration: InputDecoration(
                  hintText: 'Enter your password',

                  prefixIcon: const Icon(
                    Icons.lock_outline,
                  ),

                  suffixIcon: IconButton(
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

                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // =========================
              // CONFIRM PASSWORD
              // =========================

              const Text(
                'Confirm Password',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 8),

              TextField(
                controller:
                    confirmPasswordController,
                obscureText: !isPasswordVisible,
                decoration: InputDecoration(
                  hintText: 'Confirm your password',

                  prefixIcon: const Icon(
                    Icons.lock_outline,
                  ),

                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // =========================
              // CREATE ACCOUNT BUTTON
              // =========================

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed:
                      isLoading ? null : signup,

                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,

                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                  ),

                  child: isLoading
                      ? const SizedBox(
                          height: 25,
                          width: 25,
                          child:
                              CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),

              // =========================
              // LOGIN
              // =========================

              Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [

                  const Text(
                    'Already have an account?',
                  ),

                  TextButton(
                    onPressed: isLoading
                        ? null
                        : () {
                            Navigator.pop(context);
                          },
                    child: const Text(
                      'Login',
                      style: TextStyle(
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