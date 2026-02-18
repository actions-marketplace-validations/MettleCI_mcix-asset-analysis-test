#!/bin/sh
# Don't use -l here; we want to preserve the PATH and other env vars 
# as set in the base image, and not have it overridden by a login shell

# ███╗   ███╗███████╗████████╗████████╗██╗     ███████╗ ██████╗██╗
# ████╗ ████║██╔════╝╚══██╔══╝╚══██╔══╝██║     ██╔════╝██╔════╝██║
# ██╔████╔██║█████╗     ██║      ██║   ██║     █████╗  ██║     ██║
# ██║╚██╔╝██║██╔══╝     ██║      ██║   ██║     ██╔══╝  ██║     ██║
# ██║ ╚═╝ ██║███████╗   ██║      ██║   ███████╗███████╗╚██████╗██║
# ╚═╝     ╚═╝╚══════╝   ╚═╝      ╚═╝   ╚══════╝╚══════╝ ╚═════╝╚═╝
# MettleCI DevOps for DataStage       (C) 2025-2026 Data Migrators
#                     _                          _           _
#   __ _ ___ ___  ___| |_       __ _ _ __   __ _| |_   _ ___(_)___
#  / _` / __/ __|/ _ \ __|____ / _` | '_ \ / _` | | | | / __| / __|
# | (_| \__ \__ \  __/ ||_____| (_| | | | | (_| | | |_| \__ \ \__ \
#  \__,_|___/___/\___|\__|     \__,_|_| |_|\__,_|_|\__, |___/_|___/
#  _            _                                  |___/
# | |_ ___  ___| |_
# | __/ _ \/ __| __|
# | ||  __/\__ \ |_
#  \__\___||___/\__|
# 

set -eu

# Import MettleCI GitHub Actions utility functions
. "/usr/share//mcix/common.sh"

# -----
# Setup
# -----
export MCIX_BIN_DIR="/usr/share/mcix/bin"
export MCIX_CMD="mcix" 
export MCIX_JUNIT_CMD="/usr/share/mcix/mcix-junit-to-summary"
export MCIX_JUNIT_CMD_OPTIONS="--annotations"
# Make us immune to runner differences or potential base-image changes
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$MCIX_BIN_DIR"

: "${GITHUB_OUTPUT:?GITHUB_OUTPUT must be set}"

# We'll store the real command status here so the trap can see it
MCIX_STATUS=0

# -------------------
# Validate parameters
# -------------------

# Validate required vars
require PARAM_API_KEY "api-key"
require PARAM_URL "url"
require PARAM_USER "user"
require PARAM_REPORT "report"
require PARAM_RULES "rules"

# Ensure PARAM_REPORT will always be /github/workspace/...
PARAM_REPORT="$(resolve_workspace_path "$PARAM_REPORT")"

# Fail if the report already exists which may be the case if this action is
# invoked multiple times with the same report path but no. This is to prevent multiple 
# test runs from overwriting each other's reports and causing confusion.
if [ -e "$PARAM_REPORT" ]; then
  die "JUnit report already exists: $PARAM_REPORT. Each invocation must use a unique report path."
else
  mkdir -p "$(dirname "$PARAM_REPORT")"
  report_display="${PARAM_REPORT#${GITHUB_WORKSPACE:-/github/workspace}/}"
fi

# ------------------------
# Build command to execute
# ------------------------
 
# Start argv
set -- "$MCIX_CMD" asset-analysis test

# Core flags
set -- "$@" -api-key "$PARAM_API_KEY"
set -- "$@" -url "$PARAM_URL"
set -- "$@" -user "$PARAM_USER"
set -- "$@" -report "$PARAM_REPORT"
set -- "$@" -rules "$PARAM_RULES"

