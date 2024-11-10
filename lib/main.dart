
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: MaterialApp(
        title: 'GitHub Gallery',
        theme: ThemeData(
          primarySwatch: Colors.green,
          useMaterial3: true,
        ),
        home: const SplashScreen(),
      ),
    );
  }
}

class AppProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<Gist> _gists = [];
  List<ImageItem> _images = [];
  Set<String> _bookmarkedImages = {};
  bool _isLoading = false;

  bool get isLoading => _isLoading;
  List<Gist> get gists => _gists;
  List<ImageItem> get images => _images;
  List<ImageItem> get bookmarkedImages =>
      _images.where((img) => _bookmarkedImages.contains(img.id)).toList();

  AppProvider() {
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    _bookmarkedImages = Set.from(prefs.getStringList('bookmarks') ?? []);
    notifyListeners();
  }

  Future<void> toggleBookmark(String imageId) async {
    if (_bookmarkedImages.contains(imageId)) {
      _bookmarkedImages.remove(imageId);
    } else {
      _bookmarkedImages.add(imageId);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('bookmarks', _bookmarkedImages.toList());
    notifyListeners();
  }

  bool isBookmarked(String imageId) => _bookmarkedImages.contains(imageId);

  Future<void> fetchGists() async {
    if (!_isLoading) {
      _isLoading = true;
      notifyListeners();

      try {
        final cachedGists = await _apiService.getCachedGists();
        if (cachedGists.isNotEmpty) {
          _gists = cachedGists;
          notifyListeners();
        }

        final freshGists = await _apiService.fetchGists();
        _gists = freshGists;
        await _apiService.cacheGists(freshGists);
      } catch (e) {
        debugPrint('Error fetching gists: $e');
      }

      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchImages() async {
    if (!_isLoading) {
      _isLoading = true;
      notifyListeners();

      try {
        final cachedImages = await _apiService.getCachedImages();
        if (cachedImages.isNotEmpty) {
          _images = cachedImages;
          notifyListeners();
        }

        final freshImages = await _apiService.fetchImages();
        _images = freshImages;
        await _apiService.cacheImages(freshImages);
      } catch (e) {
        debugPrint('Error fetching images: $e');
      }

      _isLoading = false;
      notifyListeners();
    }
  }
}

class ApiService {
  final Dio _dio = Dio();
  static const String _gistsUrl = 'https://api.github.com/gists/public';
  static const String _unsplashUrl = 'https://api.unsplash.com/photos';
  static const String _unsplashAccessKey = 'YOUR_UNSPLASH_ACCESS_KEY';

  Future<List<Gist>> fetchGists() async {
    try {
      final response = await _dio.get(_gistsUrl);
      return (response.data as List).map((json) => Gist.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch gists');
    }
  }

  Future<List<ImageItem>> fetchImages() async {
    try {
      final response = await _dio.get(
        _unsplashUrl,
        queryParameters: {
          'client_id': _unsplashAccessKey,
          'per_page': 30,
        },
      );
      return (response.data as List).map((json) => ImageItem.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch images');
    }
  }

  Future<void> cacheGists(List<Gist> gists) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_gists', jsonEncode(gists.map((g) => g.toJson()).toList()));
  }

  Future<List<Gist>> getCachedGists() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('cached_gists');
    if (cached != null) {
      final List<dynamic> decoded = jsonDecode(cached);
      return decoded.map((json) => Gist.fromJson(json)).toList();
    }
    return [];
  }

  Future<void> cacheImages(List<ImageItem> images) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_images', jsonEncode(images.map((i) => i.toJson()).toList()));
  }

  Future<List<ImageItem>> getCachedImages() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('cached_images');
    if (cached != null) {
      final List<dynamic> decoded = jsonDecode(cached);
      return decoded.map((json) => ImageItem.fromJson(json)).toList();
    }
    return [];
  }
}

// lib/models/gist.dart
class Gist {
  final String id;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> files;
  final Map<String, dynamic> owner;
  final int commentCount;

  Gist({
    required this.id,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
    required this.files,
    required this.owner,
    required this.commentCount,
  });

  factory Gist.fromJson(Map<String, dynamic> json) {
    return Gist(
      id: json['id'],
      description: json['description'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      files: Map<String, dynamic>.from(json['files']),
      owner: Map<String, dynamic>.from(json['owner']),
      commentCount: json['comments'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'files': files,
      'owner': owner,
      'comments': commentCount,
    };
  }
}

// lib/models/image_item.dart
class ImageItem {
  final String id;
  final String url;
  final String thumbnailUrl;
  final String author;
  final String description;

  ImageItem({
    required this.id,
    required this.url,
    required this.thumbnailUrl,
    required this.author,
    required this.description,
  });

  factory ImageItem.fromJson(Map<String, dynamic> json) {
    return ImageItem(
      id: json['id'],
      url: json['urls']['regular'],
      thumbnailUrl: json['urls']['thumb'],
      author: json['user']['name'] ?? 'Unknown',
      description: json['description'] ?? json['alt_description'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'urls': {
        'regular': url,
        'thumb': thumbnailUrl,
      },
      'user': {
        'name': author,
      },
      'description': description,
    };
  }
}


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    await Future.wait([
      provider.fetchGists(),
      provider.fetchImages(),
    ]);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FlutterLogo(size: 100),
            SizedBox(height: 20),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIndex == 0 ? 'GitHub Repos' : 'Gallery'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) =>  HomeScreen()),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children:  [

        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.list),
            label: 'Repos',
          ),
          NavigationDestination(
            icon: Icon(Icons.photo_library),
            label: 'Gallery',
          ),
        ],
      ),
    );
  }
}


