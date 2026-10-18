# Sentinel

Sentinel is a self-monitoring, self-healing server toolkit written in bash.
It runs a set of small checks (disk, memory, load, Nginx), tracks their state
over time, sends alerts only when a problem is confirmed, restarts Nginx when
it is safe to do so, and publishes a status page.

## Features

- Checks are plain scripts in `checks.d/`. Adding one is a drop-in file.
- Smart alerting: a problem must fail `CONFIRM_AFTER` runs in a row before an
  alert is sent, and repeat alerts are limited by `COOLDOWN`.
- Self-healing: restarts Nginx with a narrow sudo rule, with a limit of
  `HEAL_MAX` restarts per `HEAL_WINDOW` seconds.
- Status page (HTML and JSON) with history and uptime.
- Runs on a systemd timer with hardening options and logrotate.
- A test suite and ShellCheck-clean code.

## Requirements

- Linux with bash 5+ (developed on Ubuntu under WSL2)
- systemd, Nginx, `flock`, `timeout` (from coreutils)
- Optional: `shellcheck` for linting

## Install

```bash
git clone TODO-your-repo-url sentinel
cd sentinel
cp sentinel.conf.example sentinel.conf
nano sentinel.conf          # set paths and thresholds
./sentinel.sh               # run once by hand
```

Keep `DRY_RUN=1` while you are testing. Alerts are then only written to the
log and no email is sent.

## Configuration

All settings live in `sentinel.conf`. Set `SENTINEL_CONF=/path/to/file` to use
a different config file.

| Option | Meaning | Default |
|---|---|---|
| `LOG_FILE` | Where Sentinel writes its log | ~/sentinel/sentinel.log |
| `STATE_DIR` | Per-check state files and history | ~/sentinel/state |
| `CHECKS_DIR` | Folder holding the check scripts | `checks.d` |
| `LOCK_FILE` | Prevents two runs at once | /tmp/sentinel.lock |
| `WEB_DIR` | Where the status page is written | `/var/www/sentinel` |
| `HISTORY_FILE` | CSV history used for uptime | `$STATE_DIR/history.csv` |
| `DISK_WARN` / `DISK_CRIT` | Disk usage thresholds (%) | `80` / '90' |
| `MEM_WARN` / `MEM_CRIT` | Memory usage thresholds (%) | '80' / '90' |
| `LOAD_WARN` / `LOAD_CRIT` | Load average thresholds | `1.0` / `2.0` |
| `HTTP_URL` | URL the HTTP check requests | `http://localhost:8080` |
| `NGINX_ACCESS_LOG` | Log read by the 5xx check | /var/log/nginx/access.log |
| `ERR5XX_WARN` / `ERR5XX_CRIT` | 5xx error count thresholds | `5` / `20` |
| `CONFIRM_AFTER` | Failed runs in a row before alerting | `3` |
| `COOLDOWN` | Seconds between repeat alerts | `1800` |
| `ALERT_EMAIL` | Where alerts are sent | none |
| `DRY_RUN` | `1` = log alerts instead of sending | `1` |
| `AUTO_HEAL` | `1` = allow automatic restarts | `1` |
| `HEAL_MAX` / `HEAL_WINDOW` | Max restarts per time window (seconds) | `3` / `3600` |

## Writing a check

Create an executable script in `checks.d/`. Files run in name order, so
`10-` runs before `20-`.

A check must:

1. Print **one line** describing the result.
2. Exit with a code:

| Exit code | Meaning |
|---|---|
| 0 | OK |
| 1 | WARNING |
| 2 | CRITICAL |
| 3 | UNKNOWN |

A check that hangs, prints nothing, or exits with another code is reported
as UNKNOWN. Each check is stopped after 10 seconds.

## Running on a schedule

```bash
sudo cp systemd/sentinel.service systemd/sentinel.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now sentinel.timer
systemctl list-timers sentinel.timer
```

Auto-heal needs one narrow sudo rule, created with
`sudo visudo -f /etc/sudoers.d/sentinel`:

```
YOUR_USER ALL=(root) NOPASSWD: /usr/bin/systemctl restart nginx
```

Logs rotate through `systemd/sentinel.logrotate`, installed as
`/etc/logrotate.d/sentinel`.

## Tests

```bash
bash tests/run_tests.sh
shellcheck -x sentinel.sh lib/*.sh checks.d/*.sh tests/run_tests.sh
```

The tests use a temporary config and fake checks, so they never touch your
real state or send alerts.

## Project layout

```
sentinel.sh        runner
lib/               common, state, heal and report functions
checks.d/          check scripts
systemd/           service, timer, override and logrotate files
tests/             test suite
```

## License

cat > LICENSE <<'LIC_END'
MIT License

Copyright (c) 2026 Vincent Teti

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
LIC_END
nano LICENSE
