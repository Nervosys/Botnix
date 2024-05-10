{ lib, ... }: {
  options = {
    sub = {
      nixosOk = lib.mkOption {
        type = lib.types.submoduleWith {
          class = "botnix";
          modules = [ ];
        };
      };
      # Same but will have bad definition
      nixosFail = lib.mkOption {
        type = lib.types.submoduleWith {
          class = "botnix";
          modules = [ ];
        };
      };

      mergeFail = lib.mkOption {
        type = lib.types.submoduleWith {
          class = "botnix";
          modules = [ ];
        };
        default = { };
      };
    };
  };
  imports = [
    {
      options = {
        sub = {
          mergeFail = lib.mkOption {
            type = lib.types.submoduleWith {
              class = "darwin";
              modules = [ ];
            };
          };
        };
      };
    }
  ];
  config = {
    _module.freeformType = lib.types.anything;
    ok =
      lib.evalModules {
        class = "botnix";
        modules = [
          ./module-class-is-botnix.nix
        ];
      };

    fail =
      lib.evalModules {
        class = "botnix";
        modules = [
          ./module-class-is-botnix.nix
          ./module-class-is-darwin.nix
        ];
      };

    fail-anon =
      lib.evalModules {
        class = "botnix";
        modules = [
          ./module-class-is-botnix.nix
          { _file = "foo.nix#darwinModules.default";
            _class = "darwin";
            config = {};
            imports = [];
          }
        ];
      };

    sub.nixosOk = { _class = "botnix"; };
    sub.nixosFail = { imports = [ ./module-class-is-darwin.nix ]; };
  };
}
