/* ===== gifts.js — هدايا Plush Pepe + المحفظة + المتجر ===== */
/* يُحمَّل بعد models.js وقبل star-gift.js. اقرأ gifts/README.md */
const PEPE_MAX=30, PEPE_PRICE=1000, DEV_BIG=1000000000;
/* أنواع الهدايا: كل نوع له مجموعة بفايربيس + مبيعات + نماذج. نوع جديد = سطر هنا + قواعد firestore */
const GIFT_KINDS={
  pepe:{key:'pepe',name:'Plush Pepe',coll:'pepes',sales:'pepeSales',field:'lastBuy',max:30,price:1000,dir:'models',models:PEPE_MODELS},
  cat:{key:'cat',name:'Scared Cat',coll:'cats',sales:'catSales',field:'lastBuyCat',max:30,price:500,dir:'cat-models',models:CAT_MODELS}
};
const gk=k=>GIFT_KINDS[k||'pepe']||GIFT_KINDS.pepe;
const PEPE_BGS=[{n:'Chocolate',a:'#b8795a',b:'#5b3326',p:30},{n:'Emerald',a:'#3fd0a0',b:'#0a5a40',p:25},{n:'Sapphire',a:'#5784e6',b:'#122565',p:20},{n:'Ruby',a:'#ea4b50',b:'#650d1a',p:15},{n:'Black',a:'#26262c',b:'#000000',p:10}];
const PEPE_SYMS=[
 {n:'Moon',p:30,d:'M20.5 14.2A8.6 8.6 0 0 1 9.8 3.5a8.6 8.6 0 1 0 10.7 10.7z'},
 {n:'Flame',p:25,d:'M12.2 2.5c.5 3.2 3.3 4.7 4.6 7.6 1.4 3.2.3 7.2-2.8 8.9a6 6 0 0 1-7.9-7.2c.5-1.6 1.6-2.6 2.5-3.9.3 1.5.9 2.3 1.9 2.6-.6-3.1.1-6.4 1.7-8z'},
 {n:'Crown',p:20,d:'M3 7.5l4.2 3.6L12 4l4.8 7.1L21 7.5 19.2 18H4.8zM5 20h14v2H5z'},
 {n:'Diamond',p:15,d:'M6.5 3h11L22 9l-10 12.5L2 9z'},
 {n:'Skull',p:10,e:1,d:'M12 2.2c-4.6 0-8 3.2-8 7.6 0 2.5 1.1 4.3 2.6 5.5V19a1 1 0 0 0 1 1H9v1.8h1.8V20h2.4v1.8H15V20h1.4a1 1 0 0 0 1-1v-3.7c1.5-1.2 2.6-3 2.6-5.5 0-4.4-3.4-7.6-8-7.6zM8.6 12.9a2.1 2.1 0 1 1 0-4.2 2.1 2.1 0 0 1 0 4.2zm6.8 0a2.1 2.1 0 1 1 0-4.2 2.1 2.1 0 0 1 0 4.2zM12 14.2l1.2 2.3h-2.4z'}
];
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
/* كل عمليات النجوم والهدايا الحساسة تمر من الخادم (/api/gifts) */
async function giftApi(op,body){
  const r=await babylonApi('/api/gifts',Object.assign({op:op},body||{}),currentUser);
  if(r.status===200)return r.data;
  const e=new Error((r.data&&r.data.error)||('http '+r.status));e.code=e.message;e.status=r.status;throw e;
}
function wpick(a){let r=Math.random()*a.reduce((s,x)=>s+x.p,0);for(let i=0;i<a.length;i++){r-=a[i].p;if(r<0)return i;}return a.length-1;}
function fmtN(n){return Number(n).toLocaleString('en-US');}

/* ---------- الرصيد ---------- */
let myStars=0,walletUnsub=null,walletFor=null,walletReady=false;
function isDevUser(){return !!(currentUser&&isDevEmail(currentUser.email));}
function starsLabel(){return isDevUser()?'∞':fmtN(myStars);}
function paintStars(){document.querySelectorAll('[data-stars]').forEach(e=>{e.textContent=starsLabel();});}
function startWallet(uid){
  if(walletFor===uid)return;
  if(walletUnsub)walletUnsub();
  walletFor=uid;walletReady=false;
  walletUnsub=db.collection('wallets').doc(uid).onSnapshot(d=>{
    const v=d.exists?(Number(d.data().stars)||0):0;
    if(walletReady&&v>myStars&&!isDevUser())showToast('🎁 وصلتك نجوم! رصيدك الآن '+fmtN(v)+' ⭐');
    myStars=v;walletReady=true;paintStars();
  },()=>{});
}
auth.onAuthStateChanged(u=>{if(u)startWallet(u.uid);else{if(walletUnsub)walletUnsub();walletUnsub=null;walletFor=null;myStars=0;walletReady=false;}});

/* ---------- Lottie ---------- */
const GIFTS_CDN='https://cdn.changes.tg/gifts/models/';
const GIFTS_CDN_DIR={pepe:'Plush Pepe',cat:'Scared Cat'};
/* ===== هدايا إضافية من gifts/manifest.json (تولّده make_manifest.py) ===== */
const gid=(K,n)=>K.gen?K.key+'_'+n:String(n);
const salesQ=K=>K.gen?db.collection('giftSales').where('k','==',K.key):db.collection(K.sales);
const FEE_PCT=5,netOf=p=>Math.floor(p*(100-FEE_PCT)/100);
const evRef=(K,n)=>db.collection('giftEvents').doc(K.key+'_'+n).collection('log').doc();
const listId=(K,n)=>K.key+'_'+n;
const kindDir=K=>GIFTS_CDN_DIR[K.key]||K.name;
const modelName=(K,i)=>i<0?(K.gen&&!K.orig?K.models[0].n:'Original'):K.models[i].n;
const BLANK_IMG='data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw==';
const loadManifest=async()=>{
  for(const u of [GIFTS_BASE+'manifest.json?v=1','/gifts/manifest.json?v=1','/manifest.json?v=1']){
    try{const r=await fetch(u);if(!r.ok)continue;const j=await r.json();if(j&&j.gifts)return j;}catch(e){}
  }
  console.warn('gifts manifest.json not found');return null;
};
const GIFTS_READY=loadManifest().then(m=>{
  if(!m||!m.gifts)return;
  m.gifts.forEach(g=>{
    const key=g.name.toLowerCase().replace(/[^a-z0-9]+/g,'-').replace(/^-|-$/g,'');
    if(!key||GIFT_KINDS[key]||/^plush pepe$|^scared cat$/i.test(g.name)||!g.models||!g.models.length)return;
    GIFTS_CDN_DIR[key]=g.name;
    const names=g.models.filter(n=>n!=='Original'),orig=names.length<g.models.length;
    if(!names.length)return;
    GIFT_KINDS[key]={key,name:g.name,gen:true,orig,coll:'gifts',field:'lastBuyGift',max:g.max||30,price:g.price||500,models:names.map(n=>({n,p:1}))};
  });
}).catch(()=>{});
const _pepeTxt={};
async function pepeText(i,kind){
  const K=gk(kind),key=K.key+':'+i;
  if(_pepeTxt[key])return _pepeTxt[key];
  const f=i<0?'original':K.models[i].f;
  /* المصدر: موقع CDN خارجي (اترك GIFTS_CDN فاضي '' للرجوع لملفات gifts/ المحلية) */
  const url=GIFTS_CDN?GIFTS_CDN+encodeURIComponent(kindDir(K))+'/'+encodeURIComponent(modelName(K,i))+'.tgs':GIFTS_BASE+K.dir+'/'+f+'.tgs';
  const r=await fetch(url);
  if(!r.ok)throw new Error('tgs '+r.status);
  const st=new Blob([await r.arrayBuffer()]).stream().pipeThrough(new DecompressionStream('gzip'));
  return _pepeTxt[key]=await new Response(st).text();
}
let _lotP=null;
function loadLottie(){
  if(window.lottie)return Promise.resolve(window.lottie);
  if(_lotP)return _lotP;
  const urls=['https://cdnjs.cloudflare.com/ajax/libs/lottie-web/5.12.2/lottie.min.js','https://cdn.jsdelivr.net/npm/lottie-web@5.12.2/build/player/lottie.min.js'];
  return _lotP=new Promise((res,rej)=>{let i=0;(function next(){
    if(i>=urls.length){_lotP=null;return rej(new Error('lottie'));}
    const s=document.createElement('script');s.src=urls[i++];
    s.onload=()=>window.lottie?res(window.lottie):next();s.onerror=next;document.head.appendChild(s);
  })();});
}
async function mountPepeAnim(h,mi,opt){
  opt=opt||{};
  if(!h)return;
  h.innerHTML='<div class="pp-fb">🐸</div>';
  try{
    const [lot,txt]=await Promise.all([loadLottie(),pepeText(mi,opt.kind)]);
    if(!h.isConnected)return;
    h.innerHTML='';
    const an=lot.loadAnimation({container:h,renderer:'svg',loop:!opt.still,autoplay:!opt.still,animationData:JSON.parse(txt)});
    if(opt.still)an.addEventListener('DOMLoaded',()=>an.goToAndStop(40,true));
    h._an=an;
  }catch(e){console.error('pepe',e);}
}

