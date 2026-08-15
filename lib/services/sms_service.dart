import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/sms_models.dart';
import '../models/message_settings.dart';
import '../models/transaction.dart';
import '../utils/expense_parser.dart';
import 'package:flutter/material.dart';

class AccountInfo {
  final String bankName;
  final String accountType;
  final String accountNumber;
  final double balance;
  final Color accentColor;

  AccountInfo({
    required this.bankName,
    required this.accountType,
    required this.accountNumber,
    required this.balance,
    required this.accentColor,
  });
}

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

  List<Conversation> _conversations = [];
  
  List<Conversation> get conversations => _conversations;
  
  List<Conversation> get deletedConversations => 
      _conversations.where((c) => c.isDeleted).toList();

  List<Transaction> get parsedTransactions {
    List<Transaction> list = [];
    for (var conv in _conversations) {
      if (conv.isBankSender) {
        for (var msg in conv.messages) {
          final parsed = ExpenseParser.parse(msg.text);
          if (parsed != null) {
            list.add(Transaction(
              id: msg.id,
              merchant: parsed.merchant ?? 'Unknown Merchant',
              amount: parsed.amount,
              date: msg.timestamp,
              category: ExpenseParser.guessCategory(parsed.merchant),
              subtitle: conv.senderName, // The source
              rawMessage: msg.text,
              type: TransactionType.expense,
            ));
          }
        }
      }
    }
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  List<AccountInfo> get linkedAccounts {
    List<AccountInfo> accounts = [];
    for (var conv in _conversations) {
      if (conv.isBankSender && conv.messages.isNotEmpty) {
        double? latestBalance;
        String accNum = '****';
        for (var msg in conv.messages.reversed) {
          final bal = ExpenseParser.extractBalance(msg.text);
          if (bal != null && latestBalance == null) {
            latestBalance = bal;
          }
          final ac = ExpenseParser.extractAccountNumber(msg.text);
          if (ac != null) {
            accNum = '**** $ac';
          }
        }
        if (latestBalance != null) {
          accounts.add(AccountInfo(
            bankName: conv.senderName,
            accountType: 'Savings Account', // Default inference
            accountNumber: accNum,
            balance: latestBalance,
            accentColor: conv.avatarColor,
          ));
        }
      }
    }
    return accounts;
  }

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
      default:
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

  void initializeDummyData() {
    _conversations = [
      Conversation(
        id: 'bank_kgb',
        senderName: 'Kerala Grameena Bank',
        senderNumber: 'KGBANK',
        avatarColor: Colors.green,
        unreadCount: 0,
        isBankSender: true,
        messages: [
          Message(id: 'kgb_1', text: 'After debit of Rs 1802,your A/c XXXXXXXXXX0544 Bal standsRs 49.82 Msg Id 2674665967 Time 15-08-2026 14:46:03 -Kerala Grameena Bank', timestamp: DateTime(2026, 8, 15, 14, 46, 3), isMe: false),
          Message(id: 'kgb_2', text: 'Your a/c no.XXXX80544 is credited by Rs.636.00 on 15/08/26 02:45 PM and debited from a/c no.XXX58475(UPI Ref no 659378522726)-Kerala Grameena Bank', timestamp: DateTime(2026, 8, 15, 14, 45), isMe: false),
          Message(id: 'kgb_3', text: 'Your a/c no.XXXX80544 is credited by Rs.13.00 on 14/08/26 02:44 PM and debited from a/c no.81381(UPI Ref no 622627819638)-Kerala Grameena Bank', timestamp: DateTime(2026, 8, 14, 14, 44), isMe: false),
          Message(id: 'kgb_4', text: 'Dear Customer, Account XXXX544 is credited with INR 26 on 14-08-2026 13:43:08 from abhinand5856@ok. UPI Ref. no. 622613706756-Kerala Grameena Bank', timestamp: DateTime(2026, 8, 14, 13, 43, 8), isMe: false),
          Message(id: 'kgb_5', text: 'Your a/c no.XXXX80544 is debited for Rs.250.00 on 12/08/26 02:37 PM and credited to a/c no.XXXX00714(UPI Ref no 659048897629)-Kerala Grameena Bank', timestamp: DateTime(2026, 8, 12, 14, 37), isMe: false),
          Message(id: 'kgb_6', text: 'After debit of Rs 2000,your A/c XXXXXXXXXX0544 Bal standsRs 276.82 Msg Id 2664021124 Time 11-08-2026 13:05:43 -Kerala Grameena Bank', timestamp: DateTime(2026, 8, 11, 13, 5, 43), isMe: false),
          Message(id: 'kgb_7', text: 'Your a/c no.XXXX80544 is debited for Rs.1003.54 on 10/08/26 04:15 PM and credited to a/c no.XXX01195(UPI Ref no 658844997113)-Kerala Grameena Bank', timestamp: DateTime(2026, 8, 10, 16, 15), isMe: false),
          Message(id: 'kgb_8', text: 'Your a/c no.XXXX80544 is debited for Rs.240.00 on 02/08/26 01:32 PM and credited to a/c no.XXXXX00025(UPI Ref no 697217462716)-Kerala Grameena Bank', timestamp: DateTime(2026, 8, 2, 13, 32), isMe: false),
          Message(id: 'kgb_9', text: 'Dear Customer, Account XXXX544 is credited with INR 28 on 01-08-2026 17:01:01 from apb8111@okaxis. UPI Ref. no. 621317178347-Kerala Grameena Bank', timestamp: DateTime(2026, 8, 1, 17, 1, 1), isMe: false),
          Message(id: 'kgb_10', text: 'Your a/c no.XXXX80544 is credited by Rs.104.75 on 29/07/26 08:44 PM and debited from a/c no.XXX22217(UPI Ref no 657697792381)-Kerala Grameena Bank', timestamp: DateTime(2026, 7, 29, 20, 44), isMe: false),
        ]..sort((a, b) => a.timestamp.compareTo(b.timestamp)),
      ),
      Conversation(
        id: 'bank_bob',
        senderName: 'Bank of Baroda',
        senderNumber: 'BOB',
        avatarColor: Colors.orange,
        unreadCount: 0,
        isBankSender: true,
        messages: [
          Message(id: 'bob_1', text: 'Rs.154.90 Dr. from A/C XXXXXX0711 and Cr. to gpay.bp.recharge1@okpayaxis. Ref:659322224053. AvlBal:Rs160.97(2026:08:15 12:40:32). Not you? Call 18005700/5000-BOB', timestamp: DateTime(2026, 8, 15, 12, 40, 32), isMe: false),
          Message(id: 'bob_2', text: 'Rs.59.00 Dr. from A/C XXXXXX0711 and Cr. to paytm-75052158@ptys. Ref:622619676943. AvlBal:Rs315.87(2026:08:14 10:10:57). Not you? Call 18005700/5000-BOB', timestamp: DateTime(2026, 8, 14, 10, 10, 57), isMe: false),
          Message(id: 'bob_3', text: 'Dear BOB UPI User: Your account is credited with INR 200.00 on 2026-08-14 08:10:08 PM by UPI Ref No 659230735826; AvlBal: Rs374.87 - BOB', timestamp: DateTime(2026, 8, 14, 20, 10, 8), isMe: false),
          Message(id: 'bob_4', text: 'Rs.61.00 Dr. from A/C XXXXXX0711 and Cr. to bbnow.esbz@mairtel. Ref:622470811230. AvlBal:Rs24.87(2026:08:12 04:24:38). Not you? Call 18005700/5000-BOB', timestamp: DateTime(2026, 8, 12, 16, 24, 38), isMe: false),
          Message(id: 'bob_5', text: 'Dear BOB UPI User: Your account is credited with INR 500.00 on 2026-08-10 04:26:17 PM by UPI Ref No 003982312751; AvlBal: Rs585.87 - BOB', timestamp: DateTime(2026, 8, 10, 16, 26, 17), isMe: false),
          Message(id: 'bob_6', text: 'Rs.12.00 Dr. from A/C XXXXXX0711 and Cr. to greenfalafel333@fbl. Ref:657614748605. AvlBal:Rs525.87(2026:07:29 03:52:39). Not you? Call 18005700/5000-BOB', timestamp: DateTime(2026, 7, 29, 15, 52, 39), isMe: false),
          Message(id: 'bob_7', text: 'Rs.20000.00 Dr. from A/C XXXXXX0711 and Cr. to abinand705@okhdfcbank. Ref:657499675373. AvlBal:Rs902.62(2026:07:27 06:49:02). Not you? Call 18005700/5000-BOB', timestamp: DateTime(2026, 7, 27, 6, 49, 2), isMe: false),
        ]..sort((a, b) => a.timestamp.compareTo(b.timestamp)),
      ),
    ];
  }
}

enum SmsFilter { all, unread, transactions, personal }
