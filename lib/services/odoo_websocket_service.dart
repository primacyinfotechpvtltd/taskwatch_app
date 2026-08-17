import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pi_task_watch/managers/odoo_rpc_api_manager.dart';

/// Odoo WebSocket Service for real-time Discuss chat updates.
/// Connects natively to wss://<server>/websocket (Odoo 17/18/19).
class OdooWebSocketService {
  static final OdooWebSocketService _instance = OdooWebSocketService._internal();
  factory OdooWebSocketService() => _instance;
  OdooWebSocketService._internal();

  WebSocket? _webSocket;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  bool _isConnecting = false;
  bool _isDisposed = false;
  
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  bool get isConnected => _webSocket != null && _webSocket!.readyState == WebSocket.open;

  final Set<String> _subscribedChannels = {};

  /// Connect to Odoo WebSocket server using active OdooRpcApiManager session
  Future<void> connect({List<String>? initialChannels}) async {
    if (_isDisposed) _isDisposed = false;
    if (isConnected || _isConnecting) return;

    final baseUrl = OdooRpcApiManager.serverUrl;
    final sessionId = OdooRpcApiManager.currentSessionId;

    if (baseUrl.isEmpty || sessionId == null || sessionId.isEmpty) {
      debugPrint('[OdooWS] Cannot connect: missing serverUrl or sessionId');
      return;
    }

    _isConnecting = true;

    if (initialChannels != null) {
      _subscribedChannels.addAll(initialChannels);
    }

    try {
      // Build wss:// or ws:// URL
      Uri uri = Uri.parse(baseUrl);
      final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
      final wsUrl = '$wsScheme://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}/websocket';

      debugPrint('[OdooWS] Connecting to $wsUrl ...');

      _webSocket = await WebSocket.connect(
        wsUrl,
        headers: {
          'Cookie': 'session_id=$sessionId; session=$sessionId',
        },
      ).timeout(const Duration(seconds: 15));

      _isConnecting = false;
      debugPrint('[OdooWS] Connected successfully!');

      // Send initial subscription if channels exist
      _subscribeToCurrentChannels();

      // Start ping heartbeat (every 45 seconds to prevent idle disconnect)
      _startPingHeartbeat();

      // Listen to incoming messages
      _webSocket!.listen(
        _onMessageReceived,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );
    } catch (e) {
      _isConnecting = false;
      debugPrint('[OdooWS] Connection failed: $e');
      _scheduleReconnect();
    }
  }

  /// Subscribe to specific channels (e.g., 'discuss.channel_42', 'res.partner_15')
  void subscribe(List<String> channels) {
    _subscribedChannels.addAll(channels);
    if (isConnected) {
      _subscribeToCurrentChannels();
    }
  }

  void _subscribeToCurrentChannels() {
    if (!isConnected || _subscribedChannels.isEmpty) return;

    try {
      final payload = jsonEncode({
        "event_name": "subscribe",
        "data": {
          "channels": _subscribedChannels.toList(),
          "last": 0,
        }
      });
      _webSocket!.add(payload);
      debugPrint('[OdooWS] Subscribed to ${_subscribedChannels.length} channels');
    } catch (e) {
      debugPrint('[OdooWS] Error sending subscribe payload: $e');
    }
  }

  void _onMessageReceived(dynamic data) {
    try {
      if (data is String) {
        final decoded = jsonDecode(data);

        // Odoo WS frame can be a List of notifications or a Map
        if (decoded is List) {
          for (var item in decoded) {
            if (item is Map<String, dynamic>) {
              _processFrame(item);
            }
          }
        } else if (decoded is Map<String, dynamic>) {
          _processFrame(decoded);
        }
      }
    } catch (e) {
      debugPrint('[OdooWS] Error parsing message: $e');
    }
  }

  void _processFrame(Map<String, dynamic> frame) {
    // Format 1: { "id": 123, "message": { "type": "...", "payload": {...} } }
    // Format 2: { "type": "...", "payload": {...} }
    Map<String, dynamic>? msgPayload;

    if (frame.containsKey('message') && frame['message'] is Map) {
      msgPayload = Map<String, dynamic>.from(frame['message']);
    } else {
      msgPayload = frame;
    }

    if (msgPayload != null) {
      debugPrint('[OdooWS] Received notification: ${msgPayload['type']}');
      _messageController.add(msgPayload);
    }
  }

  void _startPingHeartbeat() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (isConnected) {
        try {
          _webSocket!.add(jsonEncode({"event_name": "ping"}));
        } catch (e) {
          debugPrint('[OdooWS] Ping failed: $e');
        }
      }
    });
  }

  void _onError(dynamic error) {
    debugPrint('[OdooWS] WebSocket error: $error');
    _scheduleReconnect();
  }

  void _onDone() {
    debugPrint('[OdooWS] WebSocket connection closed');
    if (!_isDisposed) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _pingTimer?.cancel();
    _webSocket = null;
    if (_isDisposed) return;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 10), () {
      if (!_isDisposed && !isConnected) {
        debugPrint('[OdooWS] Attempting auto-reconnect...');
        connect();
      }
    });
  }

  /// Disconnect and cleanup WebSocket resources
  void disconnect() {
    _isDisposed = true;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    try {
      _webSocket?.close();
    } catch (_) {}
    _webSocket = null;
    _subscribedChannels.clear();
    debugPrint('[OdooWS] Disconnected');
  }
}
