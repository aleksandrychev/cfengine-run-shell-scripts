#!/usr/bin/env bash
# Build the policy sets used by tests/functional.sh.
#
# For each scenario a cfbs policy-set project (masterfiles + this module) is
# created in tests/out/projects/<name> and the built policy set is copied to
# tests/out/policies/<name>. The module is added as a local directory with the
# module's own build steps, so no git remote is needed.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/.." && pwd)"
out="$here/out"
fixtures="$here/fixtures"

rm -rf "$out/projects" "$out/policies"
mkdir -p "$out/projects" "$out/policies"

# build_policy <name> <space-separated scripts> <default condition, or "" for "any"> \
#              <default ifelapsed, or "" for "0">
#
# Each entry in <scripts> is a fixture script name, optionally followed by
# ":<condition>" and/or ":<ifelapsed>" to override the defaults for that one
# script, e.g. "one.sh" or "two.sh:!any" or "three.sh:any:5".
build_policy() {
  local name="$1" scripts="$2" condition="${3:-any}" ifelapsed="${4:-0}" project="$out/projects/$1"
  echo "Building policy set '$name' (scripts='${scripts:-none}', default condition='$condition', default ifelapsed='$ifelapsed')"
  mkdir -p "$project/run-shell-scripts/policy"
  cp "$repo/policy/main.cf" "$project/run-shell-scripts/policy/main.cf"
  # Fixture scripts are copied next to the module's input.json, the same way
  # `cfbs input` places a file that lives outside the project.
  for entry in $scripts; do
    cp -p "$fixtures/${entry%%:*}" "$project/run-shell-scripts/${entry%%:*}"
  done
  # Test-only augments for the Masterfiles Policy Framework (MPF):
  # - the package inventory needs a bootstrapped host and is unrelated to this
  #   module: disable it;
  # - cf-execd must never start agent runs in the background during the test.
  cat > "$project/test-def.json" <<'JSON'
{
  "classes": { "disable_inventory_package_refresh": ["any"] },
  "vars": { "control_executor_schedule": ["!any"] }
}
JSON
  (
    cd "$project"
    cfbs init --non-interactive >/dev/null
    REPO="$repo" SCRIPTS="$scripts" CONDITION="$condition" IFELAPSED="$ifelapsed" python3 - <<'PY'
import json, os
with open(os.path.join(os.environ["REPO"], "cfbs.json")) as f:
    module = json.load(f)["provides"]["run-shell-scripts"]
with open("cfbs.json") as f:
    project = json.load(f)
project["build"].append({
    "name": "./test-def.json",
    "description": "Test-only augments",
    "tags": ["local"],
    "steps": ["json ./test-def.json def.json"],
    "added_by": "cfbs add",
})
project["build"].append({
    "name": "./run-shell-scripts/",
    "description": module["description"],
    "tags": ["local"],
    "steps": module["steps"],
    "input": module["input"],
    "added_by": "cfbs add",
})
with open("cfbs.json", "w") as f:
    json.dump(project, f, indent=2)

names = os.environ["SCRIPTS"].split()
default_condition = os.environ["CONDITION"]
default_ifelapsed = os.environ["IFELAPSED"]
if names:
    data = []
    for element in module["input"]:
        element = dict(element)
        if element["variable"] == "scripts":
            entries = []
            for entry in names:
                parts = entry.split(":")
                script_name = parts[0]
                condition = parts[1] if len(parts) > 1 and parts[1] else default_condition
                ifelapsed = parts[2] if len(parts) > 2 and parts[2] else default_ifelapsed
                entries.append({
                    "path": "run-shell-scripts/" + script_name,
                    "condition": condition,
                    "ifelapsed": ifelapsed,
                })
            element["response"] = entries
        data.append(element)
    with open("run-shell-scripts/input.json", "w") as f:
        json.dump(data, f, indent=2)
PY
    cfbs build >/dev/null
  )
  cp -R "$project/out/masterfiles" "$out/policies/$name"
}

chmod -x "$fixtures/no-exec-bit.sh"

build_policy no-scripts "" "" ""
build_policy single "one.sh" "" ""
build_policy multiple "one.sh two.sh failing.sh" "" ""
build_policy no-exec-bit "no-exec-bit.sh" "" ""
build_policy condition-false "one.sh" "!any" ""
build_policy mixed-conditions "one.sh two.sh:!any" "" ""

echo "Policy sets built in $out/policies"
