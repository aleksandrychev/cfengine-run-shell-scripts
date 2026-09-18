# run-shell-scripts

[![CI](https://github.com/aleksandrychev/cfengine-shell-scripts-runner/actions/workflows/ci.yml/badge.svg)](https://github.com/aleksandrychev/cfengine-shell-scripts-runner/actions/workflows/ci.yml)

A [cfbs](https://github.com/cfengine/cfbs) module that runs shell/bash scripts.

## Usage

```sh
cfbs add run-shell-scripts
cfbs input run-shell-scripts
cfbs build
```

## Input

`run_shell_scripts:main.scripts` is a repeatable list; each entry describes one script:

| Key         | Type   | Default | Description                                                  |
|-------------|--------|---------|--------------------------------------------------------------|
| `path`      | file   | -       | Path to the `.sh`/`.bash` script to run.                     |
| `condition` | string | `any`   | Class expression gating whether this script runs.            |
| `ifelapsed` | string | `0`     | Minutes between runs of this script (`0` = every agent run). |

`condition` is a CFEngine [class expression](https://docs.cfengine.com/docs/lts/reference/language-concepts/classes/), e.g. `Monday`, `linux`, `!any` (never run). Each script has its own `condition` and `ifelapsed`, so scripts can be scheduled independently of each other.

*Note:* `scripts` uses a `list` input with a keyed `file`/`string` `subtype`, which requires [cfbs](https://github.com/cfengine/cfbs) `5.8.0` or newer.