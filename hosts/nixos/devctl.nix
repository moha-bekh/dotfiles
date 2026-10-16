# devctl (github.com/moha-bekh/devctl): the RGB of the RAM, GPU, board and
# mouse, and the GPU fans. What its README's install does on Arch, plus the
# NVIDIA driver the GPU's i2c bus and NVML come from. Imported from
# configuration.nix; the lighting itself is config/devctl/config.toml, linked
# by scripts/link.sh.
{ config, pkgs, ... }:

let
  src = builtins.fetchGit {
    url = "https://github.com/moha-bekh/devctl";
    ref = "main";
  };
  devctl = pkgs.callPackage "${src}/nix/package.nix" { };
in
{
  environment.systemPackages = [ devctl ];

  # The GPU's i2c bus ("NVIDIA i2c adapter 1") and NVML need NVIDIA's driver,
  # the open kernel modules as on Arch (nvidia-open).
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia.open = true;

  # /dev/i2c-N, and the devices open to the rgb group.
  boot.kernelModules = [ "i2c-dev" ];
  users.groups.rgb = { };
  users.users.moha.extraGroups = [ "rgb" ];
  services.udev.extraRules = ''
    KERNEL=="i2c-[0-9]*", GROUP="rgb", MODE="0660"
    KERNEL=="hidraw*", ATTRS{idVendor}=="1462", ATTRS{idProduct}=="7b93", GROUP="rgb", MODE="0660"
    KERNEL=="hidraw*", ATTRS{idVendor}=="2516", ATTRS{idProduct}=="0101", GROUP="rgb", MODE="0660"
  '';

  # Holds the GPU fans at the saved minimum (root, for the fan speeds).
  systemd.services.devctl-fan = {
    description = "devctl GPU fan control (keeps the GPU RGB on)";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${devctl}/bin/devctl --config /home/moha/.config/devctl/config.toml fan daemon";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  # Shows the saved lighting at login.
  systemd.user.services.devctl = {
    description = "devctl: restore the saved lighting";
    after = [ "graphical-session.target" ];
    wantedBy = [ "default.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${devctl}/bin/devctl on";
    };
  };
}