# Mutually exclusive project / project-id handling (safe with set -u)
PROJECT="${PARAM_PROJECT:-}"
PROJECT_ID="${PARAM_PROJECT_ID:-}"
validate_project
[ -n "$PROJECT" ]    && set -- "$@" -project "$PROJECT"
[ -n "$PROJECT_ID" ] && set -- "$@" -project-id "$PROJECT_ID"

# Optional flags
if [ -n "$PARAM_INCLUDED_TAGS" ]; then
  set -- "$@" -include-tags "$PARAM_INCLUDED_TAGS"
fi

if [ -n "$PARAM_EXCLUDED_TAGS" ]; then 
  set -- "$@" -exclude-tags "$PARAM_EXCLUDED_TAGS"
fi

if [ -n "$PARAM_TEST_SUITE" ]; then 
  set -- "$@" -test-suite "$PARAM_TEST_SUITE"
fi

# Optional boolean flags
if [ "$(normalise_bool "${PARAM_IGNORE_TEST_FAILURES:-0}")" -eq 1 ]; then
  set -- "$@" -ignore-test-failures
fi

if [ "$(normalise_bool "${PARAM_INCLUDE_ASSET_IN_TEST_NAME:-0}")" -eq 1 ]; then
  set -- "$@" -include-asset-in-test-name
fi

# ------------
# Step summary
# ------------
write_step_summary() {
  # Do we have a variable pointing to a JUnit XML file?
  if [ -z "${PARAM_REPORT:-}" ] || [ ! -f "$PARAM_REPORT" ]; then
    gh_warn "JUnit XML file not found" "Path: ${PARAM_REPORT:-<unset>}"

  # Do we have a mcix-junit-to-summary command available?
  elif [ -z "${MCIX_JUNIT_CMD:-}" ] || [ ! -x "$MCIX_JUNIT_CMD" ]; then
    gh_warn "JUnit summarizer not executable" "Command: ${MCIX_JUNIT_CMD:-<unset>}"

  # Did GitHub provide a writable summary file?
  elif [ -z "${GITHUB_STEP_SUMMARY:-}" ] || [ ! -w "$GITHUB_STEP_SUMMARY" ]; then
    gh_warn "GITHUB_STEP_SUMMARY not writable" "Skipping JUnit summary generation."

  # Generate summary
  else
    # Commenting out for now (too verbose.)
    # gh_notice "Generating step summary" "Running JUnit summarizer and appending to GITHUB_STEP_SUMMARY."

    # mcix-junit-to-summary [--annotations] [--max-annotations N] <junit.xml> [title]
    echo "Executing: $MCIX_JUNIT_CMD $MCIX_JUNIT_CMD_OPTIONS $PARAM_REPORT \"MCIX Asset-Analysis Test\""
    "$MCIX_JUNIT_CMD" \
      "$MCIX_JUNIT_CMD_OPTIONS" \
      "$PARAM_REPORT" \
      "MCIX Asset-Analysis Test"  >> "$GITHUB_STEP_SUMMARY" || \
      gh_warn "JUnit summarizer failed" "Continuing without failing the action."
  fi
}

# ---------
# Exit trap
# ---------
write_return_code_and_summary() {
  # Prefer MCIX_STATUS if set; fall back to $?
  rc=${MCIX_STATUS:-$?}

  echo "return-code=$rc" >>"$GITHUB_OUTPUT"
  echo "junit-path=$report_display" >>"$GITHUB_OUTPUT"

  [ -z "${GITHUB_STEP_SUMMARY:-}" ] && return

  write_step_summary
}
trap write_return_code_and_summary EXIT

# -------
# Execute
# -------
# Check the repository has been checked out
if [ ! -e "/github/workspace/.git" ]; then
  die "Repo contents not found in /github/workspace. Did you forget to run actions/checkout@v4 before this action?"
fi

# Run the command, capture its output and status, but don't let `set -e` kill us.
set +e
"$@" 2>&1
MCIX_STATUS=$?
set -e

# Let the trap handle outputs & summary using MCIX_STATUS
exit "$MCIX_STATUS"
