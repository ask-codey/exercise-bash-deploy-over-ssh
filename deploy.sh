#!/usr/bin/env bash
# deploy.sh: puts the book club's site live on its server, bookclub.
#
# Usage:   ./deploy.sh       copy site/ to the server, then list what's live there
#          ./deploy.sh -n    rehearse: show what would be copied, and copy nothing
#
# What it must do:
#   1. If site/index.html isn't there, print a message that says so, copy nothing,
#      and stop with exit code 1. An empty or wrong site/ must never replace the live one.
#   2. Copy what's inside site/ into the folder bookclub-site on the server bookclub,
#      with rsync over SSH, so the server's copy matches site/ exactly: a page deleted
#      from site/ is deleted from the server too.
#   3. With -n, rehearse: rsync lists what it would copy and changes nothing. Then print
#         Rehearsal: nothing was copied.
#      and stop with exit code 0.
#   4. Otherwise, after copying, print
#         Live on bookclub:
#      and then the files in bookclub-site on the server, by running ls there with ssh.
#
# Use the server's short name, bookclub, from ssh-config: never localhost or an address.
#
# Write your script under this line.
