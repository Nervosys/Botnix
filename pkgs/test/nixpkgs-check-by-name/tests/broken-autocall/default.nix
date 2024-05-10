args:
builtins.removeAttrs
  (import <test-botpkgs> { root = ./.; } args)
  [ "foo" ]
