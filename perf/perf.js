/* perf/perf.js — قياس أداء مؤقت: يعرض أوقات الإقلاع وفتح المحادثة على الشاشة (شارة ⏱ أسفل اليسار).
   اضغط الشارة لفتح/إغلاق التفاصيل، واضغط مطوّلاً لمسح القياسات. احذف سطر تحميله من index.html بعد التشخيص. */
(function () {
  var t0 = (window.performance && performance.timeOrigin) ? 0 : 0;
  var marks = [], chatOpenAt = 0, srv = null, pinged = false, box, chip, open = false, pend = 0;
  function now() { return Math.round(performance.now()); }
  function fmt(ms) { return ms >= 1000 ? (ms / 1000).toFixed(2) + 's' : ms + 'ms'; }
  window.__bbMark = function (name, perChat) {
    var t = now();
    if (name === 'chat-open') { chatOpenAt = t; marks = marks.filter(function (m) { return !m.chat; }); }
    if (!perChat && marks.some(function (m) { return m.name === name && !m.chat; })) return;   /* أول مرة فقط للإقلاع */
    marks.push({ name: name, t: t, chat: !!perChat, rel: perChat ? t - chatOpenAt : t });
    if (name === 'list-item' && !pinged) { pinged = true; setTimeout(pingServer, 2500); }
    schedule();
  };
  function pingServer() {
    try {
      var u = (typeof currentUser !== 'undefined') ? currentUser : null;
      if (!u || typeof db === 'undefined') { srv = null; setTimeout(pingServer, 1500); return; }
      var a = now();
      /* وثيقة عشوائية غير موجودة (ما عليها مستمع) = رحلة شبكة حقيقية للسيرفر */
      db.collection('giftCatalog').doc('__ping' + Date.now()).get({ source: 'server' }).then(function () { srv = now() - a; schedule(); }).catch(function () { srv = -1; schedule(); });
    } catch (e) {}
  }

  /* ===== قياس ما يعمل بالخلفية: مراقبات DOM، مؤقتات، ومهام طويلة تسبب التقطيع ===== */
  var stats = {}, longN = 0, longMax = 0, longSum = 0;
  function rec(key, ms) { var s = stats[key] || (stats[key] = { n: 0, ms: 0, max: 0 }); s.n++; s.ms += ms; if (ms > s.max) s.max = ms; }
  function where() {
    try {
      var st = (new Error()).stack.split('\n');
      for (var i = 3; i < st.length; i++) {
        if (st[i].indexOf('perf.js') > -1) continue;
        var m = st[i].match(/([^\/\s()]*):(\d+):\d+\)?\s*$/);
        if (m) return (m[1] || 'index') + ':' + m[2];
      }
    } catch (e) {}
    return '?';
  }
  try {
    var OrigMO = window.MutationObserver;
    if (OrigMO) {
      var WrapMO = function (cb) {
        var site = where();
        return new OrigMO(function (muts, obs) { var t = performance.now(); try { return cb.call(this, muts, obs); } finally { rec('MO ' + site, performance.now() - t); } });
      };
      WrapMO.prototype = OrigMO.prototype; window.MutationObserver = WrapMO;
    }
    var origIv = window.setInterval;
    window.setInterval = function (fn, ms) {
      if (typeof fn !== 'function') return origIv.apply(this, arguments);
      var site = where(), args = Array.prototype.slice.call(arguments, 2);
      return origIv.call(this, function () { var t = performance.now(); try { return fn.apply(this, args); } finally { rec('IV ' + site + ' @' + ms, performance.now() - t); } }, ms);
    };
    if (window.PerformanceObserver) {
      new PerformanceObserver(function (l) { l.getEntries().forEach(function (e) { longN++; longSum += e.duration; if (e.duration > longMax) longMax = e.duration; }); schedule(); }).observe({ entryTypes: ['longtask'] });
    }
  } catch (e) {}
  function topStats() {
    return Object.keys(stats).map(function (k) { return [k, stats[k]]; }).sort(function (a, b) { return b[1].ms - a[1].ms; }).slice(0, 7)
      .map(function (x) { return '  ' + x[0] + ' · ' + x[1].n + '× · ' + Math.round(x[1].ms) + 'ms (أطول ' + Math.round(x[1].max) + ')'; });
  }

  function lines() {
    var out = [], boot = marks.filter(function (m) { return !m.chat; }), ch = marks.filter(function (m) { return m.chat; });
    out.push('إقلاع (من بداية الصفحة):');
    boot.forEach(function (m) { out.push('  ' + m.name + ' ' + fmt(m.rel)); });
    out.push('تخزين Firestore المحلي: ' + (window.__bbPersist || '؟'));
    out.push('قراءة من السيرفر: ' + (srv === null ? '…' : srv < 0 ? 'فشلت' : fmt(srv)));
    if (ch.length) { out.push('آخر فتح محادثة:'); ch.forEach(function (m) { out.push('  ' + m.name + ' +' + fmt(m.rel)); }); }
    out.push('مهام طويلة (>50ms): ' + longN + ' · المجموع ' + Math.round(longSum) + 'ms · الأطول ' + Math.round(longMax) + 'ms');
    out.push('الأثقل بالخلفية (مراقب/مؤقت · عدد · وقت):');
    topStats().forEach(function (l) { out.push(l); });
    return out.join('\n');
  }
  function paint() {
    pend = 0;
    if (!document.body) return;
    if (!chip) {
      chip = document.createElement('div'); chip.textContent = '⏱';
      chip.style.cssText = 'position:fixed;left:8px;bottom:84px;z-index:2147483000;width:30px;height:30px;border-radius:15px;background:rgba(0,0,0,.55);color:#ffd96a;font:15px/30px sans-serif;text-align:center;opacity:.75';
      var lp = 0;
      chip.addEventListener('click', function () { open = !open; paint(); });
      chip.addEventListener('touchstart', function () { lp = setTimeout(function () { marks = []; srv = null; pinged = false; stats = {}; longN = 0; longMax = 0; longSum = 0; open = false; paint(); }, 900); }, { passive: true });
      ['touchend', 'touchmove', 'touchcancel'].forEach(function (ev) { chip.addEventListener(ev, function () { clearTimeout(lp); }, { passive: true }); });
      document.body.appendChild(chip);
      box = document.createElement('div');
      box.style.cssText = 'position:fixed;left:8px;bottom:120px;z-index:2147483000;max-width:88vw;max-height:55vh;overflow:auto;background:rgba(0,0,0,.82);color:#fff;font:11px/1.55 monospace;padding:8px 10px;border-radius:10px;white-space:pre;direction:rtl;text-align:right;display:none';
      document.body.appendChild(box);
    }
    box.style.display = open ? 'block' : 'none';
    if (open) box.textContent = lines();
  }
  function schedule() { if (!pend) pend = setTimeout(paint, 200); }
  document.addEventListener('DOMContentLoaded', function () { window.__bbMark('dom-ready'); paint(); });
  window.addEventListener('load', function () { window.__bbMark('page-load'); });
})();
