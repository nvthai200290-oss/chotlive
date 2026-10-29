'use strict';

// Adapt both flattened v1 and nested protobuf v2 TikTok LIVE chat payloads.
// Never fabricate a username or a comment.
function firstText(...values) {
  for (const value of values) {
    if (typeof value === 'string' && value.trim()) return value.trim();
    if ((typeof value === 'number' && Number.isFinite(value)) || typeof value === 'bigint') return String(value);
  }
  return '';
}
function normalizeChat(event, receivedAt = Date.now()) {
  if (!event || typeof event !== 'object') return null;
  const data = event.data && typeof event.data === 'object' && event.event === 'chat'
    ? event.data : event;
  const user = data.user && typeof data.user === 'object' ? data.user : {};
  const comment = firstText(data.content, data.comment, data.text, data.message?.content);
  if (!comment) return null;

  const username = firstText(user.displayId, user.uniqueId, data.displayId,
    data.uniqueId, data.unique_id).replace(/^@+/, '');
  const userId = firstText(user.id, user.userId, data.userId, data.user_id);
  const nickname = firstText(user.nickname, data.nickname, username) || 'Người xem TikTok';
  const msgId = firstText(data.common?.msgId, data.msgId, data.messageId, data.id)
    || 'relay_' + receivedAt;
  return {
    type: 'chat',
    msg_id: msgId,
    unique_id: username,
    user_id: userId,
    nickname,
    comment,
    t_relay_recv: receivedAt,
  };
}
module.exports = { normalizeChat, firstText };
