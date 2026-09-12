final: prev:
let
  inherit (final) lib;

  orAllValues = lib.const (builtins.any lib.id);
in
{
  #? composeOverridesOf :: F1 -> F2 -> (set -> )
  #? F1 :: { __functor :: (F1 -> set -> F2), override :: (set -> F1), ... }
  #? F2 :: { __functor :: (F2 -> set -> R), override :: (set -> F2), ... }
  composeOverridesOf =
    f1: f2: default-f2-args:
    let
      f1-args = lib.functionArgs f1.override;
      f2-args = lib.functionArgs f2.override;
    in
      {
        inherit f1 f2 f1-args f2-args default-f2-args;

        __functionArgs =
          builtins.zipAttrsWith
            orAllValues
            [f1-args f2-args];

        __functor =
          { f1, f1-args, f2, f2-args, default-f2-args, ... }:
          { ... }@args:
          let
            args-1 = builtins.intersectAttrs f1-args args;
            args-2 = default-f2-args // (builtins.intersectAttrs f2-args args);
          in
            if    args-1 != {}
            then  f1.override args-1 args-2
            else
              if    args-2 != {}
              then  f2.override args-2
              else  f2;
      }
      ;

  #? callPackageFunction :: topFnPackage ->
  #? topFnPackage :: (A -> (B :: { override :: (A -> B), __functor :: (B -> set -> D) })
  #? 
  callPackageFunction =
    fn: pkg-args:
    let pkg-fn = final.callPackage fn pkg-args; in
    {
      inherit pkg-fn;

      __functionArgs = lib.functionArgs pkg-fn;

      __functor =
        { pkg-fn, ... }:
        args:
        let pkg = pkg-fn args; in
        pkg // { override = final.composeOverridesOf pkg-fn pkg args; };
    };
}
