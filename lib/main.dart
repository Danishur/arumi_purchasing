import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/customer_provider.dart';
import 'providers/vendor_provider.dart';
import 'screens/home_screen.dart';
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
        ChangeNotifierProvider(create: (_) => VendorProvider()),
        // Provider modul lain (Material, RFQ) menyusul di minggu-minggu
        // berikutnya sesuai timeline.
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
        // Sekarang sudah ada 2 modul aktif (Customer & Vendor), jadi
        // home diganti ke HomeScreen (menu navigasi) -- sebelumnya
        // langsung ke CustomerListScreen waktu modul Vendor belum ada.
        home: const HomeScreen(),
      ),
    );
  }
}
