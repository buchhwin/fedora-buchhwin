#!/usr/bin/env bash
#
# Nothing private about the person who owns this machine may be in a public
# repository — and that includes the test lab.
#
# ⚠️⚠️ THIS EXISTS BECAUSE THE PREVIOUS GUARD HAD HOLES AND THEY WERE USED.
# `.github/workflows/ci.yml` carried four patterns; a sweep on 10.08.2026 found
# what they missed:
#
#   * `/home/[a-z]+/` required a TRAILING SLASH, so the line
#     "…and /home/<user> is drwx------…" in packages/dnf-desktop.txt walked
#     straight past it. The commit that added the guard names that exact string
#     as a near-miss, and then shipped the file it was in.
#   * A home town and its coordinates sat in a test fixture and two comments —
#     in 170 commits. Not an address, not a password: the place he lives.
#   * A password in plain text (`user`/`user` for the lab VM) rode along in 41
#     commits, because "it is only the test VM" felt like a reason.
#   * Hostnames (`*.fritz.box`), a hypervisor name, VM numbers and the name of
#     an ssh wrapper were never looked for at all.
#
# ⚠️ AND THE OLD GUARD COULD ONLY EVER SEE THE CHECKED-OUT TREE. History is
# public too. This script checks the tree; `git log -p` is checked by the same
#
# ⚠️ THE RULE THIS ENFORCES, given on 10.08.2026 and meant to stand: addresses,
# passwords and anything else private are never published — not even from a test
# VM. A published secret is a burnt secret even when it only ever guarded a
# throwaway machine.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

fail=0
red=$'\e[38;5;203m'; green=$'\e[38;5;114m'; off=$'\e[0m'
bad() { printf '  %sFAIL%s %s\n' "$red" "$off" "$1"; fail=1; }

# The files a check like this must look at: everything git tracks, plus anything
# new that is not ignored. ⚠️ `git ls-files` answers with NOTHING outside a
# checkout — and tests/english.sh was silently checking zero files for exactly
# that reason — so `find` is the fallback and the count is asserted below.
#
# ⚠️⚠️ `--others --exclude-standard` IS THE HALF THE COMMENT ABOVE ALREADY
# CLAIMED. Plain `git ls-files` lists TRACKED files only, so a brand-new file was
# invisible to this check — and the run that matters is the one before the
# commit, which is exactly when a new file is untracked. A secret would have
# been caught the day AFTER it was added, by which point it is in the history
# and taking it out means rewriting one. This repository has already had its
# history rewritten once to get a password out of it; that is what
# tests/update-diverged.sh is about.
#
# Found by tests/tripwires.sh: the mutation put an address into a new document
# and this file reported the repository clean. Two years of "everything git
# tracks, plus anything new" sitting above code that did the first half.
mapfile -t files < <(
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        git ls-files --cached --others --exclude-standard
    else
        find . -type f -not -path './.git/*' -not -path './node_modules/*' | sed 's|^\./||'
    fi
)

