#! @runtimeShell@ -e
# shellcheck shell=bash

# Shows the usage of this command to the user

showUsage() {
    exec man botnix-build-vms
    exit 1
}

# Parse valid argument options

nixBuildArgs=()
networkExpr=

while [ $# -gt 0 ]; do
    case "$1" in
      --no-out-link)
        nixBuildArgs+=("--no-out-link")
        ;;
      --show-trace)
        nixBuildArgs+=("--show-trace")
        ;;
      -h|--help)
        showUsage
        exit 0
        ;;
      --option)
        shift
        nixBuildArgs+=("--option" "$1" "$2"); shift
        ;;
      *)
        if [ -n "$networkExpr" ]; then
          echo "Network expression already set!"
          showUsage
          exit 1
        fi
        networkExpr="$(readlink -f "$1")"
        ;;
    esac

    shift
done

if [ -z "$networkExpr" ]
then
    echo "ERROR: A network expression must be specified!" >&2
    exit 1
fi

# Build a network of VMs
nix-build '<botpkgs/botnix/modules/installer/tools/botnix-build-vms/build-vms.nix>' \
    --argstr networkExpr "$networkExpr" "${nixBuildArgs[@]}"
