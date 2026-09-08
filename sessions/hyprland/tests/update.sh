#!/usr/bin/env bash
#
# The update group has to know which tree it is looking at — and say so when it
# is looking at one it cannot update.
#
# ⚠️ THE RULE IT GUARDS IS DERIVED, WHICH IS WHY IT NEEDS GUARDING.
# services/Update.qml finds its repository by resolving `Quickshell.shellDir`
# with `readlink -f` and taking the parent. The obvious version — the parent of
# `shellDir` itself — is wrong on every installed machine, because
# lib/60-shell.sh links ~/.config/quickshell/buchhwin to $REPO/shell and
# `shellDir` hands back the LINK. Measured with a control before it was written.
#
# What makes that worth a permanent check is the shape of the failure: if the
# rule ever breaks, the parent becomes ~/.config/quickshell, which is a real
# directory that is genuinely not a git checkout. So every row in the group
# would say "cannot update from here" — truthfully, about the wrong folder —
# nothing would crash, and no other test would notice.
#
# ⚠️ EVERY TREE IT RUNS AGAINST IS BUILT HERE, including the checkout. Asserting
# against THIS repository would make the result depend on how the machine got
# its copy: the test machine has the tree by rsync and has no .git at all, so a
# check written that way would be red there for a reason that is not a fault.
# Four arrangements, four different correct answers from the same code:
#
#   1  a fresh checkout           isCheckout yes, a commit, a branch, install offered
#   1b the same, with an edit     install REFUSED before bhctl has to refuse it
#   2  a tree with no .git        isRepo yes, isCheckout NO   ← the test machine, and his laptop before `git clone`
#   3  a bare shell folder        isRepo NO                   ← nothing around it at all
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

command -v qs >/dev/null  || { echo "quickshell (qs) not installed"; exit 2; }
command -v git >/dev/null || { echo "git not installed"; exit 2; }

