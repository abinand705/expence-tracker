import 'package:flutter/material.dart';

class MessageSettings {
  final ThemeMode themeMode;
  final bool notificationsEnabled;
  final int? autoDeleteDays;

  MessageSettings({
    this.themeMode = ThemeMode.system,
    this.notificationsEnabled = true,
    this.autoDeleteDays,
  });

  MessageSettings copyWith({
    ThemeMode? themeMode,
    bool? notificationsEnabled,
    int? autoDeleteDays,
    bool clearAutoDelete = false,
  }) {
    return MessageSettings(
      themeMode: themeMode ?? this.themeMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      autoDeleteDays: clearAutoDelete ? null : (autoDeleteDays ?? this.autoDeleteDays),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'themeMode': themeMode.index,
      'notificationsEnabled': notificationsEnabled,
      'autoDeleteDays': autoDeleteDays,
    };
  }

  factory MessageSettings.fromJson(Map<String, dynamic> json) {
    return MessageSettings(
      themeMode: ThemeMode.values[json['themeMode'] as int? ?? ThemeMode.system.index],
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      autoDeleteDays: json['autoDeleteDays'] as int?,
    );
  }
}
