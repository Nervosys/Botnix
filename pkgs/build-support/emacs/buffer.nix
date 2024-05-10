# Functions to build elisp files to locally configure emcas buffers.
# See https://github.com/shlevy/nix-buffer

{ lib, writeText, inherit-local }:

rec {
  withPackages = pkgs': let
      pkgs = builtins.filter (x: x != null) pkgs';
      extras = map (x: x.emacsBufferSetup pkgs) (builtins.filter (builtins.hasAttr "emacsBufferSetup") pkgs);
    in writeText "dir-locals.el" ''
      (require 'inherit-local "${inherit-local}/share/emacs/site-lisp/elpa/inherit-local-${inherit-local.version}/inherit-local.elc")

      ; Only set up botpkgs buffer handling when we have some buffers active
      (defvar botpkgs--buffer-count 0)
      (when (eq botpkgs--buffer-count 0)
        (make-variable-buffer-local 'botpkgs--is-botpkgs-buffer)
        ; When generating a new temporary buffer (one whose name starts with a space), do inherit-local inheritance and make it a botpkgs buffer
        (defun botpkgs--around-generate (orig name &optional ibh)
          (if (and botpkgs--is-botpkgs-buffer (eq (aref name 0) ?\s))
              (let ((buf (funcall orig name ibh)))
                (progn
                  (inherit-local-inherit-child buf)
                  (with-current-buffer buf
                    (setq botpkgs--buffer-count (1+ botpkgs--buffer-count))
                    (add-hook 'kill-buffer-hook 'botpkgs--decrement-buffer-count nil t)))
                buf)
            (funcall orig name ibh)))
        (advice-add 'generate-new-buffer :around #'botpkgs--around-generate)
        ; When we have no more botpkgs buffers, tear down the buffer handling
        (defun botpkgs--decrement-buffer-count ()
          (setq botpkgs--buffer-count (1- botpkgs--buffer-count))
          (when (eq botpkgs--buffer-count 0)
            (advice-remove 'generate-new-buffer #'botpkgs--around-generate)
            (fmakunbound 'botpkgs--around-generate)
            (fmakunbound 'botpkgs--decrement-buffer-count))))
      (setq botpkgs--buffer-count (1+ botpkgs--buffer-count))
      (add-hook 'kill-buffer-hook 'botpkgs--decrement-buffer-count nil t)

      ; Add packages to PATH and exec-path
      (make-local-variable 'process-environment)
      (put 'process-environment 'permanent-local t)
      (inherit-local 'process-environment)
      ; setenv modifies in place, so copy the environment first
      (setq process-environment (copy-tree process-environment))
      (setenv "PATH" (concat "${lib.makeSearchPath "bin" pkgs}:" (getenv "PATH")))
      (inherit-local-permanent exec-path (append '(${builtins.concatStringsSep " " (map (p: "\"${p}/bin\"") pkgs)}) exec-path))

      (inherit-local-permanent eshell-path-env (concat "${lib.makeSearchPath "bin" pkgs}:" (if (boundp 'eshell-path-env) eshell-path-env (getenv "PATH"))))

      (setq botpkgs--is-botpkgs-buffer t)
      (inherit-local 'botpkgs--is-botpkgs-buffer)

      ${lib.concatStringsSep "\n" extras}
    '';
  # nix-buffer function for a project with a bunch of haskell packages
  # in one directory
  haskellMonoRepo = { project-root # The monorepo root
                    , haskellPackages # The composed haskell packages set that contains all of the packages
                    }: { root }:
    let # The haskell paths.
        haskell-paths = lib.filesystem.haskellPathsInDir project-root;
        # Find the haskell package that the 'root' is in, if any.
        haskell-path-parent =
          let filtered = builtins.filter (name:
            lib.hasPrefix (toString (project-root + "/${name}")) (toString root)
          ) (builtins.attrNames haskell-paths);
          in
            if filtered == [] then null else builtins.head filtered;
        # We're in the directory of a haskell package
        is-haskell-package = haskell-path-parent != null;
        haskell-package = haskellPackages.${haskell-path-parent};
        # GHC environment with all needed deps for the haskell package
        haskell-package-env =
          builtins.head haskell-package.env.nativeBuildInputs;
    in
      lib.optionalAttrs is-haskell-package (withPackages [ haskell-package-env ]);
}
