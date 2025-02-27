#!/usr/bin/env nix-shell
#!nix-shell -I botpkgs=./ -i python3 -p "python3.withPackages (ps: with ps; [ requests ])" -p git -p nix-prefetch-github

import json
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import requests

SCRIPT_PATH = Path(__file__).absolute().parent
HASHES_PATH = SCRIPT_PATH / "hashes.json"
GET_REPO_THREADS = int(os.environ.get("GET_REPO_THREADS", 8))
# To add a new core, add it to the dictionary below. You need to set at least
# `repo`, that is the repository name if the owner of the repository is
# `libretro` itself, otherwise also set `owner`.
# You may set `deep_clone`, `fetch_submodules` or `leave_dot_git` options to
# `True` and they're similar to `fetchgit` options. Also if for some reason you
# need to pin a specific revision, set `rev` to a commit.
# To generate the hash file for your new core, you can run `update_cores.py
# <core>`. The script needs to be run from the root of your `botpkgs` clone.
# Do not forget to add your core to `cores.nix` file with the proper overrides
# so the core can be build.
CORES = {
    "2048": {"repo": "libretro-2048"},
    "atari800": {"repo": "libretro-atari800"},
    "beetle-gba": {"repo": "beetle-gba-libretro"},
    "beetle-lynx": {"repo": "beetle-lynx-libretro"},
    "beetle-ngp": {"repo": "beetle-ngp-libretro"},
    "beetle-pce": {"repo": "beetle-pce-libretro"},
    "beetle-pce-fast": {"repo": "beetle-pce-fast-libretro"},
    "beetle-pcfx": {"repo": "beetle-pcfx-libretro"},
    "beetle-psx": {"repo": "beetle-psx-libretro"},
    "beetle-saturn": {"repo": "beetle-saturn-libretro"},
    "beetle-supafaust": {"repo": "supafaust"},
    "beetle-supergrafx": {"repo": "beetle-supergrafx-libretro"},
    "beetle-vb": {"repo": "beetle-vb-libretro"},
    "beetle-wswan": {"repo": "beetle-wswan-libretro"},
    "blastem": {"repo": "blastem"},
    "bluemsx": {"repo": "bluemsx-libretro"},
    "bsnes": {"repo": "bsnes-libretro"},
    "bsnes-hd": {"repo": "bsnes-hd", "owner": "DerKoun"},
    "bsnes-mercury": {"repo": "bsnes-mercury"},
    "citra": {"repo": "citra", "fetch_submodules": True},
    "desmume": {"repo": "desmume"},
    "desmume2015": {"repo": "desmume2015"},
    "dolphin": {"repo": "dolphin"},
    "dosbox": {"repo": "dosbox-libretro"},
    "dosbox-pure": {"repo": "dosbox-pure", "owner": "schellingb"},
    "eightyone": {"repo": "81-libretro"},
    "fbalpha2012": {"repo": "fbalpha2012"},
    "fbneo": {"repo": "fbneo"},
    "fceumm": {"repo": "libretro-fceumm"},
    "flycast": {"repo": "flycast", "owner": "flyinghead", "fetch_submodules": True},
    "fmsx": {"repo": "fmsx-libretro"},
    "freeintv": {"repo": "freeintv"},
    "fuse": {"repo": "fuse-libretro"},
    "gambatte": {"repo": "gambatte-libretro"},
    "genesis-plus-gx": {"repo": "Genesis-Plus-GX"},
    "gpsp": {"repo": "gpsp"},
    "gw": {"repo": "gw-libretro"},
    "handy": {"repo": "libretro-handy"},
    "hatari": {"repo": "hatari"},
    "mame": {"repo": "mame"},
    "mame2000": {"repo": "mame2000-libretro"},
    "mame2003": {"repo": "mame2003-libretro"},
    "mame2003-plus": {"repo": "mame2003-plus-libretro"},
    "mame2010": {"repo": "mame2010-libretro"},
    "mame2015": {"repo": "mame2015-libretro"},
    "mame2016": {"repo": "mame2016-libretro"},
    "melonds": {"repo": "melonds"},
    "mesen": {"repo": "mesen"},
    "mesen-s": {"repo": "mesen-s"},
    "meteor": {"repo": "meteor-libretro"},
    "mrboom": {"repo": "mrboom-libretro", "owner": "Javanaise", "fetch_submodules": True},
    "mgba": {"repo": "mgba"},
    "mupen64plus": {"repo": "mupen64plus-libretro-nx"},
    "neocd": {"repo": "neocd_libretro"},
    "nestopia": {"repo": "nestopia"},
    "nxengine": {"repo": "nxengine-libretro"},
    "np2kai": {"repo": "NP2kai", "owner": "AZO234", "fetch_submodules": True},
    "o2em": {"repo": "libretro-o2em"},
    "opera": {"repo": "opera-libretro"},
    "parallel-n64": {"repo": "parallel-n64"},
    # libretro/lrps2 is a hard-fork of pcsx2 with simplified code to target
    # only libretro, while libretro/pcsx2 is supposedly closer to upstream but
    # it is a WIP.
    # TODO: switch to libretro/pcsx2 when upstream switches to it.
    "pcsx2": {"repo": "lrps2"},
    "pcsx_rearmed": {"repo": "pcsx_rearmed"},
    "picodrive": {"repo": "picodrive", "fetch_submodules": True},
    "play": {"repo": "Play-", "owner": "jpd002", "fetch_submodules": True},
    "ppsspp": {"repo": "ppsspp", "owner": "hrydgard", "fetch_submodules": True},
    "prboom": {"repo": "libretro-prboom"},
    "prosystem": {"repo": "prosystem-libretro"},
    "puae": {"repo": "libretro-uae"},
    "quicknes": {"repo": "QuickNES_Core"},
    "sameboy": {"repo": "sameboy"},
    "same_cdi": {"repo": "same_cdi"},
    # This is the old source code before they upstreamed the source code,
    # so now the libretro related code lives in the scummvm/scummvm repository.
    # However this broke the old way we were doing builds, so for now point
    # to a mirror with the old source code until this issue is fixed.
    # TODO: switch to libretro/scummvm since this is more up-to-date
    "scummvm": {"repo": "scummvm", "owner": "libretro-mirrors"},
    "smsplus-gx": {"repo": "smsplus-gx"},
    "snes9x": {"repo": "snes9x", "owner": "snes9xgit"},
    "snes9x2002": {"repo": "snes9x2002"},
    "snes9x2005": {"repo": "snes9x2005"},
    "snes9x2010": {"repo": "snes9x2010"},
    "stella": {"repo": "stella", "owner": "stella-emu"},
    "stella2014": {"repo": "stella2014-libretro"},
    "swanstation": {"repo": "swanstation"},
    "tgbdual": {"repo": "tgbdual-libretro"},
    "thepowdertoy": {"repo": "ThePowderToy"},
    "tic80": {"repo": "tic-80", "fetch_submodules": True},
    "vba-m": {"repo": "vbam-libretro"},
    "vba-next": {"repo": "vba-next"},
    "vecx": {"repo": "libretro-vecx"},
    "virtualjaguar": {"repo": "virtualjaguar-libretro"},
    "yabause": {"repo": "yabause"},
}


