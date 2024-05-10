import {
  genValueRegExp,
  logger,
  read,
  run,
  sha256RegExp,
  versionRegExp,
  write,
} from "./common.ts";

interface Replacer {
  regex: RegExp;
  value: string;
}

const log = logger("src");

const prefetchHash = (botpkgs: string, version: string) =>
  run("nix-prefetch", ["-f", botpkgs, "deno.src", "--rev", version]);
const prefetchCargoHash = (botpkgs: string) =>
  run(
    "nix-prefetch",
    [`{ sha256 }: (import ${botpkgs} {}).deno.cargoDeps.overrideAttrs (_: { hash = sha256; })`],
  );

const replace = (str: string, replacers: Replacer[]) =>
  replacers.reduce(
    (str, r) => str.replace(r.regex, r.value),
    str,
  );

const updateNix = (filePath: string, replacers: Replacer[]) =>
  read(filePath).then((str) => write(filePath, replace(str, replacers)));

const genVerReplacer = (k: string, value: string): Replacer => (
  { regex: genValueRegExp(k, versionRegExp), value }
);
const genShaReplacer = (k: string, value: string): Replacer => (
  { regex: genValueRegExp(k, sha256RegExp), value }
);

export async function updateSrc(
  filePath: string,
  botpkgs: string,
  denoVersion: string,
) {
  log("Starting src update");
  const trimVersion = denoVersion.substring(1);
  log("Fetching hash for:", trimVersion);
  const sha256 = await prefetchHash(botpkgs, denoVersion);
  log("sha256 to update:", sha256);
  await updateNix(
    filePath,
    [
      genVerReplacer("version", trimVersion),
      genShaReplacer("hash", sha256),
    ],
  );
  log("Fetching cargoHash for:", sha256);
  const cargoHash = await prefetchCargoHash(botpkgs);
  log("cargoHash to update:", cargoHash);
  await updateNix(
    filePath,
    [genShaReplacer("cargoHash", cargoHash)],
  );
  log("Finished src update");
}
