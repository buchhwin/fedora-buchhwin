#!/usr/bin/env bash
#
# Every icon name the shell uses must exist in the icon font.
#
# `text: "logout"` is valid QML and renders happily — as the letters. Fedora
# ships "Material Icons Round", the older set, while half the names anyone
# reaches for come from "Material Symbols". That difference shipped a missing
# icon and a wrong one in the session menu before this test existed.
#
# The names are collected from the source rather than listed here, so adding an
# icon cannot forget to add it to a list.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

command -v qs >/dev/null || { echo "quickshell (qs) not installed"; exit 2; }

names="$(mktemp)"
trap 'rm -f "$names"' EXIT

# Two shapes, and only these two — a bare `text:` is usually a sentence.
#
#   icon: "name"                    (LevelRow, the session menu's data)
#   Icon { … text: "name" … }       possibly spanning several lines
#
# The first attempt grepped every `text:` in ui/ and duly reported that
# "ganztägig" and "heute" are not in the icon font  english-ok: names a past bug. They are not meant to be.
# ⚠️ mapfile, not an unquoted $(find …). Word splitting is what makes the bare
# form work at all, and it breaks the moment a path contains a space. SC2046
# reports it, and is right to.
#
# (The reason for this wording: a comment line that BEGINS with the linter's
# name is read as a directive, and this one broke the job it was fixing.)
mapfile -t qml < <(find shell/ui shell/services -name '*.qml')
(( ${#qml[@]} )) || { echo '  no QML files found'; exit 1; }

awk '
  # ⚠️ A COMMENT IS DOCUMENTATION, NOT A VALUE — the same exemption
  # tests/no-literals.sh makes, and it is here because this check tripped over a
  # comment explaining this check. QuickSettings.qml warns the next reader that
  # `Icon { text: … }` lines are scraped, and quoting the pattern in order to
  # warn about it made the scraper ask the font for a glyph called "sound".
  /^[[:space:]]*\/\// { next }

  # Everything between `icon:` and the next `word:` on the same line. Taking
  # every quoted word instead swept up the neighbouring id: and label: values
  # from the session menu, and duly reported that "Ausschalten" is not a glyph.  # english-ok: the label that caused it, quoted
  function emit(line,   rest) {
      rest = line
      # Stop at the next property name, if there is one.
      if (match(rest, /[A-Za-z_]+[[:space:]]*:/))
          rest = substr(rest, 1, RSTART - 1)
      while (match(rest, /"[A-Za-z0-9_]+"/)) {
          print substr(rest, RSTART + 1, RLENGTH - 2)
          rest = substr(rest, RSTART + RLENGTH)
      }
  }
  # `icon:` and any `iconNames: [...]` list. The list form exists because a
  # service that RETURNS icon names keeps them inside a function, where no
  # scan can see them — the weather icons were invisible here at first, and a
  # tripwire that misses half the names reads as full coverage.
  /(^|[^a-zA-Z])icon:/ {
      emit(substr($0, index($0, "icon:") + 5))
      # ⚠️⚠️ A TERNARY CONTINUES ON THE NEXT LINE, AND THAT IS WHERE TWO DEAD
      # ICONS HID FOR A WEEK. `icon:` opened a three-way choice whose second
      # and third arms sat on their own lines:
      #
      #     icon: … === "power-saver" ? "eco"
      #         : … === "performance" ? "bolt"        <- never scraped
      #         : "balance"                           <- never scraped
      #
      # `bolt` and `balance` are not in Material Icons Round — measured at 300
      # and 600 px against ~70 for a real glyph — so the power tile drew nothing
      # in its DEFAULT state, while this check reported "all 86 icon names
      # resolve". It was right about every name it saw. It never saw these.
      inTernary = ($0 ~ /\?[[:space:]]*"[A-Za-z0-9_]+"[[:space:]]*$/)
      next
  }
  # The continuation arms: a line that begins with `:` and is nothing but a
  # choice. Deliberately narrow — a broader rule swept up label: values once
  # already and asked the font for a glyph that was a button label.
  inTernary && /^[[:space:]]*:[[:space:]]*/ {
      # ⚠️ ONLY WHAT COMES AFTER THE LAST `?`. The condition of a ternary arm
      # carries quoted strings too — `… activeProfile === "performance" ? …` —
      # and taking every quoted word on the line duly reported that
      # "performance" is not a glyph. Same shape as the button-label finding
      # the emit() comment above records; the fix is the same: narrow the window
      # rather than add an exception.
      arm = substr($0, index($0, ":") + 1)
      while (match(arm, /\?/))
          arm = substr(arm, RSTART + 1)
      emit(arm)
      inTernary = ($0 ~ /\?[[:space:]]*"[A-Za-z0-9_]+"[[:space:]]*$/)
      next
  }
  { inTernary = 0 }
  /(^|[^a-zA-Z])iconNames:/ {
      line = substr($0, index($0, "iconNames:") + 10)
      while (match(line, /"[A-Za-z0-9_]+"/)) {
          print substr(line, RSTART + 1, RLENGTH - 2)
          line = substr(line, RSTART + RLENGTH)
      }
  }
  # Inside an Icon { } block, a text: is an icon name.
  #
  # ⚠️ The opening line counts too. Skipping it with `next` lost every
  # single-line `Icon { text: "check" }` — seven of them — and the test then
  # cheerfully reported that all the remaining names resolve.
  {
      if (!inicon && match($0, /(^|[^A-Za-z])Icon[[:space:]]*\{/)) {
          inicon = 1
          depth = 0
          rest = substr($0, RSTART + RLENGTH - 1)
      } else if (inicon) {
          rest = $0
      } else {
          rest = ""
      }
      if (inicon && rest != "") {
          n = gsub(/\{/, "{", rest); depth += n
          n = gsub(/\}/, "}", rest); depth -= n
          if (rest ~ /(^|[^a-zA-Z])text:/)
              emit(substr(rest, index(rest, "text:") + 5))
          if (depth <= 0) inicon = 0
      }
  }
' "${qml[@]}" | sort -u > "$names"

if [[ ! -s "$names" ]]; then
    echo "  found no icon names to check — has the markup changed?"
    exit 1
fi

# ⚠️⚠️ THE SECOND FONT, AND WITHOUT THIS THE CHECK WAS BLIND TO IT BY DESIGN.
# The scraper above matches `Icon {` with a non-letter in front, so `FluentIcon`
# never enters it — correctly, because those glyphs are not in Material Icons
# Round and would all be reported missing. But that also meant nothing measured
# them at all: three status symbols in the notch with no check behind them, which
# is exactly the blind spot B14 was lost to.
#
# ⚠️ SCRAPED AS CODE POINTS, NOT AS NAMES, because that is what they are. Fluent
# has no ligatures — a glyph is `"\uE99A"` — so the corpus is every four-digit
# escape in the UI. That is broader than "inside a FluentIcon block" on purpose:
# the battery levels live in an ARRAY beside the component, and a rule tied to
# the block would have missed all eleven of them.
#
# ⚠️ Control characters are not glyphs. services/Theming.qml writes \u0000 and
# \u0001 into a binary header; anything below U+E000 (the private use area these
# fonts live in) is not an icon and is dropped rather than reported.
fluent="$(grep -rhoE '\\u[0-9A-Fa-f]{4}' shell/ui 2>/dev/null \
          | sed 's/^\\u//' | tr 'a-f' 'A-F' | sort -u \
          | awk 'strtonum("0x" $0) >= 57344')"
fluent_list="$(printf '%s' "$fluent" | tr '\n' ',' | sed 's/,$//')"

rm -f /tmp/buchhwin-icon-check.txt
BUCHHWIN_ICONS="$names" BUCHHWIN_FLUENT="$fluent_list" \
BUCHHWIN_TOOL=icon-check QT_QPA_PLATFORM=offscreen \
    timeout 60 qs -p shell >/dev/null 2>&1

[[ -f /tmp/buchhwin-icon-check.txt ]] || { echo "  no output"; exit 1; }

sed -e 's/^  ok /  \x1b[38;5;114mok\x1b[0m /' \
    -e 's/^  FAIL /  \x1b[38;5;203mFAIL\x1b[0m /' \
    -e 's/^  SKIP /  \x1b[38;5;245mSKIP\x1b[0m /' /tmp/buchhwin-icon-check.txt

# ⚠️ A SKIPPED FONT IS NOT A PASS. If the Fluent family is not installed on this
# machine the tool says so instead of measuring, and this suite reports "cannot
# run here" rather than green — the same distinction every other suite makes
# with exit 2, and the one that stops an uninstalled dependency reading as
# coverage.
if grep -q '^  SKIP' /tmp/buchhwin-icon-check.txt; then
    grep '^  SKIP' /tmp/buchhwin-icon-check.txt
    exit 2
fi

grep -q '^  FAIL' /tmp/buchhwin-icon-check.txt && exit 1
exit 0
