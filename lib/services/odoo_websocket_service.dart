import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pi_task_watch/managers/odoo_rpc_api_manager.dart';

/// Odoo WebSocket Service for real-time Discuss chat updates.
/// Connects natively to wss://server/websocket (Odoo 17/18/19).
class OdooWebSocketService {
  static final OdooWebSocketService _instance = OdooWebSocketService._internal();
  factory OdooWebSocketService() => _instance;
  OdooWebSocketService._internal();

  WebSocket? _webSocket;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  bool _isConnecting = false;
  bool _isDisposed = false;
  int _reconnectAttempts = 0;
  
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  bool get isConnected => _webSocket != null && _webSocket!.readyState == WebSocket.open;

  final Set<String> _subscribedChannels = {};
  int _lastNotificationId = 0;

  /// Connect to Odoo WebSocket server using active OdooRpcApiManager session
  Future<void> connect({List<String>? initialChannels}) async {
    if (_isDisposed) _isDisposed = false;
    if (isConnected || _isConnecting) return;

    final baseUrl = OdooRpcApiManager.serverUrl;
    var sessionId = OdooRpcApiManager.currentSessionId;

    if (baseUrl.isEmpty) {
      debugPrint('[OdooWS] Cannot connect: missing serverUrl');
      return;
    }

    if (sessionId == null || sessionId.isEmpty) {
      debugPrint('[OdooWS] No sessionId present, auto-establishing web session for WebSocket...');
      sessionId = await OdooRpcApiManager.ensureWebSession();
    }

    if (sessionId == null || sessionId.isEmpty) {
      debugPrint('[OdooWS] Cannot connect: could not establish web session');
      return;
    }

    _isConnecting = true;

    if (initialChannels != null) {
      _subscribedChannels.addAll(initialChannels);
    }

    try {
      // Build wss:// or ws:// URL with Odoo 19 version parameter and clean Origin
      final cleanUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
      Uri uri = Uri.parse(cleanUrl);
      final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
      final wsUrl = '$wsScheme://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}/websocket?version=19.0-2';

      debugPrint('[OdooWS] Connecting to $wsUrl with Origin: $cleanUrl ...');

      _webSocket = await WebSocket.connect(
        wsUrl,
        headers: {
          'Origin': cleanUrl,
          'Cookie': 'session_id=$sessionId; session=$sessionId',
        },
      ).timeout(const Duration(seconds: 15));

      _isConnecting = false;
      _reconnectAttempts = 0;
      debugPrint('[OdooWS] Connected successfully!');

      // Send initial subscription (in Odoo 19, channels: [] automatically maps all session channels)
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

  /// Subscribe to specific channels (or register extra channels)
  void subscribe(List<String> channels) {
    _subscribedChannels.addAll(channels);
    if (isConnected) {
      _subscribeToCurrentChannels();
    }
  }

  void _subscribeToCurrentChannels() {
    if (!isConnected) return;

    try {
      final payload = jsonEncode({
        "event_name": "subscribe",
        "data": {
          "channels": _subscribedChannels.toList(),
          "last": _lastNotificationId,
        }
      });
      _webSocket!.add(payload);
      debugPrint('[OdooWS] Sent subscribe payload: ${_subscribedChannels.length} channels (last: $_lastNotificationId)');
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
    // Record notification ID to maintain event ordering and recover misses
    if (frame.containsKey('id') && frame['id'] is int) {
      final nid = frame['id'] as int;
      if (nid > _lastNotificationId) {
        _lastNotificationId = nid;
      }
    }

    // Format 1: { "id": 123, "message": { "type": "...", "payload": {...} } }
    // Format 2: { "type": "...", "payload": {...} }
    final Map<String, dynamic> msgPayload;

    if (frame.containsKey('message') && frame['message'] is Map) {
      msgPayload = Map<String, dynamic>.from(frame['message']);
    } else {
      msgPayload = frame;
    }

    debugPrint('[OdooWS] Received notification: ${msgPayload['type']}');
    _messageController.add(msgPayload);
  }

  void _startPingHeartbeat() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (isConnected) {
        try {
          // Send Odoo 19 connection check byte (0x00) to keep connection alive
          _webSocket!.add([0x00]);
        } catch (e) {
          debugPrint('[OdooWS] Heartbeat failed: $e');
          _scheduleReconnect();
        }
      }
    });
  }

  void _onError(dynamic error) {
    debugPrint('[OdooWS] WebSocket error: $error');
    _scheduleReconnect();
  }

  void _onDone() {
    debugPrint('[OdooWS] WebSocket connection closed (code: ${_webSocket?.closeCode}, reason: ${_webSocket?.closeReason})');
    if (!_isDisposed) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _pingTimer?.cancel();
    _webSocket = null;
    if (_isDisposed) return;

    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    // Exponential backoff: 5s, 10s, 30s, 60s to avoid hammering the server
    final delaySeconds = _reconnectAttempts == 1
        ? 5
        : (_reconnectAttempts == 2
            ? 10
            : (_reconnectAttempts == 3 ? 30 : 60));

    debugPrint('[OdooWS] Scheduling auto-reconnect in ${delaySeconds}s (attempt $_reconnectAttempts)...');
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!_isDisposed && !isConnected) {
        debugPrint('[OdooWS] Attempting auto-reconnect (attempt $_reconnectAttempts)...');
        connect();
      }
    });
  }

  /// Ensure the socket is connected; reconnects immediately if disconnected
  void ensureConnected() {
    if (!isConnected && !_isConnecting && !_isDisposed) {
      debugPrint('[OdooWS] ensureConnected: Socket not connected, connecting now...');
      connect();
    }
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
    _lastNotificationId = 0;
    _reconnectAttempts = 0;
    debugPrint('[OdooWS] Disconnected');
  }
}
