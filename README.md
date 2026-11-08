# بابيلون — نسخة Flutter

نفس الباك إند بالضبط (Firebase مشروع `aj-chat-df534` + خادم Vercel `/api/*`)، فالحسابات
والمحادثات والرسائل الحالية تشتغل مباشرة بدون ترحيل بيانات.

## التشغيل
```bash
bash setup.sh          # يولّد android/ios ويثبّت الحزم
# انسخ app/google-services.json من المشروع القديم إلى android/app/
flutter run
```
في `android/settings.gradle(.kts)` و`android/app/build.gradle(.kts)` أضف إضافة
`com.google.gms.google-services` (أو بدلاً من ذلك شغّل `flutterfire configure`
وهو يعملها تلقائياً ويولّد `firebase_options.dart` جديداً لـ iOS).

### أذونات `android/app/src/main/AndroidManifest.xml`
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```
وفي `android/app/build.gradle` اجعل `minSdk` = 23 على الأقل.

## ما تم نقله
| الميزة | الحالة |
|---|---|
| تسجيل الدخول بالبريد أو اليوزر (`/api/auth`) / إنشاء حساب / استعادة كلمة المرور | ✅ |
| قائمة المحادثات الفردية مع آخر رسالة و«يكتب الآن» وحالة الاتصال | ✅ |
| البحث عن مستخدم بيوزر وبدء محادثة (`chatId = uid1__uid2` مرتّبة) | ✅ |
| إرسال نص / صورة / رسالة صوتية، رد، تعديل، حذف، تفاعلات إيموجي، علامات القراءة | ✅ |
| إشعارات Push (حفظ `fcmToken`/`fcmTokens` + `/api/index`) | ✅ |
| القصص (نشر صورة، حد 3، مشاهدة، حذف) | ✅ (صور فقط) |
| الملف الشخصي (صورة، اسم، نبذة) وملف الآخرين | ✅ |
| الحظر وقائمة المحظورين | ✅ |
| الوضع الداكن/الفاتح، واجهة عربية RTL | ✅ |

## غير منقول بعد (مراحل لاحقة)
- المكالمات (`calls/calls.js`، WebRTC → حزمة `flutter_webrtc` + `/api/turn`)
- الهدايا والنجوم (`gifts/` — مجسمات 3D)
- الملصقات (`stickers/`)
- المجموعات، فيديو القصص، البحث داخل المحادثة، لوحة المطور
- شاشة التحقق من البريد، بوابة التحديث (`update-gate.js`)، الوضع بدون إنترنت الإضافي

> الصور والصوت تُخزَّن كـ data-URL داخل Firestore تماماً مثل نسخة الويب، لذلك
> الرسائل متوافقة في الاتجاهين بين التطبيقين.
>
> مجلد `api/` (Vercel) يبقى كما هو ولا يتغيّر.
