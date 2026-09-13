{ lib, mlib, inputs, options, ... }:
{
  config.flake.overlays.nixpkgs =
    lib.composeManyExtensions
      [
        (import ../../overlays/nixpkgs/rustup.nix)
        (
          final: prev:
          {
            callPackageSet = mlib.callPackageSetWith final;
            callPackageFunction = mlib.callPackageFunctionWith final;
            rust-overlay = inputs.rust-overlay.outputs;
            mkRustBin = final.rust-overlay.lib.mkRustBin {} final;
          }
        )
      ]
    ;

  config.perSystem =
    { system, ... }:
    {
      _module.args.pkgs =
        (import inputs.nixpkgs)
        {
          inherit system;
          overlays = [ options.flake.value.overlays.nixpkgs ];
        }
        ;
    }
    ;
}
