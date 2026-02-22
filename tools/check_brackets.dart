import 'dart:io';

void main() {
  final path = r'd:\Alumni-Management-System\lib\features\event\presentation\screens\event_list_screen.dart';
  final s = File(path).readAsStringSync();
  final pairs = {'(': ')', '[': ']', '{': '}'};
  final inv = {')': '(', ']': '[', '}': '{'};
  final stack = <MapEntry<String,int>>[]; // char,line*1000+col
  int line = 1, col = 0;
  for (int i = 0; i < s.length; i++) {
    final ch = s[i];
    if (ch == '\n') { line++; col = 0; continue; }
    col++;
    if (pairs.containsKey(ch)) {
      stack.add(MapEntry(ch, line*1000 + col));
    } else if (inv.containsKey(ch)) {
      if (stack.isEmpty) { print('Unmatched closing $ch at $line:$col'); return; }
      final last = stack.removeLast();
      if (last.key != inv[ch]) { print('Mismatched ${last.key} opened at ${last.value~/1000}:${last.value%1000} closed by $ch at $line:$col'); return; }
    }
  }
  if (stack.isNotEmpty) {
    final last = stack.last;
    print('Unclosed ${last.key} opened at ${last.value~/1000}:${last.value%1000}');
  } else {
    print('All brackets balanced');
  }
}