/* ---------- رسم الهدية (خلفية + رموز + Pepe) ---------- */
function patInner(si){
  const sym=PEPE_SYMS[si],rings=[[29,7,7.6,.24],[42,10,6.4,.17],[55,13,5.4,.12],[68,16,4.6,.085]];
  let out='';
  rings.forEach((r,ri)=>{
    for(let k=0;k<r[1];k++){
      const a=2*Math.PI*k/r[1]+(ri%2)*Math.PI/r[1]-Math.PI/2,x=50+r[0]*Math.cos(a),y=44+r[0]*Math.sin(a)*1.02,rot=((k*47+ri*23)%50)-25;
      out+='<g transform="translate('+x.toFixed(1)+' '+y.toFixed(1)+') rotate('+rot+') scale('+(r[2]/24).toFixed(3)+') translate(-12 -12)" opacity="'+r[3]+'"><path d="'+sym.d+'"'+(sym.e?' fill-rule="evenodd"':'')+' fill="#fff"/></g>';
    }
  });
  return out;
}
function patSvg(si){return '<svg class="ga-pat" viewBox="0 0 100 100" preserveAspectRatio="xMidYMid slice" aria-hidden="true">'+patInner(si)+'</svg>';}
function bgCss(g){
  const up=g&&g.upgraded,b=up?PEPE_BGS[g.bg]:{a:'#3b414d',b:'#12151b'};
  return 'radial-gradient(circle at 50% 44%,'+b.a+' 0%,'+b.b+' 100%)';
}
function thumbLocal(g){
  const K=gk(g.k);if(K.gen)return BLANK_IMG;
  const f=g.upgraded?K.models[g.model].f:'original';
  return GIFTS_BASE+K.dir+'/thumbs/'+f+'.webp';
}
/* الصورة المصغّرة من مجلد png بالـ CDN؛ إذا ما انوجدت يرجع للمحلية تلقائياً */
function thumbUrl(g){
  if(!GIFTS_CDN)return thumbLocal(g);
  const K=gk(g.k);
  return GIFTS_CDN+encodeURIComponent(kindDir(K))+'/png/'+encodeURIComponent(modelName(K,g.upgraded?g.model:-1))+'.png';
}
function giftArt(g,opt){
  opt=opt||{};
  const el=document.createElement('div');el.className='ga'+(opt.cls?' '+opt.cls:'');
  el.style.background=bgCss(g);
  el.innerHTML=(g.upgraded?patSvg(g.sym):'')+'<div class="ga-pepe"'+(g.upgraded?'':' style="filter:grayscale(1) brightness(.78)"')+'></div>';
  const holder=el.querySelector('.ga-pepe'),mi=g.upgraded?g.model:-1;
  if(opt.still){
    /* مربعات الشبكة: صورة ثابتة خفيفة بدل أنيميشن Lottie؛ وإذا فشلت الصورة نرجع للأنيميشن */
    const im=new Image();im.alt='';im.decoding='async';im.loading='lazy';
    im.onerror=()=>mountPepeAnim(holder,mi,{still:true,kind:g.k});
    im.onerror=function(){im.onerror=null;im.src=thumbLocal(g);};im.src=thumbUrl(g);holder.appendChild(im);
  }else mountPepeAnim(holder,mi,{kind:g.k});
  return el;
}

/* شريط رقم الهدية: يخرج خارج حدود المربع، بلون خلفية الهدية وتحته ظل خفيف */
function ribCols(g){
  const b=(g&&g.upgraded&&PEPE_BGS[g.bg])||{a:'#7b8494',b:'#4b5563'};
  const grad=(k)=>'linear-gradient(rgba(0,0,0,'+k+'),rgba(0,0,0,'+k+')),linear-gradient(90deg,'+b.a+','+b.b+')';
  return {main:grad(.22),back:grad(.5)};
}
function ribHtml(g,cls){
  const c=ribCols(g);
  if(cls==='gm-rib'){
    const n=giftNum(g&&g.number),t='#'+(n==null?String(g&&g.number):n.toLocaleString('en-US'));
    return '<div class="gmr-back"><i class="gmr-band" style="background:'+c.back+';color:transparent">'+t+'</i></div>'
          +'<div class="gmr-main"><i class="gmr-band" style="background:'+c.main+'">'+t+'</i></div>';
  }
  return '<div class="'+cls+'-s1"><div class="'+cls+'" style="background:'+c.main+'">#'+g.number+'</div></div>'
        +'<div class="'+cls+'-s2"><div class="'+cls+'" style="background:'+c.back+';color:transparent">#'+g.number+'</div></div>';
}
function gtRib(g){return '<div class="gt-rw">'+ribHtml(g,'gt-n')+'</div>';}
/* ---------- شبكة الهدايا بالبروفايل ---------- */
const giftGridUnsub={};
function loadGiftsGrid(uid,gridId,wrapId){
  const grid=document.getElementById(gridId),wrap=document.getElementById(wrapId);if(!grid||!wrap)return;
  if(giftGridUnsub[gridId])giftGridUnsub[gridId]();
  const data={};
  const draw=()=>{
    gmCss(); /* لازم تنحقن أنماط أيقونة التثبيت/الإخفاء قبل رسم البلاطات */
    const isMe=uid===meId(),st=giftPrefs(uid);
    let items=[].concat(...Object.values(data)).sort((a,b)=>(b.at||0)-(a.at||0));
    if(!isMe)items=items.filter(g=>!st.hidden.has(g.k+'_'+g.number));
    items.sort((a,b)=>(st.pins.has(b.k+'_'+b.number)?1:0)-(st.pins.has(a.k+'_'+a.number)?1:0));
    wrap.classList.toggle('hidden',!items.length);
    grid.innerHTML='';
    items.forEach(g=>{
      const key=g.k+'_'+g.number;
      const t=giftArt(g,{still:true,cls:'gift-tile'});
      t.insertAdjacentHTML('beforeend',gtRib(g));
      if(st.pins.has(key))t.insertAdjacentHTML('beforeend','<div class="gt-pin">'+GM_IC.pinS+'</div>');
      if(isMe&&st.hidden.has(key)){t.classList.add('gt-hid');t.insertAdjacentHTML('beforeend','<div class="gt-eye">'+GM_IC.hideS+'</div>');}
      t.onclick=()=>{if(t._lp){t._lp=false;return;}openGiftPage(uid,g.number,g.k);};
      gmBindLongPress(t,uid,g,()=>draw());
      grid.appendChild(t);
    });
  };
  const unsubs=Object.values(GIFT_KINDS).filter(K=>!K.gen).map(K=>{
    data[K.key]=[];
    return db.collection('users').doc(uid).collection(K.coll).onSnapshot(snap=>{
      data[K.key]=snap.docs.map(d=>Object.assign({k:K.key},d.data()));draw();
    },()=>{data[K.key]=[];draw();});
  });
  /* الهدايا الإضافية كلها بمجموعة واحدة users/{uid}/gifts وكل وثيقة فيها k */
  data.__gen=[];
  unsubs.push(db.collection('users').doc(uid).collection('gifts').onSnapshot(snap=>{
    data.__gen=snap.docs.map(d=>d.data()).filter(g=>g.k&&GIFT_KINDS[g.k]);draw();
  },()=>{data.__gen=[];draw();}));
  if(uid!==meId())db.collection('users').doc(uid).get().then(d=>{if(d.exists){gmRemote[uid]={pins:d.data().giftPins||[],hidden:d.data().giftHidden||[]};draw();}}).catch(()=>{});
  giftGridUnsub[gridId]=()=>unsubs.forEach(u=>u());
}

