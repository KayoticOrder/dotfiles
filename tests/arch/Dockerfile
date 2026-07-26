FROM archlinux:latest

# Update the system and initialize the keyring
RUN pacman -Sy --noconfirm archlinux-keyring && \
    pacman-key --init && \
    pacman-key --populate archlinux && \
    pacman -Syu --noconfirm

# Clear pacman cache and install essential packages
RUN pacman -Scc --noconfirm && \
    pacman -S --noconfirm curl sudo git bash python3 python-pip gcc fontconfig

# Add a non-root user
RUN useradd -ms /bin/bash testuser && echo "testuser:testuser" | chpasswd && usermod -aG wheel testuser && \
    echo '%wheel ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/wheel

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
#   INSTALLER=install-profile TARGET=arch            (the whole profile)
#   INSTALLER=install-standalone TARGET=alacritty     (a single config)
# VERIFY_ARGS is passed straight to tests/verify.sh - "--profile arch" for
# the whole profile, or a config name for a single install-standalone run.
ARG INSTALLER=install-profile
ARG TARGET=arch
ARG VERIFY_ARGS="--profile arch"

RUN ./${INSTALLER} ${TARGET}

# Verify configs actually got linked and their packages installed
RUN ./tests/verify.sh ${VERIFY_ARGS}

# Default command
CMD ["/bin/bash"]
