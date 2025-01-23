FROM archlinux:latest

# Update the system and initialize the keyring
RUN pacman -Sy --noconfirm archlinux-keyring && \
    pacman-key --init && \
    pacman-key --populate archlinux && \
    pacman -Syu --noconfirm

# Clear pacman cache and install essential packages
RUN pacman -Scc --noconfirm && \
    pacman -S --noconfirm curl sudo git bash python3 python-pip gcc

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
RUN ./install-profile arch || echo "Profile installation failed but continuing."

# Default command
CMD ["/bin/bash"]
