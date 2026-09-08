#!/usr/bin/env bash
#
# Every name the lock screen uses has to exist in the lock screen.
#
# ⚠️ THIS IS THE OTHER HALF OF tests/lock.sh, AND IT CATCHES THE ONE THAT COST
# FOUR ROUNDS. `Keys.onPressed` wrote into `field`; the field is called `input`.
# Building the file cannot find that: the handler only runs when a key is
# pressed, and then QML throws a ReferenceError into a log nobody reads, drops
# the character, and the password box stays empty. Four handovers in a row said
# "nobody has ever typed the password" while the reason sat in one identifier.
#
# So this reads rather than runs: collect every name the directory DECLARES —
# ids, properties, signals, functions, function parameters, `var`s — and report
# every `something.` that is none of them.
#
# ⚠️ ONLY shell/ui/lock/. The same check over the whole shell would be a
# false-alarm generator: a surface legitimately reaches ids in files it is
# nested into, and a check nobody trusts costs more than it saves. The lock
# screen is two files and one process, which is exactly the shape this works on.
#
# ⚠️ AND COMMENTS ARE STRIPPED FIRST. Without that, the check reports the prose
# that explains it: a sentence ending in "…the words." looks exactly like
# `words.` to a regular expression. This project has now made that mistake three
# times, and this is the file where it would have been funniest.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

# ⚠️ THE DIRECTORY IS AN ARGUMENT NOW, and the reason is the rule this project
# has paid for four times: the list must not exist twice. The greeter is the
# same shape of thing — its own process, its own two files, its own key handler
# with the same `input`/`field` trap in it — and copying 180 lines of awk to
# check it would be a second copy to keep in step. tests/greeter-idents.sh is
# four lines and calls this.
dir="${1:-shell/ui/lock}"
fail=0

