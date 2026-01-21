import 'dart:convert'; // Necesario para JSON
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http; // Necesario para conectar al Backend

void main() {
  runApp(const AttendanceApp());
}

// ==========================================
// ⚙️ CONFIGURACIÓN DE CONEXIÓN
// ==========================================
class ApiConfig {
  // Tu URL de Ngrok
  static const String baseUrl = 'https://necole-nonburnable-daniel.ngrok-free.dev/api';
}

// ==========================================
// 🎨 DESIGN SYSTEM & THEME
// ==========================================

class AppColors {
  static const Color primaryRed = Color(0xFFD82F20);
  static const Color buttonYellow = Color(0xFFD89A38);
  static const Color neutralGrey = Color(0xFF797979);
  static const Color white = Colors.white;
  static const Color lightGrey = Color(0xFFF0F0F0);
}

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.neutralGrey,
      primaryColor: AppColors.primaryRed,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryRed,
        primary: AppColors.primaryRed,
        secondary: AppColors.buttonYellow,
        surface: AppColors.white,
      ),
      textTheme: GoogleFonts.robotoTextTheme().apply(
        bodyColor: AppColors.white,
        displayColor: AppColors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primaryRed,
        foregroundColor: AppColors.white,
        centerTitle: true,
        elevation: 4,
        titleTextStyle: GoogleFonts.roboto(
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.buttonYellow,
          foregroundColor: Colors.white,
          elevation: 4,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.roboto(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryRed;
          }
          return AppColors.white;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shadowColor: Colors.black26,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: AppColors.neutralGrey),
      ),
    );
  }
}

// ==========================================
// 🧠 DOMAIN LAYER (Entities)
// ==========================================

class User {
  final String codigo;
  final String nombre;
  final String apellido;
  final String ciudad;

  User({
    required this.codigo,
    required this.nombre,
    required this.apellido,
    required this.ciudad,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      codigo: json['codigo'] ?? '',
      nombre: json['nombre'] ?? '',
      apellido: json['apellido'] ?? '',
      ciudad: json['ciudad'] ?? '',
    );
  }
}

class Vendor {
  final String id;
  final String name;
  final DateTime? lastVisit;

  Vendor({
    required this.id, 
    required this.name,
    this.lastVisit,
  });

  factory Vendor.fromJson(Map<String, dynamic> json) {
    return Vendor(
      id: json['id_vendedor'].toString(),
      name: json['nombre_tienda'] ?? 'Sin Nombre',
      lastVisit: json['ultima_visita'] != null 
          ? DateTime.parse(json['ultima_visita']) 
          : null,
    );
  }
}

// ==========================================
// 💾 DATA LAYER (Repositories & Sources)
// ==========================================

class UserRepository {
  // ⚠️ IMPORTANTE: Estas cabeceras evitan que Ngrok bloquee la app
  final Map<String, String> _headers = {
    "Content-Type": "application/json",
    "ngrok-skip-browser-warning": "true", 
  };

  Future<User?> login(String codigo, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/login'),
        headers: _headers, // Usamos las cabeceras aquí
        body: jsonEncode({
          "codigo": codigo,
          "password": password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return User.fromJson(data);
      } else {
        print("Login fallido: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Error de conexión: $e");
      throw Exception("Error de conexión con el servidor");
    }
  }

  Future<List<Vendor>> getVendorsForUser(String userCode) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/vendors?userCode=$userCode'),
        headers: _headers, // Usamos las cabeceras aquí
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Vendor.fromJson(json)).toList();
      } else {
        throw Exception('Error al cargar vendedores: ${response.statusCode}');
      }
    } catch (e) {
      print("Error fetching vendors: $e");
      return [];
    }
  }
}

