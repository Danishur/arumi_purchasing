import 'package:flutter/material.dart';
import '../models/customer.dart';
import '../models/customer_contact.dart';
import '../services/database_service.dart';

class CustomerProvider extends ChangeNotifier {
  List<Customer> _customers = [];
  List<Customer> get customers => _customers;

  /// Dipakai layar list Customer. SENGAJA tidak memuat PIC/kontak di
  /// sini (biar tidak query berkali-kali untuk tiap baris customer di
  /// list) -- kontak baru diambil belakangan lewat [getContactsForCustomer]
  /// saat user benar-benar buka form edit customer tertentu.
  Future<void> loadCustomers() async {
    final data = await DatabaseService.instance.getCustomers();
    _customers = data.map((e) => Customer.fromMap(e)).toList();
    notifyListeners();
  }

  /// Diambil terpisah (on-demand) saat form edit dibuka, supaya layar
  /// list tidak perlu N query sekaligus (1 query customers + N query
  /// contacts untuk tiap baris) yang bisa bikin lambat kalau datanya
  /// sudah banyak nanti.
  Future<List<CustomerContact>> getContactsForCustomer(int customerId) async {
    final data = await DatabaseService.instance.getContactsByCustomerId(customerId);
    return data.map((e) => CustomerContact.fromMap(e)).toList();
  }

  Future<void> addCustomer(Customer customer, List<CustomerContact> contacts) async {
    await DatabaseService.instance.insertCustomer(
      customer.toMap(),
      contacts.map((c) => c.toMap()).toList(),
    );
    await loadCustomers();
  }

  Future<void> updateCustomer(Customer customer, List<CustomerContact> contacts) async {
    await DatabaseService.instance.updateCustomer(
      customer.toMap(),
      contacts.map((c) => c.toMap()).toList(),
    );
    await loadCustomers();
  }

  Future<void> deleteCustomer(int id) async {
    await DatabaseService.instance.deleteCustomer(id);
    await loadCustomers();
  }

  /// Hapus beberapa customer sekaligus (fitur select multi di layar list).
  Future<void> deleteCustomers(List<int> ids) async {
    await DatabaseService.instance.deleteCustomers(ids);
    await loadCustomers();
  }

  /// Ambil ulang 1 customer terbaru dari list yang sudah dimuat (dipakai
  /// layar Detail setelah balik dari Edit, supaya tampilannya ikut update
  /// tanpa perlu query manual terpisah).
  Customer? findById(int id) {
    for (final c in _customers) {
      if (c.id == id) return c;
    }
    return null;
  }
}
