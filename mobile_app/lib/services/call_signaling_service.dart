import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:mobile_app/core/app_api.dart';

class CallSignalingService {
  CallSignalingService(this.conversationId);

  final int conversationId;
  WebSocketChannel? _channel;

  void connect(void Function(Map<String, dynamic>) onMessage) {
    _channel = WebSocketChannel.connect(
      Uri.parse(AppApi.wsCall(conversationId)),
    );

    _channel!.stream.listen((event) {
      try {
        final data = jsonDecode(event as String) as Map<String, dynamic>;
        onMessage(data);
      } catch (_) {}
    });
  }

  void send(Map<String, dynamic> data) {
    _channel?.sink.add(jsonEncode(data));
  }

  void dispose() {
    _channel?.sink.close();
  }
}
