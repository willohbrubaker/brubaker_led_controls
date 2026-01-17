import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'dart:ui';
import 'dart:async';
import 'dart:math';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http_parser/http_parser.dart';

import 'star_field.dart';

void main() {
  runApp(const BrubakerLedApp());
}

class BrubakerLedApp extends StatelessWidget {
  const BrubakerLedApp({super.key});

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
        textTheme: GoogleFonts.orbitronTextTheme(ThemeData.dark().textTheme),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

// ────────────────────────────────────────────────

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  static const List<Widget> _screens = [ModeGalleryScreen(), CircleHomePage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        elevation: 0,
        backgroundColor: Colors.black.withOpacity(0.65),
        indicatorColor: Colors.deepPurple.withOpacity(0.35),
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Modes',
          ),
          NavigationDestination(icon: Icon(Icons.circle), label: 'Circle'),
        ],
      ),
    );
  }
}

class ModeGalleryScreen extends StatefulWidget {
  const ModeGalleryScreen({super.key});

  @override
  State<ModeGalleryScreen> createState() => _ModeGalleryScreenState();
}

class _ModeGalleryScreenState extends State<ModeGalleryScreen>
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
    } catch (_) {
      // silent fail
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

    return Stack(
      children: [
        const StarField(opacity: 0.35),
        SafeArea(
          child: Column(
            children: [
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
                                  orElse: () => modes[0],
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
                            builder: (context, _) {
                              final glow = _glowAnim.value;

                              return GestureDetector(
                                onTap: isUpdating
                                    ? null
                                    : () => _updateMode(mode['name']!),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    color: theme.colorScheme.surface
                                        .withOpacity(0.16),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: theme.primaryColor
                                                  .withOpacity(0.45 * glow),
                                              blurRadius: 12 * glow,
                                              spreadRadius: 2,
                                            ),
                                            BoxShadow(
                                              color: theme.primaryColor
                                                  .withOpacity(0.25 * glow),
                                              blurRadius: 24 * glow,
                                              spreadRadius: 6,
                                            ),
                                          ]
                                        : null,
                                    border: Border.all(
                                      color: isSelected
                                          ? theme.primaryColor.withOpacity(
                                              0.7 * glow,
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
                                              padding: const EdgeInsets.all(12),
                                              child: Image.asset(
                                                mode['image']!,
                                                fit: BoxFit.contain,
                                                errorBuilder: (_, __, ___) =>
                                                    const Icon(
                                                      Icons.image_not_supported,
                                                    ),
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
    );
  }
}

// ────────────────────────────────────────────────
// Circle Screen – Home + Gallery

const String serverUrl =
    'http://108.254.1.184:9026'; // ← moved to global constant

class CircleHomePage extends StatefulWidget {
  const CircleHomePage({super.key});

  @override
  State<CircleHomePage> createState() => _CircleHomePageState();
}

class _CircleHomePageState extends State<CircleHomePage> {
  List<String> _imageFilenames = [];
  String? _currentImageUrl;
  Timer? _timer;

  Future<void> _loadRandomImage() async {
    try {
      final response = await http.get(Uri.parse('$serverUrl/list/pattie'));
      if (response.statusCode == 200 && mounted) {
        final List<String> filenames = List<String>.from(
          json.decode(response.body),
        );
        if (filenames.isNotEmpty) {
          final available = filenames.where((f) => f != 'current.jpg').toList();
          if (available.isNotEmpty) {
            final random = Random();
            final selected = available[random.nextInt(available.length)];
            if (mounted) {
              setState(() {
                _imageFilenames = available;
                _currentImageUrl = '$serverUrl/images/pattie/$selected';
              });
            }
          }
        }
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _loadRandomImage();

    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_imageFilenames.isNotEmpty && mounted) {
        final random = Random();
        final selected =
            _imageFilenames[random.nextInt(_imageFilenames.length)];
        setState(() => _currentImageUrl = '$serverUrl/images/pattie/$selected');
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(imageQuality: 85);

    if (pickedFiles.isNotEmpty && mounted) {
      final imageFiles = pickedFiles.map((f) => File(f.path)).toList();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MultiPreviewScreen(imageFiles: imageFiles),
        ),
      ).then((_) => _loadRandomImage());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        const StarField(opacity: 0.35),

        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Glowing circle preview
                Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: theme.primaryColor.withOpacity(0.7),
                        blurRadius: 60,
                        spreadRadius: 20,
                      ),
                      BoxShadow(
                        color: Colors.deepPurpleAccent.withOpacity(0.4),
                        blurRadius: 80,
                        spreadRadius: 25,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 1200),
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                      child: _currentImageUrl != null
                          ? CachedNetworkImage(
                              key: ValueKey(_currentImageUrl),
                              imageUrl: _currentImageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                              errorWidget: (_, __, ___) =>
                                  Container(color: Colors.black38),
                            )
                          : Container(color: Colors.black38),
                    ),
                  ),
                ),

                const SizedBox(height: 56),

                Text(
                  'CircleScreen',
                  style: GoogleFonts.orbitron(
                    fontSize: 52,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.5,
                    shadows: [
                      Shadow(color: theme.primaryColor, blurRadius: 24),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                Text(
                  'Upload photos to your circular display',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Colors.white70),
                ),

                const SizedBox(height: 80),

                ElevatedButton.icon(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.photo_library, size: 36),
                  label: const Text(
                    'Select Photos',
                    style: TextStyle(fontSize: 22),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 56,
                      vertical: 24,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(40),
                    ),
                    elevation: 8,
                  ),
                ),

                const SizedBox(height: 40),

                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const GalleryScreen()),
                    );
                  },
                  icon: const Icon(Icons.photo_library_outlined, size: 28),
                  label: const Text(
                    'View Library',
                    style: TextStyle(fontSize: 20),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.primaryColor,
                    side: BorderSide(color: theme.primaryColor, width: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 18,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
// ────────────────────────────────────────────────
// Gallery Screen (full page)

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  Future<List<String>>? _imagesFuture;
  Set<String> selectedFilenames = {};

  @override
  void initState() {
    super.initState();
    _refreshImages();
  }

  Future<void> _refreshImages() async {
    setState(() {
      selectedFilenames.clear();
      _imagesFuture = _fetchImages();
    });
  }

  Future<List<String>> _fetchImages() async {
    try {
      final response = await http.get(Uri.parse('$serverUrl/list/pattie'));
      if (response.statusCode == 200) {
        return List<String>.from(json.decode(response.body));
      }
    } catch (_) {}
    return [];
  }

  Future<void> _deleteSelected() async {
    for (var filename in selectedFilenames) {
      await http.delete(Uri.parse('$serverUrl/delete/pattie/$filename'));
    }
    _refreshImages();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${selectedFilenames.length} photo(s) deleted')),
    );
  }

  Future<void> _downloadSelected() async {
    final bool isMobile =
        !Platform.isLinux && !Platform.isWindows && !Platform.isMacOS;

    int success = 0;
    for (var filename in selectedFilenames) {
      try {
        final response = await http.get(
          Uri.parse('$serverUrl/images/pattie/$filename'),
        );
        if (response.statusCode == 200) {
          if (isMobile) {
            await Gal.putImageBytes(response.bodyBytes, album: 'CircleScreen');
          } else {
            final dir = await getDownloadsDirectory();
            final path = '${dir!.path}/CircleScreen_$filename';
            await File(path).writeAsBytes(response.bodyBytes);
          }
          success++;
        }
      } catch (_) {}
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$success photo(s) saved')));
    setState(() => selectedFilenames.clear());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelecting = selectedFilenames.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          isSelecting ? '${selectedFilenames.length} selected' : 'Library',
        ),
        backgroundColor: Colors.black.withOpacity(0.5),
        elevation: 0,
        actions: isSelecting
            ? [
                IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: _downloadSelected,
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _deleteSelected,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => selectedFilenames.clear()),
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _refreshImages,
                ),
              ],
      ),
      body: FutureBuilder<List<String>>(
        future: _imagesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No photos yet — upload some!'));
          }

          final images = snapshot.data!;

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: images.length,
            itemBuilder: (context, index) {
              final filename = images[index];
              final url = '$serverUrl/images/pattie/$filename';
              final isSelected = selectedFilenames.contains(filename);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      selectedFilenames.remove(filename);
                    } else {
                      selectedFilenames.add(filename);
                    }
                  });
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            const Center(child: CircularProgressIndicator()),
                        errorWidget: (_, __, ___) => const Icon(Icons.error),
                      ),
                    ),
                    if (isSelected)
                      Container(
                        color: theme.primaryColor.withOpacity(0.5),
                        child: const Icon(
                          Icons.check_circle,
                          size: 60,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ────────────────────────────────────────────────
// MultiPreviewScreen (with tap to single preview)

class MultiPreviewScreen extends StatefulWidget {
  final List<File> imageFiles;

  const MultiPreviewScreen({super.key, required this.imageFiles});

  @override
  State<MultiPreviewScreen> createState() => _MultiPreviewScreenState();
}

class _MultiPreviewScreenState extends State<MultiPreviewScreen> {
  bool _isUploading = false;
  int _uploadedCount = 0;

  Future<void> _uploadAll() async {
    setState(() {
      _isUploading = true;
      _uploadedCount = 0;
    });

    int success = 0;
    for (var file in widget.imageFiles) {
      try {
        final bytes = await file.readAsBytes();
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('$serverUrl/upload/pattie'),
        );
        request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            bytes,
            filename: 'upload_${DateTime.now().millisecondsSinceEpoch}.jpg',
            contentType: MediaType('image', 'jpeg'),
          ),
        );
        var response = await request.send().timeout(
          const Duration(seconds: 60),
        );
        if (response.statusCode == 200) success++;
      } catch (_) {}
      if (mounted) setState(() => _uploadedCount++);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Uploaded $success of ${widget.imageFiles.length} photos',
          ),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.imageFiles.length} Photos Selected'),
      ),
      body: Column(
        children: [
          if (_isUploading)
            Padding(
              padding: const EdgeInsets.all(16),
              child: LinearProgressIndicator(
                value: _uploadedCount / widget.imageFiles.length,
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.imageFiles.length,
              itemBuilder: (context, i) {
                final file = widget.imageFiles[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PreviewScreen(imageFile: file),
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        const Text(
                          'Tap to preview & upload single',
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: 240,
                          height: 240,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                          ),
                          child: ClipOval(
                            child: Image.file(file, fit: BoxFit.cover),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (!_isUploading)
            Padding(
              padding: const EdgeInsets.all(24),
              child: ElevatedButton.icon(
                onPressed: _uploadAll,
                icon: const Icon(Icons.upload),
                label: Text('Upload All (${widget.imageFiles.length})'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// PreviewScreen (single image upload)
class PreviewScreen extends StatelessWidget {
  final File imageFile;

  const PreviewScreen({super.key, required this.imageFile});

  Future<void> _upload(BuildContext context) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$serverUrl/upload/pattie'),
    );
    request.files.add(
      await http.MultipartFile.fromPath('image', imageFile.path),
    );

    try {
      var response = await request.send();
      if (context.mounted) {
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Uploaded successfully! 🎉')),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Upload failed — try again')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Connection error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Preview & Upload')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'How it will look on your 240×240 circle',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, color: Colors.white70),
              ),
              const SizedBox(height: 40),
              Container(
                width: 240,
                height: 240,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: ClipOval(
                  child: Image.file(imageFile, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 60),
              ElevatedButton.icon(
                onPressed: () => _upload(context),
                icon: const Icon(Icons.upload),
                label: const Text('Upload This Photo'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Choose Another'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
