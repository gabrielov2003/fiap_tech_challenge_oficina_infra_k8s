#!/usr/bin/env bash
set -euo pipefail

REPOSITORIO="$1"
BRANCH="$2"
INICIO=$(date -u -d '-1 minute' +%Y-%m-%dT%H:%M:%SZ)
EXECUCAO=""

gh workflow run ci-cd.yml -R "$REPOSITORIO" --ref "$BRANCH"

for tentativa in $(seq 1 30); do
  sleep 10
  EXECUCAO=$(gh run list -R "$REPOSITORIO" --workflow ci-cd.yml --branch "$BRANCH" --event workflow_dispatch \
    --limit 1 --json databaseId,createdAt --jq ".[] | select(.createdAt >= \"$INICIO\") | .databaseId")
  [ -n "$EXECUCAO" ] && break
done

if [ -z "$EXECUCAO" ]; then
  echo "::error::O pipeline de $REPOSITORIO na branch $BRANCH não começou."
  exit 1
fi

echo "Acompanhando https://github.com/$REPOSITORIO/actions/runs/$EXECUCAO"
gh run watch "$EXECUCAO" -R "$REPOSITORIO" --exit-status --interval 30
