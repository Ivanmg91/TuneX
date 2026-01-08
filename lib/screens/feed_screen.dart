import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'profile_screen.dart';

class FeedScreen extends StatefulWidget {
  final AudioPlayer player;

  const FeedScreen({super.key, required this.player});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final String _uid = FirebaseAuth.instance.currentUser!.uid;
  String? _currentPlayingUrl;
  bool _isPlaying = false;

  // Variables para el Mini Player
  String _currentTitle = "";
  String _currentArtist = "";
  String _currentImage = "";
  String _currentSongId = "";
  Map<String, dynamic> _currentSongData = {};
  List<QueryDocumentSnapshot> _currentPlaylist = [];

  @override
  void initState() {
    super.initState();
    widget.player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          if (state.processingState == ProcessingState.completed) {
            _isPlaying = false;
            widget.player.seek(Duration.zero);
            widget.player.pause();
          }
        });
      }
    });
  }

  Future<void> _playSong(
    String url,
    String title,
    String artist,
    String imageUrl,
    String id,
    Map<String, dynamic> songData,
  ) async {
    setState(() {
      _currentTitle = title;
      _currentArtist = artist;
      _currentImage = imageUrl;
      _currentSongId = id;
      _currentSongData = songData;
    });

    try {
      if (_currentPlayingUrl == url) {
        if (_isPlaying) {
          widget.player.pause();
        } else {
          widget.player.play();
        }
      } else {
        _currentPlayingUrl = url;
        await widget.player.setUrl(url);
        widget.player.play();
      }
    } catch (e) {
      print("❌ Error al reproducir: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("No se pudo reproducir: $e")));
      }
    }
  }

  void _playNext() {
    if (_currentSongId.isEmpty || _currentPlaylist.isEmpty) return;

    int currentIndex = _currentPlaylist.indexWhere(
      (doc) => doc.id == _currentSongId,
    );

    if (currentIndex != -1 && currentIndex < _currentPlaylist.length - 1) {
      var nextSongDoc = _currentPlaylist[currentIndex + 1];
      var nextSong = nextSongDoc.data() as Map<String, dynamic>;

      String title = nextSong['title'] ?? 'Sin título';
      String artistEmail = nextSong['artistEmail'] ?? 'Desconocido';
      String artistName = nextSong['artistName'] ?? artistEmail.split('@')[0];

      String audioUrl = nextSong['audioUrl'] ?? '';
      String imageUrl = nextSong['imageUrl'] ?? '';

      _playSong(
        audioUrl,
        title,
        artistName,
        imageUrl,
        nextSongDoc.id,
        nextSong,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fin de la lista de reproducción")),
      );
    }
  }

  Future<void> _toggleLike(String songId, List<dynamic> likedBy) async {
    DocumentReference songRef = FirebaseFirestore.instance
        .collection('songs')
        .doc(songId);
    if (likedBy.contains(_uid)) {
      await songRef.update({
        'likes': FieldValue.increment(-1),
        'likedBy': FieldValue.arrayRemove([_uid]),
      });
    } else {
      await songRef.update({
        'likes': FieldValue.increment(1),
        'likedBy': FieldValue.arrayUnion([_uid]),
      });
    }
  }

  Future<void> _deleteSong(String songId) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¿Borrar canción?"),
        content: const Text("Esta acción no se puede deshacer."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Borrar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (_currentSongId == songId) {
        await widget.player.stop();
        setState(() {
          _currentPlayingUrl = null;
          _currentTitle = "";
          _currentArtist = "";
          _currentImage = "";
          _currentSongId = "";
          _currentSongData = {};
          _isPlaying = false;
        });
      }

      await FirebaseFirestore.instance.collection('songs').doc(songId).delete();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Canción eliminada")));
      }
    }
  }

  Future<void> _editSongTitle(String songId, String currentTitle) async {
    TextEditingController editController = TextEditingController(
      text: currentTitle,
    );
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Editar Título"),
        content: TextField(
          controller: editController,
          decoration: const InputDecoration(labelText: "Nuevo título"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (editController.text.trim().isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('songs')
                    .doc(songId)
                    .update({'title': editController.text.trim()});
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return "--:--";
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  void _showSongDetails(Map<String, dynamic> song, String songId) {
    if (song.isEmpty || songId.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        String title = song['title'] ?? 'Sin título';
        String imageUrl = song['imageUrl'] ?? '';
        String presetUrl = song['presetUrl'] ?? '';

        String ownerId = song['artistId'] ?? '';
        String artistEmail = song['artistEmail'] ?? 'Desconocido';
        String artistName = song['artistName'] ?? artistEmail.split('@')[0];

        bool isMySong = ownerId == _uid;

        return Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                height: 250,
                width: 250,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: Colors.grey[900],
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  image: imageUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(imageUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: imageUrl.isEmpty
                    ? const Icon(
                        Icons.music_note,
                        size: 80,
                        color: Colors.white24,
                      )
                    : null,
              ),
              const SizedBox(height: 25),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Column(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () {
                            if (ownerId.isNotEmpty) {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ProfileScreen(userId: ownerId),
                                ),
                              );
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Text(
                              artistName,
                              style: const TextStyle(
                                color: Color(0xFF1DB954),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.underline,
                                decorationColor: Color(0xFF1DB954),
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isMySong)
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blueGrey),
                      onPressed: () => _editSongTitle(songId, title),
                    ),
                ],
              ),

              const SizedBox(height: 20),
              StreamBuilder<Duration>(
                stream: widget.player.positionStream,
                builder: (context, snapshot) {
                  final position = snapshot.data ?? Duration.zero;
                  final total = widget.player.duration ?? Duration.zero;
                  double max = total.inMilliseconds.toDouble();
                  double value = position.inMilliseconds.toDouble();
                  if (value > max) value = max;
                  if (max <= 0) max = 1;

                  return Column(
                    children: [
                      Slider(
                        activeColor: const Color(0xFF1DB954),
                        inactiveColor: Colors.grey[800],
                        min: 0,
                        max: max,
                        value: value,
                        onChanged: (val) {
                          widget.player.seek(
                            Duration(milliseconds: val.toInt()),
                          );
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(position),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              _formatDuration(total),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  StreamBuilder<PlayerState>(
                    stream: widget.player.playerStateStream,
                    builder: (context, snapshot) {
                      final playerState = snapshot.data;
                      final processingState = playerState?.processingState;
                      final playing = playerState?.playing;

                      if (processingState == ProcessingState.loading ||
                          processingState == ProcessingState.buffering) {
                        return const CircularProgressIndicator(
                          color: Colors.white,
                        );
                      } else if (playing != true) {
                        return IconButton(
                          iconSize: 64,
                          icon: const Icon(
                            Icons.play_circle_fill,
                            color: Colors.white,
                          ),
                          onPressed: widget.player.play,
                        );
                      } else {
                        return IconButton(
                          iconSize: 64,
                          icon: const Icon(
                            Icons.pause_circle_filled,
                            color: Colors.white,
                          ),
                          onPressed: widget.player.pause,
                        );
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (presetUrl.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () async {
                    final Uri url = Uri.parse(presetUrl);
                    if (!await launchUrl(
                      url,
                      mode: LaunchMode.externalApplication,
                    )) {
                      if (mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Error al abrir enlace'),
                          ),
                        );
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  icon: const Icon(Icons.download_rounded),
                  label: const Text("Descargar Preset"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
              if (isMySong)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: TextButton.icon(
                    onPressed: () => _deleteSong(songId),
                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                    label: const Text(
                      "Eliminar Canción",
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  // --- WIDGET MINI PLAYER ---
  Widget _buildMiniPlayer() {
    if (_currentPlayingUrl == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => _showSongDetails(_currentSongData, _currentSongId),
      child: Container(
        height: 65,
        margin: const EdgeInsets.only(top: 1),
        decoration: BoxDecoration(
          color: const Color(0xFF282828),
          border: Border(top: BorderSide(color: Colors.grey[900]!, width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          children: [
            SizedBox(
              height: 2,
              child: StreamBuilder<Duration>(
                stream: widget.player.positionStream,
                builder: (context, snapshot) {
                  final position = snapshot.data ?? Duration.zero;
                  final total = widget.player.duration ?? Duration.zero;
                  double value = 0.0;
                  if (total.inMilliseconds > 0) {
                    value = position.inMilliseconds / total.inMilliseconds;
                  }
                  if (value < 0.0) value = 0.0;
                  if (value > 1.0) value = 1.0;

                  return LinearProgressIndicator(
                    value: value,
                    backgroundColor: Colors.transparent,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF1DB954),
                    ),
                  );
                },
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  if (_currentImage.isNotEmpty)
                    Image.network(
                      _currentImage,
                      width: 63,
                      height: 63,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Container(
                        width: 63,
                        height: 63,
                        color: Colors.grey[800],
                        child: const Icon(
                          Icons.music_note,
                          color: Colors.white24,
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 63,
                      height: 63,
                      color: Colors.grey[800],
                      child: const Icon(
                        Icons.music_note,
                        color: Colors.white24,
                      ),
                    ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _currentArtist,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  StreamBuilder<PlayerState>(
                    stream: widget.player.playerStateStream,
                    builder: (context, snapshot) {
                      final playerState = snapshot.data;
                      final processingState = playerState?.processingState;
                      final playing = playerState?.playing;

                      if (processingState == ProcessingState.loading ||
                          processingState == ProcessingState.buffering) {
                        return const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        );
                      }

                      return IconButton(
                        icon: Icon(
                          (playing == true) ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                        ),
                        onPressed: (playing == true)
                            ? widget.player.pause
                            : widget.player.play,
                      );
                    },
                  ),

                  IconButton(
                    icon: const Icon(Icons.skip_next, color: Colors.white),
                    onPressed: _playNext,
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Descubrir',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.search)),

          // --- AVATAR DEL USUARIO EN APPBAR ---
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(_uid)
                .snapshots(),
            builder: (context, snapshot) {
              ImageProvider? imageProvider;

              if (snapshot.hasData && snapshot.data!.exists) {
                var data = snapshot.data!.data() as Map<String, dynamic>;
                if (data.containsKey('profileImageUrl') &&
                    data['profileImageUrl'] != null &&
                    data['profileImageUrl'].toString().isNotEmpty) {
                  imageProvider = NetworkImage(data['profileImageUrl']);
                }
              }

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileScreen(),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.grey[800],
                    backgroundImage: imageProvider,
                    child: imageProvider == null
                        ? const Icon(
                            Icons.person,
                            size: 20,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E3264), Color(0xFF121212)],
            stops: [0.0, 0.3],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('songs')
                    .orderBy('uploadedAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  var songs = snapshot.data!.docs;

                  _currentPlaylist = songs;

                  if (songs.isEmpty) {
                    return const Center(
                      child: Text(
                        "No hay música aún.",
                        style: TextStyle(color: Colors.white54),
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
                      String artistName =
                          song['artistName'] ?? artistEmail.split('@')[0];

                      String audioUrl = song['audioUrl'] ?? '';
                      String imageUrl = song['imageUrl'] ?? '';
                      List<dynamic> likedBy = song['likedBy'] ?? [];
                      bool isLiked = likedBy.contains(_uid);
                      bool isThisPlaying =
                          _isPlaying && _currentPlayingUrl == audioUrl;

                      return Card(
                        color: Colors.white.withOpacity(0.05),
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            radius: 25,
                            backgroundColor: Colors.grey[800],
                            backgroundImage: imageUrl.isNotEmpty
                                ? NetworkImage(imageUrl)
                                : null,
                            child: imageUrl.isEmpty
                                ? Icon(
                                    isThisPlaying
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                    color: Colors.white,
                                  )
                                : (isThisPlaying
                                      ? Container(
                                          decoration: BoxDecoration(
                                            color: Colors.black54,
                                            borderRadius: BorderRadius.circular(
                                              50,
                                            ),
                                          ),
                                          child: const Center(
                                            child: Icon(
                                              Icons.pause,
                                              color: Colors.white,
                                            ),
                                          ),
                                        )
                                      : null),
                          ),
                          title: Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          subtitle: Text(
                            artistName,
                            style: const TextStyle(color: Colors.white60),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  isLiked
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: isLiked
                                      ? const Color(0xFF1DB954)
                                      : Colors.white60,
                                ),
                                onPressed: () =>
                                    _toggleLike(songDocs.id, likedBy),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.more_vert,
                                  color: Colors.white70,
                                ),
                                onPressed: () =>
                                    _showSongDetails(song, songDocs.id),
                              ),
                            ],
                          ),
                          onTap: () => _playSong(
                            audioUrl,
                            title,
                            artistName,
                            imageUrl,
                            songDocs.id,
                            song,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            _buildMiniPlayer(),
          ],
        ),
      ),
    );
  }
}
