import 'dart:io';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

/// Servizio per gestire la selezione e condivisione di contatti
class ContactService {
  
  /// Seleziona un contatto dalla rubrica del telefono
  static Future<ContactData?> pickContact() async {
    try {
      print('📞 ContactService.pickContact - INIZIO selezione contatto');
      
      // Richiedi permessi per accedere ai contatti
      if (!await FlutterContacts.requestPermission(readonly: true)) {
        print('❌ ContactService.pickContact - Permessi contatti negati');
        return null;
      }
      
      print('✅ ContactService.pickContact - Permessi concessi, caricamento contatti...');
      
      // Carica tutti i contatti con i dettagli
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );
      
      print('📞 ContactService.pickContact - Trovati ${contacts.length} contatti');
      
      if (contacts.isEmpty) {
        print('⚠️ ContactService.pickContact - Nessun contatto disponibile');
        return null;
      }
      
      // Ritorna la lista dei contatti per la UI
      // La UI mostrerà un dialog con la lista
      return null; // Temporaneo - verrà gestito dalla UI
      
    } catch (e) {
      print('❌ ContactService.pickContact - Errore selezione contatto: $e');
      return null;
    }
  }
  
  /// Ottiene tutti i contatti dalla rubrica
  static Future<List<Contact>> getAllContacts() async {
    try {
      print('📞 ContactService.getAllContacts - Caricamento contatti...');
      
      // Richiedi permessi per accedere ai contatti
      final permissionGranted = await FlutterContacts.requestPermission(readonly: true);
      print('📞 ContactService.getAllContacts - Permessi: $permissionGranted');
      
      if (!permissionGranted) {
        print('❌ ContactService.getAllContacts - Permessi contatti negati');
        return [];
      }
      
      print('📞 ContactService.getAllContacts - Inizio caricamento da rubrica...');
      
      // Carica tutti i contatti con i dettagli - SENZA filtri
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: true,
        withThumbnail: false,
        withAccounts: false,
        withGroups: false,
        deduplicateProperties: false,
      );
      
      print('✅ ContactService.getAllContacts - Caricati ${contacts.length} contatti dalla rubrica');
      print('📞 ContactService.getAllContacts - Rubrica ha restituito ${contacts.length} records');
      
      // Debug: mostra i primi 5 contatti
      for (int i = 0; i < contacts.length && i < 5; i++) {
        final contact = contacts[i];
        print('   📋 Contatto ${i + 1}: ${contact.displayName} - ${contact.phones.length} numeri');
      }
      
      if (contacts.length > 5) {
        print('   ... e altri ${contacts.length - 5} contatti');
      }
      
      return contacts;
      
    } catch (e) {
      print('❌ ContactService.getAllContacts - Errore: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      return [];
    }
  }
  
  /// Converte un Contact di flutter_contacts in ContactData
  static ContactData contactToContactData(Contact contact) {
    return ContactData(
      name: contact.displayName.isNotEmpty ? contact.displayName : 'Contatto senza nome',
      phoneNumbers: contact.phones.map((phone) => phone.number).where((phone) => phone.isNotEmpty).toList(),
      emails: contact.emails.map((email) => email.address).where((email) => email.isNotEmpty).toList(),
    );
  }
  
  /// Salva un contatto nella rubrica del telefono
  static Future<bool> saveContactToPhone(ContactData contactData) async {
    try {
      print('📞 ContactService.saveContactToPhone - INIZIO salvataggio: ${contactData.name}');
      
      // Richiedi permessi per scrivere i contatti
      if (!await FlutterContacts.requestPermission()) {
        print('❌ ContactService.saveContactToPhone - Permessi contatti negati');
        return false;
      }
      
      // Crea il contatto da salvare
      final newContact = Contact(
        name: Name(first: contactData.name),
        phones: contactData.phoneNumbers.map((phone) => Phone(phone)).toList(),
        emails: contactData.emails.map((email) => Email(email)).toList(),
      );
      
      // Salva il contatto nella rubrica
      await FlutterContacts.insertContact(newContact);
      
      print('✅ ContactService.saveContactToPhone - Contatto salvato con successo');
      return true;
      
    } catch (e) {
      print('❌ ContactService.saveContactToPhone - Errore salvataggio contatto: $e');
      return false;
    }
  }

  /// Formatta un contatto per la visualizzazione in chat
  static String formatContactForDisplay(ContactData contact) {
    String formatted = '👤 ${contact.name}';
    
    if (contact.phoneNumbers.isNotEmpty) {
      formatted += '\n📞 ${contact.phoneNumbers.first}';
    }
    
    if (contact.emails.isNotEmpty) {
      formatted += '\n📧 ${contact.emails.first}';
    }
    
    return formatted;
  }
}

/// Modello dati per un contatto
class ContactData {
  final String name;
  final List<String> phoneNumbers;
  final List<String> emails;
  
  ContactData({
    required this.name,
    required this.phoneNumbers,
    required this.emails,
  });
  
  /// Converte in JSON per l'invio al server
  Map<String, dynamic> toJson() => {
    'name': name,
    'phone_numbers': phoneNumbers,
    'emails': emails,
  };
  
  /// Crea da JSON ricevuto dal server
  factory ContactData.fromJson(Map<String, dynamic> json) {
    // Gestisce sia il formato nuovo (phone_numbers) che quello del backend (phone)
    List<String> phones = [];
    if (json['phone_numbers'] != null) {
      phones = List<String>.from(json['phone_numbers']);
    } else if (json['phone'] != null && json['phone'].toString().isNotEmpty) {
      phones = [json['phone'].toString()];
    }
    
    List<String> emailsList = [];
    if (json['emails'] != null) {
      emailsList = List<String>.from(json['emails']);
    } else if (json['email'] != null && json['email'].toString().isNotEmpty) {
      emailsList = [json['email'].toString()];
    }
    
    return ContactData(
      name: json['name']?.toString() ?? '',
      phoneNumbers: phones,
      emails: emailsList,
    );
  }
}
