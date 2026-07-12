import 'package:flutter/material.dart';

import '../features/delivery_lists/data/local_delivery_repository.dart';
import '../features/delivery_lists/presentation/home_screen.dart';

Widget buildApp() => const EstafetaMobileApp();

class EstafetaMobileApp extends StatelessWidget {
  const EstafetaMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Estafeta',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: const Color(0xff25f4d0),
              brightness: Brightness.dark,
            ).copyWith(
              primary: const Color(0xff25f4d0),
              secondary: const Color(0xffffb15c),
              tertiary: const Color(0xff36b8ff),
              surface: const Color(0xff0b1621),
              error: const Color(0xffff6b7a),
            ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xff06111d),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: const Color(0xff101d2a),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xff142433),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: _AnimatedSplash(
        child: HomeScreen(repository: LocalDeliveryRepository()),
      ),
    );
  }
}

class _AnimatedSplash extends StatefulWidget {
  const _AnimatedSplash({required this.child});

  final Widget child;

  @override
  State<_AnimatedSplash> createState() => _AnimatedSplashState();
}

class _AnimatedSplashState extends State<_AnimatedSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..forward();
    Future<void>.delayed(const Duration(milliseconds: 1300), () {
      if (mounted) setState(() => _done = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return widget.child;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/branding/splash.png', fit: BoxFit.cover),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  const Color(0xff25f4d0).withValues(alpha: .20),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: _controller,
                curve: Curves.easeOut,
              ),
              child: Text(
                'Estafeta',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  shadows: const [
                    Shadow(
                      color: Color(0xaa25f4d0),
                      blurRadius: 22,
                      offset: Offset(0, 4),
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