if (( ${#files[@]} < 50 )); then
    bad "only ${#files[@]} files to scan — this check is not looking at the repository"
    exit 1
fi

# ---------------------------------------------------------------- the patterns
#
# Each is `name|regex|why`. ⚠️ Every one of them is here because it was FOUND,
# not because it seemed prudent.
#
# ⚠️ EXAMPLE RANGES ARE ALLOWED AND NAMED: 127.0.0.1 and ::1 are loopback,
# 192.0.2.x / 198.51.100.x / 203.0.113.x are RFC 5737 TEST-NET, 0.0.0.0 is a
# bind address. Everything else that looks like an address is a finding.
# ⚠️⚠️ TAB-SEPARATED, AND THE PIPE THAT USED TO SEPARATE THEM MADE FOUR OF THESE
# ELEVEN CHECKS MATCH NOTHING AT ALL. The fields were split with `${rest%%|*}`,
# and a regex with alternation CONTAINS a pipe — so `private IPv4`'s pattern was
# cut down to the two characters `(^`, grep answered
#
#     ugrep: error at position 6 … mismatched ( )
#
# with exit 2 and no output, the hit list stayed empty, and the suite printed
# "ok  no private IPv4". Dead the same way: `hostname`, `ssh key`, `token`.
#
# ⚠️ AND IT WAS FOUND BY THE META-CHECKER, not by reading. A tripwire case put
# a private address into a tracked file; tests/no-secrets.sh stayed green and
# tests/tripwires.sh reported it blind. This is the rule he set in capitals and
# asked to hold "for ever", and the guard over it had a hole nobody could see
# from the outside — every run said the same reassuring thing.
#
# A tab cannot appear in any of these patterns, and `IFS=$'\t' read` splits on
# it without touching the contents.
patterns=(
  # ⚠️ THE TRAILING BOUNDARY IS WHAT KEEPS A GERMAN DATE FROM BEING AN ADDRESS.
  # `10.08.2026` matches `(10)\.[0-9]{1,3}\.[0-9]{1,3}` — "10", ".08", ".202" —
  # and this repository is full of them. `([^0-9]|$)` refuses to stop in the
  # middle of a number, so a date is left alone and a real address is not.
  $'private IPv4\t(^|[^0-9.])(10|127|169\.254|192\.168|172\.(1[6-9]|2[0-9]|3[01]))\.[0-9]{1,3}\.[0-9]{1,3}([^0-9]|$)\tan address from somebody\'s own network'
  $'public IPv4\t(^|[^0-9.])([0-9]{1,3}\.){3}[0-9]{1,3}\tany literal address at all'
  $'home path\t/home/[a-z_][a-z0-9_-]*\ta real account name in a path'
  $'user@host\tssh +[a-z_][a-z0-9_-]*@\ta login on a named machine'
  $'hostname\t[a-z0-9-]+\.(fritz\.box|local|lan|home|internal)\b\ta hostname from his network'
  $'hypervisor\t[Pp]roxmox\tthe hypervisor this lab runs on'
  $'ssh key\t(ssh-rsa|ssh-ed25519|ssh-dss|ecdsa-sha2-)[ ]+AAAA\ta public key identifies a machine'
  $'private key\tBEGIN [A-Z ]*PRIVATE KEY\ta private key, in a public repository'
  $'token\t(gh[pousr]_[A-Za-z0-9]{16,}|xox[baprs]-|AKIA[0-9A-Z]{16}|sk-[A-Za-z0-9]{20,})\tan API token'
  $'credentials\t[a-z]+://[^/@ ]+:[^/@ ]+@\ta password inside a URL'
  $'email\t[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\tan email address'
  # ⚠⚠ DEVICE MODELS, AND THIS ONE WAS MISSING WHILE TEN OF THEM SAT IN THE
  # PUBLIC TREE. The rule names them explicitly — IPs, passwords, hostnames,
  # usernames, serials, DEVICE MODELS — and every pattern above was written for
  # one of the other classes, so this suite was green over the exact CPU and GPU
  # spelled out in docs/, tests/ and lib/ — ten places.
  #
  # It was his question that found it: whether the docs should be public at
  # all. They should — CREDITS.md is a licence obligation
  # and CONFIG.md is how a stranger uses this. An exact CPU/GPU pair beside a
  # public account is a different thing: it fingerprints a person's machine, and
  # it carries no engineering meaning that "a hybrid AMD + NVIDIA laptop" does
  # not carry too.
  #
  # ⚠ THE PATTERN IS DELIBERATELY NARROW: exact part numbers, not vendors.
  # "AMD", "NVIDIA" and "Radeon" have to stay sayable — `amdgpu` is a kernel
  # module, `nvidia-smi` is a command, and a checker that forbids them would be
  # turned off within a day. What is forbidden is the thing that identifies one
  # machine rather than one class of machine.
  # ⚠ AND IT GOT NARROWER ON ITS FIRST RUN, WHICH IS THE POINT OF RUNNING IT.
  # The first version also listed EliteBook/ThinkPad/Latitude/MacBook and found
  # three lines that are all fine: Power.qml naming vendors whose firmware
  # behaves a certain way, and a settings row labelled "Latitude" — which is a
  # COORDINATE, not a Dell. A checker that cries wolf gets switched off, so a
  # product family is out and a part number is in: a full CPU or GPU part number
  # identifies one machine, a product family identifies a shop shelf.
  # â  And this comment deliberately spells NO real part number. An example is
  # exactly the line nobody proof-reads, and the first draft of it tripped this
  # very check.
  $'device model\t(Ryzen [0-9] [0-9]{4}[A-Z]{1,2}|Radeon [0-9]{3}M\\b|RTX ?[0-9]{4}|GTX ?[0-9]{3,4}|i[3579]-[0-9]{4,5}[A-Z]{0,2}|UHD [0-9]{3}\\b)\tan exact device model fingerprints a machine'
)

# ⚠️ ALLOWED, EACH WITH ITS REASON ON THE LINE. An exemption list is how a guard
# rots, so every entry says what it is and none of them is a wildcard.
allow=(
  '127\.0\.0\.1'                       # loopback
  '0\.0\.0\.0'                         # bind-anywhere
  '192\.0\.2\.|198\.51\.100\.|203\.0\.113\.'   # RFC 5737 TEST-NET, for documentation
  '/home/\$USER|/home/USER|/home/you|/home/test|/home/<'   # placeholders
  'users\.noreply\.github\.com'        # GitHub's own privacy address
  'noreply@anthropic\.com'             # the co-author trailer
  '@[a-z]+\.service|@tty1'             # systemd unit names, not addresses
  'ssh \$USER@|ssh <'                  # placeholders
  'Raspberry Pi OS'                    # quoted from Citrix's platform list
  'nas\.local|printer\.local'          # generic avahi examples in an explanation
  '\bx\.y\.z\b|1\.2\.3\.4'             # version and address stand-ins
  '1\.1\.1\.1'                          # Cloudflare's public resolver, a documentation example
  '10\.255\.255\.1'                     # RFC1918 in a comment that says so — a connect-hangs example
  '26\.04\.[0-9]+\.[0-9]+'              # Citrix RPM version strings, not addresses
  'secrets-ok:'                        # the escape hatch, spelled out below
)

allow_re="$(IFS='|'; echo "${allow[*]}")"

for entry in "${patterns[@]}"; do
    # ⚠️ A TAB, NOT A PIPE — see the note above the table. `read` with IFS set to
    # one character splits on exactly that character and leaves everything else
    # alone, which is what a field holding a regex needs.
    IFS=$'\t' read -r name re why <<< "$entry"

    # ⚠️⚠️ DOES THE PATTERN EVEN COMPILE? That is the question whose absence let
    # four of these checks report "ok" for months. grep answers a broken regex
    # with exit 2 and no output, which is indistinguishable from "found nothing"
    # unless somebody asks. Now it is asked, once per pattern, before the scan.
    # ⚠️ THE STATUS IS CAPTURED, NOT TESTED THROUGH `!`. Negation REWRITES `$?`,
    # so `if ! cmd; then case $?` reads 0 for a command that returned 1 — the
    # first version of this guard reported all eleven patterns as broken. And a
    # here-string rather than a pipe, because `… | grep -q` is the trap
    # tests/pipefail-grep.sh forbids.
    #
    # grep answers 0 for a match, 1 for none, and 2 for a pattern it cannot
    # compile. Only the last is a fault.
    grep -qE "$re" <<< "" 2>/dev/null
    if (( $? > 1 )); then
        bad "$name — the pattern itself does not compile"
        continue
    fi

    hits=""
    for f in "${files[@]}"; do
        [[ -f "$f" ]] || continue
        # Binary files have nothing to say here and grep would spend the time.
        grep -Iq . "$f" 2>/dev/null || continue
        while IFS= read -r line; do
            # ⚠️ THE ESCAPE HATCH IS PER LINE AND HAS TO SAY WHY — the same
            # shape as english-ok: and motion-ok: elsewhere in this repo.
            grep -Eq "$allow_re" <<< "$line" && continue
            hits+="    $f:$line"$'\n'
        done < <(grep -nEI "$re" "$f" 2>/dev/null)
    done

    if [[ -n "$hits" ]]; then
        bad "$name — $why"
        printf '%s' "$hits" | head -20
        [[ $(printf '%s' "$hits" | wc -l) -gt 20 ]] && printf '    … and more\n'
    else
        printf '  %sok%s   no %s\n' "$green" "$off" "$name"
    fi
done

if (( fail == 0 )); then
    printf '  %sok%s   %d files carry nothing private\n' "$green" "$off" "${#files[@]}"
else
    cat <<'EOF'

  A line that really is fine says so on itself:

      ssh $USER@<test-vm>          # secrets-ok: placeholders, not an address

  ⚠️ AND DELETING THE TEXT IS NOT ENOUGH FOR A SECRET. A password or key that
  has been pushed is burnt: change it, then remove it. The history is public as
  well, so a find here almost always means the same string is in git log too.
EOF
fi
exit $fail