/* ---------- صفحة تفاصيل الهدية (مثل تليجرام) ---------- */
let gpUnsub=null;
function closeGiftPage(){if(gpUnsub){gpUnsub();gpUnsub=null;}document.getElementById('giftPage')?.remove();document.getElementById('giftPageBackdrop')?.remove();}
const IC_BACK='<svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="m9 6 6 6-6 6"/></svg>';
const IC_X='<svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" aria-hidden="true"><path d="M6 6l12 12M18 6 6 18"/></svg>';
const IC_DOTS='<svg viewBox="0 0 24 24" width="22" height="22" fill="currentColor" aria-hidden="true"><circle cx="5" cy="12" r="2"/><circle cx="12" cy="12" r="2"/><circle cx="19" cy="12" r="2"/></svg>';
async function openGiftPage(uid,n,kind){
  const K=gk(kind);
  closeGiftPage();
  const bd=document.createElement('div');bd.id='giftPageBackdrop';bd.onclick=closeGiftPage;uiRoot().appendChild(bd);
  const ov=document.createElement('div');ov.id='giftPage';ov.className='gp-ov';uiRoot().appendChild(ov);
  ov.innerHTML='<div class="gp-hero" style="background:'+bgCss({})+'"><div class="gp-top"><button type="button" class="gp-round" id="gpBack" aria-label="إغلاق">'+IC_X+'</button></div></div>';
  /* سحب الورقة للأسفل لإغلاقها (فقط وهي بأعلى المحتوى) */
  let sy=null,dy=0;
  ov.addEventListener('touchstart',e=>{if(ov.scrollTop<=0&&e.touches.length===1){sy=e.touches[0].clientY;dy=0;ov.style.transition='none';}},{passive:true});
  ov.addEventListener('touchmove',e=>{if(sy==null)return;dy=e.touches[0].clientY-sy;if(dy>0)ov.style.transform='translateY('+dy+'px)';else{dy=0;ov.style.transform='';}},{passive:true});
  ov.addEventListener('touchend',()=>{if(sy==null)return;const d=dy;sy=null;ov.style.transition='transform .2s ease';if(d>110){ov.style.transform='translateY(100%)';setTimeout(closeGiftPage,180);}else ov.style.transform='';},{passive:true});
  ov.querySelector('#gpBack').onclick=closeGiftPage;
  const issuedP=salesQ(K).get().then(s=>s.size).catch(()=>null);
  await loadUsers([uid]);
  const issued=await issuedP;
  if(!document.getElementById('giftPage'))return;
  gpUnsub=db.collection('users').doc(uid).collection(K.coll).doc(gid(K,n)).onSnapshot(async doc=>{
    if(!doc.exists){closeGiftPage();showToast('هذه الهدية غير موجودة');return;}
    const g=Object.assign({k:K.key},doc.data());
    ov._ctx={uid,g,issued};
    let lst=null;
    try{const ld=await db.collection('giftListings').doc(listId(K,n)).get();if(ld.exists)lst=ld.data();}catch(e){}
    if(!document.getElementById('giftPage'))return;
    renderGiftPage(ov,uid,g,issued,false,lst);
  },()=>{closeGiftPage();});
}
/* نسبة ظهور النموذج الحقيقية = وزنه / مجموع الأوزان (Plush Pepe و Scared Cat مجموعها 1000، والهدايا الجديدة أوزانها متساوية) */
function rarePct(K,m){const t=K.models.reduce((a,x)=>a+(Number(x.p)||0),0)||1;return String(+((Number(m.p)||0)/t*100).toFixed(1));}
function gpRow(k,v){return '<div class="gp-row"><div class="gp-k">'+k+'</div><div class="gp-v">'+v+'</div></div>';}
function renderGiftPage(ov,uid,g,issued,reveal,lst){
  const K=gk(g.k);
  const up=!!g.upgraded,me=meId(),mine=uid===me,m=up?K.models[g.model]:null,b=up?PEPE_BGS[g.bg]:null,s=up?PEPE_SYMS[g.sym]:null;
  const u=GU[uid]||{};
  const ownerV='<div class="gp-owner" id="gpOwner">'+userAvHtml(uid,'gp-oav')+'<span>'+esc(u.displayName||'مستخدم')+(mine?' <em>(أنت)</em>':'')+'</span></div>';
  const lock='<span class="gp-lock">غير مُرقّاة</span>';
  ov.innerHTML='<div class="gp-hero'+(reveal?' reveal':'')+'" id="gpHero" style="background:'+bgCss(g)+'">'+(up?patSvg(g.sym):'')
    +'<div class="gp-top"><button type="button" class="gp-round" id="gpBack" aria-label="إغلاق">'+IC_X+'</button><button type="button" class="gp-round" id="gpMore" aria-label="المزيد">'+IC_DOTS+'</button></div>'
    +'<div class="gp-pepe"'+(up?'':' style="filter:grayscale(1) brightness(.8)"')+'></div>'
    +'<div class="gp-title">'+K.name+' <span>#'+g.number+'</span></div>'
    +'<div class="gp-chip" id="gpChip">'+(up?'نسخة '+g.number+' من '+K.max:'هدية بانتظار الترقية')+'</div></div>'
    +'<div class="gp-body"><div class="gp-table">'
    +gpRow('المالك',ownerV)
    +gpRow('النموذج',up?esc(m.n)+'<span class="gp-pill">'+rarePct(K,m)+'%</span>':lock)
    +gpRow('الرمز',up?esc(s.n)+'<span class="gp-pill">'+s.p+'%</span>':lock)
    +gpRow('الخلفية',up?esc(b.n)+'<span class="gp-pill">'+b.p+'%</span>':lock)
    +gpRow('الكمية',(issued!=null?issued:'—')+'/'+K.max+' صادرة')
    +(lst?gpRow('السعر','<span class="gp-price">⭐ '+fmtN(lst.price)+'</span>'):'')
    +'</div>'
    +(mine&&up&&!lst?'<button type="button" class="gp-cta" id="gpSell">بيع بنجوم</button><div class="gp-note">حدّد سعراً وتنعرض للبيع بالمتجر. تگدر تلغي العرض أو تغيّر السعر بأي وقت.</div>':'')
    +(mine&&lst?'<div class="gp-listed">معروضة للبيع بـ ⭐ '+fmtN(lst.price)+'</div><div class="gp-btns"><button type="button" class="gp-cta alt" id="gpEdit">تعديل السعر</button><button type="button" class="gp-cta danger" id="gpUnlist">إلغاء العرض</button></div>':'')
    +(!mine&&lst?'<button type="button" class="gp-cta" id="gpBuy">🛒 شراء بـ ⭐ '+fmtN(lst.price)+'</button><div class="gp-note">النجوم تروح لصاحب الهدية وتنتقل الهدية إلك مباشرة.</div>':'')
    +(mine&&!up?'<button type="button" class="gp-cta" id="gpUp">✨ ترقية الهدية مجاناً</button><div class="gp-note">ستحصل على نموذج وخلفية ورمز عشوائي، وبعضها نادر جداً.</div>':'')
    +(!mine&&!lst?'<button type="button" class="gp-cta alt" id="gpOk">حسنًا</button>':'')
    +'</div>';
  ov.querySelector('#gpBack').onclick=closeGiftPage;
  const okb=ov.querySelector('#gpOk');if(okb)okb.onclick=closeGiftPage;
  const mb=ov.querySelector('#gpMore');if(mb)mb.onclick=ev=>{ev.stopPropagation();if(window.giftMoreMenu)window.giftMoreMenu(ov,g);};
  mountPepeAnim(ov.querySelector('.gp-pepe'),up?g.model:-1,{kind:g.k});
  ov.querySelector('#gpOwner').onclick=()=>{
    if(mine){closeGiftPage();openProfile();return;}
    db.collection('users').doc(uid).get().then(d=>{if(d.exists){closeGiftPage();openUserProfileDirect(Object.assign({id:uid},d.data()));}});
  };
  /* سجل المالكين محذوف بطلب المستخدم */
  const upb=ov.querySelector('#gpUp');if(upb)upb.onclick=()=>doUpgrade(ov,uid,g);
  const sb=ov.querySelector('#gpSell');if(sb)sb.onclick=()=>sellGift(ov,g,null);
  const eb=ov.querySelector('#gpEdit');if(eb)eb.onclick=()=>sellGift(ov,g,lst);
  const ub=ov.querySelector('#gpUnlist');if(ub)ub.onclick=()=>unlistGift(ov,g);
  const bb=ov.querySelector('#gpBuy');if(bb)bb.onclick=()=>buyListing(ov,lst);
}
let upgrading=false;
async function doUpgrade(ov,uid,g){
  if(upgrading)return;upgrading=true;
  const K=gk(g.k);
  const hero=ov.querySelector('#gpHero'),btn=ov.querySelector('#gpUp'),chip=ov.querySelector('#gpChip');
  if(btn){btn.disabled=true;btn.textContent='جاري الترقية…';}
  hero.classList.add('rolling');
  const apiP=giftApi('upgrade',{kind:K.key,number:g.number});apiP.catch(()=>{});
  let pat=hero.querySelector('.ga-pat');
  if(!pat){hero.insertAdjacentHTML('afterbegin',patSvg(0));pat=hero.querySelector('.ga-pat');}
  try{
    const steps=24;let res=null;
    for(let i=0;i<steps;i++){
      const last=i===steps-1;
      if(last)res=await apiP;   /* النتيجة تجي من الخادم (عشوائية حقيقية لا يتحكم بها المستخدم) */
      const bi=last?res.bg:Math.floor(Math.random()*5),si=last?res.sym:Math.floor(Math.random()*5);
      hero.style.background=bgCss({upgraded:true,bg:bi});
      pat.innerHTML=patInner(si);
      if(chip)chip.textContent=PEPE_BGS[bi].n+' · '+PEPE_SYMS[si].n;
      await sleep(60+i*i*0.55);
    }
    await sleep(250);
    showToast('✨ تمت الترقية: '+K.models[res.model].n);
    const doc=ov.querySelector('#gpHero');if(doc)doc.classList.add('reveal');
  }catch(e){console.error(e);showToast('تعذرت الترقية');hero.classList.remove('rolling');renderGiftPage(ov,uid,g,null);}
  upgrading=false;
}

/* ---------- متجر الهدايا ---------- */
let storeKind='pepe';
function closeStore(){document.getElementById('giftStore')?.remove();clearInterval(window.__storeTimer);}
async function openStoreGrid(){
  closeStore();
  const ov=document.createElement('div');ov.id='giftStore';ov.className='gp-ov st-ov';uiRoot().appendChild(ov);
  ov.innerHTML='<div class="gx-top"><button type="button" class="gx-ib" id="stBack" aria-label="رجوع">'+IC_BACK+'</button><div class="gx-title"><b>متجر الهدايا</b></div></div><div class="sg-sub">جاري التحميل…</div>';
  ov.querySelector('#stBack').onclick=closeStore;
  await GIFTS_READY;
  if(!document.getElementById('giftStore'))return;
  const kinds=Object.values(GIFT_KINDS);
  const art=K=>{
    const gen=!!K.gen;
    const src=GIFTS_CDN?GIFTS_CDN+encodeURIComponent(kindDir(K))+'/png/'+encodeURIComponent(modelName(K,-1))+'.png':(gen?BLANK_IMG:GIFTS_BASE+K.dir+'/thumbs/original.webp');
    const fb=gen?BLANK_IMG:GIFTS_BASE+K.dir+'/thumbs/original.webp';
    return {src,fb};
  };
  ov.innerHTML='<div class="gx-top"><button type="button" class="gx-ib" id="stBack" aria-label="رجوع">'+IC_BACK+'</button><div class="gx-title"><b>متجر الهدايا</b></div></div>'
    +'<div class="st-seg"><button type="button" class="on" id="stTabN">هدايا جديدة</button><button type="button" id="stTabR">هدايا مطورة</button></div>'
    +'<div id="stNew"><div class="sg-grid">'+kinds.map(K=>{const a=art(K);return '<div class="sg-card" data-k="'+K.key+'" data-n="'+K.name.toLowerCase()+'"><div class="sg-ribbon"></div><div class="sg-art"><img alt="" loading="lazy" decoding="async" src="'+a.src+'" data-fb="'+a.fb+'"></div><div class="sg-name">'+K.name+'</div><div class="sg-price">⭐ '+K.price+'</div><div class="sg-floor"></div></div>';}).join('')+'</div></div><div id="stResale" class="hidden"></div>';
  ov.querySelector('#stBack').onclick=closeStore;
  const tabN=ov.querySelector('#stTabN'),tabR=ov.querySelector('#stTabR'),boxN=ov.querySelector('#stNew'),boxR=ov.querySelector('#stResale');
  tabN.onclick=()=>{tabN.classList.add('on');tabR.classList.remove('on');boxN.classList.remove('hidden');boxR.classList.add('hidden');};
  tabR.onclick=()=>{tabR.classList.add('on');tabN.classList.remove('on');boxR.classList.remove('hidden');boxN.classList.add('hidden');loadResale(boxR);};
  ov.querySelectorAll('.sg-art img').forEach(im=>{im.onerror=()=>{im.onerror=null;im.src=im.dataset.fb;};});
  ov.querySelectorAll('.sg-card').forEach(c=>c.onclick=()=>openGiftStore(c.dataset.k));
  /* "نفدت" للهديتين القديمتين فقط (الباقي نعرفه من صفحة الهدية حتى ما نقرأ مبيعات الكل) */
  kinds.filter(K=>!K.gen).forEach(K=>db.collection(K.sales).get().then(s=>{
    if(K.max-s.size<=0){const c=ov.querySelector('.sg-card[data-k="'+K.key+'"]');if(c){c.classList.add('out');c.querySelector('.sg-ribbon').textContent='نفدت';}}
  }).catch(()=>{}));
  paintFloors(ov);
  syncCatalog();
}
/* المطوّر فقط: يكتب سعر وكمية كل هدية بـ giftCatalog حتى القواعد تتحقق منها عند الشراء */
let catalogSynced=false;
async function syncCatalog(){
  if(catalogSynced||!isDevUser())return;catalogSynced=true;
  try{
    const cur={};(await db.collection('giftCatalog').get()).forEach(d=>cur[d.id]=d.data());
    const todo=Object.values(GIFT_KINDS).filter(K=>K.gen&&(!cur[K.key]||cur[K.key].price!==K.price||cur[K.key].max!==K.max));
    for(let i=0;i<todo.length;i+=400){
      const b=db.batch();todo.slice(i,i+400).forEach(K=>b.set(db.collection('giftCatalog').doc(K.key),{name:K.name,price:K.price,max:K.max}));
      await b.commit();
    }
    if(todo.length)showToast('تم تحديث كتالوج الهدايا ('+todo.length+')');
  }catch(e){console.error(e);catalogSynced=false;}
}
async function openGiftStore(kind){
  if(typeof kind!=='string')return openStoreGrid();
  storeKind=kind;
  closeStore();
  const K=gk(storeKind);
  const ov=document.createElement('div');ov.id='giftStore';ov.className='gp-ov st-ov';uiRoot().appendChild(ov);
  ov.innerHTML='<div class="gx-top"><button type="button" class="gx-ib" id="stBack" aria-label="رجوع">'+IC_BACK+'</button><div class="gx-title"><b>متجر الهدايا</b></div></div>'
    +'<div class="st-body"><div class="st-hero" id="stHero"></div>'
    +'<div class="st-title">'+K.name+'</div><div class="st-sub" id="stSub">نسخ محدودة · '+K.max+' فقط</div>'
    +'<div class="gp-table st-table">'
    +gpRow('السعر',K.price+' ⭐')
    +gpRow('رصيدك','<b data-stars>'+starsLabel()+'</b> ⭐')
    +gpRow('الترقية','مجانية، نموذج وخلفية ورمز عشوائي')
    +'</div><button type="button" class="gp-cta" id="stBuy">شراء بـ '+K.price+' نجمة</button><div class="gp-note" id="stNote"></div></div>';
  ov.querySelector('#stBack').onclick=openStoreGrid;
  // عرض متنوع: يبدّل النموذج والخلفية والرمز كل كم ثانية
  const hero=ov.querySelector('#stHero');let i=0;
  const show=()=>{
    const g={k:K.key,upgraded:true,model:(i*7+3)%K.models.length,bg:(i*2+1)%5,sym:(i*3)%5};
    const el=giftArt(g,{cls:'st-art'});el.classList.add('fadein');
    hero.innerHTML='';hero.appendChild(el);i++;
  };
  show();window.__storeTimer=setInterval(()=>{if(!document.getElementById('giftStore')){clearInterval(window.__storeTimer);return;}show();},3200);
  refreshStore();
  ov.querySelector('#stBuy').onclick=()=>buyGift(K.key);
}
async function refreshStore(){
  const ov=document.getElementById('giftStore');if(!ov)return;
  const K=gk(storeKind);
  try{
    const s=await salesQ(K).get();
    const left=K.max-s.size,sub=ov.querySelector('#stSub'),btn=ov.querySelector('#stBuy');
    if(sub)sub.textContent='نسخة محدودة · المتبقي '+Math.max(0,left)+' من '+K.max;
    if(btn&&left<=0){btn.disabled=true;btn.textContent='نفدت الكمية';}
  }catch(e){}
}
let buying=false;
async function buyGift(kind){
  if(buying)return;
  const K=gk(kind),dev=isDevUser();
  if(!dev&&myStars<K.price)return showToast('رصيدك غير كافٍ ⭐');
  buying=true;
  const btn=document.getElementById('stBuy');if(btn){btn.disabled=true;btn.textContent='جاري الشراء…';}
  try{
    const r=await giftApi('buy',{kind:K.key});
    showToast('🎉 اشتريت '+K.name+' #'+r.number);
  }catch(e){
    console.error(e);
    showToast(e.code==='soldout'?'نفدت الكمية':e.code==='funds'?'رصيدك غير كافٍ ⭐':(e.code==='otp'||e.code==='auth')?'سجّل خروج وادخل من جديد':'ممكن أحد سبقك، حاول مرة ثانية');
  }
  const sb=document.getElementById('stBuy');if(sb){sb.disabled=false;sb.textContent='شراء بـ '+K.price+' نجمة';}
  refreshStore();
  buying=false;
}