class AttendanceService {
  Future<Position> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('Servicios de ubicación desactivados.');

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) throw Exception('Permisos denegados.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Permisos denegados permanentemente.');
    }
    return await Geolocator.getCurrentPosition();
  }

  bool isVendorLocked(Vendor vendor) {
    if (vendor.lastVisit == null) return false;

    final now = DateTime.now();
    final difference = now.difference(vendor.lastVisit!);
    
    return difference.inHours < 7;
  }

  Future<void> markVendors(String userCode, List<String> vendorIds, Position position) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/attendance'),
        headers: {
          "Content-Type": "application/json",
          "ngrok-skip-browser-warning": "true", // Cabecera obligatoria
        },
        body: jsonEncode({
          "userCode": userCode,
          "vendorIds": vendorIds,
          "lat": position.latitude,
          "lng": position.longitude
        }),
      );

      if (response.statusCode != 200) {
        throw Exception("Error al guardar en base de datos: ${response.body}");
      }
    } catch (e) {
      throw Exception("Error de red: $e");
    }
  }
}

// ==========================================
// 📱 PRESENTATION LAYER (Screens)
// ==========================================

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestión Vendedores',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const LoginScreen(),
    );
  }
}

// --- Login Screen ---

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _codeController = TextEditingController();
  final _passController = TextEditingController();
  final _repo = UserRepository();
  bool _isLoading = false;

