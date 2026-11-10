#!/usr/bin/env bats
# Checks your ssh-config and your deploy.sh. No SSH server is needed, and nothing in this
# folder is changed by the check:
#   - ssh-config is read by your own ssh, with ssh -G, which shows the settings ssh would
#     use for a name without connecting anywhere.
#   - deploy.sh is run for real, on a copy of it, with a made-up site of the check's own,
#     in a throwaway folder. The check gives it a stand-in ssh that runs each command on
#     this computer, in a throwaway "server" folder, so rsync copies to a local folder.
# Run it from this folder with:  bats check.bats
# You don't need to change this file.

setup() {
  cd "$BATS_TEST_DIRNAME"
  dir="$BATS_TEST_TMPDIR/project"
  server="$BATS_TEST_TMPDIR/server-home"
  log="$BATS_TEST_TMPDIR/ssh.log"
  standin="$BATS_TEST_TMPDIR/stand-in"
}

# The check's own stand-in ssh: it skips ssh's options, writes down the server's name and
# the command, and runs the command in $SERVER_HOME, the way ssh localhost would.
make_standin() {
  mkdir -p "$standin"
  cat > "$standin/ssh" <<'STANDIN'
#!/usr/bin/env bash
while [[ $# -gt 0 && $1 == -* ]]; do
  case "$1" in
    -[BbcDEeFIiJLlmOopQRSWw]) shift 2 ;;
    *) shift ;;
  esac
done
host="$1"
shift
printf '%s\t%s\n' "$host" "$*" >> "$SSH_LOG"
mkdir -p "$SERVER_HOME" && cd "$SERVER_HOME" || exit 255
exec bash -c "$*"
STANDIN
  chmod +x "$standin/ssh"
}

# A copy of your deploy.sh beside a made-up site: three pages, one in a folder of its own.
make_project() {
  mkdir -p "$dir/site/events"
  cp deploy.sh "$dir/deploy.sh"
  printf '<h1>Riverside Garden Club</h1>\n' > "$dir/site/index.html"
  printf '<h1>About us</h1>\n' > "$dir/site/about.html"
  printf '<h1>Spring plant swap</h1>\n' > "$dir/site/events/plant-swap.html"
}

# Runs the copy of deploy.sh from its folder, with the stand-in ssh first on the PATH.
deploy() {
  (cd "$dir" && PATH="$standin:$PATH" SERVER_HOME="$server" SSH_LOG="$log" bash deploy.sh "$@")
}

# A script's lines without its comments, so the instructions at the top don't count as code.
code_of() {
  grep -v '^[[:space:]]*#' "$1" || true
}

# The settings your ssh would use for bookclub, read from ssh-config only. ssh's own
# messages go to ssh.err, so a mistake in the file can be shown as ssh words it.
settings() {
  ssh -F ssh-config -G bookclub < /dev/null 2> "$BATS_TEST_TMPDIR/ssh.err"
}

@test "deploy.sh, ssh-config and site/ are here, and so are ssh and rsync" {
  for f in deploy.sh ssh-config site/index.html; do
    if [[ ! -f "$f" ]]; then
      echo "$f is missing. Download the exercise again to get it back."
      return 1
    fi
  done
  for tool in ssh rsync; do
    if ! command -v "$tool" > /dev/null; then
      echo "$tool isn't installed yet. Install it with: sudo apt install $tool (a Mac has both already)."
      return 1
    fi
  done
}

@test "1) ssh-config gives bookclub the HostName localhost" {
  if ! out="$(settings)"; then
    echo "ssh can't read ssh-config. It says:"
    grep -v '^Pseudo-terminal' "$BATS_TEST_TMPDIR/ssh.err"
    echo "Check the spelling of each setting: Host, HostName, User and IdentityFile."
    return 1
  fi
  hostname="$(awk '$1 == "hostname" { print $2 }' <<< "$out")"
  if [[ "$hostname" != "localhost" ]]; then
    echo "For the name bookclub, ssh would connect to: $hostname"
    echo "Write a Host bookclub line, and under it HostName localhost."
    return 1
  fi
}

@test "2) ssh-config gives bookclub a User" {
  if ! grep -Eiq '^[[:space:]]*Host[[:space:]]+(.*[[:space:]])?bookclub([[:space:]]|$)' ssh-config; then
    echo "ssh-config has no Host bookclub line yet."
    return 1
  fi
  if ! grep -Eiq '^[[:space:]]*User([[:space:]]|=)+[^[:space:]#]' ssh-config; then
    echo "ssh-config has no User line yet. Under Host bookclub, write User and your user name (whoami prints it)."
    return 1
  fi
}

@test "3) ssh-config gives bookclub the key ~/.ssh/id_ed25519" {
  out="$(settings)" || true
  keys="$(awk '$1 == "identityfile" { print $2 }' <<< "$out")"
  if [[ "$keys" != "~/.ssh/id_ed25519" && "$keys" != "$HOME/.ssh/id_ed25519" ]]; then
    echo "For the name bookclub, ssh would try these keys:"
    echo "${keys:-(none)}"
    echo "Under Host bookclub, write IdentityFile ~/.ssh/id_ed25519, so ssh uses that key and no other."
    return 1
  fi
}

