String _twoDigits(int n) => n.toString().padLeft(2, '0');


String formatHms(int epochMs) {
  final dt = DateTime.fromMillisecondsSinceEpoch(epochMs);
  return '${_twoDigits(dt.hour)}:${_twoDigits(dt.minute)}:${_twoDigits(dt.second)}';
}


String formatShortDateTime(int epochMs) {
  final dt = DateTime.fromMillisecondsSinceEpoch(epochMs);
  return '${_twoDigits(dt.hour)}:${_twoDigits(dt.minute)}:${_twoDigits(dt.second)} '
      '${_twoDigits(dt.day)}/${_twoDigits(dt.month)}';
}


String formatFullDateTime(DateTime dt) {
  return '${_twoDigits(dt.hour)}:${_twoDigits(dt.minute)}:${_twoDigits(dt.second)} - '
      '${_twoDigits(dt.day)}/${_twoDigits(dt.month)}/${dt.year}';
}


class LiveComment {
  final String msgId;
  final String uniqueId;
  final String userId; // numeric TikTok UID when public @ID is unavailable
  final String nickname;
  final String comment;
  final int tRelayRecv;
  final int tAppRecv;
  int? tUiRender;
  int printCount;
  String lastPrintStatus; // 'idle' | 'printing' | 'printed' | 'error'


  LiveComment({
    required this.msgId,
    required this.uniqueId,
    this.userId = '',
    required this.nickname,
    required this.comment,
    required this.tRelayRecv,
    required this.tAppRecv,
    this.tUiRender,
    this.printCount = 0,
    this.lastPrintStatus = 'idle',
  });
}


class PrintedTicket {
  final int? id;
  final String msgId;
  final String uniqueId;
  final String nickname;
  final String comment;
  final int createdAt;
  final int printLatencyMs;
  final bool printSuccess;


  PrintedTicket({
    this.id,
    required this.msgId,
    required this.uniqueId,
    required this.nickname,
    required this.comment,
    required this.createdAt,
    required this.printLatencyMs,
    required this.printSuccess,
  });


  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'msg_id': msgId,
        'unique_id': uniqueId,
        'nickname': nickname,
        'comment': comment,
        'created_at': createdAt,
        'print_latency_ms': printLatencyMs,
        'print_success': printSuccess ? 1 : 0,
      };


  factory PrintedTicket.fromMap(Map<String, dynamic> map) => PrintedTicket(
        id: map['id'] as int?,
        msgId: (map['msg_id'] ?? '').toString(),
        uniqueId: (map['unique_id'] ?? '').toString(),
        nickname: (map['nickname'] ?? '').toString(),
        comment: (map['comment'] ?? '').toString(),
        createdAt: (map['created_at'] as int?) ?? 0,
        printLatencyMs: (map['print_latency_ms'] as int?) ?? 0,
        printSuccess: ((map['print_success'] as int?) ?? 0) == 1,
      );
}