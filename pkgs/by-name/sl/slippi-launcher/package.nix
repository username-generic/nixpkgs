{
  lib,
  dolphin-emu,
  buildNpmPackage,
  fetchFromGitHub,
  electron,
  node-gyp,
  node-gyp-build,
  sqlite,
}:
buildNpmPackage (finalAttrs: {
  pname = "slippi-launcher";
  version = "2.14.2";

  src = fetchFromGitHub {
    # owner = "project-slippi";
    owner = "username-generic";
    repo = "slippi-launcher";
    # tag = "v${finalAttrs.version}";
    rev = "fix/non-dev-builds";
    hash = "sha256-O3IITurXetdHQYrts31Ly+X8cLbaAovYnni75VA61/Y=";
  };

  # `source/release/app/package.json`
  releaseDeps = buildNpmPackage ({
    pname = "${finalAttrs.pname}-native-npm-deps";
    inherit (finalAttrs) version;
    src = "${finalAttrs.src}/release/app";
    npmDepsHash = "sha256-hLedRMRmD8OCAHRryNpnGLGTHMjLK0sMF9w1xIaO9Iw=";

    # The `postinstall` script depends on files from directories above
    # `source/release/app`, so we'll run it after copying this subpackage
    # to the primary one.
    npmFlags = [ "--ignore-scripts" ];
    dontNpmBuild = true;
    installPhase = ''cp -r . "$out"'';
  });

  # `source/package.json`
  npmDepsHash = "sha256-e4plElJ+24To04DQlmG5LWkpy19UPTQyMdDfO2lpxRo=";

  # TODO: Add `--omit=dev` once dependencies get fixed upstream.
  npmFlags = [ "--ignore-scripts" ];

  prePatch =
    let
      oldHashGetter = ''
        execSync("git rev-parse --short HEAD").toString().trim()
      '';
      finalShortCommitHash = "09e79f6";
    in
    ''
      sed -i 's@${oldHashGetter}@"${finalShortCommitHash}"@' \
      .erb/configs/webpack.config.base.ts
    '';

  nativeBuildInputs = [
    node-gyp
    node-gyp-build
    electron
  ];

  preConfigure = ''
    cp -rf --no-preserve=mode,ownership \
    "${finalAttrs.releaseDeps}/node_modules" release/app

    pushd release/app
    npm run postinstall
    popd
  '';

  postConfigure = "npm run postinstall";

  makeCacheWritable = true;

  env.ELECTRON_SKIP_BINARY_DOWNLOAD = "1";

  # This phase essentially runs the `package` script without its last
  # `electron-builder` command. This is fine since we don't need a bundle.
  buildPhase = "npm run clean && npm run build";

  propagatedInputs = [
    sqlite
    dolphin-emu
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/slippi-launcher

    cp -r release/app $out/share/slippi-launcher

    mv $out/share/slippi-launcher/app/dist/migrations \
    $out/share/slippi-launcher/app/dist/main

    makeWrapper ${lib.getExe electron} $out/bin/slippi-launcher \
      --add-flag $out/share/slippi-launcher/app \
      --prefix PATH : "${
        lib.makeBinPath [
          sqlite
          dolphin-emu
        ]
      }" \
      --inherit-argv0

    runHook postInstall;
  '';

  meta = {
    description = "The way to play Slippi Online and watch replays";
    homepage = "https://slippi.gg";
    mainProgram = "slippi-launcher";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.all;
    maintainers = with lib.maintainers; [ username-generic ];
  };
})
