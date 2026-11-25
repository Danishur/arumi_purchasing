import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/currency_provider.dart';
import 'providers/customer_provider.dart';
import 'providers/material_provider.dart';
import 'providers/rfq_provider.dart';
import 'providers/vendor_provider.dart';
import 'screens/home_screen.dart';
import 'utils/app_theme.dart';
import 'utils/dropdown_options_cache.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider(create: (_) => VendorProvider()),
        ChangeNotifierProvider(create: (_) => MaterialProvider()),
        ChangeNotifierProvider(create: (_) => RfqProvider()),
        ChangeNotifierProvider(create: (_) => CurrencyProvider()),
      ],
      child: MaterialApp(
        title: 'Purchasing Intermediary',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          scaffoldBackgroundColor: AppColors.background,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            primary: AppColors.primary,
            secondary: AppColors.secondary,
          ),
          useMaterial3: true,
        ),
        // 5 modul aktif (Customer, Vendor, Material, RFQ) + Settings
        // (Edit Dropdown & Update Valuta) lewat HomeScreen (menu navigasi).
        home: const _AppLoader(),
      ),
    );
  }
}

/// TAMBAHAN: memuat [DropdownOptionsCache] (isi semua dropdown yang
/// sekarang bisa diedit lewat Settings > Edit Dropdown) sekali di awal,
/// SEBELUM HomeScreen ditampilkan -- supaya waktu user buka form apa
/// pun, isi dropdown-nya sudah pasti sinkron dengan data terbaru di
/// database. Kalau database belum bisa diakses saat ini (mis. masih
/// loading koneksi), app tetap lanjut jalan seperti biasa dengan nilai
/// default (lihat DropdownOptionsCache.loadAll()).
class _AppLoader extends StatefulWidget {
  const _AppLoader();

  @override
  State<_AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<_AppLoader> {
  late final Future<void> _ready;

  @override
  void initState() {
    super.initState();
    _ready = DropdownOptionsCache.loadAll();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return const HomeScreen();
      },
    );
  }
}
