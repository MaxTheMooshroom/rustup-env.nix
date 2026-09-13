{
  lib,

  stdenvNoCC,
  makeBinaryWrapper,

  formats,

  mkRustBin,
  rust-toolchain-manifests,

  callPackageSet,
}:
with builtins;
lib.makeOverridable
  (
    {
      # TODO: Add cross-targets

      #?  toolchains ::
      #?    {
      #?      stable?   :: { [<semver>... | latest]? :: toolchain-config, },
      #?      beta?     :: { [<date-ymd>... | latest]? :: toolchain-config, },
      #?      nightly?  :: { [<date-ymd>... | latest]? :: toolchain-config, },
      #?    };
      #?
      #?  toolchain-config ::
      #?    {
      #?      components :: [toolchain-component],
      #?      profile :: toolchain-profile,
      #?    };
      #?
      #?  toolchain-profile :: "minimal" | "default" | "complete";
      #?
      #?  toolchain-component ::
      #?      "rustc" | "cargo" | "rustfmt" | "rust-std" | "rust-docs"
      #?    | "rust-analyzer" | "clippy" | "miri" | "rust-src" | "rust-mingw"
      #?    | "rustc-dev";
      #?
      #?  date-ymd :: strf "YYYY-MM-DD";
      #?
      toolchains ? {},

      #? defaultToolchain :: [ "stable" semver ] | [ ("beta" | "nightly") date-ymd ]
      defaultToolchain ? null,

      ...
    }:
    let
      utils =
        {
          #? writeTOML :: string -> set -> string
          writeTOML = (formats.toml {}).generate;

          fetchManifestFile =
            qualified-target:
            { url, sha256, ... }:
            fetchurl
              {
                inherit url sha256;
                name = "multirust-toolchain-manifest-${qualified-target}.json";
              }
            ;

          generateToolchains =
            { root, channel }:
            selected:
            { profile ? "default", components ? [] }:
            lib.fix
              (
                self:
                {
                  __toolchainManifest =
                    lib.getAttrFromPath
                      [ channel selected "manifest" ]
                      rust-toolchain-manifests
                    ;

                  qualified-target =
                    concatStringsSep
                      "-"
                      (
                        (lib.optional (channel != "stable") channel)
                      ++
                        [ selected target-triple ]
                      )
                    ;

                  toolchain =
                    {
                      drv =
                        mkRustBin.fromRustupToolchain
                          {
                            inherit profile components;

                            channel =
                              if    channel == "stable"
                              then  selected
                              else
                                if    selected == "latest"
                                then  channel
                                else  concatStringsSep "-" [ channel selected ]
                              ;
                          }
                        ;

                      path =
                        concatStringsSep
                          "/"
                          [ root "toolchains" self.qualified-target ]
                        ;
                    }
                    ;

                  manifest =
                    {
                      path =
                        utils.fetchManifestFile
                          self.qualified-target
                          self.__toolchainManifest
                        ;

                      values = lib.importTOML self.manifest.path;

                      all-components = attrNames self.manifest.values.pkg;
                    }
                    ;

                  components =
                    utils.writeTOML
                      "multirust-config-${channel}-${selected}.json"
                      {
                        config_version = "1";

                        components =
                          map
                            (
                              pkg:
                              {
                                inherit pkg;
                                target = target-triple;
                                is_extension = false;
                              }
                            )
                            (
                              lib.unique
                                (
                                  (getAttr profile profile-components)
                                ++
                                  components
                                )
                            )
                          ;
                      }
                    ;

                  sha256 =
                    toFile
                      "multirust-channel-manifest-${channel}-${selected}.json.sha256"
                      (
                        substring
                          0
                          20
                          self.__toolchainManifest.sha256
                      )
                    ;

                  modify-env =
                    /* bash */
                    ''
                      # === begin ${self.qualified-target} ===
                      ln -s "${self.sha256}" "$out/update-hashes/${self.qualified-target}"

                      cp -r --no-preserve=mode,ownership "${self.toolchain.drv}" "${self.toolchain.path}"
                      for bin in "${self.toolchain.path}"/bin/*; do
                        [[ -L "$bin" ]] && continue
                        chmod +x $bin
                      done

                      printf "3" > "${self.toolchain.path}/lib/rustlib/rust-installer-version"
                      ln -s "${self.manifest.path}" "${self.toolchain.path}/lib/rustlib/multirust-channel-manifest.toml"
                      ln -s "${self.components}" "${self.toolchain.path}/lib/rustlib/multirust-config.toml"
                      # === end ${self.qualified-target} ===

                    ''
                    ;
                }
              )
            ;
        };

      target-triple = stdenvNoCC.targetPlatform.config;

      profile-components =
        {
          minimal = [ "rustc" "rust-std" "cargo" ];

          default =
            [ "rustc" "rust-std" "cargo" "rust-docs" "rustfmt" "clippy" ]
            ;

          complete =
            [
              "rustc" "rust-std" "cargo" "rust-docs" "rustfmt" "clippy"
              "rust-analyzer" "miri" "rust-src" "rust-mingw" "llvm-tools"
              "rustc-dev" "enzyme"
            ]
            ;
        };

      toolchains' =
        let root = placeholder "out"; in
        {
          stable =
            lib.mapAttrsToList
              (utils.generateToolchains { inherit root; channel = "stable"; })
              (toolchains.stable or {})
            ;

          beta =
            lib.mapAttrsToList
              (utils.generateToolchains { inherit root; channel = "beta"; })
              (toolchains.beta or {})
            ;

          nightly =
            lib.mapAttrsToList
              (utils.generateToolchains { inherit root; channel = "nightly"; })
              (toolchains.nightly or {})
            ;
        };

      write-toolchain-modifications =
        map (getAttr "modify-env") (concatLists (attrValues toolchains'))
        ;

      default-toolchain =
        if    isNull defaultToolchain
        then  ""
        else
          # type validatoin
          assert isList defaultToolchain;
          # bounds validatoin
          assert length defaultToolchain == 2;
          let
            channel = head defaultToolchain;
            selected = elemAt defaultToolchain 1;
          in
          # is the channel a valid value?
          assert elem channel ["stable" "beta" "nightly"];
          # does toolchains'.${selected} have the specified version?
          assert hasAttr selected (getAttr channel toolchains);
          if    channel == "stable"
          then
            ''default_toolchain = "${
              concatStringsSep "-" [selected target-triple]
            }"''
          else
            ''default_toolchain = "${
              concatStringsSep "-" [channel selected target-triple]
            }"''
        ;
    in
      stdenvNoCC.mkDerivation
        (
          self:
          {
            name = "rustup-home";
            unpackPhase = /* bash */ "true";

            propagatedBuildInputs =
              map
                (lib.getAttrFromPath ["toolchain" "drv"])
                (concatLists (attrValues toolchains'))
              ;

            installPhase =
              /* bash */
              ''
                mkdir -p $out/{toolchains,update-hashes}

                ${concatStringsSep "\n" write-toolchain-modifications}

                cat <<EOF > $out/settings.toml
                  version = "12"
                  ${default-toolchain}

                  [overrides]
                EOF
              ''
              ;


            passthru =
              {
                shellHook =
                  /* bash */
                  ''
                    export RUSTUP_HOME="${self.finalPackage}"
                  ''
                  ;

                tests = callPackageSet ./tests {};

                applyWrapper =
                  lib.extendMkDerivation
                    {
                      # constructDrv = symlinkJoin;
                      constructDrv = stdenvNoCC.mkDerivation;
                      excludeDrvArgNames = [ "rustup" ];
                      extendDrvArgs =
                        finalAttrs:
                        { rustup, passthru ? {}, ... }:
                        {
                          name = "rustup-env-wrapper";

                          propagatedBuildInputs = [ rustup ];
                          nativeBuildInputs = [ makeBinaryWrapper ];

                          unpackPhase = /* bash */ "true";

                          installPhase =
                            /* bash */
                            ''
                              cp -r --no-preserve=mode,ownership "${rustup}" "$out"
                              chmod +x $out/bin/*
                              wrapProgram $out/bin/rustup \
                                --set RUSTUP_HOME "${self.finalPackage}" \
                                --set RUSTUP_AUTO_INSTALL "0"
                            ''
                            ;

                          passthru =
                            passthru
                          //
                            {
                              unwrapped = rustup;
                            }
                            ;
                        }
                        ;
                    }
                    ;

                toolchains = toolchains';
              }
              ;
          }
        )
  )
