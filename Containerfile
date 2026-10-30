FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Packages distrobox-init would otherwise install on first `distrobox enter`
# (see setup_apt in /usr/bin/distrobox-init), plus Mesa GPU drivers and all
# VA-API video decode drivers (Intel iHD + i965, Mesa for AMD).
# Installing them here and creating /.containersetupdone (below) makes
# distrobox skip its runtime package setup, so the container matches the image.
RUN apt-get update && apt-get install -y --no-install-recommends \
    apt-utils \
    bash \
    bash-completion \
    bc \
    bzip2 \
    ca-certificates \
    curl \
    dialog \
    diffutils \
    findutils \
    gnupg \
    gpgsm \
    hostname \
    iproute2 \
    iputils-ping \
    keyutils \
    less \
    libcap2-bin \
    libkrb5-3 \
    libnss-mdns \
    libnss-myhostname \
    libvte-2.91-common \
    locales \
    lsof \
    man-db \
    ncurses-base \
    openssh-client \
    passwd \
    pigz \
    pinentry-curses \
    procps \
    rsync \
    sudo \
    time \
    tree \
    tzdata \
    unzip \
    util-linux \
    wget \
    xauth \
    xdg-utils \
    xz-utils \
    zip \
    libgl1 \
    libegl1 \
    libegl-mesa0 \
    libglx-mesa0 \
    libgl1-mesa-dri \
    libvulkan1 \
    mesa-vulkan-drivers \
    va-driver-all \
    vainfo \
    && sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen \
    && locale-gen \
    && rm -rf /var/lib/apt/lists/*

# AWS WorkSpaces client from the official Ubuntu 24.04 (noble) repo.
# The package declares its own runtime dependencies (WebKitGTK 4.1, etc.).
RUN wget -q -O - \
    https://workspaces-client-linux-public-key.s3-us-west-2.amazonaws.com/ADB332E7.asc \
    | gpg --dearmor -o /usr/share/keyrings/amazon-workspaces-clients.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/amazon-workspaces-clients.gpg] https://d3nt0h4h6pmmc4.cloudfront.net/ubuntu noble main" \
    > /etc/apt/sources.list.d/amazon-workspaces-clients.list \
    && apt-get update \
    && apt-get install -y workspacesclient \
    && rm -rf /var/lib/apt/lists/*

# Tell distrobox-init the package setup is already done.
RUN touch /.containersetupdone
