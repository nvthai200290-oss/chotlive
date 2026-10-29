import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/models.dart';
import 'services/comment_source.dart';
import 'services/local_database.dart';
import 'services/printer_service.dart';
import 'services/settings_service.dart';
import 'services/telemetry_service.dart';
import 'services/ticket_service.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();


  final settings = SettingsService();
  await settings.init();


  final localDb = LocalDatabase();
  await localDb.init();


  final telemetry = TelemetryService();
  final commentSource = CommentSource(telemetry: telemetry);
  final printerService = PrinterService(settings: settings);
  final ticketService = TicketService(
    printerService: printerService,
    localDatabase: localDb,
    telemetryService: telemetry,
  );


  unawaited(printerService.autoReconnectSavedPrinter());


  runApp(ChotLiveApp(
    settings: settings,
    localDb: localDb,
    telemetry: telemetry,
    commentSource: commentSource,
    printerService: printerService,
    ticketService: ticketService,
  ));
}


class ChotLiveApp extends StatelessWidget {
  final SettingsService settings;
  final LocalDatabase localDb;
  final TelemetryService telemetry;
  final CommentSource commentSource;
  final PrinterService printerService;
  final TicketService ticketService;


  const ChotLiveApp({
    super.key,
    required this.settings,
    required this.localDb,
    required this.telemetry,
    required this.commentSource,
    required this.printerService,
    required this.ticketService,
  });


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CHOTLIVE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE60023),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF101216),
        useMaterial3: true,
      ),
      home: MainShell(
        settings: settings,
        localDb: localDb,
        telemetry: telemetry,
        commentSource: commentSource,
        printerService: printerService,
        ticketService: ticketService,
      ),
    );
  }
}


class MainShell extends StatefulWidget {
  final SettingsService settings;
  final LocalDatabase localDb;
  final TelemetryService telemetry;
  final CommentSource commentSource;
  final PrinterService printerService;
  final TicketService ticketService;


  const MainShell({
    super.key,
    required this.settings,
    required this.localDb,
    required this.telemetry,
    required this.commentSource,
    required this.printerService,
    required this.ticketService,
  });


  @override
  State<MainShell> createState() => _MainShellState();
}


class _MainShellState extends State<MainShell> {
  // Man hinh dau tien mac dinh khi mo app: 0 = 1. Binh luan TikTok LIVE
  int _selectedIndex = 0;


  final List<LiveComment> _comments = [];
  StreamSubscription<LiveComment>? _commentSub;
  late TextEditingController _liveIdController;


  static const List<String> _menuTitles = [
    '1. Bình luận TikTok LIVE',
    '2. Thiết lập nhanh',
    '3. Mẫu in cửa hàng',
    '4. Máy in Bluetooth',
    '5. Chế độ B',
    '6. Lịch sử phiếu đã in',
    '7. Quản trị',
  ];


