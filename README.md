# Exercise: Deploy Over SSH

Exercise code for the lesson **Exercise: Deploy Over SSH** in Bash in Depth on [ask-codey.com](https://www.ask-codey.com).

The Maple Street Book Club's website is a folder of pages, `site/`, and it lives on a server called `bookclub`. Give the server its short name in `ssh-config`, then write `deploy.sh`: one command that checks the site, copies it to the server with `rsync` over SSH, deleting pages you've removed, and lists what's live there with `ssh`. With `-n`, it rehearses instead. A check script tells you what's done, and it needs no server at all.

## Before you start

You need a terminal (the Terminal app on a Mac, Ubuntu on Linux or in WSL on Windows) with `ssh` and `rsync`, which Linux and macOS already have, and **bats**, the tool that runs the check. If `bats --version` or `rsync --version` doesn't print a version yet, install them:

```bash
sudo apt install bats rsync      # Ubuntu, and Ubuntu in WSL
brew install bats-core           # a Mac, with Homebrew
```

**On Windows, unzip or clone this folder inside Ubuntu**, in your Linux home folder (for example `~/terminal-practice/`), not in a Windows folder under `/mnt/c`, so `chmod` works on the scripts.

## What's here

- `site/`: the book club's website, four files. Ready to use: this is what you deploy.
- `ssh-config`: the lines for your `~/.ssh/config` that give the server its short name. For you to write.
- `deploy.sh`: the deploy script. For you to write.
- `stand-in/ssh`: a pretend `ssh`, for trying `deploy.sh` on a computer with no SSH server (see *Try it*). You don't need to change it.
- `check.bats`: the check. You don't need to change it.

## Run it

Open a terminal in this folder (the one with `check.bats` in it), make the scripts runnable, and open the first file:

```bash
chmod +x deploy.sh stand-in/ssh
nano ssh-config
```

The comment at the top of each file says exactly what it must do. Write your lines under the last comment, save with Ctrl+O and Enter, and quit with Ctrl+X.

The jobs:

1. **`ssh-config`**: a `Host` block for the name `bookclub`, with `HostName localhost`, `User` and your user name on that computer (`whoami` prints it), and `IdentityFile ~/.ssh/id_ed25519`. Check it without connecting: `ssh -F ssh-config -G bookclub | grep -E '^(user|hostname|identityfile) '`.
2. **`deploy.sh`** copies what's inside `site/` into the folder `bookclub-site` on the server `bookclub`, with `rsync` over SSH, so the server's copy matches `site/` exactly: a page deleted from `site/` is deleted from the server too. Then it prints `Live on bookclub:` and the files in `bookclub-site` on the server, by running `ls` there with `ssh`.
3. **`deploy.sh -n`** rehearses: `rsync` lists what it would copy and changes nothing. Then it prints `Rehearsal: nothing was copied.` and stops with exit code 0.
4. **No `site/index.html`, no deploy:** if `site/index.html` isn't there, `deploy.sh` prints a message that says so, copies nothing, and stops with exit code 1. With `--delete`, an empty `site/` would empty the live site.

## Try it

**Without an SSH server**, use the stand-in. Put its folder first on your `PATH` for one command, and `deploy.sh`'s `ssh`, and the `ssh` that `rsync` starts, are the stand-in instead of the real one. It runs each command on this computer, in the folder `stand-in/server-home/`:

```bash
PATH="$PWD/stand-in:$PATH" ./deploy.sh -n
PATH="$PWD/stand-in:$PATH" ./deploy.sh
ls stand-in/server-home/bookclub-site
```

**With your computer's SSH server on** (*Logging In to Another Computer: ssh*) and your key on it (*SSH Keys and ~/.ssh/config*), deploy for real. Add the lines from `ssh-config` to your `~/.ssh/config` with nano, then run `./deploy.sh`: the site lands in `~/bookclub-site` on your own computer.

## Check your work

From this folder:

```bash
bats check.bats
```

At first most checks fail: that is expected. Each job you finish turns its checks into a ✓. A failing check's message says what to look at. The check reads `ssh-config` with your own `ssh -G`, which connects to nothing, and runs a copy of `deploy.sh` on a made-up site of its own, in a throwaway folder, with its own stand-in `ssh`. Nothing in this folder is changed.

## The rules

- Use the short name `bookclub`, never `localhost` or an address, in `deploy.sh`: the details live in `ssh-config`.
- Copy with `rsync`, with `-a` and `--delete`, from `site/` with a slash at the end.
- List what's live with `ssh` and `ls`, after the copy.
- Print the lines exactly as shown: `Live on bookclub:` and `Rehearsal: nothing was copied.`

## Tips

- `bookclub:bookclub-site/` is the folder `bookclub-site` in your home folder on the server `bookclub`. The colon is what sends `rsync` over SSH.
- `site/` with a slash copies what's inside `site`; `site` without one puts a `site` folder inside `bookclub-site`.
- `rsync -avn` rehearses: it lists what it would copy, and the summary ends with `(DRY RUN)`.
- `${1:-}` is the first argument, or nothing when there isn't one, so `[[ ${1:-} == -n ]]` works under `set -u` too.
- In `ssh "$server" "ls $folder"`, the double quotes let your computer fill in `$folder` before ssh sends the command.
- `ssh: Could not resolve hostname bookclub` from a real deploy means the name isn't in your `~/.ssh/config` yet. The check and the stand-in don't need it there.

## Hand it in

When it works, push your solution to a public repo of your own on GitHub, then paste that repo's address into **Submit your exercise** on the lesson page at [ask-codey.com](https://www.ask-codey.com). That's what completes the lesson. The lesson page shows the Git commands, step by step.
