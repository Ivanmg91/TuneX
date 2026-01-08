import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FavoritesScreen extends StatefulWidget {
  final AudioPlayer player;
  const FavoritesScreen({super.key, required this.player});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final String _uid = FirebaseAuth.instance.currentUser!.uid;
  String? _currentPlayingUrl;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    // Reutilizamos el mismo player, así que escuchamos sus eventos igual
    widget.player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          if (state.processingState == ProcessingState.completed) {
            _isPlaying = false;
            _currentPlayingUrl = null;
          }
        });
      }
    });
  }

  Future<void> _playSong(String url) async {
    try {
      if (_currentPlayingUrl == url && _isPlaying) {
        widget.player.pause();
      } else {
        _currentPlayingUrl = url;
        await widget.player.setUrl(url);
        widget.player.play();
      }
    } catch (e) {
      print("Error: $e");
    }
  }

  Future<void> _removeLike(String songId) async {
    // Aquí solo permitimos quitar like (porque ya estamos en favoritos)
    await FirebaseFirestore.instance.collection('songs').doc(songId).update({
      'likes': FieldValue.increment(-1),
      'likedBy': FieldValue.arrayRemove([_uid]),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mis Me Gusta',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF430E14),
              Color(0xFF121212),
            ], // Degradado rojizo para Likes
            stops: [0.0, 0.3],
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          // CONSULTA FILTRADA: Dame solo donde 'likedBy' contenga mi ID
          stream: FirebaseFirestore.instance
              .collection('songs')
              .where('likedBy', arrayContains: _uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            var songs = snapshot.data!.docs;

            if (songs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(
                      Icons.favorite_border,
                      size: 80,
                      color: Colors.white24,
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Aún no tienes favoritos.",
                      style: TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: songs.length,
              itemBuilder: (context, index) {
                var songDocs = songs[index];
                var song = songDocs.data() as Map<String, dynamic>;

                String title = song['title'] ?? 'Sin título';
                String artistEmail = song['artistEmail'] ?? 'Desconocido';
                String audioUrl = song['audioUrl'] ?? '';
                bool isThisPlaying =
                    _isPlaying && _currentPlayingUrl == audioUrl;

                return Card(
                  color: Colors.white.withOpacity(0.05),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isThisPlaying
                          ? const Color(0xFF1DB954)
                          : Colors.grey[800],
                      child: Icon(
                        isThisPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    subtitle: Text(
                      artistEmail.split('@')[0],
                      style: const TextStyle(color: Colors.white60),
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.favorite,
                        color: Color(0xFF1DB954),
                      ), // Siempre verde aquí
                      onPressed: () => _removeLike(songDocs.id),
                    ),
                    onTap: () => _playSong(audioUrl),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
