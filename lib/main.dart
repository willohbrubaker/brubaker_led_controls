import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'dart:ui';
import 'dart:async';
import 'package:brubaker_led_controls/star_field.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Brubaker LED Controls',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const BrubakerLedControlsScreen(),
    );
  }
}

class BrubakerLedControlsScreen extends StatefulWidget {
  const BrubakerLedControlsScreen({super.key});

  @override
  State<BrubakerLedControlsScreen> createState() =>
      _BrubakerLedControlsScreenState();
}

class _BrubakerLedControlsScreenState extends State<BrubakerLedControlsScreen>
    with SingleTickerProviderStateMixin {
  static const String localServer = 'http://192.168.1.198:5000';
  static const String publicServer = 'http://108.254.1.184:5000';
  String activeServer = localServer;

  String currentMode = 'off';
  bool isLoading = true;
  bool isUpdating = false;

  late AnimationController _glowController;
  late Animation<double> _glowAnim;

  final List<Map<String, String>> modes = [
    {'name': 'off', 'image': 'assets/modes/off.png'},
    {'name': 'rainbow-flow', 'image': 'assets/modes/rainbow-flow.png'},
    {'name': 'constant-red', 'image': 'assets/modes/constant-red.png'},
    {
      'name': 'proletariat-crackle',
      'image': 'assets/modes/proletariat-crackle.png',
    },
    {'name': 'soma-haze', 'image': 'assets/modes/soma-haze.png'},
    {'name': 'loonie-freefall', 'image': 'assets/modes/loonie-freefall.png'},
    {'name': 'bokanovsky-burst', 'image': 'assets/modes/bokanovsky-burst.png'},
    {
      'name': 'total-perspective-vortex',
      'image': 'assets/modes/total-perspective-vortex.png',
    },
    {
      'name': 'golgafrincham-drift',
      'image': 'assets/modes/golgafrincham-drift.png',
    },
    {
      'name': 'bistromathics-surge',
      'image': 'assets/modes/bistromathics-surge.png',
    },
    {
      'name': 'groks-dissolution',
      'image': 'assets/modes/groks-dissolution.png',
    },
    {'name': 'newspeak-shrink', 'image': 'assets/modes/newspeak-shrink.png'},
    {
      'name': 'nolite-te-bastardes',
      'image': 'assets/modes/nolite-te-bastardes.png',
    },
    {
      'name': 'infinite-improbability-drive',
      'image': 'assets/modes/infinite-improbability-drive.png',
    },
    {
      'name': 'big-brother-glare',
      'image': 'assets/modes/big-brother-glare.png',
    },
    {
      'name': 'replicant-retirement',
      'image': 'assets/modes/replicant-retirement.png',
    },
    {
      'name': 'water-brother-bond',
      'image': 'assets/modes/water-brother-bond.png',
    },
    {'name': 'hypnopaedia-hum', 'image': 'assets/modes/hypnopaedia-hum.png'},
    {
      'name': 'vogon-poetry-pulse',
      'image': 'assets/modes/vogon-poetry-pulse.png',
    },
    {
      'name': 'thought-police-flash',
      'image': 'assets/modes/thought-police-flash.png',
    },
    {
      'name': 'electric-sheep-dream',
      'image': 'assets/modes/electric-sheep-dream.png',
    },
    {'name': 'QRNG', 'image': 'assets/modes/qrng.png'},
    {'name': 'sd-client', 'image': 'assets/modes/sd-client.png'},
  ];

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _glowAnim = Tween<double>(begin: 0.6, end: 1.4).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOutCubic),
    );

    _checkAndFetchMode();
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _checkAndFetchMode() async {
    setState(() => isLoading = true);

    try {
      final response = await http
          .get(Uri.parse('$localServer/mode'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        activeServer = localServer;
      } else {
        activeServer = publicServer;
      }
    } catch (_) {
      activeServer = publicServer;
    }

    await _fetchCurrentMode();
  }

  Future<void> _fetchCurrentMode() async {
    try {
      final response = await http
          .get(Uri.parse('$activeServer/mode'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final mode = response.body.trim();
        if (modes.any((m) => m['name'] == mode)) {
          setState(() => currentMode = mode);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Connection issue: $e')));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _updateMode(String modeName) async {
    if (isUpdating || modeName == currentMode) return;

    setState(() => isUpdating = true);

    try {
      final response = await http
          .post(
            Uri.parse('$activeServer/update'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'mode': modeName}),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 && mounted) {
        setState(() => currentMode = modeName);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Activated: ${titleCase(modeName)}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
      }
    } finally {
      if (mounted) setState(() => isUpdating = false);
    }
  }

  String titleCase(String text) {
    return text
        .split('-')
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Brubaker LED Controls',
          style: GoogleFonts.orbitron(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            shadows: [
              Shadow(
                blurRadius: 12,
                color: theme.primaryColor.withOpacity(0.6),
              ),
            ],
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: StarField(opacity: 0.35)),
          SafeArea(
            child: Column(
              children: [
                // Current mode showcase
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: AnimatedBuilder(
                    animation: _glowAnim,
                    builder: (context, child) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: theme.primaryColor.withOpacity(
                              (0.5 * _glowAnim.value).clamp(0.0, 1.0),
                            ),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: theme.primaryColor.withOpacity(
                                (0.3 * _glowAnim.value).clamp(0.0, 1.0),
                              ),
                              blurRadius: 20 * _glowAnim.value,
                              spreadRadius: 4,
                            ),
                          ],
                          color: theme.colorScheme.surface.withOpacity(0.18),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                child: Image.asset(
                                  modes.firstWhere(
                                    (m) => m['name'] == currentMode,
                                  )['image']!,
                                  width: 90,
                                  height: 90,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.broken_image, size: 90),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                'Active: ${titleCase(currentMode)}',
                                style: GoogleFonts.orbitron(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.78,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                          itemCount: modes.length,
                          itemBuilder: (context, index) {
                            final mode = modes[index];
                            final isSelected = mode['name'] == currentMode;

                            return AnimatedBuilder(
                              animation: _glowAnim,
                              builder: (context, child) {
                                final glowIntensity =
                                    _glowAnim.value; // 0.6 to 1.4

                                return GestureDetector(
                                  onTap: isUpdating
                                      ? null
                                      : () => _updateMode(mode['name']!),
                                  child: Transform.scale(
                                    scale: isSelected
                                        ? 1.0 + (0.03 * (glowIntensity - 0.6))
                                        : 1.0, // very subtle breathing
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        color: theme.colorScheme.surface
                                            .withOpacity(0.16),
                                        // Pulsing outer glow when selected (multiple shadows for depth)
                                        boxShadow: isSelected
                                            ? [
                                                // Strong inner glow
                                                BoxShadow(
                                                  color: theme.primaryColor
                                                      .withOpacity(
                                                        0.45 * glowIntensity,
                                                      ),
                                                  blurRadius:
                                                      12 * glowIntensity,
                                                  spreadRadius: 2,
                                                ),
                                                // Medium outer glow layer
                                                BoxShadow(
                                                  color: theme.primaryColor
                                                      .withOpacity(
                                                        0.25 * glowIntensity,
                                                      ),
                                                  blurRadius:
                                                      24 * glowIntensity,
                                                  spreadRadius: 6,
                                                ),
                                                // Very soft distant glow
                                                BoxShadow(
                                                  color: theme.primaryColor
                                                      .withOpacity(
                                                        0.12 * glowIntensity,
                                                      ),
                                                  blurRadius:
                                                      40 * glowIntensity,
                                                  spreadRadius: 12,
                                                ),
                                              ]
                                            : null,
                                        border: Border.all(
                                          color: isSelected
                                              ? theme.primaryColor.withOpacity(
                                                  0.7 * glowIntensity,
                                                )
                                              : Colors.white.withOpacity(0.18),
                                          width: isSelected ? 2.2 : 1,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(20),
                                        child: BackdropFilter(
                                          filter: ImageFilter.blur(
                                            sigmaX: 10,
                                            sigmaY: 10,
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Expanded(
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                    12,
                                                  ),
                                                  child: Image.asset(
                                                    mode['image']!,
                                                    fit: BoxFit.contain,
                                                  ),
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 12,
                                                ),
                                                child: Text(
                                                  titleCase(mode['name']!),
                                                  textAlign: TextAlign.center,
                                                  style: GoogleFonts.orbitron(
                                                    fontSize: 14,
                                                    fontWeight: isSelected
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                    color: isSelected
                                                        ? null
                                                        : Colors.white70,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
