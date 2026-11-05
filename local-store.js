/* local-store.js — تخزين محلي داخل ذاكرة التطبيق (IndexedDB). يُحذف عند مسح بيانات التطبيق أو تسجيل الخروج.
   - آخر 20 رسالة من كل محادثة (خاصة أو مجموعة) بدون الصور والفيديوهات.
   - تُرسم فوراً عند فتح المحادثة (حتى بدون إنترنت) ثم تحلّ محلها الرسائل الحقيقية من Firestore.
   (أشكال الهدايا والرموز وحركاتها وملصقات المجموعات تُخزَّن عبر offline-sw.js في Cache Storage). */
(function () {
  'use strict';
  var DB_NAME = 'babylon-local', STORE = 'chatMsgs', KEEP = 20, MAX_CHATS = 150;
  var dbP = null, timers = {}, saveCount = 0;

  function openDB() {
    if (dbP) return dbP;
    dbP = new Promise(function (res, rej) {
      try {
        var rq = indexedDB.open(DB_NAME, 1);
        rq.onupgradeneeded = function () {
          var d = rq.result;
          if (!d.objectStoreNames.contains(STORE)) {
            var s = d.createObjectStore(STORE, { keyPath: 'key' });
            s.createIndex('savedAt', 'savedAt');
          }
        };
        rq.onsuccess = function () { res(rq.result); };
        rq.onerror = function () { dbP = null; rej(rq.error); };
        rq.onblocked = function () { dbP = null; rej(new Error('blocked')); };
      } catch (e) { dbP = null; rej(e); }
    });
    return dbP;
  }
  function tx(mode, fn) {
    return openDB().then(function (d) {
      return new Promise(function (res, rej) {
        var t = d.transaction(STORE, mode), st = t.objectStore(STORE), out = fn(st);
        t.oncomplete = function () { res(out && out.result !== undefined ? out.result : out); };
        t.onerror = t.onabort = function () { rej(t.error); };
      });
    });
  }
  function uid() {
    try { if (typeof currentUser !== 'undefined' && currentUser && currentUser.uid) return currentUser.uid; } catch (e) {}
    try { return (auth && auth.currentUser && auth.currentUser.uid) || ''; } catch (e) {}
    return '';
  }
  function keyOf(chatId) { var u = uid(); return u && chatId ? u + '|' + chatId : ''; }

  /* رسالة وسائط (صورة/فيديو) => لا تُخزَّن */
  function isMedia(m) {
    if (!m) return false;
    var t = String(m.type || '').toLowerCase();
    if (t === 'sticker' || t === 'stars' || t === 'gift') return false;
    if (t === 'image' || t === 'video' || t === 'photo') return true;
    return !!(m.imageUrl || m.videoUrl);
  }
  function clean(m) {
    var c;
    try { c = JSON.parse(JSON.stringify(m)); } catch (e) { return null; }
    /* ردّ على قصة: نحذف روابط صورة/فيديو القصة */
    if (c.storyReplyData && typeof c.storyReplyData === 'object') { delete c.storyReplyData.imageUrl; delete c.storyReplyData.videoUrl; }
    return c;
  }

  function doSave(chatId, snap) {
    var key = keyOf(chatId); if (!key) return;
    var docs = snap.docs || [];
    var fromCache = !!(snap.metadata && snap.metadata.fromCache);
    if (fromCache && !docs.length) return;               /* لا نمسح المحفوظ بسبب كاش فارغ */
    var out = [];
    for (var i = 0; i < docs.length && out.length < KEEP; i++) {   /* docs مرتّبة من الأحدث للأقدم */
      var d = docs[i];
      if (d.metadata && d.metadata.hasPendingWrites) continue;     /* رسالة لم تُرسل بعد */
      var m = d.data();
      if (isMedia(m)) continue;
      var c = clean(m); if (!c) continue;
      out.push({ id: d.id, d: c });
    }
    out.reverse();                                        /* من الأقدم للأحدث */
    var rec = { key: key, uid: uid(), chatId: chatId, savedAt: Date.now(), msgs: out };
    tx('readwrite', function (s) { return s.put(rec); }).then(function () {
      if (++saveCount % 10 === 0) prune();
    }).catch(function () {});
  }
  function save(chatId, snap) {
    try {
      if (!chatId || !snap) return;
      clearTimeout(timers[chatId]);
      timers[chatId] = setTimeout(function () { try { doSave(chatId, snap); } catch (e) {} }, 400);
    } catch (e) {}
  }
  function prune() {
    openDB().then(function (d) {
      var t = d.transaction(STORE, 'readwrite'), s = t.objectStore(STORE);
      var cr = s.count();
      cr.onsuccess = function () {
        var extra = cr.result - MAX_CHATS; if (extra <= 0) return;
        var cur = s.index('savedAt').openCursor();
        cur.onsuccess = function () {
          var c = cur.result; if (!c || extra <= 0) return;
          c.delete(); extra--; c.continue();
        };
      };
    }).catch(function () {});
  }

  /* رسم الرسائل المحفوظة فوراً عند فتح المحادثة (فقط إذا لم تصل الرسائل الحقيقية بعد) */
  function paint(chatId, grp) {
    try {
      var key = keyOf(chatId); if (!key) return;
      tx('readonly', function (s) { return s.get(key); }).then(function (rec) {
        try {
          if (!rec || !rec.msgs || !rec.msgs.length) return;
          if (typeof activeChatId === 'undefined' || activeChatId !== chatId) return;
          if (window.__bbMsgSig || window.__bbRendered) return;       /* وصلت الرسائل الحقيقية */
          var box = document.getElementById('messagesArea'); if (!box) return;
          if (box.querySelector('.msg-bubble, .sys-msg, .g-row')) return;
          if (typeof renderMsgDoc !== 'function') return;
          Array.prototype.slice.call(box.children).forEach(function (c) { c.remove(); });
          rec.msgs.forEach(function (x) {
            var data = x.d;
            try {
              renderMsgDoc({ id: x.id, data: function () { return data; }, metadata: { hasPendingWrites: false, fromCache: true }, exists: true }, box, null);
            } catch (e) {}
          });
          if (grp && typeof finalizeGroupRows === 'function') { try { finalizeGroupRows(box); } catch (e) {} }
          box.scrollTop = box.scrollHeight;
          window.__bbRendered = null;      /* أول لقطة حقيقية تُعيد الرسم كاملاً */
        } catch (e) {}
      }).catch(function () {});
    } catch (e) {}
  }

  function clearAll() {
    try { Object.keys(timers).forEach(function (k) { clearTimeout(timers[k]); }); } catch (e) {}
    return openDB().then(function (d) {
      return new Promise(function (res) {
        var t = d.transaction(STORE, 'readwrite'); t.objectStore(STORE).clear(); t.oncomplete = t.onerror = t.onabort = function () { res(); };
      });
    }).catch(function () {});
  }
  function clearChat(chatId) { var k = keyOf(chatId); if (!k) return Promise.resolve(); return tx('readwrite', function (s) { return s.delete(k); }).catch(function () {}); }

  window.bbLocalSaveSnap = save;
  window.bbLocalPaint = paint;
  window.bbLocal = { clear: clearAll, clearChat: clearChat, keep: KEEP };

  /* تسجيل الخروج => احذف كل الرسائل المحفوظة من هذا الجهاز */
  try {
    if (typeof auth !== 'undefined' && auth.onAuthStateChanged) {
      var seenUser = false;
      auth.onAuthStateChanged(function (u) { if (u) seenUser = true; else if (seenUser) clearAll(); });
    }
  } catch (e) {}
})();
