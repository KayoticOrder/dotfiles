FROM ubuntu:latest

# Update package lists and install what the install scripts + omnipkg need
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      curl sudo git ca-certificates bash python3 python3-pip build-essential fontconfig && \
    rm -rf /var/lib/apt/lists/*

# Add a non-root user
RUN useradd -ms /bin/bash testuser && echo "testuser:testuser" | chpasswd && usermod -aG sudo testuser && \
    echo '%sudo ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/sudo

# Switch to the non-root user
USER testuser
WORKDIR /home/testuser

# Copy and install dotfiles
RUN mkdir /home/testuser/.dotfiles
COPY --chown=testuser:testuser . /home/testuser/.dotfiles/
RUN git config --global --add safe.directory /home/testuser/.dotfiles

ENV HOME=/home/testuser

WORKDIR /home/testuser/.dotfiles

# INSTALLER/TARGET select what gets installed, e.g.:
#   INSTALLER=install-profile TARGET=ubuntu          (the whole profile)
#   INSTALLER=install-standalone TARGET=alacritty     (a single config)
# VERIFY_ARGS is passed straight to tests/verify.sh - "--profile ubuntu" for
# the whole profile, or a config name for a single install-standalone run.
ARG INSTALLER=install-profile
ARG TARGET=ubuntu
ARG VERIFY_ARGS="--profile ubuntu"

RUN ./${INSTALLER} ${TARGET}

# Verify configs actually got linked and their packages installed
RUN ./tests/verify.sh ${VERIFY_ARGS}

# Default command
CMD ["/bin/bash"]