/* ---------- سجل نجوم بابل ---------- */
let histUnsub=null;
function closeHistory(){if(histUnsub){histUnsub();histUnsub=null;}document.getElementById('starsHist')?.remove();}
function fmtWhen(t){const d=new Date(t);return d.toLocaleDateString('ar',{day:'numeric',month:'long'})+' · '+d.toLocaleTimeString('ar',{hour:'numeric',minute:'2-digit'});}
function openStarsHistory(){
  closeHistory();
  const dev=isDevUser();
  const ov=document.createElement('div');ov.id='starsHist';ov.className='gp-ov st-ov';uiRoot().appendChild(ov);
  const tabs=[['all','الكل'],['buy','المشتريات'],['sell','المبيعات'],['in','المستلمة'],['out','المُهداة']];
  ov.innerHTML='<div class="gx-top"><button type="button" class="gx-ib" id="shBack" aria-label="رجوع">'+IC_BACK+'</button><div class="gx-title"><b>نجوم بابل</b></div></div>'
    +'<div class="sh-bal"><div class="sh-lb">رصيدك</div><div class="sh-n"><span data-stars>'+starsLabel()+'</span><i>⭐</i></div>'+(dev?'<div class="sh-dev">حساب المطور · رصيد لا نهائي</div>':'')+'</div>'
    +'<div class="sh-tabs" id="shTabs">'+tabs.map((t,i)=>'<button type="button" class="'+(i?'':'on')+'" data-t="'+t[0]+'">'+t[1]+'</button>').join('')+'</div>'
    +'<div class="sh-list" id="shList"><div class="gx-empty">جاري التحميل…</div></div>';
  ov.querySelector('#shBack').onclick=closeHistory;
  let tab='all',rows=[];
  const draw=()=>{
    const list=ov.querySelector('#shList');
    const f=rows.filter(r=>tab==='all'||r.type===tab);
    if(!f.length){list.innerHTML='<div class="gx-empty">لا توجد عمليات بعد.</div>';return;}
    list.innerHTML=f.map(r=>{
      let ic='⭐',title='',amt='',cls='';
      if(r.type==='buy'){ic='🎁';title='اشتريت '+gk(r.kind).name+' #'+r.gift;amt='−'+fmtN(r.stars);cls='neg';}
      else if(r.type==='sell'){ic='💰';title='بعت '+gk(r.kind).name+' #'+r.gift+(r.buyerName?' إلى '+esc(r.buyerName):'');amt='+'+fmtN(r.stars);cls='pos';}
      else if(r.type==='in'){ic='⭐';title='هدية نجوم من '+esc(r.fromName||'المطور');amt='+'+fmtN(r.stars);cls='pos';}
      else if(r.type==='out'){ic='📤';title='أهديت '+esc(r.toName||'مستخدم')+(r.fee?' <small>(عمولة '+fmtN(r.fee)+')</small>':'');amt='−'+fmtN(r.stars);cls='neg';}
      return '<div class="sh-row" data-g="'+(r.type==='buy'?r.gift:'')+'" data-k="'+(r.kind||'pepe')+'"><div class="sh-ic">'+ic+'</div><div class="sh-t"><b>'+title+'</b><span>'+fmtWhen(r.at)+'</span></div><div class="sh-a '+cls+'">'+amt+' <i>⭐</i></div></div>';
    }).join('');
    list.querySelectorAll('.sh-row[data-g]').forEach(el=>{if(el.dataset.g)el.onclick=()=>{closeHistory();openGiftPage(meId(),Number(el.dataset.g),el.dataset.k);};});
  };
  ov.querySelectorAll('#shTabs button').forEach(b=>b.onclick=()=>{tab=b.dataset.t;ov.querySelectorAll('#shTabs button').forEach(x=>x.classList.toggle('on',x===b));draw();});
  histUnsub=db.collection('users').doc(meId()).collection('txs').orderBy('at','desc').limit(100).onSnapshot(s=>{rows=s.docs.map(d=>d.data());draw();},()=>{rows=[];draw();});
}



