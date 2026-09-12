{
  lib,
  rust-overlay,
}:
let
  manifests = rust-overlay.lib._internal.defaultManifests;

  stable =
    builtins.zipAttrsWith
      (lib.const lib.mergeAttrsList)
      [
        manifests.stable
        (builtins.fromJSON (builtins.readFile ./stable-manifests.json))
      ]
    ;

  beta =
    builtins.zipAttrsWith
      (lib.const lib.mergeAttrsList)
      [
        manifests.stable
        (builtins.fromJSON (builtins.readFile ./beta-manifests.json))
      ]
    ;

  nightly =
    builtins.zipAttrsWith
      (lib.const lib.mergeAttrsList)
      [
        manifests.stable
        (builtins.fromJSON (builtins.readFile ./nightly-manifests.json))
      ]
    ;
in
{
  inherit stable beta nightly;
}