@test "4) deploy.sh copies what's inside site/ into bookclub-site on the server" {
  make_standin
  make_project
  run deploy
  if [[ ! -f "$server/bookclub-site/index.html" ]]; then
    echo "After ./deploy.sh (exit code $status), the server has no bookclub-site/index.html."
    if [[ -f "$server/bookclub-site/site/index.html" ]]; then
      echo "It's in bookclub-site/site/ instead. Put a slash after site: site/ means what's inside it."
    else
      echo "Copy with rsync, from site/ to the server's folder: bookclub:bookclub-site/"
    fi
    echo "deploy.sh printed:"
    echo "${output:-(nothing)}"
    return 1
  fi
  if ! cmp -s "$dir/site/events/plant-swap.html" "$server/bookclub-site/events/plant-swap.html"; then
    echo "The server's copy is missing site/events/plant-swap.html. rsync's -a copies the folders inside site/ too."
    return 1
  fi
}

@test "5) deploy.sh connects to the short name bookclub" {
  make_standin
  make_project
  run deploy
  if [[ ! -s "$log" ]]; then
    echo "deploy.sh never ran ssh, so nothing went to a server (exit code $status)."
    echo "rsync goes over SSH when one side is written host:folder, such as bookclub:bookclub-site/"
    return 1
  fi
  others="$(cut -f1 "$log" | grep -vx 'bookclub' | sort -u)"
  if [[ -n "$others" ]]; then
    echo "deploy.sh connected to: $others"
    echo "Use the short name from ssh-config, bookclub, so the settings live in one place."
    return 1
  fi
}

@test "6) deploy.sh lists what's live on the server, with ssh" {
  make_standin
  make_project
  run deploy
  if ! cut -f2- "$log" 2>/dev/null | grep -v '^rsync --server' | grep -Eq '(^|[^[:alnum:]_])ls([[:space:]]|$)'; then
    echo "deploy.sh doesn't run ls on the server yet. After copying, run it there with ssh bookclub and the command in quotes."
    return 1
  fi
  live="$(awk 'found { print } $0 == "Live on bookclub:" { found = 1 }' <<< "$output")"
  for name in about.html events index.html; do
    if ! grep -qx "$name" <<< "$live"; then
      echo "Under the line Live on bookclub:, the list should name $name. deploy.sh printed:"
      echo "$output"
      echo "Print Live on bookclub: first, then list the folder bookclub-site there: put \$folder in double quotes, so your computer fills it in."
      return 1
    fi
  done
}

@test "7) deploy.sh makes the server's copy match site/: a deleted page goes too" {
  make_standin
  make_project
  deploy > /dev/null 2>&1 || true
  rm "$dir/site/about.html"
  run deploy
  if [[ ! -f "$server/bookclub-site/index.html" ]]; then
    echo "deploy.sh didn't copy site/ to the server yet; check 4) first."
    return 1
  fi
  if [[ -f "$server/bookclub-site/about.html" ]]; then
    echo "about.html was deleted from site/, but it's still live on the server after the next deploy."
    echo "rsync's --delete removes files from the server's copy that are gone from site/."
    return 1
  fi
}

@test "8) deploy.sh -n rehearses and changes nothing on the server" {
  make_standin
  make_project
  run deploy -n
  if [[ -e "$server/bookclub-site" ]]; then
    echo "./deploy.sh -n copied files to the server. With -n, pass -n to rsync too, so it only lists what it would copy."
    return 1
  fi
  if [[ "$status" -ne 0 ]]; then
    echo "./deploy.sh -n should finish with exit code 0. It finished with $status. It printed:"
    echo "${output:-(nothing)}"
    return 1
  fi
  if ! grep -qx 'Rehearsal: nothing was copied.' <<< "$output"; then
    echo "After a rehearsal, deploy.sh should print the line: Rehearsal: nothing was copied."
    echo "It printed:"
    echo "${output:-(nothing)}"
    return 1
  fi
}

@test "9) deploy.sh stops with exit code 1, and copies nothing, when site/index.html is missing" {
  make_standin
  make_project
  deploy > /dev/null 2>&1 || true
  if [[ ! -f "$server/bookclub-site/about.html" ]]; then
    echo "deploy.sh didn't copy site/ to the server yet; check 4) first."
    return 1
  fi
  rm "$dir/site/index.html"
  run deploy
  if [[ "$status" -ne 1 ]]; then
    echo "With no site/index.html, deploy.sh should stop with exit code 1. It finished with $status."
    echo "Check with [[ ! -f site/index.html ]] before anything else, print a message, and exit 1."
    return 1
  fi
  if [[ ! -f "$server/bookclub-site/index.html" || ! -f "$server/bookclub-site/about.html" ]]; then
    echo "With no site/index.html, deploy.sh still changed the live site: its pages are gone."
    echo "Stop before rsync runs."
    return 1
  fi
}

@test "10) deploy.sh copies with rsync -a and --delete, and runs a command with ssh" {
  code="$(code_of deploy.sh)"
  if ! grep -Eq '(^|[^[:alnum:]_])rsync[[:space:]]' <<< "$code"; then
    echo "deploy.sh doesn't run rsync yet."
    return 1
  fi
  if ! grep -Eq -- '(^|[[:space:]"(])(-[a-zA-Z]*a[a-zA-Z]*|--archive)([[:space:]")]|$)' <<< "$code"; then
    echo "rsync has no -a yet. -a copies the folders inside site/ and keeps each file's date and permissions."
    return 1
  fi
  if ! grep -q -- '--delete' <<< "$code"; then
    echo "rsync has no --delete yet."
    return 1
  fi
  if ! grep -Eq '(^|[^[:alnum:]_-])ssh[[:space:]]' <<< "$code"; then
    echo "deploy.sh doesn't run ssh itself yet. After copying, list what's live with ssh."
    return 1
  fi
}
