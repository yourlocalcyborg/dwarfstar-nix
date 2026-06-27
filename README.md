# dwarfstar-nix

A Nix flake that builds [DwarfStar (`ds4`)](https://github.com/antirez/ds4) — antirez's
DeepSeek-V4 inference runtime — with its **ROCm backend for AMD Strix Halo** (`gfx1151`:
Ryzen AI MAX, Radeon 8050S/8060S).

`ds4` is its own vertical engine (not llama.cpp/ollama), hand-tuned for one model family on
one platform. Its upstream build instructions assume Ubuntu + apt; this flake packages the
ROCm build for Nix/NixOS so you get the binaries with one command and no manual ROCm setup.

## Requirements

- An AMD **Strix Halo** machine (Ryzen AI MAX APU, Radeon 8050S/8060S = `gfx1151`) with
  ≥96 GB unified RAM (128 GB recommended).
- Nix with flakes enabled (`experimental-features = nix-command flakes`).
- ROCm device access: your user must be in the `render` group and able to open `/dev/kfd`:
  ```sh
  sudo usermod -aG render,video "$USER"   # then log out and back in
  ```

## Quick start

### 1. Download the model (~81 GB)

DeepSeek-V4-Flash, 2-bit quant — fits 96/128 GB machines. Run this from the directory where
you want the model stored; it writes `./gguf/…` and symlinks `./ds4flash.gguf`.

```sh
nix shell github:paolino/dwarfstar-nix -c ds4-download-model q2-imatrix
```

### 2. Run a prompt

```sh
nix run github:paolino/dwarfstar-nix -- \
  -m ./ds4flash.gguf --rocm --ssd-streaming -p "Hello, who are you?"
```

Add `--nothink` for terse answers; omit it for full reasoning.

### 3. Or run the server (OpenAI-style API)

```sh
nix shell github:paolino/dwarfstar-nix -c \
  ds4-server -m ./ds4flash.gguf --rocm --ssd-streaming --ctx 100000
```

## Performance: `--ssd-streaming` and the GTT aperture

The 81 GB model exceeds the default ~62 GB GPU-visible (GTT) memory on Strix Halo, so the
commands above use `--ssd-streaming` (experts streamed/cached, no kernel changes needed).
It just works, at modest speed (~6 tok/s generation).

For full-residency speed, enlarge the GTT aperture via kernel params and reboot, then drop
`--ssd-streaming`:

```text
amd_iommu=off amdgpu.gttsize=126976 ttm.pages_limit=32505856 ttm.page_pool_size=32505856
```

(On NixOS: `boot.kernelParams = [ "amdgpu.gttsize=126976" … ];` then `nixos-rebuild switch` + reboot.)

## Other GPUs

Default target is `gfx1151`. The flake also exposes `#ds4-gfx1100` (RDNA3 dGPU), or build
for any arch:

```sh
nix build github:paolino/dwarfstar-nix#ds4 --override-input nixpkgs nixpkgs   # default gfx1151
# or override rocmArch in package.nix for another target
```

## Flake outputs

- `packages.x86_64-linux.default` / `.ds4` — the ROCm build (gfx1151)
- `packages.x86_64-linux.ds4-gfx1100` — RDNA3 variant
- `apps.x86_64-linux.default` — runs `ds4`
- `devShells.x86_64-linux.default` — build env + `rocminfo`/`rocm-smi`

Binaries: `ds4`, `ds4-server`, `ds4-bench`, `ds4-eval`, `ds4-agent`, and `ds4-download-model`.

## How the build works

`ds4`'s `strix-halo` Makefile target drives everything through `hipcc`, whose bundled clang
can't host-link on NixOS (no bare `ld`/crt/dynamic-linker). This flake splits the build:
device code (`*.cu`) is compiled by `hipcc` (with the gcc toolchain, glibc headers and ROCm
device-libs spelled out explicitly), and the final host link is done by the Nix-wrapped
`g++`, which handles crt, the dynamic linker and rpaths. See `package.nix`.

## Credits & license

`ds4` / DwarfStar is by [Salvatore Sanfilippo (antirez)](https://github.com/antirez/ds4),
BSD-2-Clause. This packaging (flake glue) is MIT — see `LICENSE`.
