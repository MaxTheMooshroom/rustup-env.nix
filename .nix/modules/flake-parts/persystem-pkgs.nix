{ lib, inputs, options, ... }:
{
  config.flake.overlays.nixpkgs =
    lib.composeManyExtensions
      [
        (import ../../overlays/nixpkgs/call-package-function.nix)
        (import ../../overlays/nixpkgs/rustup.nix)
        (
          final: prev:
          {
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
