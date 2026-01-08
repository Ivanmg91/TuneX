import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
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
                title: const Text(
                  'Abrir Galería',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _uploadProfileImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.white),
                title: const Text(
                  'Tomar Foto',
                  style: TextStyle(color: Colors.white),
                ),
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

      TaskSnapshot snapshot = await FirebaseStorage.instance
          .ref(refPath)
          .putFile(file);
      String downloadUrl = await snapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUid)
          .update({'profileImageUrl': downloadUrl});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto de perfil actualizada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir imagen: $e'),
            backgroundColor: Colors.red,
          ),
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

  // --- LOGOUT CORREGIDO ---
  Future<void> _logout() async {
    // 1. Limpiamos la navegación actual volviendo a la raíz (para evitar errores de contexto)
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }

    // 2. Cerramos sesión.
    // Al hacer esto, el StreamBuilder en main.dart detectará 'user == null'
    // y cambiará automáticamente la pantalla a LoginScreen de forma limpia.
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    if (targetUid.isEmpty)
      return const Scaffold(body: Center(child: Text("Usuario no encontrado")));

    return Scaffold(
      appBar: AppBar(
        title: Text(isMyProfile ? "Mi Perfil" : "Perfil de Artista"),
        actions: [
          if (isMyProfile)
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              onPressed: _logout,
              tooltip: "Cerrar Sesión",
            ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(targetUid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF1DB954)),
            );
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
                          border: Border.all(
                            color: const Color(0xFF1DB954),
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey[850],
                          backgroundImage:
                              (profileImageUrl != null &&
                                  profileImageUrl.isNotEmpty)
                              ? NetworkImage(profileImageUrl)
                              : null,
                          child:
                              (profileImageUrl == null ||
                                  profileImageUrl.isEmpty)
                              ? const Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Colors.white54,
                                )
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
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (isMyProfile && email.isNotEmpty)
                  Text(
                    email,
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),

                const SizedBox(height: 30),

                if (isMyProfile) ...[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "EDITAR NOMBRE",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _usernameController,
                          enabled: _isEditing && !_isLoading,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            hintText: "Tu nombre artístico",
                            filled: true,
                            fillColor: _isEditing
                                ? Colors.grey[900]
                                : Colors.transparent,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: _isEditing
                                  ? const BorderSide(color: Color(0xFF1DB954))
                                  : BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else
                        IconButton(
                          icon: Icon(
                            _isEditing ? Icons.check_circle : Icons.edit,
                            color: const Color(0xFF1DB954),
                          ),
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
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UploadScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text('SUBIR NUEVO TEMA'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[900],
                        foregroundColor: const Color(0xFF1DB954),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        side: const BorderSide(color: Color(0xFF1DB954)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],

                const Divider(color: Colors.white24),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "CANCIONES DE ${currentUsername.toUpperCase()}",
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                if (email.isNotEmpty)
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('songs')
                        .where('artistEmail', isEqualTo: email)
                        .orderBy('uploadedAt', descending: true)
                        .snapshots(),
                    builder: (context, songSnapshot) {
                      if (songSnapshot.hasError) {
                        return Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Text(
                            "Nota: Si no ves canciones, revisa la consola para crear el índice en Firebase.\nError: ${songSnapshot.error}",
                            style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }
                      if (songSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!songSnapshot.hasData ||
                          songSnapshot.data!.docs.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Text(
                            "Este artista aún no ha subido canciones.",
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        );
                      }

                      var songs = songSnapshot.data!.docs;

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: songs.length,
                        itemBuilder: (context, index) {
                          var song =
                              songs[index].data() as Map<String, dynamic>;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image:
                                    song['imageUrl'] != null &&
                                        song['imageUrl'].isNotEmpty
                                    ? DecorationImage(
                                        image: NetworkImage(song['imageUrl']),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                                color: Colors.grey[800],
                              ),
                              child:
                                  (song['imageUrl'] == null ||
                                      song['imageUrl'].isEmpty)
                                  ? const Icon(
                                      Icons.music_note,
                                      color: Colors.white54,
                                    )
                                  : null,
                            ),
                            title: Text(
                              song['title'] ?? 'Sin título',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              song['artistName'] ?? "Desconocido",
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  )
                else
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      "Cargando canciones...",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),

                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }
}
