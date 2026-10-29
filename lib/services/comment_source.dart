import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'telemetry_service.dart';


class CommentSource extends ChangeNotifier {
  final TelemetryService telemetry;


  WebSocket? _ws;
  StreamSubscription? _wsSub;
  Timer? _reconnectTimer;
  Timer? _pingTimer;


  String connectionState = 'idle'; // idle | connecting | connected | disconnected | ended | error
  String statusMessage = 'Chưa kết nối phiên TikTok LIVE';
  String activeRelayUrl = '';
  String activeUniqueId = '';
  bool _manualDisconnect = true;
  int receivedChatCount = 0;
  int incompleteChatCount = 0;
  String relayVersion = 'chưa xác định';
  
  static String _text(List<dynamic> options) {
    for (final value in options) {
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }


  // sync: true phat su kien truc tiep trong microtask hien tai, khong tao hang doi trung gian
  final StreamController<LiveComment> _commentStreamController =
      StreamController<LiveComment>.broadcast(sync: true);


  Stream<LiveComment> get commentStream => _commentStreamController.stream;


  CommentSource({required this.telemetry});


  Future<void> connect({
    required String relayUrl,
    required String uniqueId,
  }) async {
    final cleanId = uniqueId.trim().replaceFirst(RegExp(r'^@+'), '');
    if (cleanId.isEmpty) {
      connectionState = 'error';
      statusMessage = 'Vui lòng nhập tên tài khoản TikTok đang phát LIVE.';
      notifyListeners();
      return;
    }


    _manualDisconnect = false;
    activeRelayUrl = relayUrl.trim();
    activeUniqueId = cleanId;
    await _establishConnection();
  }


  Future<void> _establishConnection() async {
    await _cleanupSocket();
    connectionState = 'connecting';
    statusMessage = 'Đang kết nối Relay & phòng LIVE @$activeUniqueId...';
    notifyListeners();


    try {
      final ws = await WebSocket.connect(activeRelayUrl)
          .timeout(const Duration(seconds: 6));
      ws.pingInterval = const Duration(seconds: 15);
      _ws = ws;


      _wsSub = ws.listen(
        _onRawFrame,
        onError: (err) {
          _scheduleReconnect('Lỗi luồng kết nối Relay: $err');
        },
        onDone: () {
          _scheduleReconnect('Mất kết nối tới Relay. Đang tự kết nối lại...');
        },
        cancelOnError: true,
      );


      _sendPing();
      ws.add(jsonEncode({
        'action': 'connect',
        'uniqueId': activeUniqueId,
      }));


      _pingTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _sendPing(),
      );
    } catch (e) {
      _scheduleReconnect(
        'Không kết nối được tới Relay ($activeRelayUrl). Đang thử lại...',
      );
    }
  }


  void _sendPing() {
    final ws = _ws;
    if (ws != null && ws.readyState == WebSocket.open) {
      try {
        ws.add(jsonEncode({
          'action': 'ping',
          'client_ts': DateTime.now().millisecondsSinceEpoch,
        }));
      } catch (_) {}
    }
  }


  void _onRawFrame(dynamic rawData) {
    final int tAppRecv = DateTime.now().millisecondsSinceEpoch;
    if (rawData is! String) return;


    try {
      final Map<String, dynamic> data = jsonDecode(rawData) as Map<String, dynamic>;
      final String type = (data['type'] ?? '').toString();


      // LUONG NONG (HOT PATH): Binh luan day thang len giao dien khong qua bat ky tac vu phu nao
      if (type == 'chat') {
        final Map<String, dynamic> user = data['user'] is Map<String, dynamic>
            ? data['user'] as Map<String, dynamic>
            : <String, dynamic>{};
        final String username = _text([
          data['unique_id'], data['uniqueId'], data['displayId'],
          user['displayId'], user['uniqueId'],
        ]).replaceFirst(RegExp(r'^@+'), '');
        final String numericId = _text([data['user_id'], data['userId'], user['id'], user['userId']]);
        final String content = _text([data['comment'], data['content'], data['text']]);

        // Chỉ hiển thị bình luận có nội dung thật. Không tự đặt tên ID là "khach".
        if (content.isEmpty) {
          incompleteChatCount++;
          statusMessage = 'Relay gửi bình luận rỗng: kiểm tra/cập nhật máy chủ lên v2.1.';
          notifyListeners();
          return;
        }
        final item = LiveComment(
          msgId: _text([data['msg_id'], data['msgId'], tAppRecv]),
          uniqueId: username,
          userId: numericId,
          nickname: _text([data['nickname'], user['nickname'], username, 'Người xem TikTok']),
          comment: content,
          tRelayRecv: (data['t_relay_recv'] as num?)?.toInt() ?? tAppRecv,
          tAppRecv: tAppRecv,
        );
        receivedChatCount++;
        if (username.isEmpty && numericId.isEmpty) {
          incompleteChatCount++;
          statusMessage = 'Có bình luận nhưng TikTok không trả ID người gửi. Kiểm tra Relay.';
          notifyListeners();
        }
        _commentStreamController.add(item);
        return;
      }


      if (type == 'pong') {
        final clientTs = (data['client_ts'] as num?)?.toInt() ?? tAppRecv;
        final serverTs = (data['server_ts'] as num?)?.toInt() ?? tAppRecv;
        telemetry.updateClockOffset(clientTs, serverTs, tAppRecv);
        return;
      }


      if (type == 'status') {
        connectionState = (data['state'] ?? 'idle').toString();
        statusMessage = (data['message'] ?? '').toString();
        relayVersion = _text([data['relay_version'], relayVersion]);
        notifyListeners();
      }
    } catch (_) {}
  }


  void _scheduleReconnect(String reason) {
    _cleanupSocket();
    if (_manualDisconnect) return;


    connectionState = 'disconnected';
    statusMessage = reason;
    notifyListeners();


    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(milliseconds: 2500), () {
      if (!_manualDisconnect && activeUniqueId.isNotEmpty) {
        _establishConnection();
      }
    });
  }


  Future<void> disconnect() async {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    final ws = _ws;
    if (ws != null && ws.readyState == WebSocket.open) {
      try {
        ws.add(jsonEncode({'action': 'disconnect'}));
      } catch (_) {}
    }
    await _cleanupSocket();
    connectionState = 'idle';
    statusMessage = 'Đã ngắt kết nối phiên LIVE.';
    notifyListeners();
  }


  Future<void> _cleanupSocket() async {
    _pingTimer?.cancel();
    _pingTimer = null;
    await _wsSub?.cancel();
    _wsSub = null;
    try {
      await _ws?.close();
    } catch (_) {}
    _ws = null;
  }
}