final: prev:
{
  rust-toolchain-manifests =
    final.callPackage ../../packages/make-rustup-env/manifests.nix {};

  mkRustupEnv =
    final.callPackageFunction ../../packages/make-rustup-env {};
}
