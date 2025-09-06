import 'package:flutter/material.dart';
import '../models/note.dart';
import '../utils/database_helper.dart';
import 'note_detail_screen.dart';
import '../widgets/note_tile.dart';
import '../main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final TextEditingController _searchController = TextEditingController();
  List<Note> _notes = [];
  List<Note> _filteredNotes = [];
  bool _showFavoritesOnly = false;

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _searchController.addListener(_filterNotes);
  }

  Future<void> _loadNotes() async {
    try {
      final notes = await _dbHelper.getNotes();
      setState(() {
        _notes = notes;
        _filterNotes();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading notes: $e')),
      );
    }
  }

  void _filterNotes() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredNotes = _notes.where((note) {
        final matchesSearch = note.title.toLowerCase().contains(query) ||
            note.content.toLowerCase().contains(query);
        final matchesFavorite = !_showFavoritesOnly || note.isFavorite;
        return matchesSearch && matchesFavorite;
      }).toList();
      _filteredNotes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    });
  }

  Future<void> _toggleFavorite(int id) async {
    try {
      final note = _notes.firstWhere((n) => n.id == id);
      await _dbHelper.updateNote(note.copyWith(
        isFavorite: !note.isFavorite,
        updatedAt: DateTime.now(),
      ));
      _loadNotes();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating favorite: $e')),
      );
    }
  }

  Future<void> _deleteNote(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Note?'),
        content: const Text('Are You Sure You Want To Delete?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _dbHelper.deleteNote(id);
        _loadNotes();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting note: $e')),
        );
      }
    }
  }

  void _navigateToDetail({Note? note}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NoteDetailScreen(note: note)),
    );
    _loadNotes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = themeNotifier.value == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Notes'),
        actions: [
          IconButton(
            icon: Icon(_showFavoritesOnly ? Icons.star_rounded : Icons.star_outline_rounded),
            onPressed: () {
              setState(() => _showFavoritesOnly = !_showFavoritesOnly);
              _filterNotes();
            },
          ),
          IconButton(
            icon: Icon(Theme.of(context).brightness == Brightness.dark
                ? Icons.light_mode
                : Icons.dark_mode),
            onPressed: () {
              themeNotifier.value = Theme.of(context).brightness == Brightness.dark
                  ? ThemeMode.light
                  : ThemeMode.dark;
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16).copyWith(bottom: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search notes...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) => _filterNotes(),
            ),
          ),
          Expanded(
            child: _filteredNotes.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.note_alt_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No notes found',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.only(bottom: 100),
              itemCount: _filteredNotes.length,
              itemBuilder: (context, index) => NoteTile(
                note: _filteredNotes[index],
                onTap: () => _navigateToDetail(note: _filteredNotes[index]),
                onDelete: () => _deleteNote(_filteredNotes[index].id!),
                onToggleFavorite: () => _toggleFavorite(_filteredNotes[index].id!),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 28),
        onPressed: () => _navigateToDetail(),
      ),
    );
  }
}