FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    gnupg2 \
    ca-certificates \
    libcanberra-gtk-module \
    libcanberra-gtk3-module \
    packagekit-gtk3-module \
    libsoup2.4-1 \
    libwebkit2gtk-4.0-37 \
    libgtk-3-0 \
    libnotify4 \
    libnss3 \
    libxss1 \
    libasound2 \
    libgbm1 \
    libpulse0 \
    dbus-x11 \
    xdg-utils \
    && rm -rf /var/lib/apt/lists/*

RUN wget -q -O - \
    https://workspaces-client-linux-public-key.s3-us-west-2.amazonaws.com/ADB332E7.asc \
    | gpg --dearmor -o /usr/share/keyrings/amazon-workspaces-clients.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/amazon-workspaces-clients.gpg] https://d3nt0h4h6pmmc4.cloudfront.net/ubuntu jammy main" \
    > /etc/apt/sources.list.d/amazon-workspaces-clients.list \
    && apt-get update \
    && apt-get install -y workspacesclient \
    && rm -rf /var/lib/apt/lists/*