/* ===== إهداء هدية لمستخدم: تنتقل الملكية له وتوصله رسالة كارت بالمحادثة ===== */
function closeSend(){document.getElementById('giftSend')?.remove();}
async function transferGift(g,to){
  const K=gk(g.k),me=meId(),now=Date.now(),id=gid(K,g.number);
  const cref=db.collection('chats').doc([me,to].sort().join('__'));
  const cs=await cref.get();
  if(cs.exists)await cref.update({updatedAt:now});else await cref.set({participants:[me,to],updatedAt:now});
  const doc={number:g.number,upgraded:!!g.upgraded,at:g.at||now};
  if(K.gen)doc.k=K.key;
  const msg={senderId:me,type:'gift',k:K.key,number:g.number,upgraded:!!g.upgraded,to:to,text:'🎁 هدية '+K.name+' #'+g.number,createdAt:now,read:false};
  if(g.upgraded){doc.model=g.model;doc.bg=g.bg;doc.sym=g.sym;msg.model=g.model;msg.bg=g.bg;msg.sym=g.sym;}
  const b=db.batch();
  b.delete(db.collection('users').doc(me).collection(K.coll).doc(id));
  b.set(db.collection('users').doc(to).collection(K.coll).doc(id),doc);
  b.update(db.collection(K.gen?'giftSales':K.sales).doc(id),{ownerId:to});
  b.set(evRef(K,g.number),{k:K.key,number:g.number,coll:K.coll,type:'send',from:me,to:to,at:now});
  b.set(cref.collection('messages').doc(),msg);
  await b.commit();
}
async function openSendGift(){
  const to=currentChatOtherUserId,me=meId();
  if(!to||to===me)return showToast('افتح بروفايل المستخدم أولاً');
  const toName=String((document.getElementById('otherHeaderNameText')||{}).textContent||'مستخدم').trim();
  closeSend();
  const ov=document.createElement('div');ov.id='giftSend';ov.className='gp-ov';uiRoot().appendChild(ov);
  const top='<div class="gx-top"><button type="button" class="gx-ib" id="gsBack" aria-label="رجوع">'+IC_BACK+'</button><div class="gx-title"><b>إهداء هدية</b></div></div>';
  ov.innerHTML=top+'<div class="sg-sub">جاري التحميل…</div>';
  ov.querySelector('#gsBack').onclick=closeSend;
  await GIFTS_READY;
  if(!document.getElementById('giftSend'))return;
  const items=[];
  try{
    const kinds=Object.values(GIFT_KINDS),colls=[...new Set(kinds.map(K=>K.coll))];
    const snaps=await Promise.all(colls.map(c=>db.collection('users').doc(me).collection(c).get()));
    snaps.forEach((sn,i)=>{
      const c=colls[i],legacy=kinds.find(K=>K.coll===c&&!K.gen);
      sn.docs.forEach(d=>{const x=d.data(),key=c==='gifts'?x.k:(legacy&&legacy.key);if(key&&GIFT_KINDS[key])items.push(Object.assign({},x,{k:key}));});
    });
  }catch(e){console.error(e);}
  items.sort((a,b)=>(b.at||0)-(a.at||0));
  const listed=new Set();
  try{(await db.collection('giftListings').where('sellerId','==',me).get()).forEach(d=>listed.add(d.id));}catch(e){}
  ov.querySelector('#gsBack').onclick=closeSend;
  if(!items.length){ov.innerHTML=top+'<div class="sg-sub">ما عندك هدايا لتهديها. اشتر هدية من المتجر أولاً.</div>';ov.querySelector('#gsBack').onclick=closeSend;return;}
  ov.innerHTML=top+'<div class="sg-sub">اختر هدية لإرسالها إلى <b>'+esc(toName)+'</b></div><div id="gsGrid" class="posts-grid gifts-grid"></div><div class="gs-bar"><button type="button" class="gs-send" id="gsSend" disabled>اختر هدية</button></div>';
  ov.querySelector('#gsBack').onclick=closeSend;
  const grid=ov.querySelector('#gsGrid'),btn=ov.querySelector('#gsSend');let sel=null,sending=false;
  items.forEach(g=>{
    const t=giftArt(g,{still:true,cls:'gift-tile'});
    t.insertAdjacentHTML('beforeend',gtRib(g));
    if(listed.has(g.k+'_'+g.number)){
      t.classList.add('gs-listed');t.insertAdjacentHTML('beforeend','<div class="rs-mine">معروضة</div>');
      t.onclick=()=>showToast('هذه الهدية معروضة للبيع، ألغِ العرض أولاً');
      grid.appendChild(t);return;
    }
    t.onclick=()=>{
      grid.querySelectorAll('.gs-sel').forEach(x=>x.classList.remove('gs-sel'));
      t.classList.add('gs-sel');sel=g;btn.disabled=false;btn.textContent='إرسال '+gk(g.k).name+' #'+g.number;
    };
    grid.appendChild(t);
  });
  btn.onclick=async()=>{
    if(!sel||sending)return;
    const K=gk(sel.k);
    const r=await clAsk({title:'إرسال الهدية',icon:'gift',body:'إرسال <b>'+esc(K.name)+' #'+sel.number+'</b> إلى <b>'+esc(toName)+'</b>؟ تصير ملكه ولا ترجع إلك.',buttons:[{text:'إرسال'},{text:'إلغاء',cls:'cl-cancel'}]});
    if(!r||r.i!==0)return;
    sending=true;btn.disabled=true;btn.textContent='جاري الإرسال…';
    try{await transferGift(sel,to);showToast('🎁 وصلت الهدية إلى '+toName);closeSend();}
    catch(e){console.error(e);showToast('تعذر إرسال الهدية');sending=false;btn.disabled=false;btn.textContent='إرسال '+K.name+' #'+sel.number;}
  };
}
/* كارت الهدية داخل المحادثة */
function giftMsgNode(m,id,isMine){
  const K=GIFT_KINDS[m.k]||GIFT_KINDS.pepe;
  const other=String((document.getElementById('otherHeaderNameText')||{}).textContent||'').trim();
  const myName=(typeof currentUserData!=='undefined'&&currentUserData&&currentUserData.displayName)||'أنت';
  const from=isMine?myName:other;
  const who=other?(' <b>'+esc(other)+'</b>'):'';
  const line=m.shared?(isMine?('شاركت'+who+' هدية'):('شاركك'+who+' هدية')):(isMine?('أنت أهديت'+who+' هدية'):('أهداك'+who+' هدية'));
  const g={k:K.key,number:m.number,upgraded:!!m.upgraded,model:m.model,bg:m.bg,sym:m.sym};
  const up=g.upgraded&&K.models[g.model]&&PEPE_BGS[g.bg]&&PEPE_SYMS[g.sym];
  const w=document.createElement('div');w.className='gm-wrap';w.id='message_'+id;w.dataset.created=String(m.createdAt||0);
  const row=(a,b)=>'<div class="gg-row"><span>'+a+'</span><b>'+esc(b)+'</b></div>';
  w.innerHTML='<div class="sys-msg">'+line+'</div>'
    +'<div class="gg-card" style="background:'+bgCss(g)+'">'+(up?patSvg(g.sym):'')
    +'<div class="gg-art"><img alt="" src="'+thumbUrl(g)+'"></div>'
    +(m.shared?'':'<div class="gg-from">هدية من <b>'+esc(from||'مستخدم')+'</b></div>')
    +'<div class="gg-title">'+esc(K.name)+' #'+g.number+'</div>'
    +(up?row('النموذج',K.models[g.model].n)+row('الخلفية',PEPE_BGS[g.bg].n)+row('الرمز',PEPE_SYMS[g.sym].n):'')
    +'<button type="button" class="gg-btn">عرض</button></div>';
  const im=w.querySelector('.gg-art img');im.onerror=()=>{im.onerror=null;im.src=thumbLocal(g);};
  w.querySelector('.gg-btn').onclick=ev=>{ev.stopPropagation();
    /* الهدية المشاركة: نجلب المالك الحالي من قاعدة البيانات لأنها قد تنتقل لشخص آخر */
    if(m.shared&&typeof giftOpenFromRef==='function')giftOpenFromRef({kind:K.key,number:m.number,owner:null});
    else openGiftPage(m.owner||m.to||meId(),m.number,K.key);};
  return w;
}


