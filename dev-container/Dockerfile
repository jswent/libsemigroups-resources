FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install development dependencies
RUN apt-get update && apt-get install -y \
    autoconf \
    automake \
    build-essential \
    ccache \
    clang \
    expect \
    g++ \
    git \
    libc6-dbg \
    libtool \
    libtool-bin \
    pkg-config \
    valgrind \
    vim \
    && rm -rf /var/lib/apt/lists/*

# Configure ccache
ENV PATH="/usr/lib/ccache:${PATH}"
ENV CCACHE_DIR=/root/.ccache

# Set up working directory
WORKDIR /workspace

# Configure git
RUN git config --global init.defaultBranch main \
    && git config --global pull.rebase false \
    && git config --global safe.directory '*'

CMD ["/bin/bash"]
