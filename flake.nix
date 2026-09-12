{
  description =
    "A flake for building rustup derivations with vendored rust toolchains";

  inputs =
    {
      nixpkgs.url = "github:NixOS/nixpkgs/26.05";

      flake-parts.url = "github:hercules-ci/flake-parts";
      flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

      mlib.url = "github:MaxTheMooshroom/mlib.nix";
      mlib.inputs.flake-parts.follows = "flake-parts";

      rust-overlay.url = "github:oxalica/rust-overlay";
    };

  outputs =
    { ... }@inputs:
    inputs.mlib.lib.mkFlake
      { inherit inputs; }
      (
        { lib, ... }:
        {
          systems = lib.systems.flakeExposed;

          imports =
            [
              inputs.mlib.flakeModules.perSystem-packageSets
              ./.nix/modules/flake-parts/persystem-pkgs.nix
            ]
            ;

          perSystem =
            { self', pkgs, ... }:
            # let
            #   packages' = self'.packages;
            # in
            {
              packages =
                {
                  # default = packages'.mkRustupEnv;
                  # mkRustupEnv = pkgs.mkRustupEnv;
                };

              checks =
                {
                  no-toolchains = pkgs.mkRustupEnv {};
                  no-toolchains-wrapped =
                    self'.checks.no-toolchains.applyWrapper
                      { inherit (pkgs) rustup; }
                    ;

                  single-toolchain-stable =
                    pkgs.mkRustupEnv
                      {
                        toolchains.stable."1.93.1" =
                          {
                            profile = "default";
                            components = [ "rust-src" "rust-analyzer" ];
                          };
                      }
                    ;

                  single-toolchain-stable-wrapped =
                    self'.checks.single-toolchain-stable.applyWrapper
                      { inherit (pkgs) rustup; };

                  single-toolchain-with-default-stable =
                    pkgs.mkRustupEnv
                      {
                        toolchains.stable."1.93.1" =
                          {
                            profile = "default";
                            components = [];
                          };

                        defaultToolchain = [ "stable" "1.93.1" ];
                      }
                    ;

                  single-toolchain-with-default-stable-wrapped =
                    self'.checks
                      .single-toolchain-with-default-stable.applyWrapper
                        { inherit (pkgs) rustup; };

                  multi-toolchain-stable =
                    pkgs.mkRustupEnv
                      {
                        toolchains.stable."1.93.1" = {};
                        toolchains.stable."1.92.0" = {};
                        defaultToolchain = [ "stable" "1.93.1" ];
                      }
                      ;

                  multi-toolchain-stable-wrapped =
                    self'.checks.multi-toolchain-stable.applyWrapper
                      { inherit (pkgs) rustup; };

                  single-toolchain-nightly =
                    pkgs.mkRustupEnv
                      {
                        toolchains.nightly."2026-02-05" =
                          {
                            profile = "default";
                            components =
                              [
                                "rust-src" "rustc-dev" "llvm-tools"
                                "rustfmt" "clippy"
                              ];
                          };
                      }
                      ;

                  single-toolchain-nightly-wrapped =
                    self'.checks.single-toolchain-nightly.applyWrapper
                      { inherit (pkgs) rustup; };

                  # rustup-with-local-toolchain =
                  #   packages'.rustup.withToolchains
                  #     (
                  #       { fromToolchainFile, ... }@manifests:
                  #       let
                  #         toolchain = fromToolchainFile ./.rust-toolchain.toml;
                  #       in
                  #       {
                  #         toolchains.${toolchain.version} =
                  #           {
                  #             ${toolchain.target} = toolchain.pkg;
                  #             sha256 = lib.fakeSha256;
                  #           };
                  #       }
                  #     );
                }
                ;

              devShells =
                {
                  default =
                    let
                      rustup-env =
                        pkgs.mkRustupEnv
                          {
                            toolchains.stable."1.93.1" = {};
                            defaultToolchain = [ "stable" "1.93.1" ];
                          }
                        ;

                      rustup =
                        rustup-env.applyWrapper { inherit (pkgs) rustup; }
                        ;
                    in
                    pkgs.mkShell
                      {
                        inputsFrom = [ rustup-env ];
                        packages = [ rustup ];
                      }
                    ;
                }
                ;
            }
            ;
        }
      )
    ;
}
