# bazzite-deck-legacy-nvidia
#
# Bazzite's KDE Gaming Mode image (bazzite-deck) with the LEGACY proprietary
# NVIDIA driver (nvidia-lts / 580 branch) for Maxwell/Pascal/Volta GPUs.
#
# Upstream only ships nvidia-open on the deck images, which does not support
# Pascal. The legacy kmods are only built for Bazzite's ogc-lts kernel, which is
# why upstream bazzite-nvidia runs ogc-lts (commit 3eb7b094 "Use LTS kernel for
# LTS Nvidia Driver"). So this image:
#   1. starts FROM the official bazzite-deck image,
#   2. swaps its kernel to ogc-lts using Bazzite's own install-kernel-akmods,
#   3. runs the same steps as Bazzite's "bazzite-nvidia" Containerfile stage
#      with NVIDIA_FLAVOR=nvidia-lts.
#
# upstream/ is a checkout of ublue-os/bazzite at the exact revision the base
# image was built from (done by the workflow). Build args are also filled in by
# the workflow from the upstream :stable image labels.

ARG BASE_IMAGE="ghcr.io/ublue-os/bazzite-deck:stable"
ARG AKMODS_TAG="ogc-lts-44-6.18.52-ogc1.1.fc44.x86_64"

FROM ghcr.io/ublue-os/akmods:${AKMODS_TAG} AS akmods
FROM ghcr.io/ublue-os/akmods-extra:${AKMODS_TAG} AS akmods-extra
FROM ghcr.io/ublue-os/akmods-nvidia-lts:${AKMODS_TAG} AS akmods-nvidia

FROM scratch AS ctx
COPY upstream/build_files /
COPY build_files /custom

FROM ${BASE_IMAGE}

ARG IMAGE_NAME="bazzite-deck-legacy-nvidia"
ARG IMAGE_VENDOR="ublue-os"
ARG IMAGE_BRANCH="stable"
ARG BASE_IMAGE_NAME="kinoite"
ARG KERNEL_FLAVOR="ogc-lts"
ARG NVIDIA_FLAVOR="nvidia-lts"
ARG VERSION_TAG
ARG VERSION_PRETTY

# Swap kernel ogc -> ogc-lts (plus matching common/extra kmods such as xone)
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=bind,from=akmods,src=/kernel-rpms,dst=/tmp/kernel-rpms \
    --mount=type=bind,from=akmods,src=/rpms/common,dst=/tmp/rpms/common \
    --mount=type=bind,from=akmods,src=/rpms/kmods,dst=/tmp/rpms/kmods \
    --mount=type=bind,from=akmods-extra,src=/rpms/extra,dst=/tmp/rpms/extra \
    --mount=type=bind,from=akmods-extra,src=/rpms/kmods,dst=/tmp/rpms/kmods-extra \
    /ctx/custom/pre-kernel-swap && \
    /ctx/install-kernel-akmods && \
    /ctx/custom/post-kernel-swap && \
    /ctx/cleanup

################################################################
# Below mirrors the "bazzite-nvidia" stage of ublue-os/bazzite
################################################################

# Fetch NVIDIA driver
COPY upstream/system_files/nvidia/shared upstream/system_files/nvidia/kinoite /

# Remove everything that doesn't work well with NVIDIA, unset skip_if_unavailable option if was set beforehand
# (upstream runs the nvidia-lts block on the desktop image; the deck image may
# not ship every cardwire package, so those steps are guarded here)
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    dnf5 config-manager unsetopt skip_if_unavailable && \
    dnf5 -y remove \
        nvidia-gpu-firmware && \
    if [ "${NVIDIA_FLAVOR}" = "nvidia-lts" ]; then \
        { systemctl disable cardwired.service || true; } && \
        if rpm -q cardwire-gui; then dnf5 -y remove cardwire-gui; fi && \
        if rpm -q cardwire; then dnf5 -y swap cardwire switcheroo-control; fi && \
        dnf5 -y install --enable-repo=terra \
            supergfxctl \
    ; fi && \
    if ! grep -q "deck" <<< "${IMAGE_NAME}"; then \
        rm -f /usr/lib/modprobe.d/nvidia-deck.conf \
    ; fi && \
    /ctx/cleanup

# Install NVIDIA driver
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=bind,from=akmods-nvidia,src=/rpms,dst=/tmp/rpms/nvidia \
    --mount=type=tmpfs,dst=/tmp \
    dnf5 config-manager setopt "terra-mesa".enabled=1 && \
    dnf5 -y copr enable ublue-os/staging && \
    dnf5 -y install \
        egl-wayland.x86_64 \
        egl-wayland.i686 \
        egl-wayland2.x86_64 \
        egl-wayland2.i686 && \
    IMAGE_NAME="SKIP_PACKAGE_INSTALL" AKMODNV_PATH="/tmp/rpms/nvidia" MULTILIB=1 /tmp/rpms/nvidia/ublue-os/nvidia-install.sh && \
    rm -f /usr/share/vulkan/icd.d/nouveau_icd.*.json && \
    ln -sf libnvidia-ml.so.1 /usr/lib64/libnvidia-ml.so && \
    dnf5 config-manager setopt "terra-mesa".enabled=0 && \
    dnf5 -y copr disable ublue-os/staging && \
    dnf5 -y swap \
        --repo terra-extras \
            waydroid waydroid-nvidia && \
    /ctx/cleanup

# Cleanup & Finalize
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    echo "import \"/usr/share/ublue-os/just/95-bazzite-nvidia.just\"" >> /usr/share/ublue-os/justfile && \
    sed -i 's/ nvidia_peermem\b//' /usr/lib/dracut/dracut.conf.d/99-nvidia.conf && \
    systemctl enable nvidia-powerd.service && \
    systemctl disable nvidia-persistenced.service && \
    systemctl enable ublue-nvidia-flatpak-runtime-sync && \
    systemctl enable ublue-nvidia-flatpak-runtime-verify && \
    dnf5 config-manager setopt skip_if_unavailable=1 && \
    if [ -f /etc/modprobe.d/nvidia-modeset.conf ]; then \
      cp /etc/modprobe.d/nvidia-modeset.conf /usr/lib/modprobe.d/nvidia-modeset.conf \
    ; fi && \
    /ctx/image-info && \
    /ctx/build-initramfs && \
    /ctx/finalize

RUN --mount=type=tmpfs,target=/run --network=none bootc container lint
