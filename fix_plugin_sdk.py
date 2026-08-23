#!/usr/bin/env python3
"""Force all plugin subprojects to compileSdk 36 (fixes file_picker module)."""
import sys
F = r"android\build.gradle.kts"
s = open(F, encoding="utf-8", newline="").read().replace("\r\n","\n")

if "compileSdkVersion(36)" in s or "compileSdk = 36" in s:
    print("already patched"); sys.exit()

# Add an afterEvaluate override into the existing evaluationDependsOn subprojects block.
old = """subprojects {
    project.evaluationDependsOn(":app")
}"""
new = """subprojects {
    project.evaluationDependsOn(":app")
    afterEvaluate {
        extensions.findByType<com.android.build.gradle.BaseExtension>()?.apply {
            compileSdkVersion(36)
        }
    }
}"""
if old in s:
    s = s.replace(old, new, 1)
    print("OK: subproject compileSdk 36 override added")
else:
    print("MISS: subprojects block not matched"); sys.exit(1)

open(F,"w",encoding="utf-8",newline="").write(s.replace("\n","\r\n"))
c = open(F, encoding="utf-8").read()
print("verify:", "OK" if "compileSdkVersion(36)" in c else "MISS")