tmp="$(mktemp -d)" || { echo "  could not make a temporary directory"; exit 2; }
[[ -n "$tmp" && "$tmp" == /tmp/* ]] || { echo "  refusing to run against $tmp"; exit 2; }
trap 'rm -rf "$tmp"' EXIT

fails=0
ok()   { printf '  \033[38;5;114mok\033[0m   %s\n' "$1"; }
bad()  { printf '  \033[38;5;203mFAIL\033[0m %s\n' "$1"; fails=$((fails + 1)); }
note() { printf '       %s\n' "$1"; }

val() { grep -m1 "^$1=" "$2" | cut -d= -f2-; }
want() { # want <case> <key> <expected> <file>
    local got; got="$(val "$2" "$4")"
    if [[ "$got" == "$3" ]]; then ok "$1: $2 = $3"
    else bad "$1: $2 — expected '$3', got '$got'"; fi
}
wantset() { # wantset <case> <key> <file>
    local got; got="$(val "$2" "$3")"
    if [[ -n "$got" ]]; then ok "$1: $2 is set ($got)"
    else bad "$1: $2 is empty"; fi
}

run() { # run <shell-dir> <out-file>
    rm -f "$2"
    BUCHHWIN_TOOL=update-check \
    BUCHHWIN_UPDATE_OUT="$2" \
    QT_QPA_PLATFORM=offscreen \
        timeout 60 qs -p "$1" >/dev/null 2>&1
    if [[ ! -f "$2" ]]; then bad "the tool wrote nothing for $1"; return 1; fi
    if grep -q '^timeout=yes' "$2"; then bad "the service never answered for $1"; return 1; fi
    return 0
}

# A tree that looks like this project to Update.qml: a shell folder to be
# launched from, plus the two files it uses to decide "this is the repository"
# rather than "some folder that happens to be above a shell".
maketree() { # maketree <dir>
    mkdir -p "$1/bin"
    cp -a shell "$1/shell"
    cp -a install.sh "$1/install.sh"
    cp -a bin/bhctl "$1/bin/bhctl"
}

# ── 1 · a fresh checkout ────────────────────────────────────────────────────
maketree "$tmp/checkout"
(
    cd "$tmp/checkout" || exit 2
    git init -q -b main
    git -c user.email=t@t -c user.name=t add -A >/dev/null 2>&1
    git -c user.email=t@t -c user.name=t commit -qm "a tree to look at" >/dev/null 2>&1
) || { echo "  could not make a test checkout"; exit 2; }

if run "$tmp/checkout/shell" "$tmp/co.txt"; then
    want    "checkout" isRepo     yes              "$tmp/co.txt"
    want    "checkout" isCheckout yes              "$tmp/co.txt"
    want    "checkout" dirty      0                "$tmp/co.txt"
    want    "checkout" canInstall yes              "$tmp/co.txt"
    want    "checkout" branch     main             "$tmp/co.txt"
    wantset "checkout" commit                      "$tmp/co.txt"
    # ⚠️ THE ONE THAT CATCHES A BROKEN DERIVATION. Every line above stays true
    # if the rule walks up to some OTHER checkout — a parent repository, or a
    # versioned home directory. The path has to be exactly this tree.
    want    "checkout" repoDir    "$tmp/checkout"  "$tmp/co.txt"
fi

# ── 1a · THE SAME CHECKOUT, REACHED THROUGH A SYMLINK ──────────────────────
#
# ⚠️⚠️ THIS IS THE CASE THE WHOLE FILE EXISTS FOR, AND THE FIRST VERSION OF THIS
# TEST DID NOT HAVE IT. Every case above launches from a real path, where
# `readlink -f` is a no-op — so deleting it from Update.qml changed nothing and
# the suite stayed green while the rule it guards was broken. Measured, as a
# control: the derivation was replaced with a plain `printf %s` and all
# twenty-odd lines above still passed.
#
# An installed machine never launches from a real path. lib/60-shell.sh links
# ~/.config/quickshell/buchhwin to $REPO/shell and `qs -c buchhwin` follows it,
# and Quickshell hands back the LINK — measured both ways, from a real directory
# and through a symlink to the same one.
#
# Without `readlink -f`, `repoDir` here would be $tmp — the directory the link
# happens to sit in — which on the real machine is ~/.config/quickshell: a
# folder that exists, is not a checkout, and would make every row in the update
# group say "cannot update from here" about the wrong place. That failure is
# silent, which is why it needs a line that is not.
ln -sfn "$tmp/checkout/shell" "$tmp/link"
if run "$tmp/link" "$tmp/link.txt"; then
    want "through a symlink" shellDir   "$tmp/link"     "$tmp/link.txt"
    want "through a symlink" repoDir    "$tmp/checkout" "$tmp/link.txt"
    want "through a symlink" isCheckout yes             "$tmp/link.txt"
fi

# ── 1b · the same checkout with an uncommitted edit ─────────────────────────
#
# ⚠️ THE REFUSAL BELONGS IN FRONT OF THE BUTTON, not behind it. bhctl update
# already stops on a dirty tree — correctly — but it stops inside a terminal the
# person was just made to open, after a password prompt. Saying it in the row is
# the same refusal one step earlier and costs nothing.
echo "// an edit nobody committed" >> "$tmp/checkout/shell/shell.qml"
if run "$tmp/checkout/shell" "$tmp/dirty.txt"; then
    want "dirty checkout" isCheckout yes "$tmp/dirty.txt"
    want "dirty checkout" canInstall no  "$tmp/dirty.txt"
    if [[ "$(val dirty "$tmp/dirty.txt")" -gt 0 ]]; then
        ok "dirty checkout: the edit is counted ($(val dirty "$tmp/dirty.txt"))"
    else
        bad "dirty checkout: the uncommitted file was not seen"
    fi
fi

# ── 2 · the same tree with no history: what the test machine really is ──────
#
# ⚠️ AND IT MUST NOT FIND SOME OTHER REPOSITORY. /tmp is not inside this
# checkout, so `git rev-parse` walks up to the mount point and stops — the same
# thing that happens in ~/repo on the test machine. `isCheckout=yes` here would
# mean the derivation has escaped the tree it was pointed at.
maketree "$tmp/copied"
if run "$tmp/copied/shell" "$tmp/copied.txt"; then
    want "copied tree" isRepo     yes            "$tmp/copied.txt"
    want "copied tree" isCheckout no             "$tmp/copied.txt"
    want "copied tree" canInstall no             "$tmp/copied.txt"
    want "copied tree" repoDir    "$tmp/copied"  "$tmp/copied.txt"
    if grep -q '^status=.*not a git checkout' "$tmp/copied.txt"; then
        ok "copied tree: the row says why"
    else
        bad "copied tree: status does not explain itself — $(val status "$tmp/copied.txt")"
    fi
fi

# ── 3 · a shell folder with no repository around it ─────────────────────────
mkdir -p "$tmp/bare"
cp -a shell "$tmp/bare/shell"
if run "$tmp/bare/shell" "$tmp/bare.txt"; then
    want "bare" isRepo     no "$tmp/bare.txt"
    want "bare" isCheckout no "$tmp/bare.txt"
    want "bare" canInstall no "$tmp/bare.txt"
fi

# ── 4 · this machine, when it happens to be a checkout ──────────────────────
#
# Extra rather than required, and it says which it is. On a development machine
# it proves the rule against the real thing; on the test machine, where the tree
# arrived by rsync, there is nothing here to prove it against and skipping is
# the honest answer rather than a red line about the machine.
if git rev-parse --git-dir >/dev/null 2>&1; then
    if run shell "$tmp/here.txt"; then
        want "this tree" repoDir    "$PWD" "$tmp/here.txt"
        want "this tree" isCheckout yes    "$tmp/here.txt"
    fi
else
    note "skipped: this tree is not a git checkout, so there is nothing to compare against here"
fi

# ── 5 · the install button goes through the configured terminal ─────────────
#
# ⚠️ A TEXT CHECK, and it says so: opening a terminal cannot be run headlessly.
# What it holds shut is the regression that costs nothing to make and everything
# to notice — hard-coding "kitty", so the button stops working the day
# `programs.terminal` changes and nothing says why.
if grep -q 'Config.program("@terminal")' shell/services/Update.qml; then
    ok "install: resolves the terminal through Config.program"
else
    bad "install: does not go through Config.program(\"@terminal\")"
fi
if grep -qE '"(kitty|alacritty|foot|gnome-terminal)"' shell/services/Update.qml; then
    bad "install: names a terminal outright instead of asking the config"
else
    ok "install: no terminal named in the code"
fi
# install.sh restarts buchhwin-shell, so a child of the shell would be killed by
# the very update it is running. See the note on install().
if grep -q 'Quickshell.execDetached' shell/services/Update.qml; then
    ok "install: detached, so the restart cannot kill the terminal"
else
    bad "install: not detached — install.sh restarts the shell and would kill it"
fi

# ── 6 · nothing runs on its own ─────────────────────────────────────────────
#
# The service is allowed to shell out to git only because it never does it
# unasked. A Timer or a `running: true` in here is a git process on an idle
# laptop — the fault this project deleted the brightness poll for.
if grep -qE '^\s*(running:\s*true|interval:)' shell/services/Update.qml; then
    bad "idle: something in Update.qml runs by itself"
else
    ok "idle: nothing runs until it is asked"
fi

(( fails == 0 )) || exit 1
exit 0
