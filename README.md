# commit_motivation

Block distracting websites on macOS until you make at least one GitHub commit today.

By default it blocks Gmail (`mail.google.com`, `gmail.com`) until your GitHub account has a `PushEvent` dated today (in your local timezone). The block re-engages automatically every day at 00:01.

## How it works

- A small shell script (`commit_gate.sh`) hits the public GitHub events API for your username. If there's a `PushEvent` today, it removes a marked block from `/etc/hosts`. Otherwise, it adds it.
- Two `launchd` agents run the script: one every 5 minutes (and at login), and one daily at 00:01 to re-block.
- A narrow `sudoers` rule lets the script copy a single staged file into `/etc/hosts` without prompting for a password each time.

## Requirements

- macOS
- A public GitHub account (private-repo pushes won't show up in the public events API)
- `python3` (preinstalled at `/usr/bin/python3` on macOS)

## Install

```bash
git clone https://github.com/<you>/commit_motivation.git
cd commit_motivation
cp .env.example .env
# edit .env and set GITHUB_USER to your github username
$EDITOR .env
bash install.sh
```

`install.sh` will:

1. Read your `.env`
2. Install a sudoers rule at `/etc/sudoers.d/commit_motivation` (asks for your password once)
3. Render and load two LaunchAgents into `~/Library/LaunchAgents`
4. Run an initial check

## Configuration

Edit `.env`:

```bash
GITHUB_USER=your-github-username
BLOCKED_HOSTS=mail.google.com,www.mail.google.com,gmail.com,www.gmail.com
```

`BLOCKED_HOSTS` is a comma-separated list. Examples:

```bash
# Block Twitter and Reddit instead
BLOCKED_HOSTS=twitter.com,www.twitter.com,x.com,www.x.com,reddit.com,www.reddit.com
```

After changing `.env`, re-run `bash install.sh` (or just wait — the next 5-minute poll picks up the new value, but staged blocks won't reflect new hostnames until the next state change).

## Manual commands

```bash
./commit_gate.sh check     # poll GitHub and toggle the block
./commit_gate.sh status    # print BLOCKED or UNBLOCKED
./commit_gate.sh unblock   # force-remove the block (next poll may re-add)
./commit_gate.sh reset     # force-add the block
```

Logs: `~/.commit_motivation/gate.log`

## Uninstall

```bash
bash uninstall.sh
```

Unloads the LaunchAgents, removes the `/etc/hosts` block, and deletes the sudoers rule.

## Caveats

- **Browser cache**: after a hostname is added to `/etc/hosts`, browsers may keep an existing tab connected. Cmd+Q (fully quit) and reopen.
- **Public events only**: pushes to private repos don't show up in `/users/<name>/events/public`. If you only commit to private repos, this won't work for you.
- **Fails open**: if GitHub's API is unreachable, the script does *not* block (so you're not stranded with no email when GitHub goes down).
- **Local timezone**: "today" is your machine's local date, not UTC.
- **Doesn't block native apps**: this is `/etc/hosts`-based, so anything bypassing system DNS (some VPNs, some apps using DoH) will still work.
