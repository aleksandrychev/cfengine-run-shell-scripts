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

| Variable                              | Type             | Default | Description                                      |
|---------------------------------------|------------------|---------|--------------------------------------------------|
| `run_shell_scripts:main.scripts`   | file, repeatable | -       | Path to a `.sh`/`.bash` script to run.           |
| `run_shell_scripts:main.condition` | string           | `any`   | Class expression gating whether the scripts run. |
| `run_shell_scripts:main.ifelapsed` | string           | `0`     | Minutes between runs (`0` = every agent run).    |

`condition` is a CFEngine [class expression](https://docs.cfengine.com/docs/lts/reference/language-concepts/classes/), e.g. `Monday`, `linux`, `!any` (never run).

*Note:* `scripts` uses the `file` input type, which requires [cfbs](https://github.com/cfengine/cfbs) `5.7.0` or newer.