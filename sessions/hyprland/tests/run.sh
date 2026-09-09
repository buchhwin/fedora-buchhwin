#!/usr/bin/env bash
#
# Run the suite and say what happened.
#
# ⚠️ THE REASON THIS FILE EXISTS IS A MISREADING THAT COST A ROUND. There was no
# runner in the repository at all — CI runs only the repository-level
# tests/check-repo.sh, and everything here was started by hand, one at a time,
# with the results counted in a notebook. A test that exits 2 means "I could not
# ask the question on this machine", and the hand-count wrote one of those down
# as a failure. The next session started by looking for a bug in a test that had
# never run.
#
# So the three outcomes are told apart here, once, and named:
#
#   0   ok      the question was asked and answered
#   1   FAIL    the question was asked and the answer is wrong
#   2   skip    the question could not be asked here — no quickshell, no
#               compositor, a tool that is not installed. NOT a failure, and
#               never silently counted as one.
#
# Anything else is its own line: a timeout is 124, and a test killed by a signal
# is neither a pass nor a skip.
#
# ⚠️ SKIPS ARE PRINTED AT THE END BY NAME, not just counted. A suite that skips
# nine of its checks and prints "0 failed" is telling the truth in a way that
# reads like a lie. What was not asked is part of the result.
#
#   bash tests/run.sh              every test
#   bash tests/run.sh pages lock   just those, by name
#
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

# ⚠️ A CAP PER TEST, because the failure this suite has actually seen is a QML
# tool that finishes its checks and never quits: tools/monitors-check.qml threw
# on a stale fixture before it reached its own Qt.quit, and the run sat there.
# Every test that starts quickshell already has its own inner `timeout`; this is
# the backstop for the ones that do not, and for the shell around them.
TEST_TIMEOUT="${TEST_TIMEOUT:-900}"

green=$'\033[38;5;114m'; red=$'\033[38;5;203m'
amber=$'\033[38;5;179m'; grey=$'\033[38;5;245m'; off=$'\033[0m'

if (( $# > 0 )); then
    names=("$@")
else
    names=()
    for f in tests/*.sh; do
        b="$(basename "$f" .sh)"
        [[ "$b" == "run" ]] && continue      # not itself
        names+=("$b")
    done
fi

passed=0; failed=0
failed_names=(); skipped_names=(); odd_names=()

for name in "${names[@]}"; do
    f="tests/$name.sh"
    if [[ ! -f "$f" ]]; then
        printf '%s%-24s no such test%s\n' "$red" "$name" "$off"
        failed=$((failed + 1)); failed_names+=("$name")
        continue
    fi

    printf '%s┄┄ %s%s\n' "$grey" "$name" "$off"
    start=$SECONDS
    timeout "$TEST_TIMEOUT" bash "$f"
    code=$?
    took=$((SECONDS - start))

    case "$code" in
        0)   printf '%s   ok%s     %s  %ss\n' "$green" "$off" "$name" "$took"
             passed=$((passed + 1)) ;;
        1)   printf '%s   FAIL%s   %s  %ss\n' "$red" "$off" "$name" "$took"
             failed=$((failed + 1)); failed_names+=("$name") ;;
        2)   printf '%s   skip%s   %s  %ss\n' "$amber" "$off" "$name" "$took"
             skipped_names+=("$name") ;;
        124) printf '%s   TIMED OUT%s after %ss  %s\n' "$red" "$off" "$TEST_TIMEOUT" "$name"
             failed=$((failed + 1)); failed_names+=("$name (timed out)") ;;
        *)   printf '%s   exit %s%s  %s  %ss\n' "$red" "$code" "$off" "$name" "$took"
             failed=$((failed + 1)); odd_names+=("$name (exit $code)") ;;
    esac
    echo
done

printf '%s──────────────────────────────────────────────%s\n' "$grey" "$off"
printf '%s%s ok%s' "$green" "$passed" "$off"
(( failed > 0 )) && printf ' · %s%s failed%s' "$red" "$failed" "$off"
(( ${#skipped_names[@]} > 0 )) && printf ' · %s%s skipped%s' \
    "$amber" "${#skipped_names[@]}" "$off"
printf '\n'

if (( ${#skipped_names[@]} > 0 )); then
    printf '%sskipped — the question could not be asked on this machine:%s\n' \
           "$amber" "$off"
    for n in "${skipped_names[@]}"; do printf '   %s\n' "$n"; done
fi
if (( ${#failed_names[@]} > 0 )); then
    printf '%sfailed:%s\n' "$red" "$off"
    for n in "${failed_names[@]}"; do printf '   %s\n' "$n"; done
fi
if (( ${#odd_names[@]} > 0 )); then
    printf '%sneither passed nor skipped:%s\n' "$red" "$off"
    for n in "${odd_names[@]}"; do printf '   %s\n' "$n"; done
fi

(( failed == 0 )) || exit 1
exit 0
