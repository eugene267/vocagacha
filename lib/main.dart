import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/inventory_screen.dart';
import 'services/db_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    const MaterialApp(home: VocachaTest(), debugShowCheckedModeBanner: false),
  );
}

class VocachaTest extends StatefulWidget {
  const VocachaTest({super.key});

  @override
  State<VocachaTest> createState() => _VocachaTestState();
}

class _VocachaTestState extends State<VocachaTest> {
  final String _testUid = "test_user_01";
  final DbService _dbService = DbService();
  int _tokens = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _dbService.initializeUser(_testUid);
    _dbService.getUserTokensStream(_testUid).listen((tokens) {
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
              testUid: _testUid,
              dbService: _dbService,
              tokens: _tokens,
              onLoadingStart: _onLoadingStart,
              onLoadingEnd: _onLoadingEnd,
              isLoading: _isLoading,
            ),
            InventoryScreen(
              testUid: _testUid,
              dbService: _dbService,
            ),
          ],
        ),
      ),
    );
  }
}
