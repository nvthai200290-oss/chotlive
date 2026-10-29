'use strict';
// CHOTLIVE Relay v2.1: TikTok v2 nested chat + legacy chat -> single stable JSON shape.
const os = require('node:os');
const { WebSocketServer } = require('ws');
const connector = require('tiktok-live-connector');
const { normalizeChat } = require('./comment_normalizer');
const Connection = connector.TikTokLiveConnection || connector.WebcastPushConnection;
const CHAT = connector.WebcastEvent?.CHAT || 'chat';
const STREAM_END = connector.ControlEvent?.STREAM_END || connector.WebcastEvent?.STREAM_END || 'streamEnd';
const DISCONNECTED = connector.ControlEvent?.DISCONNECTED || 'disconnected';
const ERROR = connector.ControlEvent?.ERROR || 'error';
const PORT = Number(process.env.PORT || 8080);
const VERSION = '2.1.0';
const wss = new WebSocketServer({ host: '0.0.0.0', port: PORT, perMessageDeflate: false });
let serial = 0;

function lanAddresses() {
  return Object.values(os.networkInterfaces()).flat()
    .filter((i) => i && (i.family === 'IPv4' || i.family === 4) && !i.internal)
    .map((i) => 'ws://' + i.address + ':' + PORT);
}
wss.on('listening', () => {
  console.log('CHOTLIVE Relay v' + VERSION + ' listening on ' + PORT);
  for (const address of lanAddresses()) console.log('APP RELAY URL: ' + address);
});
wss.on('error', (err) => console.error('Relay server error:', err));

wss.on('connection', (socket, request) => {
  if (request.socket?.setNoDelay) request.socket.setNoDelay(true);
  let live = null;
  let generation = 0;
  let currentAccount = '';
  let received = 0;
  let invalid = 0;
  function send(payload) {
    if (socket.readyState === 1) socket.send(JSON.stringify(payload));
  }
  function status(state, message) {
    send({ type: 'status', state, message, relay_version: VERSION,
      received_count: received, invalid_count: invalid, uniqueId: currentAccount });
  }
  function cleanup() {
    generation++;
    const previous = live;
    live = null;
    if (previous) {
      try { previous.removeAllListeners(); } catch (_) {}
      try { Promise.resolve(previous.disconnect()).catch(() => {}); } catch (_) {}
    }
  }
  status('connecting', 'Đã kết nối máy chủ CHOTLIVE v' + VERSION + '. Nhập ID kênh và kết nối LIVE.');

  socket.on('message', (raw) => {
    let cmd;
    try { cmd = JSON.parse(raw.toString()); }
    catch (_) { status('error', 'Gói tin điều khiển không hợp lệ.'); return; }

    if (cmd.action === 'ping') {
      send({ type: 'pong', client_ts: cmd.client_ts, server_ts: Date.now() });
      return;
    }
    if (cmd.action === 'disconnect') {
      cleanup();
      currentAccount = '';
      status('idle', 'Đã ngắt kết nối TikTok LIVE.');
      return;
    }
    if (cmd.action !== 'connect') return;

    const account = String(cmd.uniqueId || '').trim()
      .replace(/^https?:\/\/(www\.)?tiktok\.com\/@/i, '')
      .replace(/\/live\/?(?:\?.*)?$/i, '')
      .replace(/^@+/, '');
    if (!account) { status('error', 'Chưa nhập ID tài khoản đang LIVE.'); return; }
    cleanup();
    currentAccount = account;
    received = 0;
    invalid = 0;
    const id = generation;
    status('connecting', 'Đang kết nối tới TikTok LIVE @' + account + '...');
    let instance;
    try {
      if (!Connection) throw new Error('Thư viện TikTok chưa hỗ trợ kết nối LIVE.');
      const options = { processInitialData: false, enableExtendedGiftInfo: false };
      if (process.env.TIKTOK_SIGN_API_KEY) options.signApiKey = process.env.TIKTOK_SIGN_API_KEY;
      instance = new Connection(account, options);
      live = instance;
    } catch (e) {
      status('error', 'Không tạo được kết nối TikTok: ' + (e.message || e));
      return;
    }

    instance.on(CHAT, (event) => {
      if (id !== generation) return;
      const at = Date.now();
      const chat = normalizeChat(event, at);
      if (!chat) {
        invalid++;
        if (invalid <= 3 || invalid % 100 === 0)
          status('connected', 'Có sự kiện chat không chứa nội dung (đã bỏ qua ' + invalid + ').');
        return;
      }
      if (!chat.msg_id || chat.msg_id.startsWith('relay_'))
        chat.msg_id = at + '_' + (++serial);
      received++;
      send(chat); // no artificial throttling or buffering
    });
    instance.on(STREAM_END, () => {
      if (id === generation) status('ended', 'Phiên LIVE @' + account + ' đã kết thúc.');
    });
    instance.on(DISCONNECTED, () => {
      if (id === generation) status('disconnected', 'Mất luồng TikTok LIVE @' + account + '.');
    });
    instance.on(ERROR, (err) => {
      if (id !== generation) return;
      const message = err?.info || err?.message || err?.exception?.message || String(err);
      status('error', 'Lỗi TikTok LIVE: ' + message);
    });
    Promise.resolve().then(() => instance.connect())
      .then((state) => {
        if (id === generation) status('connected', 'Đang nhận bình luận mới từ @' + account +
          ' (phòng ' + String(state?.roomId || '?') + ')');
      })
      .catch((err) => {
        if (id === generation)
          status('error', 'Không kết nối được TikTok LIVE @' + account + ': ' + (err?.message || err));
      });
  });
  socket.on('close', cleanup);
  socket.on('error', (err) => console.error('Client WebSocket error:', err.message));
});