void _handleLogin() async {
    setState(() => _isLoading = true);
    
    try {
      print("Intentando conectar a: ${ApiConfig.baseUrl}/login"); // Log para consola
      final user = await _repo.login(_codeController.text, _passController.text);
      
      if (user != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => VendorListScreen(user: user)),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Credenciales incorrectas o usuario no encontrado"),
            backgroundColor: AppColors.primaryRed,
          ),
        );
      }
    } catch (e) {
      // AQUÍ ESTÁ LA CLAVE: Mostramos el error real en la pantalla
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("ERROR TÉCNICO: $e"), // <--- Esto nos dirá qué pasa
            backgroundColor: Colors.purple, // Color diferente para distinguir
            duration: const Duration(seconds: 10), // Que dure bastante para leerlo
          ),
        );
        print("ERROR COMPLETO EN CONSOLA: $e");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.business, size: 60, color: AppColors.primaryRed),
              ),
              const SizedBox(height: 30),
              Text(
                "Gestión de Asistencia",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
              ),
              const SizedBox(height: 40),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _codeController,
                        style: const TextStyle(color: Colors.black),
                        decoration: const InputDecoration(
                          hintText: "Código de usuario",
                          prefixIcon: Icon(Icons.person, color: AppColors.primaryRed),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passController,
                        obscureText: true,
                        style: const TextStyle(color: Colors.black),
                        decoration: const InputDecoration(
                          hintText: "Contraseña",
                          prefixIcon: Icon(Icons.lock, color: AppColors.primaryRed),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text("INGRESAR"),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Vendor List Screen (Checklist) ---

class VendorListScreen extends StatefulWidget {
  final User user;
  const VendorListScreen({super.key, required this.user});

  @override
  State<VendorListScreen> createState() => _VendorListScreenState();
}

class _VendorListScreenState extends State<VendorListScreen> {
  final _repo = UserRepository();
  final _service = AttendanceService();
  
  List<Vendor> _allVendors = [];
  final Set<String> _selectedVendorIds = {};
  bool _isLoadingData = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadVendorsAndStatus();
  }

  Future<void> _loadVendorsAndStatus() async {
    try {
      final vendors = await _repo.getVendorsForUser(widget.user.codigo);
      setState(() {
        _allVendors = vendors;
        _isLoadingData = false;
      });
    } catch (e) {
      setState(() => _isLoadingData = false);
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error cargando asesores. Revisa tu conexión.")),
        );
      }
    }
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      if (value == true) {
        for (var v in _allVendors) {
          if (!_service.isVendorLocked(v)) {
            _selectedVendorIds.add(v.id);
          }
        }
      } else {
        _selectedVendorIds.clear();
      }
    });
  }

  Future<void> _submitAttendance() async {
    if (_selectedVendorIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecciona al menos un asesor disponible.")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final position = await _service.getCurrentLocation();
      await _service.markVendors(widget.user.codigo, _selectedVendorIds.toList(), position);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SummaryScreen(
              user: widget.user,
              position: position,
              vendorsCount: _selectedVendorIds.length,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableVendors = _allVendors.where((v) => !_service.isVendorLocked(v)).toList();
    final allSelected = availableVendors.isNotEmpty && 
                        availableVendors.every((v) => _selectedVendorIds.contains(v.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Seleccionar Asesores"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            ),
          )
        ],
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator(color: AppColors.buttonYellow))
          : Column(
              children: [
                // 1. HEADER
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.black12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Hola, ${widget.user.nombre}",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Registra a los asesores que esten presentes ahora.",
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),

                // 2. CHECKBOX MAESTRO
                if (availableVendors.isNotEmpty)
                  Container(
                    color: AppColors.white,
                    child: CheckboxListTile(
                      title: const Text(
                        "Registrar a todos tus asesores",
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryRed),
                      ),
                      value: allSelected,
                      onChanged: _toggleSelectAll,
                      activeColor: AppColors.primaryRed,
                    ),
                  ),

                // 3. LISTA
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 20, left: 8, right: 8),
                    itemCount: _allVendors.length,
                    itemBuilder: (context, index) {
                      final vendor = _allVendors[index];
                      final isLocked = _service.isVendorLocked(vendor);
                      final isSelected = _selectedVendorIds.contains(vendor.id);

                      return Card(
                        color: isLocked ? Colors.grey.shade300 : AppColors.white,
                        child: CheckboxListTile(
                          title: Text(
                            vendor.name,
                            style: TextStyle(
                              color: isLocked ? Colors.grey : Colors.black87,
                              decoration: isLocked ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          subtitle: isLocked 
                            ? const Text("Ya fue registrada su asistencia", style: TextStyle(color: AppColors.primaryRed, fontSize: 12)) 
                            : null,
                          value: isLocked ? true : isSelected,
                          onChanged: isLocked
                              ? null 
                              : (bool? value) {
                                  setState(() {
                                    if (value == true) {
                                      _selectedVendorIds.add(vendor.id);
                                    } else {
                                      _selectedVendorIds.remove(vendor.id);
                                    }
                                  });
                                },
                          activeColor: isLocked ? Colors.grey : AppColors.primaryRed,
                          checkColor: Colors.white,
                        ),
                      );
                    },
                  ),
                ),

                // 4. BOTÓN
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.neutralGrey,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        offset: const Offset(0, -2),
                        blurRadius: 4,
                      )
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSubmitting || availableVendors.isEmpty ? null : _submitAttendance,
                          icon: const Icon(Icons.check_circle_outline),
                          label: _isSubmitting
                              ? const Text("PROCESANDO...")
                              : const Text("REGISTRAR ASISTENCIA"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.buttonYellow,
                            disabledBackgroundColor: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// --- Summary Screen ---

class SummaryScreen extends StatelessWidget {
  final User user;
  final Position position;
  final int vendorsCount;

  const SummaryScreen({
    super.key,
    required this.user,
    required this.position,
    required this.vendorsCount,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr = DateFormat('dd/MM/yyyy').format(now);
    final timeStr = DateFormat('HH:mm').format(now);

    return Scaffold(
      backgroundColor: AppColors.neutralGrey,
      appBar: AppBar(title: const Text("Resumen del Registro")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.verified,
                size: 80,
                color: AppColors.buttonYellow,
              ),
              const SizedBox(height: 20),
              Text(
                "¡Registro Exitoso!",
                style: GoogleFonts.roboto(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.white,
                ),
              ),
              const SizedBox(height: 30),
              
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildRow(Icons.calendar_today, "Fecha", dateStr),
                      const Divider(),
                      _buildRow(Icons.access_time, "Hora", timeStr),
                      const Divider(),
                      _buildRow(Icons.people_alt, "Asesores", "$vendorsCount registrados"),
                      const Divider(),
                      _buildRow(Icons.person, "Usuario", "${user.nombre} ${user.apellido}"),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                  child: const Text("VOLVER AL INICIO"),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryRed, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.neutralGrey,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}