'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { normalizeChat } = require('../comment_normalizer');

test('modern TikTok v2 fields: user.displayId and content', () => {
  const x = normalizeChat({
    user: { id: '778899', displayId: 'khach_ao', nickname: 'Nguyễn Anh' },
    content: 'Chốt áo đen size L',
    common: { msgId: 'm2' }
  }, 123456);
  assert.equal(x.unique_id, 'khach_ao');
  assert.equal(x.user_id, '778899');
  assert.equal(x.nickname, 'Nguyễn Anh');
  assert.equal(x.comment, 'Chốt áo đen size L');
  assert.equal(x.msg_id, 'm2');
  assert.equal(x.t_relay_recv, 123456);
});

test('legacy flat event remains compatible', () => {
  const x = normalizeChat({ uniqueId: '@buyer99', nickname: 'Khách A',
    comment: 'Em lấy 2 cái', msgId: 'old1' });
  assert.equal(x.unique_id, 'buyer99');
  assert.equal(x.comment, 'Em lấy 2 cái');
  assert.equal(x.msg_id, 'old1');
});

test('nested legacy payload remains compatible', () => {
  const x = normalizeChat({user:{uniqueId:'buyer77', nickname:'Khách B'},comment:'Lấy em'});
  assert.equal(x.unique_id, 'buyer77');
  assert.equal(x.comment, 'Lấy em');
});

test('TikTok numeric UID is preserved when public username not supplied', () => {
  const x = normalizeChat({user:{id:999111, nickname:'A'},content:'Đặt hàng'});
  assert.equal(x.unique_id, '');
  assert.equal(x.user_id, '999111');
  assert.equal(x.comment, 'Đặt hàng');
});

test('never turn unrelated event into an empty comment', () => {
  assert.equal(normalizeChat({user:{displayId:'x'},content:''}),null);
  assert.equal(normalizeChat(null),null);
});
