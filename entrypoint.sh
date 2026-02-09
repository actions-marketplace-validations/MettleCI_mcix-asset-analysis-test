#!/bin/sh -l
set -eu

# Failure handling utility function
die() { echo "$*" 1>&2 ; exit 1; }

MCIX_BIN_DIR="/usr/share/mcix/bin"
MCIX_CMD="$MCIX_BIN_DIR/mcix"
PATH="$PATH:$MCIX_BIN_DIR"

# Validate required vars
: "${PARAM_API_KEY:?Missing required input: api-key}"
: "${PARAM_URL:?Missing required input: url}"
: "${PARAM_USER:?Missing required input: user}"
: "${PARAM_REPORT:?Missing required input: report}"
: "${PARAM_RULES:?Missing required input: rules}"

normalise_bool() {
  case "$1" in
    1|true|TRUE|yes|YES|on|ON) echo 1 ;;
    0|false|FALSE|no|NO|off|OFF|"") echo 0 ;;
    *) die "Invalid boolean: $1" ;;
  esac
}

# Optional arguments
PROJECT="${PARAM_PROJECT:-}"
PROJECT_ID="${PARAM_PROJECT_ID:-}"

# 1) Fail if BOTH project and project-id were provided
if [ -n "$PROJECT" ] && [ -n "$PROJECT_ID" ]; then
  die "ERROR: Both 'project' and 'project-id' were provided. Please specify only one."
fi

# 2) Fail if NEITHER project or project-id were provided
if [ -z "$PROJECT" ] && [ -z "$PROJECT_ID" ]; then
  die "ERROR: You must provide either 'project' or 'project-id'." 
fi

# Build command to execute
CMD="$MCIX_CMD asset-analysis test \
 -api-key \"$PARAM_API_KEY\" \
 -url \"$PARAM_URL\" \
 -user \"$PARAM_USER\" \
 -report \"$PARAM_REPORT\" \
 -rules \"$PARAM_RULES\""

# Add optional project/project-id
[ -n "$PROJECT" ] && CMD="$CMD -project \"$PROJECT\""
[ -n "$PROJECT_ID" ] && CMD="$CMD -project-id \"$PROJECT_ID\""

# Echo diagnostics for included and excluded tags
[ -n "$PARAM_INCLUDED_TAGS" ] && CMD="$CMD -include-tags $PARAM_INCLUDED_TAGS"
if [ -n "$PARAM_EXCLUDED_TAGS" ]; then 
  CMD="$CMD -exclude-tags example,$PARAM_EXCLUDED_TAGS"
else
  CMD="$CMD -exclude-tags example"
fi

[ -n "$PARAM_TEST_SUITE" ] && CMD="$CMD -test-suite \"$PARAM_TEST_SUITE\""

if [ -n "$PARAM_IGNORE_TEST_FAILURES" ] && [ "$(normalise_bool "${PARAM_IGNORE_TEST_FAILURES:-0}")" = "1" ]; then 
  CMD="$CMD -ignore-test-failures"
fi

if [ -n "$PARAM_INCLUDE_ASSET_IN_TEST_NAME" ] && [ "$(normalise_bool "${PARAM_INCLUDE_ASSET_IN_TEST_NAME:-0}")" = "1" ]; then
  CMD="$CMD -include-asset-in-test-name"
fi

echo "Executing: $CMD"

# Execute the command
# shellcheck disable=SC2086
sh -c "$CMD"
status=$?

echo "return-code=$status" >> "$GITHUB_OUTPUT"
echo "report=$PARAM_REPORT" >> "$GITHUB_OUTPUT"
exit "$status"
