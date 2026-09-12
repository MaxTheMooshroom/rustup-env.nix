
# Rustup-Env.nix

This flake provides a builder for rustup environments. The resulting derivation
should be assigned to the `RUSTUP_HOME` environment variable available to rustup.

To produce a rustup environment:

```nix
{
  inputs =
    {
      nixpkgs.url = "github:NixOS/nixpkgs/26.05";

      flake-parts.url = "github:hercules-ci/flake-parts";
      flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

      mk-rustup-env.url = "github:MaxTheMooshroom/rustup-env.nix";
      mk-rustup-env.inputs.nixpkgs.follows = "nixpkgs";
      mk-rustup-env.inputs.flake-parts.follows = "flake-parts";
    }
    ;

  outputs =
    { flake-parts, ... }@inputs:
    flake-parts.lib.mkFlake
      { inherit inputs; }
      (
        { lib, ... }:
        {
          systems = lib.systems.flakeExposed;

          perSystem =
            { system, self', pkgs, ... }:
            {
              _module.args.pkgs =
                (import inputs.nixpkgs)
                  {
                    inherit system;
                    overlays = [ inputs.mk-rustup-env.overlays.nixpkgs ];
                  }
                  ;

              packages.default = self'.packages.my-package;

              packages.my-package =
                pkgs.stdenv.mkDerivation
                  {
                    pname = "my-package";
                    version = "0.1.0";

                    src = ./.;

                    nativeBuildInputs = [ self'.packages.rustup ];

                    # ...
                  }
                  ;

              packages.rustup-env =
                pkgs.mkRustupEnv
                  {
                    toolchains.stable."1.93.1" =
                      {
                        profile = "default";
                        components = [ "rust-analyzer" ];
                      }
                      ;
                  }
                ;

              packages.rustup =
                self'.packages.rustup-env.applyWrapper { inherit (pkgs) rustup; }
                ;

              devShells.default =
                pkgs.mkShell
                  {
                    inputsFrom = [ self'.packages.rustup-env ];
                    packages = [ pkgs.rustup ];
                  }
                  ;
            }
            ;
        }
      )
      ;
}
```

