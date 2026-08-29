#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright 2026 The SLSA Authors
# SPDX-License-Identifier: Apache-2.0
#
# Verifies a SLSA source attestation with slsa-verifier source. The
# attestation is a file (INPUT_ATTESTATION) or the git note of a commit
# of the checked-out repository (INPUT_COMMIT), read the way the
# get_note action does. Inputs arrive through the environment, prefixed
# INPUT_, and map onto the command's flags; see action.yml.
set -euo pipefail
# shellcheck source=../lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

attestation="${INPUT_ATTESTATION:-}"
commit="${INPUT_COMMIT:-}"
if [ -n "$commit" ]; then
  case "$commit" in
    *[!0-9a-f]*|'') fail "commit must be a full lowercase commit sha, got: ${commit}" ;;
  esac
  [ "${#commit}" -eq 40 ] || [ "${#commit}" -eq 64 ] || fail "commit must be a full commit sha, got: ${commit}"
  [ -z "$attestation" ] || fail "give either attestation or commit, not both"
  repo_dir="${INPUT_PATH:-.}"
  git -C "$repo_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "commit needs the repository checked out (actions/checkout) at ${repo_dir} to read its git note"
  echo "Reading the git note of ${commit}" >&2
  git -C "$repo_dir" fetch origin "refs/notes/*:refs/notes/*" >&2
  attestation="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/note-${commit}.jsonl"
  git -C "$repo_dir" notes show "$commit" > "$attestation" || fail "commit ${commit} has no git note"
  [ -s "$attestation" ] || fail "the git note of ${commit} is empty"
fi
[ -n "$attestation" ] || fail "attestation or commit is required"
[ -e "$attestation" ] || fail "attestation not found: ${attestation}"

VERIFIER="${VERIFIER:?path of the verified slsa-verifier binary}"

ARGS=(source "$attestation")
[ -n "$commit" ] && ARGS+=("$commit")
add_flag --subject "${INPUT_SUBJECT:-}"
add_flag --expected-repo "${INPUT_EXPECTED_REPO:-}"
add_flag --expected-branch "${INPUT_EXPECTED_BRANCH:-}"
add_flag --expected-tag "${INPUT_EXPECTED_TAG:-}"
add_bool --official "${INPUT_OFFICIAL:-}"
add_each --signer "${INPUT_SIGNER:-}"
add_bool --require-signatures "${INPUT_REQUIRE_SIGNATURES:-}"
add_each --key "${INPUT_KEY:-}"
add_each --param "${INPUT_PARAMS:-}"
add_flag --level "${INPUT_LEVEL:-}"
add_flag --since "${INPUT_SINCE:-}"
add_flag --spec "${INPUT_SPEC:-}"
add_flag --controls "${INPUT_CONTROLS:-}"
add_bool --verbose "${INPUT_VERBOSE:-}"
add_flag --verifier-id "${INPUT_VERIFIER_ID:-}"
add_raw_args "${INPUT_ARGS:-}"

VSA_PATH="${INPUT_VSA:-}"
run_verification "$VERIFIER" "SLSA source verification"
