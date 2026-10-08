# Koderup Laptop-manual

Danish user manual for the managed laptops (written to the laptop user, "anon").
Authored with [mdBook](https://rust-lang.github.io/mdBook/), served on every laptop
at `http://localhost:8888` (localhost only) by
[`modules/manual.nix`](../../modules/manual.nix).

## Layout

- `book.toml` — mdBook configuration
- `src/SUMMARY.md` — chapter list (the sidebar table of contents)
- `src/chapters/*.md` — the actual chapters, in Danish
- `book/` — build output; **never commit this** (gitignored)

The fleet screenshots in the repo `docs/` directory (`*.png`) are copied next to the
rendered pages at build time, so chapters can reference them relative to the site
root (f.x. `../browser-configured.png`).

## Preview locally

From the devshell (`nix develop`):

```sh
just manual
```

That builds the book and serves it at `http://localhost:8888` — the same URL (and the
same plain `python3 -m http.server`) as on the laptops.

## How it ships to laptops

The markdown never reaches a laptop. During the NixOS config build,
`modules/manual.nix` runs `mdbook build` (mdbook comes from the locked nixpkgs) and
the rendered HTML becomes a Nix store path. A systemd service
(`koderup-manual.service`) serves that store path on `127.0.0.1:8888`. The store path
is part of the system closure, so laptops get it via `nixos-rebuild` /
`nixos-anywhere` and the nightly `system.autoUpgrade` (which fetches this git repo
with `--refresh`).

**Edits only reach laptops once they are committed and pushed** — then the ~17:30
auto-upgrade (or `just rebuild HOST`) picks them up. Because the mdBook derivation
ingests the whole `docs/manual/` tree, every docs change triggers a configuration
change (validated by CI's koderup1 build).