/* ===== سوق الهدايا المُرقّاة: بيع وشراء بالنجوم ===== */
async function refreshGP(ov){
  const c=ov&&ov._ctx;if(!c||!document.getElementById('giftPage'))return;
  const K=gk(c.g.k);let lst=null;
  try{const ld=await db.collection('giftListings').doc(listId(K,c.g.number)).get();if(ld.exists)lst=ld.data();}catch(e){}
  renderGiftPage(ov,c.uid,c.g,c.issued,false,lst);
}
async function sellGift(ov,g,old){
  const K=gk(g.k),me=meId();
  const fl=await floorFor(K);
  const r=await clAsk({title:old?'تعديل السعر':'بيع الهدية',icon:'tag',body:'اكتب السعر بالنجوم لـ <b>'+esc(K.name)+' #'+g.number+'</b><br><small>عمولة السوق '+FEE_PCT+'% · تستلم '+(100-FEE_PCT)+'% من السعر'+(fl!=null?'<br>أرخص عرض حالياً لهذا النوع: ⭐ '+fmtN(fl):'')+'</small>',input:{value:old?String(old.price):'',placeholder:'السعر بالنجوم',max:7,numeric:true,phSmall:true},buttons:[{text:old?'حفظ':'عرض للبيع'},{text:'إلغاء',cls:'cl-cancel'}]});
  if(!r||r.i!==0)return;
  const price=parseInt(String(r.value).replace(/[^\d]/g,''),10);
  if(!price||price<1||price>1000000)return showToast('اكتب سعراً بين 1 و 1,000,000');
  try{
    const ref=db.collection('giftListings').doc(listId(K,g.number));
    if(old)await ref.update({price});
    else await ref.set({k:K.key,number:g.number,coll:K.coll,sellerId:me,price,at:Date.now(),giftAt:g.at||0,model:g.model,bg:g.bg,sym:g.sym,name:K.name});
    _lc.t=0;
    showToast(old?'تم تحديث السعر':'🏷️ انعرضت للبيع بـ '+fmtN(price)+' ⭐ · تستلم '+fmtN(netOf(price)));
    refreshGP(ov);
  }catch(e){console.error(e);showToast('تعذر عرض الهدية للبيع');}
}
async function unlistGift(ov,g){
  const K=gk(g.k);
  const r=await clAsk({title:'إلغاء العرض',icon:'untag',body:'تريد تلغي بيع <b>'+esc(K.name)+' #'+g.number+'</b>؟',buttons:[{text:'إلغاء العرض',cls:'cl-danger'},{text:'رجوع',cls:'cl-cancel'}]});
  if(!r||r.i!==0)return;
  try{await db.collection('giftListings').doc(listId(K,g.number)).delete();_lc.t=0;showToast('تم إلغاء العرض');refreshGP(ov);}
  catch(e){console.error(e);showToast('تعذر إلغاء العرض');}
}
async function buyListing(ov,l){
  if(buying||!l)return;
  const K=gk(l.k),me=meId(),dev=isDevUser();
  if(l.sellerId===me)return;
  if(!dev&&myStars<l.price)return showToast('رصيدك غير كافٍ ⭐');
  const r=await clAsk({title:'شراء الهدية',icon:'cart',body:'شراء <b>'+esc(K.name)+' #'+l.number+'</b> بـ <b>'+fmtN(l.price)+' ⭐</b>؟ النجوم تروح لصاحبها وتصير الهدية إلك.',buttons:[{text:'شراء'},{text:'إلغاء',cls:'cl-cancel'}]});
  if(!r||r.i!==0)return;
  buying=true;
  const btn=document.getElementById('gpBuy');if(btn){btn.disabled=true;btn.textContent='جاري الشراء…';}
  try{
    await giftApi('buy-listing',{kind:K.key,number:l.number});
    _lc.t=0;
    showToast('🎉 مبروك! صارت '+K.name+' #'+l.number+' إلك');
    buying=false;
    closeGiftPage();closeStore();openGiftPage(me,l.number,K.key);
    return;
  }catch(e){
    console.error(e);
    showToast(e.code==='funds'?'رصيدك غير كافٍ ⭐':e.code==='gone'?'العرض تغيّر أو انباع':'ما تم الشراء، يمكن أحد سبقك');
    const b2=document.getElementById('gpBuy');if(b2){b2.disabled=false;b2.textContent='🛒 شراء بـ ⭐ '+fmtN(l.price);}
  }
  buying=false;
}
/* ===== سجل الهدية + أرخص سعر + فلتر النوع ===== */
async function loadGiftHistory(ov,K,g){
  const body=ov.querySelector('.gp-body');if(!body)return;
  const box=document.createElement('div');box.className='gp-hist';
  box.innerHTML='<div class="gp-hh">سجل الهدية</div><div class="gp-hl"><div class="gp-hn">جاري التحميل…</div></div>';
  body.appendChild(box);
  let evs=[];
  try{evs=(await db.collection('giftEvents').doc(listId(K,g.number)).collection('log').orderBy('at','desc').limit(20).get()).docs.map(d=>d.data());}catch(e){}
  const ids=[...new Set(evs.flatMap(e=>[e.from,e.to].filter(Boolean)))];
  try{if(ids.length)await loadUsers(ids);}catch(e){}
  if(!ov.contains(box))return;
  const nm=id=>'<b>'+esc((GU[id]&&GU[id].displayName)||'مستخدم')+'</b>';
  const list=box.querySelector('.gp-hl');
  if(!evs.length){list.innerHTML='<div class="gp-hn">ما كو سجل لهذه الهدية (قبل تفعيل السجل).</div>';return;}
  list.innerHTML=evs.map(e=>{
    let ic='🎁',t='';
    if(e.type==='mint'){t='اشتراها '+nm(e.to)+' من المتجر'+(e.price?' بـ ⭐ '+fmtN(e.price):'');}
    else if(e.type==='send'){ic='📤';t='أهداها '+nm(e.from)+' إلى '+nm(e.to);}
    else{ic='🛒';t='باعها '+nm(e.from)+' إلى '+nm(e.to)+' بـ ⭐ '+fmtN(e.price||0);}
    return '<div class="gp-he"><span class="gp-hi">'+ic+'</span><div><div>'+t+'</div><small>'+fmtWhen(e.at)+'</small></div></div>';
  }).join('');
}
async function floorFor(K){
  try{const s=await db.collection('giftListings').where('k','==',K.key).get();let m=null;s.forEach(d=>{const p=d.data().price;if(m===null||p<m)m=p;});return m;}catch(e){return null;}
}
let _lc={t:0,list:null,p:null};
async function getListings(){
  if(_lc.list&&Date.now()-_lc.t<45000)return _lc.list;
  if(_lc.p)return _lc.p;
  _lc.p=db.collection('giftListings').orderBy('at','desc').limit(200).get().then(sn=>{_lc.list=sn.docs.map(d=>d.data());_lc.t=Date.now();_lc.p=null;return _lc.list;}).catch(e=>{_lc.p=null;throw e;});
  return _lc.p;
}
/* أرخص سعر مطورة تحت كل كرت بتبويب "هدايا جديدة" */
async function paintFloors(ov){
  try{
    const list=await getListings(),fl={};
    list.forEach(l=>{if(fl[l.k]==null||l.price<fl[l.k])fl[l.k]=l.price;});
    ov.querySelectorAll('.sg-card').forEach(c=>{const f=fl[c.dataset.k],e=c.querySelector('.sg-floor');if(e&&f!=null)e.textContent='🏷️ مطورة من '+fmtN(f);});
  }catch(e){}
}
/* تبويب "هدايا مطورة" بالمتجر */
const resaleState={sort:'new',kind:''};
async function loadResale(box){
  box.innerHTML='<div class="sg-sub">جاري التحميل…</div>';
  let all=[];
  try{all=await getListings();}catch(e){console.error(e);box.innerHTML='<div class="sg-sub">تعذر تحميل العروض</div>';return;}
  const me=meId(),st=resaleState;
  const stat={};all.forEach(l=>{const o=stat[l.k]||(stat[l.k]={n:0,min:Infinity});o.n++;if(l.price<o.min)o.min=l.price;});
  if(st.kind&&!stat[st.kind])st.kind='';
  let list=all.filter(l=>!st.kind||l.k===st.kind);
  list=list.slice().sort((a,b)=>st.sort==='low'?a.price-b.price:st.sort==='high'?b.price-a.price:(b.at||0)-(a.at||0));
  const sorts=[['new','الأحدث'],['low','الأرخص'],['high','الأغلى']].map(x=>'<button type="button" class="rs-chip'+(x[0]===st.sort?' on':'')+'" data-s="'+x[0]+'">'+x[1]+'</button>').join('');
  const kinds=Object.keys(stat).sort((a,b)=>stat[b].n-stat[a].n).map(k=>'<button type="button" class="rs-chip'+(k===st.kind?' on':'')+'" data-k="'+k+'">'+esc(GIFT_KINDS[k]?GIFT_KINDS[k].name:k)+' · '+stat[k].n+'</button>').join('');
  const floor=st.kind?'<div class="rs-floor">أرخص سعر: ⭐ '+fmtN(stat[st.kind].min)+' · '+stat[st.kind].n+' معروضة</div>':'';
  box.innerHTML='<div class="rs-chips">'+sorts+'</div>'
    +(kinds?'<div class="rs-chips"><button type="button" class="rs-chip'+(st.kind?'':' on')+'" data-k="">الكل · '+all.length+'</button>'+kinds+'</div>':'')
    +floor
    +(list.length?'<div class="rs-grid"></div>':'<div class="sg-sub">ما كو هدايا مطورة معروضة هسه</div>');
  box.querySelectorAll('[data-s]').forEach(c=>c.onclick=()=>{st.sort=c.dataset.s;loadResale(box);});
  box.querySelectorAll('[data-k]').forEach(c=>c.onclick=()=>{st.kind=c.dataset.k;loadResale(box);});
  const grid=box.querySelector('.rs-grid');if(!grid)return;
  list.forEach(l=>{
    const K=GIFT_KINDS[l.k];if(!K)return;
    const g={k:K.key,number:l.number,upgraded:true,model:l.model,bg:l.bg,sym:l.sym};
    const card=document.createElement('div');card.className='rs-card';
    const t=giftArt(g,{still:true,cls:'gift-tile'});
    t.insertAdjacentHTML('beforeend',gtRib(g)+(l.sellerId===me?'<div class="rs-mine">عرضك</div>':''));
    card.appendChild(t);
    card.insertAdjacentHTML('beforeend','<div class="sg-name">'+esc(K.name)+'</div><div class="sg-price">⭐ '+fmtN(l.price)+'</div>');
    card.onclick=()=>openGiftPage(l.sellerId,l.number,K.key);
    grid.appendChild(card);
  });
}
/* رسالة "انباعت هديتك" بالمحادثة */
function soldMsgNode(m,id,isMine){
  const K=GIFT_KINDS[m.k]||GIFT_KINDS.pepe;
  const w=document.createElement('div');w.className='sys-msg';w.id='message_'+id;w.dataset.created=String(m.createdAt||0);
  w.innerHTML=isMine?('🛒 اشتريت <b>'+esc(K.name)+' #'+m.number+'</b> بـ ⭐ '+fmtN(m.price||0))
                   :('🛒 اشترى هديتك <b>'+esc(K.name)+' #'+m.number+'</b> بـ ⭐ '+fmtN(m.price||0)+' · استلمت ⭐ '+fmtN(m.net||0));
  return w;
}


