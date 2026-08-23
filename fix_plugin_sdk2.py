#!/usr/bin/env python3
"""Fix the afterEvaluate timing error: move the compileSdk override into its own
subprojects block that configures before evaluationDependsOn."""
import sys
F = r"android\build.gradle.kts"
s = open(F, encoding="utf-8", newline="").read().replace("\r\n","\n")

# Remove the broken afterEvaluate we added.
broken = """subprojects {
    project.evaluationDependsOn(":app")
    afterEvaluate {
        extensions.findByType<com.android.build.gradle.BaseExtension>()?.apply {
            compileSdkVersion(36)
        }
    }
}"""
fixed = """subprojects {
    afterEvaluate {
        extensions.findByType<com.android.build.gradle.BaseExtension>()?.apply {
            compileSdkVersion(36)
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}"""
if broken in s:
    s = s.replace(broken, fixed, 1)
    print("OK: moved override to its own block before evaluationDependsOn")
else:
    print("MISS: broken block not found - trying to locate")
    j = s.find("afterEvaluate")
    print(repr(s[j-100:j+200]) if j>=0 else "not found")
    sys.exit(1)

open(F,"w",encoding="utf-8",newline="").write(s.replace("\n","\r\n"))
print("done")
print(open(F, encoding="utf-8").read())
