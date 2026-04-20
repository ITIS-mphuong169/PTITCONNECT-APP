import 'package:flutter/foundation.dart';

class IncomingCallData {
  IncomingCallData({
    required this.conversationId,
    required this.callLogId,
    required this.callType,
    required this.callerUsername,
    required this.callerName,
    required this.isGroup,
    required this.conversationName,
  });

  final int conversationId;
  final int callLogId;
  final String callType;
  final String callerUsername;
  final String callerName;
  final bool isGroup;
  final String conversationName;
}

class ActiveCallData {
  ActiveCallData({
    required this.conversationId,
    required this.callLogId,
    required this.callType,
    required this.isCaller,
    required this.title,
  });

  final int conversationId;
  final int callLogId;
  final String callType;
  final bool isCaller;
  final String title;
}

class CallState extends ChangeNotifier {
  CallState._();
  static final CallState instance = CallState._();

  IncomingCallData? incoming;
  ActiveCallData? active;
  bool minimized = false;

  void showIncoming(IncomingCallData data) {
    if (active != null) return;
    incoming = data;
    notifyListeners();
  }

  void clearIncoming() {
    incoming = null;
    notifyListeners();
  }

  void startActive(ActiveCallData data) {
    incoming = null;
    active = data;
    minimized = false;
    notifyListeners();
  }

  void setMinimized(bool value) {
    minimized = value;
    notifyListeners();
  }

  void endActive() {
    incoming = null;
    active = null;
    minimized = false;
    notifyListeners();
  }
}
