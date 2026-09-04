#!/usr/bin/env bash
# Run the functional test locally in Docker.
#
# Builds the policy sets with cfbs, builds an Ubuntu image with CFEngine
# installed via `cf-remote install --clients localhost`, and runs
# tests/functional.sh as root in a container.
#
# Requirements: cfbs, docker.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
out="$here/out"
image="run-shell-scripts-test"

bash "$here/build-policies.sh"

mkdir -p "$out/docker"
cat > "$out/docker/Dockerfile" <<'DOCKERFILE'
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
# sudo is needed by cf-remote even when running as root.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates sudo python3 python3-pip \
 && rm -rf /var/lib/apt/lists/*
RUN pip3 install --break-system-packages --no-cache-dir cf-remote
RUN cf-remote install --clients localhost --edition community
ENV PATH="/var/cfengine/bin:${PATH}"
DOCKERFILE
docker build -q -t "$image" "$out/docker" >/dev/null

docker run --rm \
  -v "$out/policies:/policies:ro" \
  -v "$here/functional.sh:/functional.sh:ro" \
  -e POLICIES=/policies \
  "$image" bash /functional.sh
