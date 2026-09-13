self:
{ callPackage, rustup, ... }:
{
  no-toolchains = callPackage ./no-toolchains.nix {};

  single-toolchain = callPackage ./single-toolchain.nix {};
  single-toolchain-with-default =
    callPackage ./single-toolchain-with-default.nix {}
    ;

  multi-toolchain = callPackage ./multi-toolchain.nix {};
  multi-toolchain-with-default =
    callPackage ./multi-toolchain-with-default.nix {}
    ;
}
