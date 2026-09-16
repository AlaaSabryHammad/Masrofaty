import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../core/services/storage_service.dart';
import '../models/contact_model.dart';
import '../models/debt_model.dart';

class ContactProvider extends ChangeNotifier {
  final StorageService _storage;
  final Uuid _uuid = const Uuid();

  List<ContactModel> _contacts = [];
  String _searchQuery = '';
  String _selectedRelationship = 'all';

  ContactProvider(this._storage) {
    _loadContacts();
  }

  List<ContactModel> get contacts => _contacts;
  String get searchQuery => _searchQuery;
  String get selectedRelationship => _selectedRelationship;

  List<ContactModel> get filteredContacts {
    return _contacts.where((c) {
      final matchesQuery = _searchQuery.isEmpty ||
          c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (c.phone != null && c.phone!.contains(_searchQuery));
      final matchesRel = _selectedRelationship == 'all' || c.relationship == _selectedRelationship;
      return matchesQuery && matchesRel;
    }).toList();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedRelationship(String rel) {
    _selectedRelationship = rel;
    notifyListeners();
  }

  void _loadContacts() {
    _contacts = _storage.loadContacts();
  }

  void reload() {
    _loadContacts();
    notifyListeners();
  }

  /// Auto-discovers and syncs contacts from debts list
  void syncFromDebts(List<DebtModel> debts) {
    bool hasNew = false;
    for (final debt in debts) {
      final trimmedName = debt.personName.trim();
      if (trimmedName.isEmpty) continue;
      final exists = _contacts.any((c) => c.name.trim().toLowerCase() == trimmedName.toLowerCase());
      if (!exists) {
        _contacts.add(
          ContactModel(
            id: _uuid.v4(),
            name: trimmedName,
            phone: debt.phone,
            relationship: 'friend',
            createdAt: debt.createdDate,
          ),
        );
        hasNew = true;
      }
    }
    if (hasNew) {
      _saveContacts();
      notifyListeners();
    }
  }

  ContactModel? getContactById(String id) {
    try {
      return _contacts.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  ContactModel? getContactByName(String name) {
    try {
      return _contacts.firstWhere(
        (c) => c.name.trim().toLowerCase() == name.trim().toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  ContactModel getOrCreateContact(String name, {String? phone}) {
    final existing = getContactByName(name);
    if (existing != null) {
      if (phone != null && phone.isNotEmpty && (existing.phone == null || existing.phone!.isEmpty)) {
        final updated = existing.copyWith(phone: phone);
        updateContact(updated);
        return updated;
      }
      return existing;
    }
    final contact = ContactModel(
      id: _uuid.v4(),
      name: name.trim(),
      phone: phone?.trim(),
      relationship: 'friend',
      createdAt: DateTime.now(),
    );
    _contacts.insert(0, contact);
    _saveContacts();
    notifyListeners();
    return contact;
  }

  Future<ContactModel> addContact({
    required String name,
    String? phone,
    String relationship = 'friend',
    String? notes,
  }) async {
    final contact = ContactModel(
      id: _uuid.v4(),
      name: name.trim(),
      phone: phone?.trim(),
      relationship: relationship,
      notes: notes?.trim(),
      createdAt: DateTime.now(),
    );
    _contacts.insert(0, contact);
    await _saveContacts();
    notifyListeners();
    return contact;
  }

  Future<void> updateContact(ContactModel contact) async {
    final index = _contacts.indexWhere((c) => c.id == contact.id);
    if (index != -1) {
      _contacts[index] = contact;
      await _saveContacts();
      notifyListeners();
    }
  }

  Future<void> deleteContact(String id) async {
    _contacts.removeWhere((c) => c.id == id);
    await _saveContacts();
    notifyListeners();
  }

  Future<void> _saveContacts() async {
    await _storage.saveContacts(_contacts);
  }
}
