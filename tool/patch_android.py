# يضبط توقيع الإصدار (release) بنفس مفتاح تطبيقك الأصلي — يُشغَّل بعد flutter create
import pathlib, re, sys

def die(msg):
    print("::error::" + msg)
    sys.exit(1)


DESUGAR_VER = "2.1.4"

def add_desugaring_kts(g):
    if "isCoreLibraryDesugaringEnabled" not in g:
        if re.search(r'compileOptions\s*\{', g):
            g = re.sub(r'(compileOptions\s*\{)', r'\1\n        isCoreLibraryDesugaringEnabled = true', g, count=1)
        else:
            g = re.sub(r'(\n[ \t]*defaultConfig\s*\{)', '\n    compileOptions {\n        isCoreLibraryDesugaringEnabled = true\n    }\n\\1', g, count=1)
    if "coreLibraryDesugaring(" not in g:
        dep = '    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:' + DESUGAR_VER + '")\n'
        m = re.search(r'^dependencies\s*\{[ \t]*\n', g, re.M)
        if m:
            g = g[:m.end()] + dep + g[m.end():]
        else:
            g += '\ndependencies {\n' + dep + '}\n'
    return g

def add_desugaring_groovy(g):
    if "coreLibraryDesugaringEnabled" not in g:
        if re.search(r'compileOptions\s*\{', g):
            g = re.sub(r'(compileOptions\s*\{)', r'\1\n        coreLibraryDesugaringEnabled true', g, count=1)
        else:
            g = re.sub(r'(\n[ \t]*defaultConfig\s*\{)', '\n    compileOptions {\n        coreLibraryDesugaringEnabled true\n    }\n\\1', g, count=1)
    if "coreLibraryDesugaring '" not in g:
        dep = "    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:" + DESUGAR_VER + "'\n"
        m = re.search(r'^dependencies\s*\{[ \t]*\n', g, re.M)
        if m:
            g = g[:m.end()] + dep + g[m.end():]
        else:
            g += '\ndependencies {\n' + dep + '}\n'
    return g

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
    g = add_desugaring_kts(g)
    kts.write_text(g, encoding="utf-8")
    print("patched build.gradle.kts for release signing + desugaring")
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
    g = add_desugaring_groovy(g)
    grv.write_text(g, encoding="utf-8")
    print("patched build.gradle for release signing + desugaring")
else:
    die("ما لقيت ملف build.gradle للتطبيق")
