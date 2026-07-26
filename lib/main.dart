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
  // ────────────────────────────────────────────────
  // CHANGE THIS TO YOUR PUBLIC DNS
  // ────────────────────────────────────────────────
  static const String serverUrl =
      'https://pebbles.immenseaccumulationonline.online/';

  // Fish light server (fish_light_server.py) — plain-text query API
  // Live: https://lovelywill.immenseaccumulationonline.online/
  static const String fishtankBaseUrl =
      'https://lovelywill.immenseaccumulationonline.online';

  String currentMode = 'off';
  bool isLoading = true;
  bool isUpdating = false;

  // ── Fishtank state (mirrors server) ──
  int fishBrightness = 0;
  bool fishWillezMode = true;
  bool fishPartyMode = false;
  int fishOverrideSeconds = 0;
  TimeOfDay fishOnTime = const TimeOfDay(hour: 6, minute: 15);
  TimeOfDay fishOffTime = const TimeOfDay(hour: 21, minute: 30);
  bool isFishtankLoading = false;
  bool fishConnected = false;
  bool fishPanelExpanded = true;
  double _sliderBrightness = 0; // local slider while dragging
  bool _sliderDragging = false;
  Timer? _fishPollTimer;
  Timer? _overrideTickTimer;

  late AnimationController _glowController;
  late Animation<double> _glowAnim;

  final List<Map<String, String>> modes = [
    {'name': 'off', 'image': 'assets/modes/off.png'},
    {'name': 'rainbow-flow', 'image': 'assets/modes/rainbow-flow.png'},
    {'name': 'constant-red', 'image': 'assets/modes/constant-red.png'},
    {
      'name': 'proletariat-crackle',
      'image': 'assets/modes/proletariat-crackle.png'
    },
    {'name': 'soma-haze', 'image': 'assets/modes/soma-haze.png'},
    {'name': 'loonie-freefall', 'image': 'assets/modes/loonie-freefall.png'},
    {'name': 'bokanovsky-burst', 'image': 'assets/modes/bokanovsky-burst.png'},
    {
      'name': 'total-perspective-vortex',
      'image': 'assets/modes/total-perspective-vortex.png'
    },
    {
      'name': 'golgafrincham-drift',
      'image': 'assets/modes/golgafrincham-drift.png'
    },
    {
      'name': 'bistromathics-surge',
      'image': 'assets/modes/bistromathics-surge.png'
    },
    {
      'name': 'groks-dissolution',
      'image': 'assets/modes/groks-dissolution.png'
    },
    {'name': 'newspeak-shrink', 'image': 'assets/modes/newspeak-shrink.png'},
    {
      'name': 'nolite-te-bastardes',
      'image': 'assets/modes/nolite-te-bastardes.png'
    },
    {
      'name': 'infinite-improbability-drive',
      'image': 'assets/modes/infinite-improbability-drive.png'
    },
    {
      'name': 'big-brother-glare',
      'image': 'assets/modes/big-brother-glare.png'
    },
    {
      'name': 'replicant-retirement',
      'image': 'assets/modes/replicant-retirement.png'
    },
    {
      'name': 'water-brother-bond',
      'image': 'assets/modes/water-brother-bond.png'
    },
    {'name': 'hypnopaedia-hum', 'image': 'assets/modes/hypnopaedia-hum.png'},
    {
      'name': 'vogon-poetry-pulse',
      'image': 'assets/modes/vogon-poetry-pulse.png'
    },
    {
      'name': 'thought-police-flash',
      'image': 'assets/modes/thought-police-flash.png'
    },
    {'name': 'random-conquest', 'image': 'assets/modes/battle-blocks.png'},
    {
      'name': 'red-green-conquest',
      'image': 'assets/modes/red-green-conquest.png'
    },
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

    _fetchCurrentMode();
    _fetchFishState();
    _fishPollTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _fetchFishState(silent: true),
    );
    // Smooth countdown for override badge between polls
    _overrideTickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || fishOverrideSeconds <= 0) return;
      setState(() => fishOverrideSeconds = (fishOverrideSeconds - 1).clamp(0, 1 << 30));
    });
  }

  @override
  void dispose() {
    _glowController.dispose();
    _fishPollTimer?.cancel();
    _overrideTickTimer?.cancel();
    super.dispose();
  }

  // ────────────────────────────────────────────────
  // Room LED modes
  // ────────────────────────────────────────────────
  Future<void> _fetchCurrentMode() async {
    setState(() => isLoading = true);

    try {
      final response = await http
          .get(Uri.parse('$serverUrl/mode'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final mode = response.body.trim();
        if (modes.any((m) => m['name'] == mode)) {
          setState(() => currentMode = mode);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not connect to LED server')),
        );
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
            Uri.parse('$serverUrl/update'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'mode': modeName}),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200 && mounted) {
        setState(() => currentMode = modeName);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Activated: ${titleCase(modeName)}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update mode')),
        );
      }
    } finally {
      if (mounted) setState(() => isUpdating = false);
    }
  }

  // ────────────────────────────────────────────────
  // Fish light API (matches fish_light_server.py)
  // ────────────────────────────────────────────────
  Uri _fishUri(String path, [Map<String, String>? query]) {
    return Uri.parse('$fishtankBaseUrl$path').replace(queryParameters: query);
  }

  Future<String?> _fishGet(String path, {Map<String, String>? query}) async {
    final response = await http
        .get(_fishUri(path, query))
        .timeout(const Duration(seconds: 8));
    if (response.statusCode == 200) return response.body.trim();
    throw Exception('HTTP ${response.statusCode} on $path');
  }

  TimeOfDay? _parseHhMm(String raw) {
    final parts = raw.trim().split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    if (h < 0 || h > 23 || m < 0 || m > 59) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _fmtHhMm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _fmtOverride(int secs) {
    if (secs <= 0) return '';
    final m = secs ~/ 60;
    final s = secs % 60;
    if (m > 0) return '${m}m ${s.toString().padLeft(2, '0')}s';
    return '${s}s';
  }

  /// Best-effort GET; returns null on any failure (missing route, network, etc.).
  Future<String?> _fishGetOptional(String path) async {
    try {
      return await _fishGet(path);
    } catch (_) {
      return null;
    }
  }

  Future<void> _fetchFishState({bool silent = false}) async {
    if (!silent && mounted) setState(() => isFishtankLoading = true);
    try {
      // Core endpoints (required on all server versions)
      final briRaw = await _fishGet('/getbrightness');
      final modeRaw = await _fishGet('/getmode');
      final timesRaw = await _fishGet('/gettimes');
      // Extended endpoints (new server) — optional so old deploys still work
      final partyRaw = await _fishGetOptional('/getparty');
      final ovRaw = await _fishGetOptional('/getoverride');

      final bri = int.tryParse(briRaw ?? '') ?? 0;
      final mode = (modeRaw ?? '0') == '1';
      final times = (timesRaw ?? '').split(',');
      final party = (partyRaw ?? '0') == '1';
      final ov = int.tryParse(ovRaw ?? '0') ?? 0;

      TimeOfDay onT = fishOnTime;
      TimeOfDay offT = fishOffTime;
      if (times.length >= 2) {
        onT = _parseHhMm(times[0]) ?? onT;
        offT = _parseHhMm(times[1]) ?? offT;
      }

      if (!mounted) return;
      setState(() {
        fishBrightness = bri.clamp(0, 255);
        if (!_sliderDragging) _sliderBrightness = fishBrightness.toDouble();
        fishWillezMode = mode;
        fishPartyMode = party;
        fishOverrideSeconds = ov;
        fishOnTime = onT;
        fishOffTime = offT;
        fishConnected = true;
        isFishtankLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        fishConnected = false;
        isFishtankLoading = false;
      });
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not reach fish light server'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _fishAction(
    Future<void> Function() action, {
    String? successMessage,
  }) async {
    if (isFishtankLoading) return;
    setState(() => isFishtankLoading = true);
    try {
      await action();
      await _fetchFishState(silent: true);
      if (mounted && successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: Colors.teal,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => isFishtankLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fish light error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _setFishBrightness(int value) async {
    final v = value.clamp(0, 255);
    await _fishAction(
      () async {
        await _fishGet('/set', query: {'value': '$v'});
      },
      successMessage: fishWillezMode && !fishPartyMode
          ? 'Brightness $v (schedule paused ~60m)'
          : 'Brightness set to $v',
    );
  }

  Future<void> _setFishWillez(bool enabled) async {
    await _fishAction(
      () async {
        await _fishGet('/setmode', query: {'value': enabled ? '1' : '0'});
      },
      successMessage: enabled ? 'WillEZ schedule ON' : 'WillEZ schedule OFF',
    );
  }

  Future<void> _setFishParty(bool enabled) async {
    await _fishAction(
      () async {
        await _fishGet('/setparty', query: {'value': enabled ? '1' : '0'});
      },
      successMessage: enabled ? '🎉 Party mode ON' : 'Party mode OFF',
    );
  }

  Future<void> _clearFishOverride() async {
    await _fishAction(
      () async {
        await _fishGet('/clearoverride');
      },
      successMessage: 'Schedule resumed',
    );
  }

  Future<void> _saveFishSchedule(TimeOfDay on, TimeOfDay off) async {
    await _fishAction(
      () async {
        await _fishGet('/settimes', query: {
          'on': _fmtHhMm(on),
          'off': _fmtHhMm(off),
        });
      },
      successMessage: 'Schedule saved (${_fmtHhMm(on)} → ${_fmtHhMm(off)} CT)',
    );
  }

  Future<void> _pickFishTime({required bool isOn}) async {
    final initial = isOn ? fishOnTime : fishOffTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: isOn ? 'Auto ON (Central Time)' : 'Auto OFF (Central Time)',
    );
    if (picked == null) return;
    final on = isOn ? picked : fishOnTime;
    final off = isOn ? fishOffTime : picked;
    await _saveFishSchedule(on, off);
  }

  // ────────────────────────────────────────────────
  // UI helpers
  // ────────────────────────────────────────────────
  String titleCase(String text) {
    return text
        .split('-')
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : '')
        .join(' ');
  }

  Widget _fishChip({
    required String label,
    required Color color,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.orbitron(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fishActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
    bool filled = true,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isFishtankLoading ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: filled
                ? LinearGradient(
                    colors: [color.withOpacity(0.95), color.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: filled ? null : color.withOpacity(0.12),
            border: filled ? null : Border.all(color: color.withOpacity(0.5)),
            boxShadow: filled
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.orbitron(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFishPanel(ThemeData theme) {
    final lit = fishBrightness > 0;
    final overrideActive = fishOverrideSeconds > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: theme.colorScheme.surface.withOpacity(0.22),
          border: Border.all(
            color: fishPartyMode
                ? Colors.pinkAccent.withOpacity(0.65)
                : Colors.tealAccent.withOpacity(0.35),
          ),
          boxShadow: fishPartyMode
              ? [
                  BoxShadow(
                    color: Colors.pinkAccent.withOpacity(0.25),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            InkWell(
              onTap: () =>
                  setState(() => fishPanelExpanded = !fishPanelExpanded),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
                child: Row(
                  children: [
                    Text(
                      '🐟 FISH TANK',
                      style: GoogleFonts.orbitron(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.tealAccent,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Spacer(),
                    if (isFishtankLoading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Icon(
                        fishConnected ? Icons.cloud_done : Icons.cloud_off,
                        size: 18,
                        color: fishConnected ? Colors.tealAccent : Colors.redAccent,
                      ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        fishPanelExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                      ),
                      onPressed: () => setState(
                        () => fishPanelExpanded = !fishPanelExpanded,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (fishPanelExpanded) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Status chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _fishChip(
                          label: lit ? 'ON · $fishBrightness' : 'OFF',
                          color: lit ? Colors.lightGreenAccent : Colors.redAccent,
                          icon: lit
                              ? Icons.lightbulb
                              : Icons.lightbulb_outline,
                        ),
                        _fishChip(
                          label: fishWillezMode ? 'WillEZ ON' : 'WillEZ OFF',
                          color: fishWillezMode
                              ? Colors.lightGreenAccent
                              : Colors.orangeAccent,
                          icon: Icons.schedule,
                        ),
                        _fishChip(
                          label: fishPartyMode ? 'PARTY' : 'Solid',
                          color: fishPartyMode
                              ? Colors.pinkAccent
                              : Colors.blueGrey,
                          icon: fishPartyMode
                              ? Icons.celebration
                              : Icons.wb_sunny,
                        ),
                        if (overrideActive)
                          _fishChip(
                            label: 'Override ${_fmtOverride(fishOverrideSeconds)}',
                            color: Colors.amberAccent,
                            icon: Icons.pause_circle_filled,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Schedule row
                    Row(
                      children: [
                        Expanded(
                          child: _fishActionButton(
                            label: 'ON ${_fmtHhMm(fishOnTime)}',
                            icon: Icons.wb_twilight,
                            color: Colors.teal,
                            filled: false,
                            onTap: () => _pickFishTime(isOn: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _fishActionButton(
                            label: 'OFF ${_fmtHhMm(fishOffTime)}',
                            icon: Icons.nightlight_round,
                            color: Colors.indigo,
                            filled: false,
                            onTap: () => _pickFishTime(isOn: false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Schedule uses Central Time · tap times to change',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.45),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Full ON / OFF
                    Row(
                      children: [
                        Expanded(
                          child: _fishActionButton(
                            label: 'FULL ON',
                            icon: Icons.lightbulb,
                            color: Colors.teal,
                            onTap: () => _setFishBrightness(255),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _fishActionButton(
                            label: 'OFF',
                            icon: Icons.lightbulb_outline,
                            color: Colors.redAccent,
                            onTap: () => _setFishBrightness(0),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Brightness slider
                    Row(
                      children: [
                        Icon(Icons.brightness_low,
                            size: 18, color: Colors.white54),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: Colors.tealAccent,
                              thumbColor: Colors.tealAccent,
                              inactiveTrackColor: Colors.white24,
                              overlayColor:
                                  Colors.tealAccent.withOpacity(0.2),
                            ),
                            child: Slider(
                              min: 0,
                              max: 255,
                              divisions: 51,
                              value: _sliderBrightness.clamp(0, 255),
                              label: _sliderBrightness.round().toString(),
                              onChangeStart: (_) =>
                                  setState(() => _sliderDragging = true),
                              onChanged: (v) =>
                                  setState(() => _sliderBrightness = v),
                              onChangeEnd: (v) {
                                setState(() => _sliderDragging = false);
                                _setFishBrightness(v.round());
                              },
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 36,
                          child: Text(
                            '${_sliderBrightness.round()}',
                            textAlign: TextAlign.end,
                            style: GoogleFonts.orbitron(
                              fontSize: 12,
                              color: Colors.tealAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // WillEZ / Party / Resume
                    Row(
                      children: [
                        Expanded(
                          child: _fishActionButton(
                            label: fishWillezMode ? 'WillEZ ✓' : 'WillEZ',
                            icon: Icons.schedule,
                            color: fishWillezMode
                                ? Colors.green
                                : Colors.blueGrey,
                            filled: fishWillezMode,
                            onTap: () => _setFishWillez(!fishWillezMode),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _fishActionButton(
                            label: fishPartyMode ? 'PARTY ✓' : 'PARTY',
                            icon: Icons.celebration,
                            color: fishPartyMode
                                ? Colors.pinkAccent
                                : const Color(0xFF9C27B0),
                            filled: fishPartyMode,
                            onTap: () => _setFishParty(!fishPartyMode),
                          ),
                        ),
                      ],
                    ),
                    if (overrideActive || fishWillezMode) ...[
                      const SizedBox(height: 8),
                      _fishActionButton(
                        label: overrideActive
                            ? 'Resume schedule now'
                            : 'Refresh status',
                        icon: overrideActive
                            ? Icons.play_arrow
                            : Icons.refresh,
                        color: Colors.blueGrey,
                        filled: false,
                        onTap: overrideActive
                            ? _clearFishOverride
                            : () => _fetchFishState(),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      fishWillezMode
                          ? 'Manual ON/OFF/slider pauses the timer for ~60 min, then WillEZ resumes. Party mode runs a rainbow until you turn it off.'
                          : 'WillEZ is off — lights stay at whatever you set until you change them.',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.35,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
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
                                    orElse: () => modes.first,
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

                _buildFishPanel(theme),

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

                            return GestureDetector(
                              onTap: isUpdating
                                  ? null
                                  : () => _updateMode(mode['name']!),
                              child: AnimatedBuilder(
                                animation: _glowAnim,
                                builder: (context, child) {
                                  final glow = _glowAnim.value;

                                  Widget cardContent = Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(18),
                                      color: theme.colorScheme.surface
                                          .withOpacity(0.16),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(18),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(
                                            sigmaX: 10, sigmaY: 10),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Expanded(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(12),
                                                child: Image.asset(
                                                  mode['image']!,
                                                  fit: BoxFit.contain,
                                                  errorBuilder: (_, __, ___) =>
                                                      const Icon(
                                                    Icons.broken_image,
                                                    size: 48,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 12),
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
                                  );

                                  if (!isSelected) {
                                    return cardContent;
                                  }

                                  return Transform.scale(
                                    scale: 1.0 + (0.03 * (glow - 0.6)),
                                    child: _RainbowGlowBorder(
                                      glowIntensity: glow,
                                      primaryColor: theme.primaryColor,
                                      child: cardContent,
                                    ),
                                  );
                                },
                              ),
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

// ────────────────────────────────────────────────
//  Animated rainbow + pulsing glow border widget
// ────────────────────────────────────────────────
class _RainbowGlowBorder extends StatefulWidget {
  final Widget child;
  final double glowIntensity;
  final Color primaryColor;

  const _RainbowGlowBorder({
    required this.child,
    required this.glowIntensity,
    required this.primaryColor,
  });

  @override
  State<_RainbowGlowBorder> createState() => _RainbowGlowBorderState();
}

class _RainbowGlowBorderState extends State<_RainbowGlowBorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _rainbowController;

  @override
  void initState() {
    super.initState();
    _rainbowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _rainbowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glow = widget.glowIntensity.clamp(0.6, 1.4);

    return AnimatedBuilder(
      animation: _rainbowController,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: SweepGradient(
              colors: const [
                Color(0xFFFF0000),
                Color(0xFFFF8800),
                Color(0xFFFFFF00),
                Color(0xFF00FF00),
                Color(0xFF00FFFF),
                Color(0xFF0000FF),
                Color(0xFFAA00FF),
                Color(0xFFFF0000),
              ],
              stops: const [0.0, 0.14, 0.28, 0.42, 0.57, 0.71, 0.85, 1.0],
              transform:
                  GradientRotation(_rainbowController.value * 2 * 3.14159),
            ),
            boxShadow: [
              BoxShadow(
                color: widget.primaryColor.withOpacity(0.25 * glow),
                blurRadius: 28 * glow,
                spreadRadius: 8,
              ),
            ],
          ),
          child: Container(
            margin: const EdgeInsets.all(3.2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              color: Theme.of(context).colorScheme.surface.withOpacity(0.18),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.10 * glow),
                  blurRadius: 10 * glow,
                  spreadRadius: -2,
                  offset: const Offset(0, 0),
                ),
                BoxShadow(
                  color: widget.primaryColor.withOpacity(0.5 * glow),
                  blurRadius: 14 * glow,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: widget.primaryColor.withOpacity(0.3 * glow),
                  blurRadius: 24 * glow,
                  spreadRadius: 6,
                ),
              ],
            ),
            child: widget.child,
          ),
        );
      },
    );
  }
}
