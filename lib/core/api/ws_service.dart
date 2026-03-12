import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/app_config.dart';
import '../providers/providers.dart';

enum WSEventType {
  newNotification,
  maintenanceUpdate,
  newForumPost,
  newTimelinePost,
  paymentConfirmed,
  emergencyAlert,
}

class WSEvent {
  final WSEventType type;
  final Map<String, dynamic> data;

  WSEvent({required this.type, required this.data});

  factory WSEvent.fromJson(Map<String, dynamic> json) {
    final eventStr = json['event'] as String;
    final type = _parseEventType(eventStr);
    return WSEvent(type: type, data: json['data'] ?? {});
  }

  static WSEventType _parseEventType(String event) {
    switch (event) {
      case 'new_notification':
        return WSEventType.newNotification;
      case 'maintenance_update':
        return WSEventType.maintenanceUpdate;
      case 'new_forum_post':
        return WSEventType.newForumPost;
      case 'new_timeline_post':
        return WSEventType.newTimelinePost;
      case 'payment_confirmed':
        return WSEventType.paymentConfirmed;
      case 'emergency_alert':
        return WSEventType.emergencyAlert;
      default:
        return WSEventType.newNotification;
    }
  }
}

class WebSocketService {
  WebSocketChannel? _channel;
  final _eventController = StreamController<WSEvent>.broadcast();
  Timer? _reconnectTimer;
  bool _isConnected = false;

  Stream<WSEvent> get events => _eventController.stream;
  bool get isConnected => _isConnected;

  void connect() {
    final token = Hive.box('auth').get('accessToken');
    if (token == null) return;

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('${AppConfig.wsUrl}?token=$token'),
      );

      _channel!.stream.listen(
        (data) {
          _isConnected = true;
          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            _eventController.add(WSEvent.fromJson(json));
          } catch (_) {}
        },
        onDone: () {
          _isConnected = false;
          _scheduleReconnect();
        },
        onError: (_) {
          _isConnected = false;
          _scheduleReconnect();
        },
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), connect);
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _isConnected = false;
  }

  void dispose() {
    disconnect();
    _eventController.close();
  }
}

// Riverpod provider
final wsServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService();
  final authState = ref.watch(authStateProvider);

  if (authState.status == AuthStatus.authenticated) {
    service.connect();
  } else {
    service.disconnect();
  }

  ref.onDispose(() => service.dispose());
  return service;
});

// Stream provider for reacting to WS events in UI
final wsEventProvider = StreamProvider<WSEvent>((ref) {
  final service = ref.watch(wsServiceProvider);
  return service.events;
});
