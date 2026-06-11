import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

void main() {
  runApp(const PokemonApp());
}

class PokemonApp extends StatelessWidget {
  const PokemonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pokémon API',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const PokemonPage(),
    );
  }
}

class PokemonPage extends StatefulWidget {
  const PokemonPage({super.key});

  @override
  State<PokemonPage> createState() => _PokemonPageState();
}

class _PokemonPageState extends State<PokemonPage> {
  final TextEditingController _controller = TextEditingController();
  
// SOLUCIÓN AL DUPLICADO Y NULL SAFETY: Controlamos el offset manualmente protegiendo los nulos
  late final PagingController<int, dynamic> _pagingController =
      PagingController<int, dynamic>(
    getNextPageKey: (state) {
      // Si la última página vino vacía, detenemos el scroll (retorna null)
      if (state.lastPageIsEmpty) return null;
      
      // Si las páginas son nulas o están vacías, significa que es la primera carga y empezamos en offset 0
      if (state.pages == null || state.pages!.isEmpty) return 0;

      // Accedemos a la última clave de forma segura con '?.' 
      // Si por alguna razón llega a ser nulo, usamos '?? 0' como respaldo y le sumamos 5
      final lastKey = state.keys?.last ?? 0;
      
      return lastKey + 5;
    },
    fetchPage: fetchPage,
  );

  // Actividad 2: Trae los Pokémon de 5 en 5 (Nombre y URL de detalle)
  Future<List<dynamic>> fetchPage(int pageKey) async {
    try {
      final response = await http.get(
        Uri.parse('https://pokeapi.co/api/v2/pokemon?limit=5&offset=$pageKey'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<dynamic>.from(data['results']);
      } else {
        throw Exception('Error al cargar la página');
      }
    } catch (e) {
      throw Exception('Error de red: $e');
    }
  }

  @override
  void dispose() {
    _pagingController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pokémon List'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: PagingListener(
                controller: _pagingController,
                builder: (context, state, fetchNextPage) {
                  return PagedListView<int, dynamic>(
                    state: state,
                    fetchNextPage: fetchNextPage,
                    builderDelegate: PagedChildBuilderDelegate(
                      itemBuilder: (context, item, index) {
                        return PokemonDetailCard(
                          url: item['url'],
                          index: index,
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
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// WIDGET PARA MOSTRAR DETALLES REALES (Actividad 1)
// ═════════════════════════════════════════════════════════════════════════════
class PokemonDetailCard extends StatelessWidget {
  final String url;
  final int index;

  const PokemonDetailCard({
    super.key,
    required this.url,
    required this.index,
  });

  Future<Map<String, dynamic>> _fetchPokemonDetails() async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Error al cargar detalles');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchPokemonDetails(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            margin: EdgeInsets.all(8),
            child: ListTile(
              title: Text('Cargando datos del Pokémon...'),
              trailing: Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return const Card(
            margin: EdgeInsets.all(8),
            child: ListTile(
              title: Text('Error al cargar este Pokémon'),
            ),
          );
        }

        final pokemonData = snapshot.data!;
        final spriteUrl = pokemonData['sprites']['front_default'] ?? '';
        
        final List typesList = pokemonData['types'];
        final types = typesList
            .map((t) => t['type']['name'].toString().toUpperCase())
            .join(', ');

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          elevation: 3,
          child: ListTile(
            leading: spriteUrl.isNotEmpty
                ? Image.network(
                    spriteUrl,
                    width: 60,
                    height: 60,
                    errorBuilder: (c, e, s) => const Icon(Icons.broken_image),
                  )
                : const Icon(Icons.catching_pokemon, size: 40),
            title: Text(
              '#${index + 1} - ${pokemonData['name'].toString().toUpperCase()}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text('Tipo(s): $types'),
            trailing: Text('Peso: ${pokemonData['weight']}'),
          ),
        );
      },
    );
  }
}