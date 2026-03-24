{
  lib,
  nurl,
  prefetch-npm-deps,
  writeShellApplication,
  jq,
  coreutils,
  git,
}:
writeShellApplication {
  name = "antigravity-bin-update";
  runtimeInputs = [
    jq
    nurl
    prefetch-npm-deps
    coreutils
    git
  ];
  text = ''
    set -euo pipefail
    echo "Fetching latest revision from github.com/google-gemini/gemini-cli"

    NEW_REV=$(git ls-remote https://github.com/google-gemini/gemini-cli.git refs/heads/main | awk '{print $1}')
    PREV_REV=$(jq -r '.rev' version.json)
    if [ "$NEW_REV" = "$PREV_REV" ]; then
      echo "Revision matches current version.json, skipping update"
      exit 0
    fi
    echo "New revision $NEW_REV does not match current version.json revision $PREV_REV, updating version.json"

    # fetch git hash
    GIT_HASH=$(nurl --fetcher fetchgit --hash "https://github.com/google-gemini/gemini-cli.git" "$NEW_REV")
    echo "Fetched git revision with hash $GIT_HASH"

    # fetch npm hash
    GIT_PATH=$(mktemp -d)
    git clone --quiet --depth 1 "https://github.com/google-gemini/gemini-cli.git" "$GIT_PATH"
    NPM_HASH=$(prefetch-npm-deps "$GIT_PATH/package-lock.json")
    echo "Fetched npm dependencies with hash $NPM_HASH"
    rm -rf "$GIT_PATH"

    jq --arg rev "$NEW_REV" \
       --arg hash_git "$GIT_HASH" \
       --arg hash_npm "$NPM_HASH" \
       '.rev = $rev |
        ."gitHash" = $hash_git |
        ."npmDepsHash" = $hash_npm' \
       version.json > version.json.tmp
    mv version.json.tmp version.json
    echo "done updating version.json with new revision and hashes"
  '';
}
