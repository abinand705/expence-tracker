import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/sms_models.dart';
import '../models/message_settings.dart';



class SmsService extends ChangeNotifier {
  static final SmsService _instance = SmsService._internal();
  factory SmsService() => _instance;
  SmsService._internal() {
    _initPreferences();
  }

  void refreshAccounts() {
    // Notify listeners so UI redraws and parses balances again
    notifyListeners();
  }

  final List<Conversation> _conversations = [];
  
  List<Conversation> get conversations => _conversations;
  
  List<Conversation> get deletedConversations => 
      _conversations.where((c) => c.isDeleted).toList();

  List<Conversation> get filteredConversations {
    List<Conversation> list = _conversations.where((c) => !c.isDeleted && !c.isBlocked).toList();
    
    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      list = list.where((c) {
        return c.senderName.toLowerCase().contains(query) ||
               (c.latestMessage?.text.toLowerCase().contains(query) ?? false);
      }).toList();
    }
    
    // Apply chip filter
    switch (_currentFilter) {
      case SmsFilter.unread:
        list = list.where((c) => c.unreadCount > 0).toList();
        break;
      case SmsFilter.transactions:
        list = list.where((c) => c.isBankSender).toList();
        break;
      case SmsFilter.personal:
        list = list.where((c) => !c.isBankSender).toList();
        break;
      case SmsFilter.all:
        break;
    }
    
