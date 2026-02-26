{
  lib,
  nix-prefetch-scripts,
  prefetch-npm-deps,
  writeShellApplication,
  jq,
  coreutils,
}:
writeShellApplication {
  name = "antigravity-bin-update";
  runtimeInputs = [
    jq
    nix-prefetch-scripts
    prefetch-npm-deps
    coreutils
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

    # fetch git and nix store path
    PREFETCH_GIT=$(nix-prefetch-git https://github.com/google-gemini/gemini-cli.git --rev "$NEW_REV")
    GIT_HASH=$(echo "$PREFETCH_GIT" | jq -r '.hash')
    GIT_PATH=$(echo "$PREFETCH_GIT" | jq -r '.path')
    echo "Fetched git revision with hash $GIT_HASH and path $GIT_PATH"

    # fetch npm hash
    NPM_HASH=$(prefetch-npm-deps "$GIT_PATH/package-lock.json")
    echo "Fetched npm dependencies with hash $NPM_HASH"

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
