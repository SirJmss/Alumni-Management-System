from collections import deque
import sys
p = {'(':')','[':']','{':'}'}
inv = {v:k for k,v in p.items()}
path = r"d:\Alumni-Management-System\lib\features\event\presentation\screens\event_list_screen.dart"
with open(path, encoding='utf-8') as f:
    s = f.read()
stack = []
line = 1
col = 0
for i,ch in enumerate(s):
    if ch == '\n':
        line += 1
        col = 0
        continue
    col += 1
    if ch in p:
        stack.append((ch,line,col))
    elif ch in inv:
        if not stack:
            print(f"Unmatched closing {ch} at line {line} col {col}")
            sys.exit(0)
        last, lline, lcol = stack.pop()
        if inv[ch] != last:
            print(f"Mismatched {last} opened at {lline}:{lcol} closed by {ch} at {line}:{col}")
            sys.exit(0)
if stack:
    last, lline, lcol = stack[-1]
    print(f"Unclosed {last} opened at {lline}:{lcol}")
else:
    print("All brackets balanced")