mapfile -t files < <(find "$dir" -name '*.qml' | sort)
(( ${#files[@]} )) || { echo "  no QML in $dir"; exit 1; }

printf '  %-34s ' "every name in $dir resolves"

report="$(awk '
    # ---- strings, then comments. In that order, or a // inside a string eats
    # the rest of a real line.
    function clean(s) {
        gsub(/"[^"]*"/, "\"\"", s)
        gsub(/\047[^\047]*\047/, "\047\047", s)
        sub(/\/\/.*/, "", s)
        return s
    }
    BEGIN {
        # QML grouped properties and JS globals: real names that are declared
        # nowhere in the file because they belong to Qt or to the language.
        # ⚠️ `easing` joined this list the day the lock screen got its first
        # Behavior. It is the grouped property of NumberAnimation — `easing.type`
        # — and it read as a name declared nowhere, which is exactly the shape of
        # a real fault, so the check was right to ask. Adding a genuine Qt name
        # here is the answer; silencing the line would not have been.
        #
        # The second block holds the properties an Item already has, which QML
        # lets you name without a prefix. Qt declares them, so a bare `width` is
        # a reference to something real and not the fault this looks for.
        #
        # ⚠️ TWO WAYS TO BREAK THIS FILE, BOTH MET WHILE WRITING THIS COMMENT.
        # The awk program is one single-quoted shell string, so an apostrophe
        # anywhere in it — writing "an Item" with a possessive — closes the
        # quote and hands the rest of the program to the shell. And awk ends a
        # line at `#`, so a comment inside the split() below truncates it
        # silently. Both printed "command not found" for awk source text.
        split("anchors font layer border margins padding sourceSize easing " \
              "console parent modelData point event Math JSON Date parseInt " \
              "parseFloat String Number Array Object Boolean RegExp isNaN " \
              "undefined arguments this window " \
              "width height implicitWidth implicitHeight x y z opacity scale " \
              "rotation visible enabled clip focus activeFocus contentWidth " \
              "contentHeight childrenRect state states transitions text " \
              "color radius source running interval repeat spacing " \
              "transformOrigin smooth antialiasing", g, " ")
        for (i in g) known[g[i]] = 1
    }
    {
        line = clean($0)

        # ---- what this directory declares ------------------------------
        if (match(line, /(^|[^A-Za-z0-9_])id:[ \t]*[A-Za-z_][A-Za-z0-9_]*/)) {
            s = substr(line, RSTART, RLENGTH); sub(/.*id:[ \t]*/, "", s)
            known[s] = 1
        }
        if (match(line, /property[ \t]+[A-Za-z_<>0-9]+[ \t]+[A-Za-z_][A-Za-z0-9_]*/)) {
            s = substr(line, RSTART, RLENGTH); sub(/.*[ \t]/, "", s)
            known[s] = 1
        }
        if (match(line, /property[ \t]+alias[ \t]+[A-Za-z_][A-Za-z0-9_]*/)) {
            s = substr(line, RSTART, RLENGTH); sub(/.*[ \t]/, "", s)
            known[s] = 1
        }
        if (match(line, /signal[ \t]+[A-Za-z_][A-Za-z0-9_]*/)) {
            s = substr(line, RSTART, RLENGTH); sub(/.*[ \t]/, "", s)
            known[s] = 1
        }
        if (match(line, /function[ \t]+[A-Za-z_][A-Za-z0-9_]*/)) {
            s = substr(line, RSTART, RLENGTH); sub(/.*[ \t]/, "", s)
            known[s] = 1
        }
        # function parameters, both shapes: `function (a, b)` and `function f(a)`
        if (match(line, /function[ \t]*[A-Za-z_0-9]*[ \t]*\([^)]*\)/)) {
            s = substr(line, RSTART, RLENGTH)
            sub(/^[^(]*\(/, "", s); sub(/\).*$/, "", s)
            n = split(s, p, /[ \t,]+/)
            for (i = 1; i <= n; i++) if (p[i] ~ /^[A-Za-z_]/) known[p[i]] = 1
        }
        # locals
        if (match(line, /(^|[^A-Za-z0-9_])var[ \t]+[A-Za-z_][A-Za-z0-9_]*/)) {
            s = substr(line, RSTART, RLENGTH); sub(/.*[ \t]/, "", s)
            known[s] = 1

            # ⚠️ AND THE REST OF A COMMA-SEPARATED DECLARATION. `var a = "",
            # b = ""` declares two names and this used to see only the first,
            # so the second was reported as undeclared — a false alarm, which
            # is the one thing a check like this cannot afford: the next person
            # softens it instead of reading it. Found by the greeter, which had
            # `var name = "", exec = "", inEntry = false` in its .desktop
            # parser.
            #
            # ⚠️ IT REFUSES TO GUESS WHEN THERE IS A CALL IN THE LINE. In
            # `var x = f(a, b)` the comma belongs to the argument list, and
            # splitting on it would register `b` as declared — that is not a
            # false alarm, it is a MISSED one, and this whole file exists
            # because a missed one cost four rounds. A part counts only when it
            # is plainly `name =`, and only in a statement with no parenthesis
            # in it at all.
            tail = line
            sub(/^.*[^A-Za-z0-9_]var[ \t]+/, "", tail)
            if (index(tail, "(") == 0) {
                n = split(tail, parts, /,/)
                for (i = 2; i <= n; i++)
                    if (match(parts[i], /^[ \t]*[A-Za-z_][A-Za-z0-9_]*[ \t]*=/)) {
                        d = substr(parts[i], RSTART, RLENGTH)
                        gsub(/[ \t=]/, "", d)
                        known[d] = 1
                    }
            }
        }

        # ---- and what it uses ------------------------------------------
        rest = line
        while (match(rest, /[A-Za-z_][A-Za-z0-9_]*\./)) {
            u = substr(rest, RSTART, RLENGTH - 1)
            pre = (RSTART > 1) ? substr(rest, RSTART - 1, 1) : " "
            # ⚠️ THE DOT STAYS. Cutting past it turns `pam.message.length` into
            # a fresh look at `message.` with nothing in front of it, and the
            # check reports a member of PAM as an undeclared name. Keeping the
            # separator is what makes the "not the first name in a chain" test
            # work at all — it reported two of these before it was kept.
            rest = substr(rest, RSTART + RLENGTH - 1)
            # A member of something else (`a.b.c`) is not a name in its own
            # right, and an upper-case first letter is a type or a singleton.
            if (pre == "." || u ~ /^[A-Z]/) continue
            uses[u] = uses[u] FILENAME ":" FNR " "
        }

        # ---- and the names with no dot after them ----------------------
        # ⚠️ THE CHECK ABOVE ONLY EVER LOOKED AT THE HEAD OF A DOTTED CHAIN, so
        # a bare name was never examined at all. `field` instead of `input` was
        # caught because it was written `field.text`; `opacity: shwon` sails
        # straight through, and it is the same fault with the same silence — the
        # binding throws a ReferenceError nobody sees and the value stays at its
        # default.
        #
        # Only the right-hand side of a binding is read. The left is the name
        # being DECLARED, and a property called `shown` must not count as a use
        # of itself.
        if (match(line, /^[ \t]*[A-Za-z_][A-Za-z0-9_.]*[ \t]*:/)) {
            rhs = substr(line, RSTART + RLENGTH)
            gsub(/[A-Za-z_][A-Za-z0-9_]*[ \t]*\(/, " ", rhs)   # calls
            gsub(/[A-Za-z_][A-Za-z0-9_]*\.[A-Za-z0-9_.]*/, " ", rhs)  # chains
            n = split(rhs, w, /[^A-Za-z0-9_]+/)
            for (i = 1; i <= n; i++) {
                b = w[i]
                if (b == "" || b ~ /^[0-9]/ || b ~ /^[A-Z]/) continue
                if (b ~ /^(true|false|null|undefined|if|else|return|function|new|typeof|void|in|of|var|let|const|this|for|while|do|break|continue|switch|case|default|try|catch|finally|throw|delete|instanceof)$/)
                    continue
                uses[b] = uses[b] FILENAME ":" FNR " "
            }
        }
    }
    END {
        for (u in uses)
            if (!(u in known)) {
                n = split(uses[u], where, " ")
                print u "\t" where[1]
            }
    }
' "${files[@]}")"

if [[ -z "$report" ]]; then
    printf '\033[38;5;114mok\033[0m\n'
else
    printf '\033[38;5;203m%s unknown\033[0m\n' "$(wc -l <<< "$report")"
    while IFS=$'\t' read -r name where; do
        printf '      \033[38;5;203m%-18s\033[0m %s — declared nowhere in %s\n' \
               "$name" "$where" "$dir"
    done <<< "$report"
    cat <<'EOF'

  A name used here exists in no file under the directory above. In QML that is not
  an error you see: the binding or handler throws a ReferenceError, the value
  stays at its default, and everything looks almost right. `field` instead of
  `input` swallowed every keystroke on the lock screen for four rounds.

  If the name really does come from somewhere else, it belongs behind a type
  or a singleton — those start with a capital letter and are not checked here.
EOF
    fail=1
fi

exit $fail
