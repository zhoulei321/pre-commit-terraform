#!/usr/bin/env bash
# shellcheck disable=SC2155 # No way to assign to readonly variable in separate lines
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=_common.sh
. "$SCRIPT_DIR/_common.sh"

#
# Unique part
#

readonly GH_ORG="aquasecurity"
readonly GH_RELEASE_REGEX_LATEST="https://.+?/${TOOL}-${TARGETOS}-${TARGETARCH}"
readonly GH_RELEASE_REGEX_SPECIFIC_VERSION="https://.+?v${VERSION}/${TOOL}-${TARGETOS}-${TARGETARCH}"
readonly DISTRIBUTED_AS="binary"

common::install_from_gh_release "$GH_ORG" "$DISTRIBUTED_AS" \
  "$GH_RELEASE_REGEX_LATEST" "$GH_RELEASE_REGEX_SPECIFIC_VERSION"