/* ===== قائمة الضغط المطوّل على الهدية (إخفاء / إرسال / تثبيت / مشاركة) ===== */
const gmRemote={};
const GM_IC={
 pin:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M8.5 3.5h7M10 3.5v5.2L7 12v1.5h10V12l-3-3.3V3.5M12 13.5V21"/></svg>',
 unpin:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M8.5 3.5h7M10 3.5v5.2L7 12v1.5h10V12l-3-3.3V3.5M12 13.5V21"/><path d="M4 4l16 16"/></svg>',
 share:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M12 15V3.5M8 7l4-4 4 4M5 12v6.5A1.5 1.5 0 0 0 6.5 20h11a1.5 1.5 0 0 0 1.5-1.5V12"/></svg>',
 hide:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M3 12c2.2-4.2 5.6-6.5 9-6.5s6.8 2.3 9 6.5c-2.2 4.2-5.6 6.5-9 6.5S5.2 16.2 3 12z"/><circle cx="12" cy="12" r="2.6"/><path d="M4 4l16 16"/></svg>',
 show:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M3 12c2.2-4.2 5.6-6.5 9-6.5s6.8 2.3 9 6.5c-2.2 4.2-5.6 6.5-9 6.5S5.2 16.2 3 12z"/><circle cx="12" cy="12" r="2.6"/></svg>',
 send:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M21 3 10.5 13.5M21 3l-6.5 18-4-7.5L3 9.5z"/></svg>',
 pinS:'<svg width="16" height="16" viewBox="0 0 24 24"><g transform="rotate(35 12 12)" stroke="#fff" stroke-linejoin="round" stroke-linecap="round"><path d="M9.4 3.8h5.2l-.5 4.9 2.6 3v1.6H7.3v-1.6l2.6-3z" fill="#fff" stroke-width="2.2"/><path d="M12 14.5v5.5" fill="none" stroke-width="2"/></g></svg>',
 hideS:'<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/><path d="M3 3l18 18"/></svg>'
};
function giftPrefs(uid){
  let pins=[],hidden=[];
  if(uid===meId()){
    try{const o=JSON.parse(localStorage.getItem('bbGiftPrefs_'+uid)||'{}');pins=o.pins||[];hidden=o.hidden||[];}catch(e){}
  }else{const r=gmRemote[uid];if(r){pins=r.pins;hidden=r.hidden;}}
  return {pins:new Set(pins),hidden:new Set(hidden)};
}
function giftPrefsSave(uid,st){
  const o={pins:[...st.pins],hidden:[...st.hidden]};
  try{localStorage.setItem('bbGiftPrefs_'+uid,JSON.stringify(o));}catch(e){}
  try{db.collection('users').doc(uid).update({giftPins:o.pins,giftHidden:o.hidden}).catch(()=>{});}catch(e){}
}
function gmBindLongPress(t,uid,g,redraw){
  let timer=null,sx=0,sy=0;
  const cancel=()=>{if(timer){clearTimeout(timer);timer=null;}};
  t.addEventListener('touchstart',e=>{
    if(e.touches.length!==1)return;
    sx=e.touches[0].clientX;sy=e.touches[0].clientY;cancel();
    timer=setTimeout(()=>{timer=null;t._lp=true;if(navigator.vibrate)try{navigator.vibrate(12);}catch(_){}gmOpenMenu(t,uid,g,redraw);},320);
  },{passive:true});
  t.addEventListener('touchmove',e=>{const x=e.touches[0];if(Math.abs(x.clientX-sx)>8||Math.abs(x.clientY-sy)>8)cancel();},{passive:true});
  ['touchend','touchcancel'].forEach(ev=>t.addEventListener(ev,()=>{cancel();setTimeout(()=>{t._lp=false;},350);},{passive:true}));
  t.addEventListener('contextmenu',e=>{e.preventDefault();cancel();t._lp=true;gmOpenMenu(t,uid,g,redraw);});
}
function gmCss(){
  if(document.getElementById('gmCss'))return;
  const st=document.createElement('style');st.id='gmCss';
  st.textContent=`
.gifts-grid .gift-tile{outline:0!important;-webkit-touch-callout:none;-webkit-user-select:none;user-select:none}
.gift-tile .gt-pin{position:absolute;top:6px;right:6px;width:16px;height:16px;background:none!important;border:0;border-radius:0;box-shadow:none!important;display:flex;align-items:center;justify-content:center;z-index:4;pointer-events:none}
.gift-tile .gt-pin svg{width:16px;height:16px;fill:#fff;filter:none;display:block}
.gift-tile.gt-hid .ga-pepe,.gift-tile.gt-hid .ga-pat{opacity:.35}
.gift-tile .gt-eye{position:absolute;bottom:6px;right:6px;width:16px;height:16px;background:none!important;border:0;border-radius:0;box-shadow:none!important;display:flex;align-items:center;justify-content:center;z-index:4;pointer-events:none;color:#fff}
.gift-tile .gt-eye svg{width:16px;height:16px;display:block;fill:none!important;stroke:#fff!important}
.gift-tile .gt-eye svg *{fill:none!important;stroke:#fff!important}
.gm-ov{position:fixed;inset:0;z-index:100001;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:12px;padding:18px;direction:rtl;box-sizing:border-box;
  background:rgba(8,12,18,0);transition:background .18s ease}
.gm-ov.in{background:rgba(8,12,18,.72)}
.gm-ov.out{background:rgba(8,12,18,0);transition-duration:.12s}
.gmx-wrap{position:relative;width:calc(100% - 36px);max-width:560px;aspect-ratio:1.55/1;flex:0 0 auto;
  transform:scale(.7);opacity:0;will-change:transform,opacity;transition:transform .22s cubic-bezier(.2,1.1,.4,1),opacity .15s ease}
.gm-ov.in .gmx-wrap{transform:scale(1);opacity:1}
.gm-ov.out .gmx-wrap{transform:scale(.7);opacity:0;transition:transform .18s ease,opacity .16s ease}
.gm-ov .gm-card{position:absolute;inset:0;border-radius:26px;overflow:hidden;border:0!important;outline:0!important;box-shadow:none!important;background-clip:border-box}
.gm-ov .gmx-wrap,.gm-ov .gm-menu,.gm-ov .gm-it{border:0!important;outline:0!important}
.gm-ov .gmx-wrap{box-shadow:none!important}
.gm-ribw{position:absolute;top:-3px;right:-3px;width:54px;height:54px;overflow:hidden;pointer-events:none;z-index:5}
.gmr-back,.gmr-main{position:absolute;inset:0}
/* الشريط الأمامي مقصوص بنفس انحناء زاوية البطاقة (26px) فيبدو الجزء الخارج عنها (3px) كأنه خلف البطاقة بلون أغمق */
.gmr-main{-webkit-clip-path:inset(3px 3px 0 0 round 0 26px 0 0);clip-path:inset(3px 3px 0 0 round 0 26px 0 0)}
.gmr-band{position:absolute;left:-10.6px;top:17.7px;width:104px;height:19px;box-sizing:border-box;padding-right:20px;display:block;transform:rotate(45deg);transform-origin:50% 50%;font-style:normal;font-weight:800;font-size:7px;line-height:19px;letter-spacing:0;text-align:center;white-space:nowrap;direction:ltr;color:#fff;text-shadow:0 1px 1px rgba(0,0,0,.25)}
.gmr-main .gmr-band{box-shadow:0 0 7px rgba(0,0,0,.28),inset 0 0 0 1px rgba(255,255,255,.07)}

.gm-card .ga-pat{position:absolute;inset:0;width:100%;height:100%}
.gm-pepe{position:absolute;left:50%;top:8%;width:54%;aspect-ratio:1/1;transform:translateX(-50%)}
.gm-pepe>div,.gm-pepe svg{width:100%;height:100%}
.gm-title{position:absolute;left:0;right:0;bottom:15%;text-align:center;color:#fff;font-weight:800;font-size:26px;direction:ltr;text-shadow:0 1px 6px rgba(0,0,0,.25)}
.gm-sub{position:absolute;left:0;right:0;bottom:7%;text-align:center;color:rgba(255,255,255,.62);font-size:14px;font-weight:600}
.gm-rib{box-shadow:0 2px 5px rgba(0,0,0,.4);box-sizing:border-box;text-align:center;color:#fff;font-size:11px;font-weight:800;direction:ltr;line-height:1.3;z-index:3}
.gm-menu{align-self:flex-end;margin-inline-end:max(18px,calc((100% - 560px)/2));width:min(calc(72vw - 15px),255px);background:var(--cl-card,#17212b);border-radius:18px;overflow:hidden;
  transform-origin:top left;transform:scale(.8);opacity:0;will-change:transform,opacity;transition:transform .2s cubic-bezier(.2,1.1,.4,1),opacity .14s ease;box-shadow:0 10px 30px rgba(0,0,0,.4)}
.gm-ov.in .gm-menu{transform:scale(1);opacity:1}
.gm-ov.out .gm-menu{transform:scale(.8);opacity:0;transition:transform .16s ease,opacity .14s ease}
.gm-it{display:flex;align-items:center;gap:14px;width:100%;padding:15px 18px;background:none;border:0;color:var(--cl-text,#f1f5f9);font-size:17px;font-family:inherit;text-align:right;cursor:pointer;direction:rtl;
  opacity:0;transform:translateY(6px);transition:opacity .15s ease,transform .15s ease,background .12s}
.gm-ov.in .gm-it{opacity:1;transform:none}
.gm-it:active{background:var(--cl-chip,rgba(255,255,255,.08))}
.gm-it svg{width:24px;height:24px;flex:0 0 24px}
.gm-it span{flex:1}
.gm-sep{height:8px;background:var(--cl-sep,rgba(255,255,255,.07))}
.gm-pick{position:fixed;inset:0;z-index:99990;background:var(--cl-bg,#0e1621);color:var(--cl-text,#f1f5f9);display:flex;flex-direction:column;direction:rtl}
.gm-pick-top{display:flex;align-items:center;gap:10px;padding:calc(12px + var(--sat,0px)) 14px 12px;font-weight:700;font-size:17px}
.gm-pick-top button{background:none;border:0;color:inherit;font-size:22px;padding:4px 10px}
.gm-pick-list{flex:1;overflow:auto}
.gm-pick-row{display:flex;align-items:center;gap:12px;padding:10px 16px;cursor:pointer}
.gm-pick-row:active{background:rgba(255,255,255,.07)}
.gm-pick-row .g-av{width:44px;height:44px}
.gm-pick-empty{padding:40px 20px;text-align:center;opacity:.7}
body:has(.app-container[data-app-theme="light"]) :is(.gm-ov,.gm-pick){--cl-bg:#f4f6fa;--cl-card:#ffffff;--cl-text:#16202b;--cl-sub:#6b7a8c;--cl-sep:rgba(22,32,43,.08);--cl-chip:#e8edf4}
body:has(.app-container[data-app-theme="dark"]) :is(.gm-ov,.gm-pick){--cl-bg:#0e1621;--cl-card:#17212b;--cl-text:#f1f5f9;--cl-sub:#8798aa;--cl-sep:rgba(255,255,255,.08);--cl-chip:#243243}
body:has(.app-container[data-app-theme="light"]) .gm-ov.in{background:rgba(244,246,250,.55)}
body:has(.app-container[data-app-theme="light"]) .gm-ov.out{background:rgba(244,246,250,0)}
body:has(.app-container[data-app-theme="light"]) .gm-menu{box-shadow:0 10px 30px rgba(22,32,43,.18)}
.gm-pick-row .g-av+b{color:var(--cl-text,#f1f5f9)}
.gm-pick-row:active{background:var(--cl-chip,rgba(255,255,255,.07))}
`;
  document.head.appendChild(st);
}
function gmCloseMenu(ov,cb){
  if(!ov||ov._closing)return;ov._closing=true;
  ov.classList.remove('in');ov.classList.add('out');
  setTimeout(()=>{if(ov._pepe&&ov._pepe._an)try{ov._pepe._an.destroy();}catch(e){}ov.remove();if(cb)cb();},170);
}
function gmOpenMenu(tile,uid,g,redraw){
  gmCss();
  document.querySelectorAll('.gm-ov').forEach(x=>x.remove());
  const K=gk(g.k),me=meId(),mine=uid===me,key=g.k+'_'+g.number;
  const st=giftPrefs(uid),pinned=st.pins.has(key),hid=st.hidden.has(key);
  const ov=document.createElement('div');ov.className='gm-ov';
  const items=[];
  if(mine)items.push({id:'pin',ic:pinned?GM_IC.unpin:GM_IC.pin,t:pinned?'إلغاء التثبيت':'تثبيت',sep:true});
  items.push({id:'share',ic:GM_IC.share,t:'مشاركة'});
  if(mine)items.push({id:'hide',ic:hid?GM_IC.show:GM_IC.hide,t:hid?'إظهار':'إخفاء'});
  if(mine)items.push({id:'send',ic:GM_IC.send,t:'إرسال'});
  ov.innerHTML='<div class="gmx-wrap"><div class="gm-card" style="background:'+bgCss(g)+'">'+(g.upgraded?patSvg(g.sym):'')
    +'<div class="gm-pepe"'+(g.upgraded?'':' style="filter:grayscale(1) brightness(.8)"')+'></div>'
    +'<div class="gm-title">'+esc(K.name)+'</div><div class="gm-sub">مُقتنى رقمي #'+g.number+'</div></div>'
    +'<div class="gm-ribw">'+ribHtml(g,'gm-rib')+'</div></div>'
    +'<div class="gm-menu">'+items.map((x,i)=>'<button type="button" class="gm-it" data-id="'+x.id+'" style="transition-delay:'+(0.02+i*0.025)+'s"><span>'+x.t+'</span>'+x.ic+'</button>'+(x.sep?'<div class="gm-sep"></div>':'')).join('')+'</div>';
  uiRoot().appendChild(ov);
  ov._pepe=ov.querySelector('.gm-pepe');
  requestAnimationFrame(()=>ov.classList.add('in'));
  setTimeout(()=>{if(ov.isConnected)mountPepeAnim(ov._pepe,g.upgraded?g.model:-1,{kind:g.k});},260);
  ov.addEventListener('click',e=>{if(e.target===ov)gmCloseMenu(ov);});
  ov.querySelectorAll('.gm-it').forEach(b=>b.onclick=ev=>{
    ev.stopPropagation();
    const id=b.dataset.id;
    if(id==='pin'||id==='hide'){
      if(id==='pin'){pinned?st.pins.delete(key):st.pins.add(key);}
      else{hid?st.hidden.delete(key):st.hidden.add(key);}
      giftPrefsSave(uid,st);
      gmCloseMenu(ov,()=>{if(redraw)redraw();showToast(id==='pin'?(pinned?'تم إلغاء التثبيت':'تم التثبيت'):(hid?'صارت الهدية ظاهرة':'تم إخفاء الهدية عن الآخرين'));});
    }else if(id==='share'){
      gmCloseMenu(ov,()=>gmShare(K,g,uid));
    }else if(id==='send'){
      gmCloseMenu(ov,()=>gmSendPick(g));
    }
  });
}
/* ---------- رابط الهدية: المشاركة ترسل الرابط فقط، وفتحه يعرض صفحة الهدية ---------- */
function giftBaseUrl(){
  const host=location.hostname,web=/^https?:$/.test(location.protocol)&&host&&host!=='localhost'&&host!=='127.0.0.1';
  return (web?location.origin:(window.BB_PUBLIC_URL||location.origin)).replace(/\/$/,'');
}
const giftSlug=K=>String(K.name||K.key).replace(/\s+/g,'');
/* يستخرج رقم الهدية الحقيقي حتى لو وصل داخل كائن (مثل {number:..} أو {g:{number:..}}) */
function giftNum(v,d){
  d=d||0;
  if(v==null||d>4)return null;
  if(typeof v==='number')return isFinite(v)&&v>=0?Math.floor(v):null;
  if(typeof v==='string'){const m=/^\s*#?(\d+)\s*$/.exec(v);return m?parseInt(m[1],10):null;}
  if(typeof v==='object'){
    if(typeof v.toNumber==='function'){try{return giftNum(v.toNumber(),d+1);}catch(e){}}
    for(const k of ['number','n','num','value','g']){if(k in v){const r=giftNum(v[k],d+1);if(r!=null)return r;}}
  }
  return null;
}
/* اسم فريد حتى لا يطغى عليه تعريف آخر لـ giftLink في ملف ثاني (مثل gift-link.js) */
function gmGiftLink(K,g){
  const n=giftNum(g);
  if(!K||n==null)return null;
  const link=giftBaseUrl()+'/nft/'+encodeURIComponent(giftSlug(K))+'-'+n;
  return /\[object|undefined|NaN/.test(link)?null:link;
}
function giftLink(K,g,uid){return gmGiftLink(K,g);}
function giftKindBySlug(slug){
  const w=String(slug||'').toLowerCase();
  return Object.values(GIFT_KINDS).find(K=>giftSlug(K).toLowerCase()===w)||null;
}
function giftHostOk(h){
  const hs=[location.hostname,'babyllon.vercel.app'];
  try{if(window.BB_PUBLIC_URL)hs.push(new URL(window.BB_PUBLIC_URL).hostname);}catch(e){}
  h=String(h||'').replace(/^www\./,'').toLowerCase();
  return hs.some(x=>String(x||'').replace(/^www\./,'').toLowerCase()===h);
}
/* يدعم الرابط الجديد /nft/VictoryMedal-1 (المالك يُجلب من قاعدة البيانات) والقديم ?gift=kind_n&o=uid */
function giftFromUrl(raw){
  try{
    const u=new URL(raw,location.href);
    const nm=/^\/nft\/([^\/?#]+)-(\d+)\/?$/.exec(decodeURIComponent(u.pathname));
    if(nm&&giftHostOk(u.hostname))return {slug:nm[1],number:parseInt(nm[2],10),owner:null,kind:(giftKindBySlug(nm[1])||{}).key||null};
    const p=u.searchParams.get('gift'),o=u.searchParams.get('o');
    if(!p||!o)return null;
    const m=/^([a-z]+)_(\d+)$/.exec(p);
    if(!m||!GIFT_KINDS[m[1]])return null;
    return {kind:m[1],number:parseInt(m[2],10),owner:o};
  }catch(e){return null;}
}
async function giftResolveOwner(r){
  if(r.owner)return r.owner;
  const K=r.kind?GIFT_KINDS[r.kind]:giftKindBySlug(r.slug);
  if(!K)return null;
  try{
    const d=await db.collection(K.gen?'giftSales':K.sales).doc(gid(K,r.number)).get();
    return d.exists?(d.data().ownerId||null):null;
  }catch(e){return null;}
}
async function giftOpenFromRef(r){
  const K=r.kind?GIFT_KINDS[r.kind]:giftKindBySlug(r.slug);
  if(!K){showToast('هذه الهدية غير موجودة');return;}
  const owner=await giftResolveOwner(Object.assign({},r,{kind:K.key}));
  if(!owner){showToast('هذه الهدية غير موجودة');return;}
  openGiftPage(owner,r.number,K.key);
}
document.addEventListener('click',e=>{
  const a=e.target&&e.target.closest&&e.target.closest('a.msg-link');if(!a)return;
  const r=giftFromUrl(a.getAttribute('href'));if(!r)return;
  if(typeof messageSelectionMode!=='undefined'&&messageSelectionMode)return;
  e.preventDefault();e.stopPropagation();
  giftOpenFromRef(r);
},true);
(function openGiftFromLaunchUrl(){
  const r0=giftFromUrl(location.href);if(!r0)return;
  let tries=0;
  const t=setInterval(()=>{
    if(++tries>60){clearInterval(t);return;}
    if(typeof currentUser==='undefined'||!currentUser)return;
    const r=giftFromUrl(location.href)||r0;
    if(!r.kind&&r.slug)return; /* أنواع الهدايا المولّدة تُحمَّل لاحقاً */
    clearInterval(t);try{giftOpenFromRef(r);}catch(e){}
  },500);
})();
async function gmShare(K,g,uid){
  document.getElementById('gmSharePicker')?.remove();
  const d=document.createElement('div');d.id='gmSharePicker';d.className='message-delete-modal';
  d.innerHTML='<div class="message-delete-card fwd-card"><div class="message-delete-heading">مشاركة الهدية إلى</div><div class="fwd-list" id="gmShList"><div class="fwd-empty">جارٍ التحميل…</div></div><button type="button" class="cancel" id="gmShCancel">إلغاء</button></div>';
  uiRoot().appendChild(d);
  const close=()=>d.remove();
  d.addEventListener('click',e=>{if(e.target===d)close();});
  d.querySelector('#gmShCancel').onclick=close;
  const list=d.querySelector('#gmShList'),me=meId(),rows=[];
  const ids=Object.keys(chatMetaCache||{});
  for(let i=0;i<ids.length;i++){
    const id=ids[i],m=chatMetaCache[id];
    if(!m||m.type==='group'||!(m.participants||[]).includes(me))continue;
    const o=(m.participants||[]).find(x=>x!==me);
    if(!o||(typeof myBlocks!=='undefined'&&myBlocks&&myBlocks[o]))continue;
    let u=null;try{u=await fetchUser(o);}catch(e){}
    if(!u)continue;
    rows.push({id,o,name:u.displayName||'مستخدم',sub:'@'+(u.username||''),at:m.updatedAt||0,photo:(typeof pvUrl==='function'?pvUrl(u):'')});
  }
  if(!d.isConnected)return;
  rows.sort((a,b)=>b.at-a.at);
  if(!rows.length){list.innerHTML='<div class="fwd-empty">لا توجد محادثات متاحة</div>';return;}
  list.innerHTML='';
  rows.forEach(r=>{
    const b=document.createElement('button');b.type='button';b.className='fwd-row';
    b.innerHTML='<span class="avatar">'+(r.photo?'<img src="'+esc(r.photo)+'" alt="">':esc((r.name||'?').charAt(0).toUpperCase()))+'</span><span class="fwd-info"><b>'+esc(r.name)+'</b><i>'+esc(r.sub)+'</i></span>';
    b.onclick=async()=>{
      close();
      try{
        const now=Date.now();
        /* المشاركة ترسل الهدية نفسها (كارت) بدون أي رابط نصي */
        const n=giftNum(g);if(n==null){showToast('تعذرت مشاركة الهدية');return;}
        const msg={senderId:me,type:'gift',shared:true,k:K.key,number:n,upgraded:!!g.upgraded,owner:me,to:r.o,text:'🎁 '+K.name+' #'+n,read:false,createdAt:now};
        if(g.upgraded){msg.model=g.model;msg.bg=g.bg;msg.sym=g.sym;}
        await db.collection('chats').doc(r.id).collection('messages').add(msg);
        await db.collection('chats').doc(r.id).set({updatedAt:now},{merge:true});
        try{notifyPeer(r.id,'🎁 '+K.name+' #'+g.number);}catch(e){}
        showToast('تمت مشاركة الهدية مع '+r.name);
      }catch(e){console.error(e);showToast('تعذرت مشاركة الهدية');}
    };
    list.appendChild(b);
  });
}
async function gmSendPick(g){
  gmCss();
  const K=gk(g.k);
  try{
    const ld=await db.collection('giftListings').doc(listId(K,g.number)).get();
    if(ld.exists){showToast('هذه الهدية معروضة للبيع، ألغِ العرض أولاً');return;}
  }catch(e){}
  const ids=contactIds(new Set([meId()]));
  const ov=document.createElement('div');ov.className='gm-pick';
  ov.innerHTML='<div class="gm-pick-top"><button type="button" id="gmpBack">✕</button><span>إرسال '+esc(K.name)+' #'+g.number+' إلى…</span></div><div class="gm-pick-list"><div class="gm-pick-empty">جاري التحميل…</div></div>';
  uiRoot().appendChild(ov);
  ov.querySelector('#gmpBack').onclick=()=>ov.remove();
  await loadUsers(ids);
  const list=ov.querySelector('.gm-pick-list');
  if(!ids.length){list.innerHTML='<div class="gm-pick-empty">لا توجد محادثات لإرسال الهدية إليها.</div>';return;}
  list.innerHTML='';
  ids.forEach(uid=>{
    const r=document.createElement('div');r.className='gm-pick-row';
    r.innerHTML=userAvHtml(uid)+'<b>'+esc(gUserName(uid))+'</b>';
    r.onclick=async()=>{
      const a=await clAsk({title:'إرسال الهدية',icon:'gift',body:'إرسال <b>'+esc(K.name)+' #'+g.number+'</b> إلى <b>'+esc(gUserName(uid))+'</b>؟ تصير ملكه ولا ترجع إلك.',buttons:[{text:'إرسال'},{text:'إلغاء',cls:'cl-cancel'}]});
      if(!a||a.i!==0)return;
      try{await transferGift(g,uid);showToast('🎁 وصلت الهدية إلى '+gUserName(uid));ov.remove();}
      catch(e){console.error(e);showToast('تعذر إرسال الهدية');}
    };
    list.appendChild(r);
  });
}

/* زر الرجوع بالهاتف: يغلق نافذة الاختيار أو قائمة الهدية (يُستدعى من معالج الرجوع بالتطبيق) */
window.__gmCloseTop=function(){
  if(document.querySelector('.cl-dlg-ov'))return false;
  const pk=document.querySelector('.gm-pick');
  if(pk){pk.remove();return true;}
  const ov=document.querySelector('.gm-ov:not(.out)');
  if(ov){gmCloseMenu(ov);return true;}
  return false;
};