  @override
  void initState() {
    super.initState();
    _liveIdController = TextEditingController(text: widget.settings.tiktokUniqueId);


    _commentSub = widget.commentSource.commentStream.listen((newComment) {
      setState(() {
        _comments.insert(0, newComment);
        if (_comments.length > 1000) {
          _comments.removeLast();
        }
      });


      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (newComment.tUiRender == null) {
          final int tUi = DateTime.now().millisecondsSinceEpoch;
          newComment.tUiRender = tUi;
          widget.telemetry.recordCommentLatency(
            tRelayRecv: newComment.tRelayRecv,
            tAppRecv: newComment.tAppRecv,
            tUiRender: tUi,
          );
        }
      });
    });
  }


  @override
  void dispose() {
    _commentSub?.cancel();
    _liveIdController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.commentSource,
        widget.printerService,
        widget.settings,
        widget.telemetry,
      ]),
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFF181B22),
            title: Text(
              _menuTitles[_selectedIndex],
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            actions: [
              _buildBadge(
                label: widget.commentSource.connectionState == 'connected' ? 'LIVE' : 'OFF',
                color: widget.commentSource.connectionState == 'connected'
                    ? Colors.green.shade700
                    : Colors.red.shade800,
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => setState(() => _selectedIndex = 3),
                child: _buildBadge(
                  label: widget.printerService.isConnected ? 'MÁY IN OK' : 'CHƯA IN',
                  color: widget.printerService.isConnected
                      ? Colors.blue.shade700
                      : Colors.orange.shade800,
                ),
              ),
              const SizedBox(width: 10),
            ],
          ),
          drawer: Drawer(
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: const Color(0xFFE60023),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CHOTLIVE v2.0',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text('Chạm bình luận - In phiếu tức thời'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _menuTitles.length,
                      itemBuilder: (context, idx) => ListTile(
                        selected: _selectedIndex == idx,
                        selectedTileColor: Colors.white10,
                        title: Text(_menuTitles[idx]),
                        onTap: () {
                          setState(() => _selectedIndex = idx);
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          body: _buildScreen(),
        );
      },
    );
  }


  Widget _buildBadge({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }


  Widget _buildScreen() {
    switch (_selectedIndex) {
      case 0:
        return _buildLiveCommentScreen();
      case 1:
        return _buildQuickSettingsScreen();
      case 2:
        return _buildPrintTemplateScreen();
      case 3:
        return _buildBluetoothPrinterScreen();
      case 4:
        return _buildModeBScreen();
      case 5:
        return _buildTicketHistoryScreen();
      case 6:
        return _buildAdminTelemetryScreen();
      default:
        return _buildLiveCommentScreen();
    }
  }


  // 1. MAN HINH BINH LUAN TIKTOK LIVE
  Widget _buildLiveCommentScreen() {
    final isConnected = widget.commentSource.connectionState == 'connected';
    final isConnecting = widget.commentSource.connectionState == 'connecting';


    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          color: const Color(0xFF1A1E26),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _liveIdController,
                      decoration: const InputDecoration(
                        isDense: true,
                        prefixText: '@',
                        hintText: 'Nhập tài khoản TikTok đang LIVE...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isConnected ? Colors.red.shade700 : Colors.green.shade700,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      if (isConnected || isConnecting) {
                        widget.commentSource.disconnect();
                      } else {
                        widget.settings.saveLiveAccountOnly(_liveIdController.text);
                        widget.commentSource.connect(
                          relayUrl: widget.settings.relayUrl,
                          uniqueId: _liveIdController.text,
                        );
                      }
                    },
                    child: Text(isConnected || isConnecting ? 'NGẮT' : 'KẾT NỐI'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.commentSource.statusMessage,
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    'Nhận: ${widget.commentSource.receivedChatCount} | Thiếu: ${widget.commentSource.incompleteChatCount}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.amberAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _comments.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Chưa có bình luận.\nNhập ID kênh đang LIVE và bấm KẾT NỐI.\nChạm trực tiếp vào bất kỳ bình luận nào để máy in nhiệt in phiếu ngay lập tức.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _comments.length,
                  itemBuilder: (context, index) {
                    final item = _comments[index];
                    final timeStr = formatHms(item.tAppRecv);
                    Color cardColor = const Color(0xFF1E232D);
                    if (item.lastPrintStatus == 'printing') cardColor = const Color(0xFF4A3B00);
                    if (item.lastPrintStatus == 'printed') cardColor = const Color(0xFF123524);
                    if (item.lastPrintStatus == 'error') cardColor = const Color(0xFF4A151B);


                    return Card(
                      color: cardColor,
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: InkWell(
                        onTap: () {
                          widget.ticketService.tapAndPrintImmediately(
                            item,
                            onStateChanged: () {
                              if (mounted) setState(() {});
                            },
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.nickname.trim().isEmpty ? 'Người xem TikTok' : item.nickname,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.cyanAccent,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.uniqueId.trim().isNotEmpty
                                                ? 'ID TikTok: @${item.uniqueId.trim()}'
                                                : (item.userId.trim().isNotEmpty
                                                    ? 'UID TikTok: ${item.userId.trim()}'
                                                    : 'ID TikTok: chưa được TikTok cung cấp'),
                                            style: const TextStyle(
                                              color: Colors.lightBlueAccent,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        Text(timeStr, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      item.comment,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                item.printCount > 0 ? 'ĐÃ IN (${item.printCount})' : 'CHẠM IN',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: item.printCount > 0 ? Colors.greenAccent : Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }


  // 2. MAN HINH THIET LAP NHANH
  Widget _buildQuickSettingsScreen() {
    final relayCtrl = TextEditingController(text: widget.settings.relayUrl);
    final idCtrl = TextEditingController(text: widget.settings.tiktokUniqueId);
    int paper = widget.settings.paperWidthMm;
    bool autoCut = widget.settings.autoCutPaper;


    return StatefulBuilder(
      builder: (context, setLocal) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Địa chỉ WebSocket Relay (trên PC hoặc VPS):'),
          const SizedBox(height: 6),
          TextField(controller: relayCtrl, decoration: const InputDecoration(border: OutlineInputBorder())),
          const SizedBox(height: 16),
          const Text('Tài khoản TikTok LIVE mặc định:'),
          const SizedBox(height: 6),
          TextField(
            controller: idCtrl,
            decoration: const InputDecoration(prefixText: '@', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          const Text('Khổ giấy in nhiệt:'),
          Row(
            children: [
              Radio<int>(value: 58, groupValue: paper, onChanged: (v) => setLocal(() => paper = v!)),
              const Text('58 mm'),
              const SizedBox(width: 24),
              Radio<int>(value: 80, groupValue: paper, onChanged: (v) => setLocal(() => paper = v!)),
              const Text('80 mm'),
            ],
          ),
          SwitchListTile(
            title: const Text('Tự động cắt giấy (Dành cho máy K80 có dao cắt)'),
            value: autoCut,
            onChanged: (v) => setLocal(() => autoCut = v),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              await widget.settings.saveQuickSettings(
                newRelayUrl: relayCtrl.text,
                newUniqueId: idCtrl.text,
                newPaperWidthMm: paper,
                newAutoCutPaper: autoCut,
              );
              _liveIdController.text = widget.settings.tiktokUniqueId;
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã lưu thiết lập nhanh.')),
                );
              }
            },
            child: const Text('LƯU THIẾT LẬP NHANH'),
          ),
        ],
      ),
    );
  }


  // 3. MAN HINH MAU IN CUA HANG
  Widget _buildPrintTemplateScreen() {
    final nameCtrl = TextEditingController(text: widget.settings.shopName);
    final phoneCtrl = TextEditingController(text: widget.settings.shopPhone);
    final footerCtrl = TextEditingController(text: widget.settings.shopFooter);
    double scale = widget.settings.fontScale;


    return StatefulBuilder(
      builder: (context, setLocal) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Tên Shop trên đầu phiếu:'),
          TextField(controller: nameCtrl),
          const SizedBox(height: 12),
          const Text('Số điện thoại liên hệ:'),
          TextField(controller: phoneCtrl),
          const SizedBox(height: 12),
          const Text('Ghi chú cuối phiếu:'),
          TextField(controller: footerCtrl),
          const SizedBox(height: 12),
          Text('Cỡ chữ: ${(scale * 100).round()}%'),
          Slider(value: scale, min: 0.8, max: 1.4, divisions: 6, onChanged: (v) => setLocal(() => scale = v)),
          ElevatedButton(
            onPressed: () async {
              await widget.settings.saveTemplateSettings(
                newShopName: nameCtrl.text,
                newShopPhone: phoneCtrl.text,
                newShopFooter: footerCtrl.text,
                newFontScale: scale,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu mẫu phiếu.')));
              }
            },
            child: const Text('LƯU MẪU PHIẾU'),
          ),
        ],
      ),
    );
  }


  // 4. MAN HINH MAY IN BLUETOOTH
  Widget _buildBluetoothPrinterScreen() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Trạng thái: ${widget.printerService.statusMessage}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: widget.printerService.isScanning
                      ? null
                      : () => widget.printerService.scanDevices(),
                  child: const Text('QUÉT BLUETOOTH'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => widget.printerService.enqueueTicketPrint(
                    nickname: 'Khách In Thử',
                    uniqueId: 'test_bluetooth',
                    comment: 'Kiểm tra in tiếng Việt có dấu sắc huyền hỏi ngã nặng!',
                    timestamp: DateTime.now(),
                  ),
                  child: const Text('IN THỬ'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: widget.printerService.devices.length,
              itemBuilder: (context, idx) {
                final d = widget.printerService.devices[idx];
                return ListTile(
                  title: Text(d.name),
                  subtitle: Text(d.macAdress),
                  trailing: ElevatedButton(
                    onPressed: () => widget.printerService.connectPrinter(d.macAdress, d.name),
                    child: const Text('KẾT NỐI'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }


  // 5. MAN HINH CHE DO B (Ke thua tu THAO-NGUYEN-LIVE-AUDIT-v1.0.zip)
  Widget _buildModeBScreen() {
    final customerCtrl = TextEditingController();
    final contentCtrl = TextEditingController();


    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'CHẾ ĐỘ B - TẠO PHIẾU THỦ CÔNG & KIỂM THỬ B1',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.cyanAccent),
        ),
        const SizedBox(height: 6),
        const Text(
          'Kế thừa từ chức năng "+ Thêm bình luận thủ công / Mẫu thử B1" trong bản THAO-NGUYEN-LIVE cũ, giúp in nhanh phiếu cho khách đặt ngoài luồng hoặc kiểm tra máy in.',
          style: TextStyle(fontSize: 13, color: Colors.white70),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: customerCtrl,
          decoration: const InputDecoration(labelText: 'Tên khách hàng', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: contentCtrl,
          decoration: const InputDecoration(labelText: 'Nội dung đơn / Bình luận', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.print),
          label: const Text('IN PHIẾU THỦ CÔNG NGAY'),
          onPressed: () {
            if (contentCtrl.text.trim().isEmpty) return;
            final manualItem = LiveComment(
              msgId: 'manual_${DateTime.now().millisecondsSinceEpoch}',
              uniqueId: 'khach_le',
              nickname: customerCtrl.text.trim().isEmpty ? 'Khách Lẻ' : customerCtrl.text.trim(),
              comment: contentCtrl.text.trim(),
              tRelayRecv: DateTime.now().millisecondsSinceEpoch,
              tAppRecv: DateTime.now().millisecondsSinceEpoch,
            );
            widget.ticketService.tapAndPrintImmediately(manualItem, onStateChanged: () {});
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Đã gửi lệnh in phiếu thủ công.')),
            );
          },
        ),
      ],
    );
  }


  // 6. MAN HINH LICH SU PHIEU DA IN
  Widget _buildTicketHistoryScreen() {
    String query = '';
    return StatefulBuilder(
      builder: (context, setLocal) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Tìm phiếu đã in...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => setLocal(() => query = v),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<PrintedTicket>>(
              future: widget.localDb.getTickets(query: query),
              builder: (context, snap) {
                final list = snap.data ?? [];
                if (list.isEmpty) return const Center(child: Text('Chưa có lịch sử phiếu.'));
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, idx) {
                    final t = list[idx];
                    final dt = formatShortDateTime(t.createdAt);
                    return ListTile(
                      title: Text('${t.nickname} (@${t.uniqueId})'),
                      subtitle: Text('${t.comment}\n$dt • ${t.printLatencyMs} ms'),
                      isThreeLine: true,
                      trailing: ElevatedButton(
                        onPressed: () => widget.printerService.enqueueTicketPrint(
                          nickname: t.nickname,
                          uniqueId: t.uniqueId,
                          comment: t.comment,
                          timestamp: DateTime.fromMillisecondsSinceEpoch(t.createdAt),
                        ),
                        child: const Text('IN LẠI'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }


  // 7. MAN HINH QUAN TRI & DO DO TRE THUC TE
  Widget _buildAdminTelemetryScreen() {
    final t = widget.telemetry;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          t.buildSummaryReport(),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: t.buildSummaryReport()));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã sao chép báo cáo độ trễ.')),
                    );
                  }
                },
                child: const Text('SAO CHÉP BÁO CÁO'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: () => widget.telemetry.reset(),
                child: const Text('ĐẶT LẠI BỘ ĐO'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}