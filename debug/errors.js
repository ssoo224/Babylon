/* debug/errors.js — يعرض أخطاء JavaScript على الشاشة (للمطوّر فقط: يشتغل إذا كان localStorage.bbDebug === '1').
   اللي يحدد هذا العلم هو index.html عند تسجيل الدخول: '1' لحسابات المطورين و'0' لغيرهم.
   اضغط على الشريط الأحمر لإغلاقه. */
(function () {
  try { if (localStorage.getItem('bbDebug') !== '1') return; } catch (e) { return; }
  var box, list = [];
  function paint() {
    if (!document.body) return;
    if (!box) {
      box = document.createElement('div');
      box.style.cssText = 'position:fixed;top:0;left:0;right:0;z-index:2147483647;max-height:38vh;overflow:auto;background:#7f1d1d;color:#fff;font:11px/1.5 monospace;padding:6px 10px;direction:ltr;text-align:left;white-space:pre-wrap;word-break:break-all;opacity:.96';
      box.onclick = function () { list = []; box.remove(); box = null; };
      document.body.appendChild(box);
    }
    box.textContent = list.slice(-6).join('\n—\n');
  }
  function add(m) { list.push(String(m).slice(0, 700)); if (list.length > 20) list.shift(); paint(); }
  function frames() {
    try {
      return (new Error()).stack.split('\n').slice(1).filter(function (l) { return l.indexOf('errors.js') < 0; }).slice(0, 4)
        .map(function (l) { var m = l.match(/([^\/\s()]*):(\d+):\d+\)?\s*$/); return m ? (m[1] || 'index') + ':' + m[2] : ''; }).filter(Boolean).join(' ← ');
    } catch (e) { return '?'; }
  }
  window.addEventListener('error', function (e) {
    add('ERROR: ' + e.message + '\n' + String(e.filename || '').split('/').pop() + ':' + e.lineno + ':' + e.colno);
  });
  window.addEventListener('unhandledrejection', function (e) {
    var r = e.reason; add('PROMISE: ' + ((r && (r.stack || r.message)) || r));
  });
  var ce = console.error;
  console.error = function () {
    try { add('console.error: ' + Array.prototype.map.call(arguments, function (a) { return (a && a.message) || (typeof a === 'object' ? JSON.stringify(a) : a); }).join(' ')); } catch (x) {}
    return ce.apply(console, arguments);
  };
  /* تحديد مكان استدعاء doc() بمسار فارغ: يسجّل السطور اللي استدعته */
  function hook() {
    try {
      var F = window.firebase && firebase.firestore;
      if (!F || !F.CollectionReference || !F.Firestore) return false;
      var wrap = function (proto, label) {
        if (!proto || proto.__bbDocHook || typeof proto.doc !== 'function') return;
        proto.__bbDocHook = true;
        var od = proto.doc;
        proto.doc = function (p) {
          if (arguments.length && (p === '' || p === null)) add('doc("") فارغ [' + label + ']: ' + frames());
          return od.apply(this, arguments);
        };
      };
      wrap(F.CollectionReference.prototype, 'collection.doc');
      wrap(F.Firestore.prototype, 'db.doc');
      return true;
    } catch (e) { return false; }
  }
  var n = 0, iv = setInterval(function () { if (hook() || ++n > 200) clearInterval(iv); }, 50);
})();
