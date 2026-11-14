# يضبط توقيع الإصدار (release) بنفس مفتاح تطبيقك الأصلي — يُشغَّل بعد flutter create
import pathlib, re, sys

def die(msg):
    print("::error::" + msg)
    sys.exit(1)

kts = pathlib.Path("android/app/build.gradle.kts")
grv = pathlib.Path("android/app/build.gradle")

if kts.exists():
    g = kts.read_text(encoding="utf-8")
    if 'create("release")' in g:
        print("already patched"); sys.exit(0)
    block = '''    signingConfigs {
        create("release") {
            storeFile = file(System.getenv("KS_FILE") ?: "release.jks")
            storePassword = System.getenv("KS_PASS")
            keyAlias = "babylon"
            keyPassword = System.getenv("KS_PASS")
        }
    }

    // فحص Lint ينهار داخلياً مع بعض الحزم، نعطّله لنسخة الإصدار
    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }

'''
    m = re.search(r'^[ \t]*buildTypes\s*\{', g, re.M)
    if not m:
        die("ما لقيت buildTypes داخل build.gradle.kts")
    g = g[:m.start()] + block + g[m.start():]
    if 'signingConfigs.getByName("debug")' not in g:
        die("ما لقيت signingConfig الافتراضي للإصدار")
    g = g.replace('signingConfigs.getByName("debug")', 'signingConfigs.getByName("release")', 1)
    kts.write_text(g, encoding="utf-8")
    print("patched build.gradle.kts for release signing")
elif grv.exists():
    g = grv.read_text(encoding="utf-8")
    block = '''    signingConfigs {
        release {
            storeFile file(System.getenv("KS_FILE") ?: "release.jks")
            storePassword System.getenv("KS_PASS")
            keyAlias "babylon"
            keyPassword System.getenv("KS_PASS")
        }
    }

    lint {
        checkReleaseBuilds false
        abortOnError false
    }

'''
    m = re.search(r'^[ \t]*buildTypes\s*\{', g, re.M)
    if not m:
        die("ما لقيت buildTypes داخل build.gradle")
    g = g[:m.start()] + block + g[m.start():]
    g = re.sub(r'signingConfig\s+signingConfigs\.debug', 'signingConfig signingConfigs.release', g, count=1)
    grv.write_text(g, encoding="utf-8")
    print("patched build.gradle for release signing")
else:
    die("ما لقيت ملف build.gradle للتطبيق")
