#!/usr/bin/env python3
"""Fix the invalid Icons.transition_enterexit -> a real Material icon."""
import sys
F = r"lib\editor\ui\editor_screen.dart"
s = open(F, encoding="utf-8", newline="").read().replace("\r\n","\n")

if "transition_enterexit" not in s:
    print("already fixed"); sys.exit()

# transition_enterexit was likely meant for a transition/effect. Use a valid
# icon. 'Icons.transition_fade' isn't valid either; use 'Icons.auto_awesome'
# or 'Icons.movie_filter'. Context is probably transitions -> use 'Icons.swap_horiz'
# Safest generic: Icons.animation
s = s.replace("Icons.transition_enterexit", "Icons.animation")
open(F,"w",encoding="utf-8",newline="").write(s.replace("\n","\r\n"))
print("fixed: transition_enterexit -> animation")
c = open(F, encoding="utf-8").read()
print("verify:", "OK" if "transition_enterexit" not in c else "STILL THERE")
