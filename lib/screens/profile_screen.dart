import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart'; // NECESARIO AHORA AQUÍ TAMBIÉN
import 'upload_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;

  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? currentUser;
  final TextEditingController _usernameController = TextEditingController();
  
  late String targetUid;
  bool isMyProfile = false;
  bool _isEditing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    currentUser = FirebaseAuth.instance.currentUser;
    targetUid = widget.userId ?? currentUser?.uid ?? '';
    isMyProfile = (currentUser != null && targetUid == currentUser!.uid);
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.white),
                title: const Text('Abrir Galería', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _uploadProfileImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.white),
                title: const Text('Tomar Foto', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _uploadProfileImage(ImageSource.camera);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Future<void> _uploadProfileImage(ImageSource source) async {
    final picker = ImagePicker();
    
    try {
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (pickedFile == null) return;

      setState(() => _isLoading = true);

      File file = File(pickedFile.path);
      String refPath = 'profile_images/$targetUid.jpg';
      
      TaskSnapshot snapshot = await FirebaseStorage.instance.ref(refPath).putFile(file);
      String downloadUrl = await snapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(targetUid).update({
        'profileImageUrl': downloadUrl,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto de perfil actualizada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir imagen: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateUsername() async {
    if (!isMyProfile || _usernameController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);
    final newUsername = _usernameController.text.trim();

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      final userRef = firestore.collection('users').doc(targetUid);
      batch.set(userRef, {'username': newUsername}, SetOptions(merge: true));

      final songsQuery = await firestore
          .collection('songs')
          .where('artistId', isEqualTo: targetUid)
          .get();

      for (var doc in songsQuery.docs) {
        batch.update(doc.reference, {'artistName': newUsername});
      }

      await batch.commit();
      
      setState(() {
        _isEditing = false;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil actualizado.'),
            backgroundColor: Color(0xFF1DB954),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  // --- FUNCIÓN PARA ABRIR EL EDITOR AVANZADO ---
  void _openEditSongDialog(Map<String, dynamic> songData, String songId) {
    showDialog(
      context: context,
      builder: (context) => EditSongDialog(
        songId: songId,
        currentTitle: songData['title'] ?? '',
        currentImageUrl: songData['imageUrl'] ?? '',
        currentAudioUrl: songData['audioUrl'] ?? '',
        currentPresetUrl: songData['presetUrl'] ?? '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (targetUid.isEmpty) return const Scaffold(body: Center(child: Text("Usuario no encontrado")));

    return Scaffold(
      appBar: AppBar(
        title: Text(isMyProfile ? "Mi Perfil" : "Perfil de Artista"),
        actions: [
          if (isMyProfile)
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              onPressed: _logout,
              tooltip: "Cerrar Sesión",
            )
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(targetUid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF1DB954)));
          }

          var userData = snapshot.data!.exists 
              ? snapshot.data!.data() as Map<String, dynamic> 
              : <String, dynamic>{};
              
          String role = userData['role'] ?? 'user';
          String email = userData['email'] ?? ''; 
          String currentUsername = userData['username'] ?? email.split('@')[0];
          String? profileImageUrl = userData['profileImageUrl'];

          if (!_isEditing) {
            _usernameController.text = currentUsername;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Center(
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF1DB954), width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey[850],
                          backgroundImage: (profileImageUrl != null && profileImageUrl.isNotEmpty)
                              ? NetworkImage(profileImageUrl)
                              : null,
                          child: (profileImageUrl == null || profileImageUrl.isEmpty)
                              ? const Icon(Icons.person, size: 60, color: Colors.white54)
                              : null,
                        ),
                      ),
                      if (isMyProfile)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _isLoading ? null : _showImagePickerOptions,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color(0xFF1DB954),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                Text(
                  currentUsername,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                if (isMyProfile && email.isNotEmpty)
                  Text(email, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                
                const SizedBox(height: 30),

                if (isMyProfile) ...[
                  const Align(alignment: Alignment.centerLeft, child: Text("EDITAR NOMBRE", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold))),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _usernameController,
                          enabled: _isEditing && !_isLoading,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          decoration: InputDecoration(
                            hintText: "Tu nombre artístico",
                            filled: true,
                            fillColor: _isEditing ? Colors.grey[900] : Colors.transparent,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: _isEditing ? const BorderSide(color: Color(0xFF1DB954)) : BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      if (_isLoading)
                        const Padding(padding: EdgeInsets.all(12.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                      else
                        IconButton(
                          icon: Icon(_isEditing ? Icons.check_circle : Icons.edit, color: const Color(0xFF1DB954)),
                          onPressed: () {
                            if (_isEditing) {
                              _updateUsername();
                            } else {
                              setState(() => _isEditing = true);
                            }
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],

                if (isMyProfile && role == 'artist') ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const UploadScreen())),
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text('SUBIR NUEVO TEMA'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[900],
                        foregroundColor: const Color(0xFF1DB954),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        side: const BorderSide(color: Color(0xFF1DB954)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],

                const Divider(color: Colors.white24),
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerLeft, child: Text("CANCIONES DE ${currentUsername.toUpperCase()}", style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 1.0))),
                const SizedBox(height: 10),

                if (email.isNotEmpty)
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('songs')
                        .where('artistEmail', isEqualTo: email) 
                        .orderBy('uploadedAt', descending: true)
                        .snapshots(),
                    builder: (context, songSnapshot) {
                      if (songSnapshot.hasError) return Text("Error: ${songSnapshot.error}", style: const TextStyle(color: Colors.red));
                      if (songSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                      
                      if (!songSnapshot.hasData || songSnapshot.data!.docs.isEmpty) {
                        return Padding(padding: const EdgeInsets.all(20.0), child: Text("Este artista aún no ha subido canciones.", style: TextStyle(color: Colors.grey[600])));
                      }

                      var songs = songSnapshot.data!.docs;

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: songs.length,
                        itemBuilder: (context, index) {
                          var song = songs[index].data() as Map<String, dynamic>;
                          String songId = songs[index].id;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: song['imageUrl'] != null && song['imageUrl'].isNotEmpty
                                    ? DecorationImage(image: NetworkImage(song['imageUrl']), fit: BoxFit.cover)
                                    : null,
                                color: Colors.grey[800],
                              ),
                              child: (song['imageUrl'] == null || song['imageUrl'].isEmpty)
                                  ? const Icon(Icons.music_note, color: Colors.white54)
                                  : null,
                            ),
                            title: Text(song['title'] ?? 'Sin título', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                            subtitle: Text("${song['likes'] ?? 0} Likes", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                            trailing: isMyProfile 
                              ? IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.white70),
                                  onPressed: () => _openEditSongDialog(song, songId),
                                )
                              : null,
                          );
                        },
                      );
                    },
                  )
                else
                  const Padding(padding: EdgeInsets.all(20), child: Text("Cargando canciones...", style: TextStyle(color: Colors.grey))),
                  
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }
}

// =======================================================
// WIDGET DE EDICIÓN AVANZADA (Título, Imagen, Audio, Preset)
// =======================================================
class EditSongDialog extends StatefulWidget {
  final String songId;
  final String currentTitle;
  final String currentImageUrl;
  final String currentAudioUrl;
  final String currentPresetUrl;

  const EditSongDialog({
    super.key,
    required this.songId,
    required this.currentTitle,
    required this.currentImageUrl,
    required this.currentAudioUrl,
    required this.currentPresetUrl,
  });

  @override
  State<EditSongDialog> createState() => _EditSongDialogState();
}

class _EditSongDialogState extends State<EditSongDialog> {
  final TextEditingController _titleController = TextEditingController();
  
  // Archivos nuevos (si se seleccionan)
  File? _newImageFile;
  File? _newAudioFile;
  File? _newPresetFile;
  String? _newPresetName; // Para mostrar el nombre del archivo seleccionado

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.currentTitle;
  }

  // Pickers
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _newImageFile = File(picked.path));
    }
  }

  Future<void> _pickAudio() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null) {
      setState(() => _newAudioFile = File(result.files.single.path!));
    }
  }

  Future<void> _pickPreset() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null) {
      setState(() {
        _newPresetFile = File(result.files.single.path!);
        _newPresetName = result.files.single.name;
      });
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    
    try {
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      Map<String, dynamic> updates = {};

      // 1. Título
      if (_titleController.text.trim() != widget.currentTitle) {
        updates['title'] = _titleController.text.trim();
      }

      // 2. Imagen
      if (_newImageFile != null) {
        // Usamos timestamp para evitar caché
        String path = 'covers/${widget.songId}_$timestamp.jpg';
        TaskSnapshot snap = await FirebaseStorage.instance.ref(path).putFile(_newImageFile!);
        updates['imageUrl'] = await snap.ref.getDownloadURL();
      }

      // 3. Audio
      if (_newAudioFile != null) {
        String path = 'songs/${widget.songId}_$timestamp.mp3';
        TaskSnapshot snap = await FirebaseStorage.instance.ref(path).putFile(_newAudioFile!);
        updates['audioUrl'] = await snap.ref.getDownloadURL();
      }

      // 4. Preset
      if (_newPresetFile != null) {
        String path = 'presets/${widget.songId}/$_newPresetName';
        TaskSnapshot snap = await FirebaseStorage.instance.ref(path).putFile(_newPresetFile!);
        updates['presetUrl'] = await snap.ref.getDownloadURL();
      }

      // 5. Aplicar cambios en Firestore
      if (updates.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('songs')
            .doc(widget.songId)
            .update(updates);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Canción actualizada con éxito')),
        );
      }

    } catch (e) {
      print(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF282828),
      title: const Text("Editar Canción", style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // TÍTULO
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Título",
                labelStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF1DB954))),
              ),
            ),
            const SizedBox(height: 20),

            // IMAGEN
            Row(
              children: [
                Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(5),
                    image: _newImageFile != null
                        ? DecorationImage(image: FileImage(_newImageFile!), fit: BoxFit.cover)
                        : (widget.currentImageUrl.isNotEmpty 
                            ? DecorationImage(image: NetworkImage(widget.currentImageUrl), fit: BoxFit.cover)
                            : null),
                  ),
                  child: (_newImageFile == null && widget.currentImageUrl.isEmpty) 
                      ? const Icon(Icons.music_note, color: Colors.white24) : null,
                ),
                const SizedBox(width: 15),
                TextButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image, color: Color(0xFF1DB954)),
                  label: Text(_newImageFile == null ? "Cambiar Portada" : "Imagen Seleccionada", 
                      style: const TextStyle(color: Colors.white70)),
                )
              ],
            ),
            const SizedBox(height: 15),

            // AUDIO
            Row(
              children: [
                const Icon(Icons.audio_file, color: Colors.white54),
                const SizedBox(width: 15),
                Expanded(
                  child: TextButton(
                    onPressed: _pickAudio,
                    style: TextButton.styleFrom(alignment: Alignment.centerLeft),
                    child: Text(
                      _newAudioFile == null ? "Cambiar Audio (.mp3)" : "Nuevo audio seleccionado",
                      style: TextStyle(color: _newAudioFile == null ? const Color(0xFF1DB954) : Colors.greenAccent),
                    ),
                  ),
                ),
              ],
            ),

            // PRESET
            Row(
              children: [
                const Icon(Icons.settings_suggest, color: Colors.white54),
                const SizedBox(width: 15),
                Expanded(
                  child: TextButton(
                    onPressed: _pickPreset,
                    style: TextButton.styleFrom(alignment: Alignment.centerLeft),
                    child: Text(
                      _newPresetFile == null ? "Cambiar Preset" : "Preset: $_newPresetName",
                      style: TextStyle(color: _newPresetFile == null ? const Color(0xFF1DB954) : Colors.greenAccent),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancelar", style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveChanges,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1DB954)),
          child: _isSaving 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text("Guardar Cambios", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}