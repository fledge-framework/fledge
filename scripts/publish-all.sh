#!/usr/bin/env bash
#
# Manually publish every Fledge package to pub.dev in dependency order.
#
# Idempotent: for each package, this script queries pub.dev for the
# version declared in that package's pubspec. If pub.dev already has
# it (HTTP 200), the package is skipped. Otherwise it attempts to
# publish, with three retries on failure to absorb pub.dev CDN
# propagation lag between sibling publishes.
#
# Usage:
#   dart pub login          # once, if you haven't already
#   ./scripts/publish-all.sh
#
# Environment:
#   DRY_RUN=1               # runs `dart pub publish --dry-run` instead
#                             of the real thing — nothing gets uploaded.
#   SKIP_CONFIRM=1          # skip the interactive confirmation prompt.
#
# Requirements:
#   - Run from the repository root (script tolerates being run from
#     `scripts/` too — it cds up to the repo root automatically).
#   - `dart` and `curl` on PATH.
#   - You must have publish rights to every listed package (or be a
#     member of the pub.dev publisher that owns them).
#
# For a v0.2.0 first-release specifically:
#   - New packages must be manually claimed via this script or a manual
#     `dart pub publish` before the OIDC-based tag-triggered workflow
#     can publish them. See CONTRIBUTING.md.
#

set -euo pipefail

# ---------------------------------------------------------------------------
# Resolve repo root regardless of where the script was invoked from.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# ---------------------------------------------------------------------------
# Package publish order. Each package must be already on pub.dev before
# any package that depends on it publishes — pub validates hosted deps
# resolve at their declared constraint. Shims publish last because they
# depend on the merged/renamed packages.
PACKAGES=(
  # Foundation: no in-tree deps.
  "fledge_ecs_annotations"
  # Core: depends on annotations.
  "fledge_ecs"
  "fledge_ecs_generator"
  # Assets: depends on ecs.
  "fledge_assets"
  # Render (2D infra + components merged in v0.2).
  "fledge_render_2d"
  # Render extensions: depend on ecs + render_2d (+ assets).
  "fledge_camera_2d"
  "fledge_tween"
  "fledge_particles"
  "fledge_lighting_2d"
  # Platform / peripherals.
  "fledge_input"
  "fledge_audio"
  "fledge_window"
  # Physics (no longer depends on tiled after v0.2).
  "fledge_physics"
  # UI + calendar + yarn + save + net.
  "fledge_ui"
  "fledge_calendar"
  "fledge_yarn"
  "fledge_save"
  "fledge_net"
  # Tiled depends on physics + assets + camera_2d.
  "fledge_tiled"
  # Debug depends on ui + physics + camera_2d + render_2d.
  "fledge_debug"
  # Shims publish last — they depend on the new packages above.
  "fledge_render"
  "fledge_time"
)

# ---------------------------------------------------------------------------
# Small helpers.

get_version() {
  local pkg="$1"
  grep "^version:" "packages/$pkg/pubspec.yaml" | head -1 | awk '{print $2}'
}

is_published() {
  local pkg="$1" version="$2"
  local http_status
  http_status=$(curl -sS -o /dev/null -w "%{http_code}" \
    "https://pub.dev/api/packages/$pkg/versions/$version" || echo "000")
  [ "$http_status" = "200" ]
}

publish_cmd() {
  if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "dart pub publish --dry-run"
  else
    echo "dart pub publish --force"
  fi
}

publish_with_retry() {
  local pkg="$1"
  local cmd
  cmd=$(publish_cmd)
  local delays=(0 20 40)
  for attempt in 1 2 3; do
    local delay="${delays[$((attempt - 1))]}"
    if [ "$delay" -gt 0 ]; then
      echo "    retry $attempt after ${delay}s (propagation wait)..."
      sleep "$delay"
    fi
    if (cd "packages/$pkg" && $cmd); then
      return 0
    fi
  done
  return 1
}

# ---------------------------------------------------------------------------
# Confirm before doing anything destructive.

if [ "${DRY_RUN:-0}" = "1" ]; then
  echo "DRY_RUN=1 — no packages will be uploaded."
elif [ "${SKIP_CONFIRM:-0}" != "1" ]; then
  echo "About to publish ${#PACKAGES[@]} packages to pub.dev."
  echo "Set DRY_RUN=1 to preview without uploading."
  echo ""
  read -r -p "Continue? [y/N] " reply
  case "$reply" in
    y|Y|yes|YES) ;;
    *) echo "Aborted."; exit 0 ;;
  esac
fi

# ---------------------------------------------------------------------------
# Main loop.

FAILED=()

for pkg in "${PACKAGES[@]}"; do
  version=$(get_version "$pkg")
  echo ""
  echo "=== $pkg $version ==="

  if [ -z "$version" ]; then
    echo "  ! could not read version from packages/$pkg/pubspec.yaml"
    FAILED+=("$pkg")
    continue
  fi

  http_status=$(curl -sS -o /dev/null -w "%{http_code}" \
    "https://pub.dev/api/packages/$pkg/versions/$version" || echo "000")

  case "$http_status" in
    200)
      echo "  ✓ $pkg $version already on pub.dev, skipping."
      ;;
    404)
      echo "  → publishing..."
      if publish_with_retry "$pkg"; then
        echo "  ✓ published"
      else
        echo "  ✗ failed after 3 attempts"
        FAILED+=("$pkg")
      fi
      ;;
    *)
      echo "  ! unexpected HTTP $http_status from pub.dev; attempting publish anyway"
      if publish_with_retry "$pkg"; then
        echo "  ✓ published"
      else
        echo "  ✗ failed after 3 attempts"
        FAILED+=("$pkg")
      fi
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Report.

echo ""
if [ ${#FAILED[@]} -gt 0 ]; then
  echo "Failed packages:"
  printf '  - %s\n' "${FAILED[@]}"
  echo ""
  echo "Re-run this script to retry only the failed ones — successful"
  echo "packages will be skipped."
  exit 1
fi

echo "All packages either already published or successfully published."
