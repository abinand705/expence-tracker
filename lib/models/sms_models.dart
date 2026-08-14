import 'package:flutter/material.dart';

class Message {
  final String id;
  final String text;
  final DateTime timestamp;
  final bool isMe;
  final bool isRead;

  Message({
    required this.id,
    required this.text,
    required this.timestamp,
    required this.isMe,
    this.isRead = true,
  });
}

class Conversation {
  final String id;
  final String senderName;
  final String senderNumber;
  final Color avatarColor;
  final List<Message> messages;
  int unreadCount;
  final bool isBankSender;

  Conversation({
    required this.id,
    required this.senderName,
    required this.senderNumber,
    required this.avatarColor,
    required this.messages,
    this.unreadCount = 0,
    this.isBankSender = false,
  });

  Message? get latestMessage => messages.isNotEmpty ? messages.last : null;
}
