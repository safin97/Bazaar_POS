import 'package:flutter/material.dart';

import '../core/branding.dart';
import '../core/strings.dart';
import '../widgets/common.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    final store = context.store;
    setState(() => _busy = true);
    try {
      await store.login(_username.text, _password.text);
    } catch (e) {
      if (mounted) notifyError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          welcomeBackgroundAsset,
          fit: BoxFit.cover,
          excludeFromSemantics: true,
        ),
        const ColoredBox(color: Color(0x33203A35)),
        SafeArea(
          child: Column(
            children: [
              const Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    child: LanguageMenu(),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Form(
                            key: _form,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Center(
                                  child: Image.asset(
                                    defaultLogoAsset,
                                    width: 96,
                                    height: 96,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  context.store.settings.name,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 28),
                                Text(
                                  context.tr('loginTitle'),
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium,
                                ),
                                const SizedBox(height: 28),
                                AutofillGroup(
                                  child: Column(
                                    children: [
                                      TextFormField(
                                        key: const ValueKey('login-username'),
                                        controller: _username,
                                        enabled: !_busy,
                                        autofillHints: const [
                                          AutofillHints.username,
                                        ],
                                        autocorrect: false,
                                        enableSuggestions: false,
                                        textInputAction: TextInputAction.next,
                                        decoration: InputDecoration(
                                          labelText: context.tr('username'),
                                          prefixIcon: const Icon(
                                            Icons.person_outline_rounded,
                                          ),
                                        ),
                                        validator: (value) =>
                                            value == null ||
                                                value.trim().isEmpty
                                            ? context.tr('required')
                                            : null,
                                      ),
                                      const SizedBox(height: 18),
                                      TextFormField(
                                        key: const ValueKey('login-password'),
                                        controller: _password,
                                        enabled: !_busy,
                                        obscureText: true,
                                        autofillHints: const [
                                          AutofillHints.password,
                                        ],
                                        autocorrect: false,
                                        enableSuggestions: false,
                                        textInputAction: TextInputAction.done,
                                        onFieldSubmitted: (_) => _submit(),
                                        decoration: InputDecoration(
                                          labelText: context.tr('password'),
                                          prefixIcon: const Icon(
                                            Icons.lock_outline_rounded,
                                          ),
                                        ),
                                        validator: (value) =>
                                            value == null || value.isEmpty
                                            ? context.tr('required')
                                            : null,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                FilledButton(
                                  key: const ValueKey('login-submit'),
                                  onPressed: _busy ? null : _submit,
                                  child: _busy
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(context.tr('signIn')),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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
