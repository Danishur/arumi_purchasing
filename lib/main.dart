import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/customer_provider.dart';
import 'screens/customer_list_screen.dart';
import 'utils/app_theme.dart';

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
        // Provider modul lain (Vendor, Material, RFQ) menyusul di
        // minggu-minggu berikutnya sesuai timeline.
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
        // Untuk sekarang, home langsung ke Customer (minggu 1 timeline).
        // Nanti kalau modul Vendor/Material/RFQ sudah dibangun, ini akan
        // diganti jadi layar Home dengan navigasi ke semua modul.
        home: const CustomerListScreen(),
      ),
    );
  }
}
