import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'feed_screen.dart'; // Pestaña 1
import 'favorites_screen.dart'; // Pestaña 2
import 'profile_screen.dart'; // Pestaña 3

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 1. Instanciamos el Reproductor AQUÍ (en el padre)
  // para poder pasárselo a las pestañas y que compartan la música.
  late AudioPlayer _player;

  // Índice de la pestaña actual (0: Inicio, 1: Favoritos, 2: Perfil)
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Lista de las 3 pantallas, pasándoles el reproductor
    final List<Widget> pages = [
      FeedScreen(player: _player),
      FavoritesScreen(player: _player),
      const ProfileScreen(),
    ];

    return Scaffold(
      // Usamos IndexedStack para mantener el estado de las pantallas
      // (así la lista no se recarga cada vez que cambias de pestaña)
      body: IndexedStack(index: _currentIndex, children: pages),

      // BARRA DE NAVEGACIÓN INFERIOR
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          indicatorColor: const Color(0xFF1DB954).withOpacity(0.2),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
        child: NavigationBar(
          height: 70,
          backgroundColor: Colors.black, // Fondo negro puro
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() => _currentIndex = index);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, color: Colors.grey),
              selectedIcon: Icon(Icons.home, color: Color(0xFF1DB954)),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(Icons.favorite_outline, color: Colors.grey),
              selectedIcon: Icon(Icons.favorite, color: Color(0xFF1DB954)),
              label: 'Favoritos',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline, color: Colors.grey),
              selectedIcon: Icon(Icons.person, color: Color(0xFF1DB954)),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}
