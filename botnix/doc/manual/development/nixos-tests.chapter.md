# Botnix Tests {#sec-nixos-tests}

When you add some feature to Botnix, you should write a test for it.
Botnix tests are kept in the directory `nixos/tests`, and are executed
(using Nix) by a testing framework that automatically starts one or more
virtual machines containing the Botnix system(s) required for the test.

```{=include=} sections
writing-nixos-tests.section.md
running-nixos-tests.section.md
running-nixos-tests-interactively.section.md
linking-nixos-tests-to-packages.section.md
```