    list.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      final aTime = a.latestMessage?.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.latestMessage?.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    
    return list;
  }

  String _searchQuery = '';
  SmsFilter _currentFilter = SmsFilter.all;
  
  MessageSettings _settings = MessageSettings();
  MessageSettings get settings => _settings;

  Set<String> _blockedNumbers = {};
  Set<String> get blockedNumbers => _blockedNumbers;

  String get searchQuery => _searchQuery;
  SmsFilter get currentFilter => _currentFilter;

  double _monthlyTargetAmount = 20000.0;
  double get monthlyTargetAmount => _monthlyTargetAmount;

  Future<void> setMonthlyTargetAmount(double amount) async {
    _monthlyTargetAmount = amount;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('monthly_target', amount);
    } catch (_) {}
  }

  Future<void> _initPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsStr = prefs.getString('message_settings');
      if (settingsStr != null) {
        try {
          _settings = MessageSettings.fromJson(jsonDecode(settingsStr));
        } catch (_) {}
      }
      
      final blockedStr = prefs.getStringList('blocked_numbers');
      if (blockedStr != null) {
        _blockedNumbers = blockedStr.toSet();
      }
      
      final targetAmount = prefs.getDouble('monthly_target');
      if (targetAmount != null) {
        _monthlyTargetAmount = targetAmount;
      }
      
      _applyAutoDelete();
      _loadContacts();
    } catch (e) {
      debugPrint('Error loading preferences: $e');
    }
    notifyListeners();
  }

  Future<void> _loadContacts() async {
    try {
      if (await Permission.contacts.request().isGranted) {
        final contacts = await FlutterContacts.getAll(properties: {ContactProperty.phone});
        bool changed = false;
        for (var conv in _conversations) {
          if (!conv.isBankSender) {
            for (var contact in contacts) {
              if (contact.phones.isNotEmpty) {
                final contactNum = contact.phones.first.number.replaceAll(RegExp(r'\D'), '');
                final convNum = conv.senderNumber.replaceAll(RegExp(r'\D'), '');
                if (contactNum.isNotEmpty && (contactNum.contains(convNum) || convNum.contains(contactNum))) {
                  final displayName = contact.displayName;
                  if (displayName != null && displayName.isNotEmpty && conv.senderName != displayName) {
                    conv.senderName = displayName;
                    changed = true;
                  }
                  break;
                }
              }
            }
          }
        }
        if (changed) notifyListeners();
      }
    } catch (_) {}
  }

  void _applyAutoDelete() {
    if (_settings.autoDeleteDays != null) {
      final now = DateTime.now();
      bool changed = false;
      for (var conv in _conversations) {
        final initialCount = conv.messages.length;
        conv.messages.removeWhere((msg) => now.difference(msg.timestamp).inDays >= _settings.autoDeleteDays!);
        if (conv.messages.length != initialCount) changed = true;
      }
      final initialConvCount = _conversations.length;
      _conversations.removeWhere((c) => c.messages.isEmpty);
      if (_conversations.length != initialConvCount) changed = true;
      if (changed) notifyListeners();
    }
  }

  Future<void> updateSettings(MessageSettings next) async {
    _settings = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('message_settings', jsonEncode(_settings.toJson()));
    } catch (e) {
      // Handle fallback
    }
    _applyAutoDelete();
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setFilter(SmsFilter filter) {
    _currentFilter = filter;
    notifyListeners();
  }

  void markAsRead(String conversationId) {
    final idx = _conversations.indexWhere((c) => c.id == conversationId);
    if (idx != -1 && _conversations[idx].unreadCount > 0) {
      _conversations[idx].unreadCount = 0;
      notifyListeners();
    }
  }

  void markAllAsRead() {
    bool changed = false;
    for (var conv in _conversations) {
      if (!conv.isDeleted && conv.unreadCount > 0) {
        conv.unreadCount = 0;
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  void deleteConversation(String conversationId) {
    final idx = _conversations.indexWhere((c) => c.id == conversationId);
    if (idx != -1) {
      _conversations[idx].isDeleted = true;
      _conversations[idx].deletedAt = DateTime.now();
      notifyListeners();
    }
  }

  void permanentlyDeleteConversation(String conversationId) {
    _conversations.removeWhere((c) => c.id == conversationId);
    notifyListeners();
  }

  void toggleMute(String conversationId) {
    final idx = _conversations.indexWhere((c) => c.id == conversationId);
    if (idx != -1) {
      _conversations[idx].isMuted = !_conversations[idx].isMuted;
      notifyListeners();
    }
  }

  void togglePin(String conversationId) {
    final idx = _conversations.indexWhere((c) => c.id == conversationId);
    if (idx != -1) {
      _conversations[idx].isPinned = !_conversations[idx].isPinned;
      notifyListeners();
    }
  }

  Future<void> blockConversation(String conversationId) async {
    final idx = _conversations.indexWhere((c) => c.id == conversationId);
    if (idx != -1) {
      _conversations[idx].isBlocked = true;
      _blockedNumbers.add(_conversations[idx].senderNumber);
      
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('blocked_numbers', _blockedNumbers.toList());
      } catch (e) {
        // Fallback
      }
      
      notifyListeners();
    }
  }

  Future<void> unblockNumber(String number) async {
    _blockedNumbers.remove(number);
    for (var conv in _conversations) {
      if (conv.senderNumber == number) {
        conv.isBlocked = false;
      }
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('blocked_numbers', _blockedNumbers.toList());
    } catch (e) {
      // Fallback
    }
    
    notifyListeners();
  }

  void recoverConversations(List<String> conversationIds) {
    bool changed = false;
    for (var id in conversationIds) {
      final idx = _conversations.indexWhere((c) => c.id == id);
      if (idx != -1 && _conversations[idx].isDeleted) {
        _conversations[idx].isDeleted = false;
        _conversations[idx].deletedAt = null;
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  void cleanUpBin() {
    final now = DateTime.now();
    bool changed = false;
    _conversations.removeWhere((c) {
      if (c.isDeleted && c.deletedAt != null) {
        if (now.difference(c.deletedAt!).inDays >= 30) {
          changed = true;
          return true;
        }
      }
      return false;
    });
    if (changed) notifyListeners();
  }

  void sendMessage(String conversationId, String text) {
    final idx = _conversations.indexWhere((c) => c.id == conversationId);
    if (idx != -1) {
      final msg = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        timestamp: DateTime.now(),
        isMe: true,
      );
      _conversations[idx].messages.add(msg);
      
      // Move this conversation to the top
      final conv = _conversations.removeAt(idx);
      _conversations.insert(0, conv);
      
      notifyListeners();
    }
  }
  
  Conversation? startOrSendToNumber(String number, String text) {
    if (_blockedNumbers.contains(number)) return null;

    final idx = _conversations.indexWhere((c) => c.senderNumber == number);
    if (idx != -1) {
      sendMessage(_conversations[idx].id, text);
      return _conversations[idx];
    } else {
      return createNewConversation(number, text);
    }
  }
  
  Conversation createNewConversation(String nameOrNumber, String text) {
    final newConv = Conversation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderName: nameOrNumber,
      senderNumber: nameOrNumber,
      avatarColor: Colors.deepPurple,
      messages: [
        Message(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: text,
          timestamp: DateTime.now(),
          isMe: true,
        ),
      ],
      isBankSender: false,
    );
    _conversations.insert(0, newConv);
    notifyListeners();
    return newConv;
  }

}

enum SmsFilter { all, unread, transactions, personal }
