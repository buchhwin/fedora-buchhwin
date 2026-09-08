#!/usr/bin/env bash
#
# Every setting in shell.json is read by something.
#
# ⚠️ THIS IS THE AXIS THAT FOUND A KEY I HAD ORPHANED AN HOUR EARLIER.
# `notch.expandedHeight` sized the covers in the wallpaper picker; rewriting that
# page as a grid (commit 3added8) took its last reader with it. Nothing said a
# word — the key stayed in Config.qml, stayed in shell.json, and simply stopped
# doing anything. Somebody sets it, nothing happens, and there is no error to
# search for.
#
# It is the mirror of the debt this project already names in the other
# direction — btop was themed with no way to reach it — and it was the direct
# prerequisite for the settings window, where every one of its 123 rows is a new
# reader. A row that writes a key nothing reads is a switch that lies.
#
# ⚠️ THE OTHER HALF IS tests/setting-rows.sh: this one asks whether anything
# READS a setting, that one whether anything OFFERS it. Neither is the other,
# and neither can borrow the other's extraction — see the note there about leaf
# names, because `enabled` exists four times and `monitors` five.
#
# (The number said "~80" for a while. It was 126 when anyone counted.)
#
# ⚠️ WHAT COUNTS AS A READER, and why it is not just `Config.<section>.<key>`:
#
#   * `programs.terminal` and its five siblings are never named directly. They
#     are resolved through `Config.program("@terminal")` — a STRING lookup, which
#     no search for the identifier can see. Six false positives on the first run.
#   * generators read some keys through a local alias (`var l = Config.look`),
#     so `l.gapsIn` is a real reader of `look.gapsIn`.
#
# So a key counts as read when its NAME appears anywhere outside Config.qml —
# after a dot, in a string, in a fingerprint. That is deliberately generous: this
# check exists to find keys that appear NOWHERE, which is unambiguous. A tighter
# rule would spend its life explaining itself.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

file=shell/config/Config.qml
printf '  %-34s ' "every setting has a reader"

# Where a reader could be. Not the plan files or the docs — a key mentioned only
# in prose is exactly the case this is looking for.
# ⚠️ `--others --exclude-standard` IS NOT OPTIONAL. Plain `git ls-files` lists
# TRACKED files only, so a brand-new file — the most likely place for a mistake
# ⚠️ AND dotfiles/ IS IN THE LIST SINCE 10.08.2026, because a reader does not
# have to be QML. `fetch.onNewTerminal` is read by dotfiles/zsh/zshrc — that is
# where the decision belongs, since it is the shell that would do the calling —
# and this check reported it as a key nothing reads. It was right to look and
# wrong about where: a generated dotfile is as much a reader as a service is.
#
# to be — is silently left out. Found on 07.08.2026 when a new shell/common/
# singleton became the sole reader of four settings and key-readers.sh reported
# all four as having none: the advice it printed was "delete the key", which
# would have deleted four working settings. Untracked-but-not-ignored is the
# corpus that matches what is actually on disk.
readers=$(git ls-files --cached --others --exclude-standard \
                 'shell/*.qml' 'shell/**/*.qml' 'bin/*' 'lib/*.sh' 'install.sh' \
                 'dotfiles/**/*' 2>/dev/null)
[[ -n "$readers" ]] || readers=$(find shell bin lib dotfiles -type f \( -name '*.qml' -o -name '*.sh' -o -path 'bin/*' -o -path 'dotfiles/*' \) 2>/dev/null)
[[ -n "$readers" ]] || { echo "found no files to search — not a checkout?"; exit 2; }

# Everything except Config.qml itself: a key referring to itself is not a reader.
corpus=$(mktemp)
# ⚠️ COMMENT-ONLY LINES ARE STRIPPED, and that is the difference between this
# check working and merely passing. `notch.expandedHeight` lost its last real
# reader when the wallpaper picker became a grid — and it did NOT show up here,
# because NotchContent.qml still discusses it in prose. A name explained in a
# comment is not a name anybody reads.
#
# Whole comment lines only. A trailing `// …` after code stays in, because a key
# named beside a line of code is almost always named BY that line as well, and
# cutting those would start inventing orphans.
for f in $readers; do
    [[ "$f" == "$file" ]] && continue
    sed -E 's@^[[:space:]]*//.*$@@' "$f"
done > "$corpus" 2>/dev/null

orphans=""
while read -r key; do
    [[ -z "$key" ]] && continue
    # ⚠️ A LEADING UNDERSCORE MEANS PRIVATE, and private is not a setting.
    # `_failed` and friends are Config's own bookkeeping; they never reach
    # shell.json and there is nobody outside to read them.
    [[ "$key" == _* ]] && continue
    grep -qw -- "$key" "$corpus" && continue
    # ⚠️ AND `@name` COUNTS, even inside Config.qml. The program references live
    # in `defaultBinds`, which is IN Config.qml — so excluding that file from the
    # corpus made `programs.fileManager` and `programs.imageViewer` look dead
    # when `Mod+E` binds `@fileManager` three hundred lines further down. The
    # generator resolves those at build time; they are readers.
    grep -q -- "@$key\b" "$file" && continue
    orphans+="$key"$'\n'
done < <(grep -oE "^[[:space:]]+property (list<[a-z]+>|[a-z]+) [a-zA-Z_]+:" "$file" \
         | awk '{print $NF}' | tr -d ':' | sort -u)

rm -f "$corpus"

if [[ -z "$orphans" ]]; then
    printf '\033[38;5;114mok\033[0m\n'
    exit 0
fi

printf '\033[38;5;203mfound\033[0m\n'
while read -r key; do
    [[ -z "$key" ]] && continue
    printf '      %s\n' "$key"
    grep -nE "property .* $key:" "$file" | sed 's/^/        /'
done <<< "${orphans%$'\n'}"
cat <<'WHY'

  Nothing outside shell/config/Config.qml mentions these. They are still written
  to shell.json, still shown by anything that lists settings, and they do
  nothing at all — a switch that lies rather than one that is missing.

  Two ways out, and the first is usually right:
    * give it back its reader, if the behaviour is still wanted
    * delete the key AND add a migration step, because it is already sitting in
      somebody's shell.json

  Do not silence this by mentioning the name in a comment. The check treats any
  occurrence as a reader on purpose — being generous is what keeps it free of
  false alarms — and that trust is the whole of its value.
WHY
exit 1
