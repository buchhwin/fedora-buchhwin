#!/usr/bin/env python3
"""Small dependency-free structural QML/JS delimiter check for CI."""
from __future__ import annotations

import re
import sys
from pathlib import Path

PAIRS = {')': '(', ']': '[', '}': '{'}
OPEN = set(PAIRS.values())
CLOSE = set(PAIRS)


def check(path: Path) -> list[str]:
    text = path.read_text(encoding='utf-8')
    stack: list[tuple[str, int, int]] = []
    errors: list[str] = []
    i = 0
    line = 1
    col = 0
    quote: str | None = None
    escaped = False
    line_comment = False
    block_comment = False

    while i < len(text):
        ch = text[i]
        nxt = text[i + 1] if i + 1 < len(text) else ''
        col += 1

        if ch == '\n':
            line += 1
            col = 0
            line_comment = False
            i += 1
            continue

        if line_comment:
            i += 1
            continue

        if block_comment:
            if ch == '*' and nxt == '/':
                block_comment = False
                i += 2
                col += 1
            else:
                i += 1
            continue

        if quote is not None:
            if escaped:
                escaped = False
            elif ch == '\\':
                escaped = True
            elif ch == quote:
                quote = None
            i += 1
            continue

        if ch == '/' and nxt == '/':
            line_comment = True
            i += 2
            col += 1
            continue
        if ch == '/' and nxt == '*':
            block_comment = True
            i += 2
            col += 1
            continue
        if ch in ('"', "'", '`'):
            quote = ch
            i += 1
            continue

        if ch in OPEN:
            stack.append((ch, line, col))
        elif ch in CLOSE:
            if not stack or stack[-1][0] != PAIRS[ch]:
                expected = PAIRS[ch]
                errors.append(f'{path}:{line}:{col}: unmatched {ch!r}; expected opener {expected!r}')
            else:
                stack.pop()
        i += 1

    if quote is not None:
        errors.append(f'{path}: unterminated string literal')
    if block_comment:
        errors.append(f'{path}: unterminated block comment')
    for token, token_line, token_col in reversed(stack):
        errors.append(f'{path}:{token_line}:{token_col}: unclosed {token!r}')
    return errors


def sanitize(text: str) -> str:
    """Blank out string literals and comments, preserving offsets and lines."""
    out = list(text)
    i = 0
    quote: str | None = None
    escaped = False
    line_comment = False
    block_comment = False
    while i < len(text):
        ch = text[i]
        nxt = text[i + 1] if i + 1 < len(text) else ''
        if ch == '\n':
            line_comment = False
            i += 1
            continue
        if line_comment or block_comment:
            out[i] = ' '
            if block_comment and ch == '*' and nxt == '/':
                out[i + 1] = ' '
                block_comment = False
                i += 2
                continue
            i += 1
            continue
        if quote is not None:
            out[i] = ' '
            if escaped:
                escaped = False
            elif ch == '\\':
                escaped = True
            elif ch == quote:
                quote = None
            i += 1
            continue
        if ch == '/' and nxt == '/':
            out[i] = out[i + 1] = ' '
            line_comment = True
            i += 2
            continue
        if ch == '/' and nxt == '*':
            out[i] = out[i + 1] = ' '
            block_comment = True
            i += 2
            continue
        if ch in ('"', "'", '`'):
            out[i] = ' '
            quote = ch
            i += 1
            continue
        i += 1
    return ''.join(out)


ELEMENT = re.compile(r'\b(Text|TextInput)\s*\{')


def check_fonts(path: Path) -> list[str]:
    """Every visible text element must use the project's Nerd Font.

    Qt falls back to its default UI font silently, so a forgotten
    `font.family` is only visible as one element looking subtly wrong.
    """
    text = path.read_text(encoding='utf-8')
    clean = sanitize(text)
    errors: list[str] = []
    for match in ELEMENT.finditer(clean):
        start = match.end() - 1
        depth = 0
        end = len(clean)
        for i in range(start, len(clean)):
            if clean[i] == '{':
                depth += 1
            elif clean[i] == '}':
                depth -= 1
                if depth == 0:
                    end = i
                    break
        if 'font.family' not in clean[start:end]:
            line = text.count('\n', 0, match.start()) + 1
            errors.append(f'{path}:{line}: {match.group(1)} without font.family')
    return errors


def main() -> int:
    paths = [Path(p) for p in sys.argv[1:]]
    if not paths:
        paths = sorted(Path('config/quickshell/buchhwin').glob('*.qml'))
    errors: list[str] = []
    for path in paths:
        errors.extend(check(path))
    for path in paths:
        errors.extend(check_fonts(path))
    if errors:
        print('\n'.join(errors), file=sys.stderr)
        return 1
    print(f'QML structure and fonts OK ({len(paths)} files).')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
