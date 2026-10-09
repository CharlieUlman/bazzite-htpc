# bazzite-htpc

Bazzite's KDE Gaming Mode image (`bazzite-deck`) with the **legacy proprietary NVIDIA 580 driver** (`nvidia-lts`) for Maxwell / Pascal / Volta GPUs (e.g. GTX 10xx, Titan Xp), which the official `bazzite-deck-nvidia` (nvidia-open only) does not support.

Image: `ghcr.io/charlieulman/bazzite-deck-legacy-nvidia:stable` (rebuilt daily from upstream `:stable`).

How it is built (see `Containerfile`):
1. `FROM ghcr.io/ublue-os/bazzite-deck:stable`
2. Kernel swapped to Bazzite's `ogc-lts` kernel with Bazzite's own `install-kernel-akmods` (the legacy kmods are only built for ogc-lts, same as upstream `bazzite-nvidia`).
3. The upstream `bazzite-nvidia` Containerfile stage, with `NVIDIA_FLAVOR=nvidia-lts`.

Installer ISOs are built with Bazzite's own installer + titanoboa and published as split release assets (GitHub's 2 GiB per-asset limit). Rejoin with:

```powershell
cmd /c copy /b bazzite-deck-nvidia-legacy-custom.iso.part00+bazzite-deck-nvidia-legacy-custom.iso.part01+... bazzite-deck-nvidia-legacy-custom.iso
```

Gaming Mode on NVIDIA is considered beta by Bazzite. To fall back to the desktop image: `sudo bootc switch ghcr.io/ublue-os/bazzite-nvidia:stable`.
