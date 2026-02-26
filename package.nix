{
  lib,
  fetchgit,
  buildNpmPackage,
  libsecret,
  pkg-config,
  ripgrep,
  nodejs,
  makeWrapper,
  jq,
}:
let
  currentVersion = lib.importJSON ./version.json;
  shortRev = builtins.substring 0 7 currentVersion.rev;
  version = "ib-unstable-${shortRev}";
in
buildNpmPackage (finalAttrs: {
  pname = "gemini-cli";
  inherit version;
  src = fetchgit {
    url = "https://github.com/google-gemini/gemini-cli.git";
    rev = currentVersion.rev;
    hash = currentVersion.gitHash;
  };
  inherit (currentVersion) npmDepsHash;

  nativeBuildInputs = [
    pkg-config
    makeWrapper
  ];

  buildInputs = [
    libsecret
    jq
  ];

  postPatch = ''
    # Generate git-commit.ts files
    # Normally done by scripts/generate-git-commit-info.js which shells out to git
    for dir in packages/cli/src/generated packages/core/src/generated; do
      mkdir -p "$dir"
      echo "export const GIT_COMMIT_INFO = '${shortRev}';" > "$dir/git-commit.ts"
      echo "export const CLI_VERSION = '${version}';" >> "$dir/git-commit.ts"
    done
    # replace version in package.json with short rev for better user experience
    for loc in package.json packages/cli/package.json packages/devtools/package.json; do
      # replace the git revision in the version field with the short rev for better user experience
      ${jq}/bin/jq --arg version "${version}" '.version = $version' \
        "$loc" > "$loc.tmp"
      mv "$loc.tmp" "$loc"
    done

    # Disable prepare script which runs husky (needs .git) and the full bundle
    substituteInPlace package.json \
      --replace-fail '"prepare": "husky && npm run bundle"' '"prepare": ""'

    # Strip the generate step from the bundle script since we created the files above
    substituteInPlace package.json \
      --replace-fail '"npm run generate && npm run build --workspace=@google/gemini-cli-devtools' \
                     '"npm run build --workspace=@google/gemini-cli-devtools'
  '';

  npmBuildScript = "bundle";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/gemini-cli $out/bin
    cp -rL bundle/* $out/lib/gemini-cli/

    makeWrapper ${nodejs}/bin/node $out/bin/gemini \
      --add-flags "$out/lib/gemini-cli/gemini.js" \
      --prefix PATH : ${lib.makeBinPath [ ripgrep ]}

    runHook postInstall
  '';

  meta = {
    description = "Google's AI-powered CLI tool";
    homepage = "https://github.com/google-gemini/gemini-cli";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    platforms = lib.platforms.linux;
    mainProgram = "gemini";
  };
})
