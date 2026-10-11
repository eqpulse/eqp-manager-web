import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pages/dashboard_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // A PKCE password-recovery link returns with ?code=... rather than
  // ?type=recovery. Read it BEFORE Supabase processes the callback.
  final link = Uri.base;
  final fragment = link.fragment;
  final fragmentQuery = fragment.contains('?')
      ? fragment.substring(fragment.indexOf('?') + 1)
      : fragment;
  final fragmentParams = Uri.splitQueryString(fragmentQuery);
  _initialAuthLinkType =
      link.queryParameters['type'] ?? fragmentParams['type'];
  _isPasswordCallback =
      _initialAuthLinkType == 'recovery' ||
      _initialAuthLinkType == 'invite' ||
      link.queryParameters.containsKey('code') ||
      fragmentParams.containsKey('access_token');

  await Supabase.initialize(
    url: 'https://kalfayszcbvvepwhzdar.supabase.co',
    publishableKey: 'sb_publishable_uG5ASdERlsfn-gLh4XxH8Q_MELAk7Az',
  );

  runApp(const EqManagerApp());
}

class EqManagerApp extends StatelessWidget {
  const EqManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EQP Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blueGrey,
      ),
      home: const AuthGate(),
    );
  }
}


// Supabase invitation/recovery links may contain the flow type in the URL
// fragment. Capture it before Supabase processes the redirect.
String? _initialAuthLinkType;
bool _isPasswordCallback = false;

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? _authSubscription;
  bool _setPasswordMode = false;

  @override
  void initState() {
    super.initState();
    // Auth events can fire during Supabase.initialize, before this widget
    // subscribes. Preserve the intent captured from the original callback.
    _setPasswordMode = _isPasswordCallback;

    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      if (data.event == AuthChangeEvent.passwordRecovery) {
        setState(() => _setPasswordMode = true);
      } else if (data.event == AuthChangeEvent.signedOut) {
        setState(() => _setPasswordMode = false);
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    if (_setPasswordMode && session == null) {
      return const Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'לא ניתן לאמת את קישור הגדרת הסיסמה. '
                'ייתכן שפג תוקפו או שנפתח בדפדפן אחר. '
                'חזור למסך ההתחברות ובקש קישור חדש.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }
    if (_setPasswordMode && session != null) {
      return SetPasswordPage(
        onFinished: () {
          if (mounted) setState(() => _setPasswordMode = false);
        },
      );
    }
    return session == null ? const LoginPage() : const DashboardPage();
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool loading = false;
  bool recoveryMode = false;
  String? errorMessage;
  String? successMessage;

  Future<void> signIn() async {
    if (loading) return;
    final email = emailController.text.trim();
    final password = passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => errorMessage = 'יש להזין אימייל וסיסמה');
      return;
    }
    setState(() {
      loading = true;
      errorMessage = null;
      successMessage = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      debugPrint('EQP sign in failed: ${e.message}');
      if (mounted) {
        setState(() => errorMessage =
            'לא ניתן להתחבר. בדוק את האימייל והסיסמה או אפס סיסמה.');
      }
    } catch (e) {
      debugPrint('EQP sign in error: $e');
      if (mounted) setState(() => errorMessage = 'שגיאה בהתחברות. נסה שוב.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> sendRecovery() async {
    if (loading) return;
    final email = emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => errorMessage = 'יש להזין כתובת אימייל תקינה');
      return;
    }
    setState(() {
      loading = true;
      errorMessage = null;
      successMessage = null;
    });
    try {
      // Keep the GitHub Pages subpath; do not redirect to the domain root.
      const redirectUrl = 'https://eqpulse.github.io/eqp-manager-web/';
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: redirectUrl,
      );
      if (mounted) {
        setState(() => successMessage =
            'אם הכתובת רשומה במערכת, נשלח אליה קישור להגדרת סיסמה. בדוק גם בספאם.');
      }
    } on AuthException catch (e) {
      debugPrint('EQP recovery error: ${e.message}');
      if (mounted) {
        setState(() => errorMessage =
            'לא ניתן לשלוח קישור כרגע. בדוק את הגדרות ההפניה ב-Supabase.');
      }
    } catch (e) {
      debugPrint('EQP recovery error: $e');
      if (mounted) setState(() => errorMessage = 'שגיאה בשליחת הקישור.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F4FA),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('EQP',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 32, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        recoveryMode ? 'איפוס סיסמה' : 'כניסה למערכת הניהול',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 28),
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        textDirection: TextDirection.ltr,
                        decoration: const InputDecoration(
                          labelText: 'אימייל',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) =>
                            recoveryMode ? sendRecovery() : signIn(),
                      ),
                      if (!recoveryMode) ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: passwordController,
                          obscureText: true,
                          textDirection: TextDirection.ltr,
                          decoration: const InputDecoration(
                            labelText: 'סיסמה',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => signIn(),
                        ),
                      ],
                      if (errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red)),
                      ],
                      if (successMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(successMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.green)),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: loading
                            ? null
                            : (recoveryMode ? sendRecovery : signIn),
                        child: loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : Text(recoveryMode ? 'שלח קישור לאיפוס' : 'כניסה'),
                      ),
                      TextButton(
                        onPressed: loading
                            ? null
                            : () => setState(() {
                                  recoveryMode = !recoveryMode;
                                  errorMessage = null;
                                  successMessage = null;
                                }),
                        child: Text(recoveryMode
                            ? 'חזרה להתחברות'
                            : 'שכחתי סיסמה / הגדרת סיסמה ראשונית'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SetPasswordPage extends StatefulWidget {
  final VoidCallback onFinished;
  const SetPasswordPage({super.key, required this.onFinished});

  @override
  State<SetPasswordPage> createState() => _SetPasswordPageState();
}

class _SetPasswordPageState extends State<SetPasswordPage> {
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  bool loading = false;
  String? errorMessage;

  Future<void> savePassword() async {
    if (loading) return;
    final password = passwordController.text;
    if (password.length < 12) {
      setState(() => errorMessage = 'יש לבחור סיסמה בת 12 תווים לפחות');
      return;
    }
    if (password != confirmController.text) {
      setState(() => errorMessage = 'הסיסמאות אינן תואמות');
      return;
    }
    setState(() {
      loading = true;
      errorMessage = null;
    });
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: password),
      );
      // Require a fresh sign-in after setting the initial/recovery password.
      await Supabase.instance.client.auth.signOut();
      _isPasswordCallback = false;
      if (mounted) widget.onFinished();
    } on AuthException catch (e) {
      debugPrint('EQP password update failed: ${e.message}');
      if (mounted) {
        setState(() => errorMessage =
            'לא ניתן לעדכן סיסמה. ייתכן שהקישור פג תוקף. בקש קישור חדש.');
      }
    } catch (e) {
      debugPrint('EQP password update error: $e');
      if (mounted) setState(() => errorMessage = 'שגיאה בעדכון הסיסמה.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F4FA),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('EQP – הגדרת סיסמה',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 23, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        textDirection: TextDirection.ltr,
                        decoration: const InputDecoration(
                          labelText: 'סיסמה חדשה (לפחות 12 תווים)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: confirmController,
                        obscureText: true,
                        textDirection: TextDirection.ltr,
                        decoration: const InputDecoration(
                          labelText: 'אימות סיסמה',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => savePassword(),
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(errorMessage!,
                            style: const TextStyle(color: Colors.red)),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: loading ? null : savePassword,
                        child: loading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Text('שמור סיסמה'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
