import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/login_screen.dart';
import 'services/db_service.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    const MaterialApp(home: AuthWrapper(), debugShowCheckedModeBanner: false),
  );
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          // You user is logged in
          return VocachaTest(uid: snapshot.data!.uid);
        }
        // User is not logged in
        return const LoginScreen();
      },
    );
  }
}

class VocachaTest extends StatefulWidget {
  final String uid;

  const VocachaTest({super.key, required this.uid});

  @override
  State<VocachaTest> createState() => _VocachaTestState();
}

class _VocachaTestState extends State<VocachaTest> {
  final DbService _dbService = DbService();
  final AuthService _authService = AuthService();
  int _tokens = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _dbService.initializeUser(widget.uid);
    _dbService.getUserTokensStream(widget.uid).listen((tokens) {
      if (mounted) setState(() => _tokens = tokens);
    });
  }

  void _onLoadingStart() => setState(() => _isLoading = true);
  void _onLoadingEnd() => setState(() => _isLoading = false);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Vocacha'),
          backgroundColor: Colors.amber,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await _authService.signOut();
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: "가챠", icon: Icon(Icons.casino)),
              Tab(text: "인벤토리", icon: Icon(Icons.inventory)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            HomeScreen(
              uid: widget.uid,
              dbService: _dbService,
              tokens: _tokens,
              onLoadingStart: _onLoadingStart,
              onLoadingEnd: _onLoadingEnd,
              isLoading: _isLoading,
            ),
            InventoryScreen(uid: widget.uid, dbService: _dbService),
          ],
        ),
      ),
    );
  }
}
