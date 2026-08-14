import 'package:flutter/material.dart';
import '../models/sms_models.dart';

class MockSmsService extends ChangeNotifier {
  static final MockSmsService _instance = MockSmsService._internal();
  factory MockSmsService() => _instance;
  MockSmsService._internal();

  List<Conversation> _conversations = [];
  
  List<Conversation> get conversations => _conversations;
  
  List<Conversation> get filteredConversations {
    List<Conversation> list = _conversations;
    
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
    
    return list;
  }

  String _searchQuery = '';
  SmsFilter _currentFilter = SmsFilter.all;
  
  String get searchQuery => _searchQuery;
  SmsFilter get currentFilter => _currentFilter;

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
  
  void createNewConversation(String nameOrNumber, String text) {
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
  }

  void initializeDummyData() {
    _conversations = [
      Conversation(
        id: '1',
        senderName: 'Mom',
        senderNumber: '+91 9876543210',
        avatarColor: Colors.pinkAccent,
        unreadCount: 2,
        messages: [
          Message(id: 'm1', text: 'Hey dear, how are you?', timestamp: DateTime.now().subtract(const Duration(minutes: 60)), isMe: false),
          Message(id: 'm2', text: 'Did you have lunch?', timestamp: DateTime.now().subtract(const Duration(minutes: 58)), isMe: false, isRead: false),
          Message(id: 'm3', text: 'Call me when you are free.', timestamp: DateTime.now().subtract(const Duration(minutes: 15)), isMe: false, isRead: false),
        ],
      ),
      Conversation(
        id: '2',
        senderName: 'HDFC Bank',
        senderNumber: 'HDFCBK',
        avatarColor: Colors.blueAccent,
        unreadCount: 0,
        isBankSender: true,
        messages: [
          Message(id: 'm4', text: 'Update: Your account ends with 1234 was credited with Rs 5,000 on 12-Aug.', timestamp: DateTime.now().subtract(const Duration(days: 2)), isMe: false),
          Message(id: 'm5', text: 'Alert: Rs 850 debited from HDFC CC at Zomato.', timestamp: DateTime.now().subtract(const Duration(hours: 2)), isMe: false),
        ],
      ),
      Conversation(
        id: '3',
        senderName: 'Rahul',
        senderNumber: '+91 9998887776',
        avatarColor: Colors.teal,
        unreadCount: 0,
        messages: [
          Message(id: 'm6', text: 'Are we still on for the movie tonight?', timestamp: DateTime.now().subtract(const Duration(days: 1)), isMe: false),
          Message(id: 'm7', text: 'Yeah, see you at 8 PM.', timestamp: DateTime.now().subtract(const Duration(days: 1, hours: -1)), isMe: true),
        ],
      ),
      Conversation(
        id: '4',
        senderName: 'Jio',
        senderNumber: 'JioNet',
        avatarColor: Colors.deepOrange,
        unreadCount: 1,
        isBankSender: true,
        messages: [
          Message(id: 'm8', text: 'Your plan expires in 2 days. Recharge now to avoid interruption.', timestamp: DateTime.now().subtract(const Duration(minutes: 5)), isMe: false, isRead: false),
        ],
      ),
      Conversation(
        id: '5',
        senderName: 'SBI',
        senderNumber: 'SBI-IN',
        avatarColor: Colors.indigo,
        unreadCount: 0,
        isBankSender: true,
        messages: [
          Message(id: 'm9', text: 'Dear Customer, your a/c is debited for Rs 2,400 at Amazon.', timestamp: DateTime.now().subtract(const Duration(hours: 5)), isMe: false),
        ],
      ),
    ];
  }
}

enum SmsFilter { all, unread, transactions, personal }
