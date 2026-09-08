#!/usr/bin/env bash
#
# Every name the login screen uses has to exist in the login screen.
#
# ⚠️ FOUR LINES, BECAUSE THE CHECK ALREADY EXISTS. tests/lock-idents.sh is 180
# lines of awk that collects every name a directory declares and reports every
# `something.` that is none of them. Copying it here would be the fault this
# project has paid for four times — a list in two places, one of them updated.
# It takes the directory as an argument for exactly this.
#
# ⚠️ AND THE GREETER NEEDS IT MORE THAN THE LOCK SCREEN DID. The bug it was
# written for — `Keys.onPressed` writing into `field` when the field is called
# `input`, so every keystroke threw and the box stayed empty — is a bug that is
# invisible to compilation, invisible to qmllint, and fatal here: a login screen
# you cannot type into is a machine you cannot get into. GreeterFace has the
# same handler shape and the same two names in it.
exec "$(dirname "$0")/lock-idents.sh" shell/ui/greeter