def info(*msg):
    print(*msg, file=sys.stderr)


def get_rev_date_fetchFromGitHub(repo, owner, rev):
    # https://docs.github.com/en/rest/commits/commits?apiVersion=2022-11-28#get-a-commit
    url = f"https://api.github.com/repos/{owner}/{repo}/commits/{rev}"
    headers = {
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    if token := os.environ.get("GITHUB_TOKEN"):
        headers["Authorization"] = f"Bearer {token}"
    r = requests.get(url, headers=headers)

    try:
        j = r.json()
    except requests.exceptions.JSONDecodeError:
        return None

    date = j.get("commit", {}).get("committer", {}).get("date")
    if date:
        # Date format returned by API: 2023-01-30T06:29:13Z
        return f"unstable-{date[:10]}"
    else:
        return None


def get_repo_hash_fetchFromGitHub(
    repo,
    owner="libretro",
    deep_clone=False,
    fetch_submodules=False,
    leave_dot_git=False,
    rev=None,
):
    extra_args = []
    if deep_clone:
        extra_args.append("--deep-clone")
    else:
        extra_args.append("--no-deep-clone")
    if fetch_submodules:
        extra_args.append("--fetch-submodules")
    else:
        extra_args.append("--no-fetch-submodules")
    if leave_dot_git:
        extra_args.append("--leave-dot-git")
    else:
        extra_args.append("--no-leave-dot-git")
    if rev:
        extra_args.append("--rev")
        extra_args.append(rev)
    result = subprocess.run(
        ["nix-prefetch-github", owner, repo, *extra_args],
        check=True,
        capture_output=True,
        text=True,
    )
    j = json.loads(result.stdout)
    date = get_rev_date_fetchFromGitHub(repo, owner, j["rev"])
    if date:
        j["date"] = date
    # Remove False values
    return {k: v for k, v in j.items() if v}


def get_repo_hash(fetcher="fetchFromGitHub", **kwargs):
    if fetcher == "fetchFromGitHub":
        return get_repo_hash_fetchFromGitHub(**kwargs)
    else:
        raise ValueError(f"Unsupported fetcher: {fetcher}")


def get_repo_hashes(cores={}):
    def get_repo_hash_from_core_def(core_def):
        core, repo = core_def
        info(f"Getting repo hash for '{core}'...")
        result = core, get_repo_hash(**repo)
        info(f"Got repo hash for '{core}'!")
        return result

    with open(HASHES_PATH) as f:
        repo_hashes = json.loads(f.read())

    info(f"Running with {GET_REPO_THREADS} threads!")
    with ThreadPoolExecutor(max_workers=GET_REPO_THREADS) as executor:
        new_repo_hashes = executor.map(get_repo_hash_from_core_def, cores.items())

    for core, repo in new_repo_hashes:
        repo_hashes[core] = repo

    return repo_hashes


def main():
    # If you don't want to update all cores, pass the name of the cores you
    # want to update on the command line. E.g.:
    # $ ./update.py citra snes9x
    if len(sys.argv) > 1:
        cores_to_update = sys.argv[1:]
    else:
        cores_to_update = CORES.keys()

    cores = {core: repo for core, repo in CORES.items() if core in cores_to_update}
    repo_hashes = get_repo_hashes(cores)
    info(f"Generating '{HASHES_PATH}'...")
    with open(HASHES_PATH, "w") as f:
        f.write(json.dumps(dict(sorted(repo_hashes.items())), indent=4))
        f.write("\n")
    info("Finished!")


if __name__ == "__main__":
    main()
