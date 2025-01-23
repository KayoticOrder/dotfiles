import os
import re
import subprocess
from typing import Mapping, Callable, Iterable, Any
import dotbot


class Yay(dotbot.Plugin):
    """
    Dotbot plugin for yay (an AUR helper), analogous to Brew/Pacman plugins.
    """

    _directives: Mapping[str, Callable] = {}
    _defaults: Mapping[str, Any] = {}

    def __init__(self, *args, **kwargs) -> None:
        # Define which directives this plugin can handle.
        self._directives = {
            "yay": self._yay,  # For installing a list of packages
            "yayfile": self._yayfile,  # For installing packages from file(s)
            "install-yay": self._install_yay,  # Optional directive to ensure yay is installed
        }

        # Define default behaviors for each directive.
        self._defaults = {
            "yay": {
                "stdin": False,
                "stderr": False,
                "stdout": False,
                "need_sudo": False,  # Typically yay does not need sudo for normal usage
                "refresh_db": True,  # Whether to run yay -Sy before installing
            },
            "yayfile": {
                "stdin": True,
                "stderr": True,
                "stdout": True,
                "need_sudo": False,
                "refresh_db": True,
            },
            "install-yay": {
                "stdin": True,
                "stderr": True,
                "stdout": True,
                "need_sudo": False,
            },
        }
        super().__init__(*args, **kwargs)

    def can_handle(self, directive: str) -> bool:
        """Check if this plugin can handle the given directive."""
        return directive in self._directives

    def handle(self, directive: str, data: Iterable) -> bool:
        """
        Main Dotbot entry point: calls the function
        for the specified directive with user-provided data.
        """
        # Merge defaults from dotbot config and local plugin settings
        user_defaults = self._context.defaults().get(directive, {})
        local_defaults = self._defaults.get(directive, {})
        defaults = {**local_defaults, **user_defaults}

        return self._directives[directive](data, defaults)

    def _invoke_shell_command(self, cmd: str, defaults: Mapping[str, Any]) -> int:
        """
        Helper method to run shell commands with optional I/O redirection
        and optional sudo (if needed).
        """
        with open(os.devnull, "w") as devnull:
            if defaults.get("need_sudo", False):
                cmd = f"sudo {cmd}"

            return subprocess.call(
                cmd,
                shell=True,
                cwd=self._context.base_directory(),
                stdin=devnull if defaults["stdin"] else None,
                stdout=devnull if defaults["stdout"] else None,
                stderr=devnull if defaults["stderr"] else None,
            )

    def _check_installed(self, pkg_name: str) -> bool:
        """
        Check if a given package is installed via yay.
        If 'yay -Q <pkg>' returns 0, it's installed.
        """
        with open(os.devnull, "w") as devnull:
            status = subprocess.call(
                f"yay -Q {pkg_name}",
                shell=True,
                stdin=devnull,
                stdout=devnull,
                stderr=devnull,
                cwd=self._context.base_directory(),
            )
        return status == 0

    def _yay(self, packages: Iterable[str], defaults: Mapping[str, Any]) -> bool:
        """
        Installs a list of packages via yay.
        Example usage in install.conf.yaml:
          - yay:
              - zsh
              - google-chrome
              - spotify
        """
        result = True

        # Optionally refresh the package database
        if defaults.get("refresh_db", True):
            self._log.info("Refreshing package databases (yay -Sy)...")
            if self._invoke_shell_command("yay -Sy --noconfirm", defaults) != 0:
                self._log.error("Failed to refresh package databases.")
                return False

        for pkg in packages:
            if not pkg:
                self._log.error("Cannot process blank package name.")
                result = False
                continue

            # Extract the actual package name (strip out extra arguments/spaces)
            pkg_strip = pkg.strip()
            pkg_name_match = re.search(r"^([\w\-.+]+)", pkg_strip)
            if not pkg_name_match:
                self._log.error(f"Package name '{pkg}' could not be parsed.")
                result = False
                continue

            pkg_name = pkg_name_match[1]

            # Check if already installed
            if self._check_installed(pkg_name):
                self._log.lowinfo(f"{pkg_name} is already installed.")
                continue

            self._log.info(f"Installing {pkg_name} via yay...")
            cmd = f"yay -S --noconfirm {pkg_name}"
            if self._invoke_shell_command(cmd, defaults) != 0:
                self._log.error(f"Failed to install '{pkg_name}'.")
                result = False
            else:
                self._log.lowinfo(f"Successfully installed '{pkg_name}'.")

        if result:
            self._log.info("All specified yay packages have been processed.")
        else:
            self._log.warning("Some packages failed to install.")

        return result

    def _yayfile(self, yay_files: Iterable[str], defaults: Mapping[str, Any]) -> bool:
        """
        Installs packages from one or more files. Each file can have one
        package per line. For example:
          google-chrome
          spotify
          slack
        Example usage in install.conf.yaml:
          - yayfile:
              - packages-aur.txt
              - packages-extra.txt
        """
        result = True

        # Optionally refresh the package database
        if defaults.get("refresh_db", True):
            self._log.info("Refreshing package databases (yay -Sy)...")
            if self._invoke_shell_command("yay -Sy --noconfirm", defaults) != 0:
                self._log.error("Failed to refresh package databases.")
                return False

        for file in yay_files:
            file_path = os.path.join(self._context.base_directory(), file)
            if not os.path.exists(file_path):
                self._log.error(f"File not found: {file_path}")
                result = False
                continue

            with open(file_path, "r") as pkg_file:
                packages = [line.strip() for line in pkg_file if line.strip()]

            for pkg in packages:
                if self._check_installed(pkg):
                    self._log.lowinfo(f"{pkg} is already installed.")
                    continue

                self._log.info(f"Installing {pkg} from {file} via yay...")
                cmd = f"yay -S --noconfirm {pkg}"
                if self._invoke_shell_command(cmd, defaults) != 0:
                    self._log.error(f"Failed to install '{pkg}'.")
                    result = False
                else:
                    self._log.lowinfo(f"Successfully installed '{pkg}'.")

        if result:
            self._log.info("All packages from yay files have been processed.")
        else:
            self._log.warning("Some packages failed to install from the listed files.")

        return result

    def _install_yay(self, val: bool, defaults: Mapping[str, Any]) -> bool:
        """
        Optional directive: tries to ensure `yay` is installed on the system.
        - If 'yay' is already present, does nothing.
        - Otherwise, attempts to clone and install it from the AUR.

        In your `install.conf.yaml`, you'd do:
          - install-yay: true
        """
        if not val:
            self._log.error("`install-yay: false` doesn't do anything.")
            return False

        # Check if yay is already available
        with open(os.devnull, "w") as devnull:
            yay_check = subprocess.call(
                "command -v yay",
                shell=True,
                stdin=devnull,
                stdout=devnull,
                stderr=devnull,
                cwd=self._context.base_directory(),
            )

        if yay_check == 0:
            self._log.lowinfo("Yay is already installed.")
            return True

        # Attempt to install yay from AUR (requires base-devel, git, etc.)
        self._log.info("Yay not found; attempting to install it from the AUR.")
        commands = [
            "sudo pacman -S --noconfirm --needed base-devel git",
            "rm -rf /tmp/yay_install && mkdir -p /tmp/yay_install",
            "git clone https://aur.archlinux.org/yay.git /tmp/yay_install",
            "cd /tmp/yay_install && makepkg -si --noconfirm",
        ]

        for cmd in commands:
            if self._invoke_shell_command(cmd, defaults) != 0:
                self._log.error(f"Command failed: {cmd}")
                return False

        # Verify yay is installed now
        if self._invoke_shell_command("command -v yay", defaults) != 0:
            self._log.error("Installation of yay appears to have failed.")
            return False

        self._log.lowinfo("Successfully installed yay.")
        return True
