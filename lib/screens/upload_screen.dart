import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final TextEditingController _titleController = TextEditingController();

  File? _audioFile;
  File? _imageFile;
  File? _presetFile;

  String? _audioFileName;
  String? _presetFileName;

  bool _isUploading = false;

  // Seleccionar Audio (.mp3, .wav, etc)
  Future<void> _pickAudio() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );

    if (result != null) {
      setState(() {
        _audioFile = File(result.files.single.path!);
        _audioFileName = result.files.single.name;
      });
    }
  }

  // Seleccionar Preset (CUALQUIER EXTENSIÓN, MÁX 1MB)
  Future<void> _pickPreset() async {
    try {
      // type: FileType.any permite cualquier extensión
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null) {
        File file = File(result.files.single.path!);

        // Validación de tamaño (1MB = 1024 * 1024 bytes)
        int sizeInBytes = await file.length();
        if (sizeInBytes > 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('El archivo supera el límite de 1MB'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        setState(() {
          _presetFile = file;
          _presetFileName = result.files.single.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar archivo: $e')),
        );
      }
    }
  }

  // Seleccionar Imagen (Carátula)
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  // Subir Canción a Firebase
  Future<void> _uploadSong() async {
    if (_audioFile == null || _titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falta el audio o el título')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 1. Obtener datos actualizados del artista
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      String artistName = user.email!.split('@')[0];
      if (userDoc.exists) {
        var data = userDoc.data() as Map<String, dynamic>;
        if (data.containsKey('username') &&
            data['username'].toString().isNotEmpty) {
          artistName = data['username'];
        }
      }

      String songId = DateTime.now().millisecondsSinceEpoch.toString();

      // 2. Subir Audio
      String audioPath = 'songs/$songId.mp3';
      TaskSnapshot audioSnap = await FirebaseStorage.instance
          .ref(audioPath)
          .putFile(_audioFile!);
      String audioUrl = await audioSnap.ref.getDownloadURL();

      // 3. Subir Imagen (si existe)
      String imageUrl = '';
      if (_imageFile != null) {
        String imagePath = 'covers/$songId.jpg';
        TaskSnapshot imageSnap = await FirebaseStorage.instance
            .ref(imagePath)
            .putFile(_imageFile!);
        imageUrl = await imageSnap.ref.getDownloadURL();
      }

      // 4. Subir Preset (si existe)
      String presetUrl = '';
      if (_presetFile != null) {
        // Usamos el nombre original para mantener la extensión
        String presetPath = 'presets/$songId/$_presetFileName';
        TaskSnapshot presetSnap = await FirebaseStorage.instance
            .ref(presetPath)
            .putFile(_presetFile!);
        presetUrl = await presetSnap.ref.getDownloadURL();
      }

      // 5. Guardar en Firestore
      await FirebaseFirestore.instance.collection('songs').doc(songId).set({
        'id': songId,
        'title': _titleController.text.trim(),
        'artistId': user.uid,
        'artistEmail': user.email,
        'artistName': artistName,
        'audioUrl': audioUrl,
        'imageUrl': imageUrl,
        'presetUrl': presetUrl,
        'uploadedAt': FieldValue.serverTimestamp(),
        'likes': 0,
        'likedBy': [],
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Canción y preset subidos con éxito!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al subir: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Subir Canción")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Selección de Imagen (Carátula)
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                width: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(15),
                  image: _imageFile != null
                      ? DecorationImage(
                          image: FileImage(_imageFile!),
                          fit: BoxFit.cover,
                        )
                      : null,
                  border: Border.all(color: Colors.grey[800]!),
                ),
                child: _imageFile == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image, size: 50, color: Colors.white54),
                          SizedBox(height: 10),
                          Text(
                            "Toca para añadir carátula",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 30),

            // Título
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Título de la canción",
                labelStyle: const TextStyle(color: Colors.grey),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey[800]!),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF1DB954)),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Selección de Audio
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[800]!),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.audio_file,
                      color: Color(0xFF1DB954),
                    ),
                    onPressed: _pickAudio,
                  ),
                  Expanded(
                    child: Text(
                      _audioFileName ?? "Seleccionar archivo de audio (.mp3)",
                      style: TextStyle(
                        color: _audioFileName != null
                            ? Colors.white
                            : Colors.grey,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Selección de Preset (Cualquier Archivo)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[800]!),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.file_present,
                      color: Colors.blueAccent,
                    ),
                    onPressed: _pickPreset,
                  ),
                  Expanded(
                    child: Text(
                      _presetFileName ??
                          "Seleccionar archivo Preset (Opcional)",
                      style: TextStyle(
                        color: _presetFileName != null
                            ? Colors.white
                            : Colors.grey,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_presetFile != null)
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.red,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _presetFile = null;
                          _presetFileName = null;
                        });
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                " Máx. 1MB. Sube tu archivo preset (cualquier formato aceptado)",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),

            const SizedBox(height: 40),

            // Botón de Subida
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _uploadSong,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1DB954),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: _isUploading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "PUBLICAR CANCIÓN",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
