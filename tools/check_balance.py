import sys
from collections import defaultdict
path = sys.argv[1]
stack = []
pairs = {'(':')','[':']','{':'}'}
openers = set(pairs.keys())
closers = {v:k for k,v in pairs.items()}
with open(path, 'r', encoding='utf-8') as f:
    for i,line in enumerate(f, start=1):
        for ch in line:
            if ch in openers:
                stack.append((ch,i))
            elif ch in closers:
                if stack and stack[-1][0] == closers[ch]:
                    stack.pop()
                else:
                    print(f"Unmatched closer {ch!r} at line {i}")
                    sys.exit(0)
if stack:
    for op,line in stack:
        print(f"Unmatched opener {op!r} at line {line}")
    sys.exit(1)
print('All balanced')
