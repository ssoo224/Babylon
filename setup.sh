#!/usr/bin/env bash
# شغّله مرة واحدة داخل مجلد المشروع:  bash setup.sh
set -e
# يولّد مجلدات android/ios بنفس الـ applicationId القديم (com.babylon.chat)
flutter create --org com.babylon --project-name chat --platforms=android,ios . >/dev/null
# نعيد اسم الحزمة إلى babylon_chat (flutter create يتجاوز pubspec الموجود، نتأكد فقط)
sed -i 's/^name: .*/name: babylon_chat/' pubspec.yaml
flutter pub get
echo
echo "الآن: ضع android/app/google-services.json (موجود في المشروع القديم: app/google-services.json)"
echo "ثم أضف الأذونات المذكورة في README.md إلى AndroidManifest.xml"
echo "ثم شغّل: flutter run"
