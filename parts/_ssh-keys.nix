# Public keys only. One key per client device, labelled <device>@minerales.network.
# The leading underscore keeps import-tree from loading this file as a flake-parts module.
rec {
  infra = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIta/YTO7vK7KqWadce0kNY2O618apzWX+Hol3jP7X7i rubi@minerales.network"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF7Sa5hSyj0z5jYprbH8MXJXHi5PucmHDUUAw96y8CRJ cobalto@minerales.network"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIpXSRXYbg97jxtfnnitIgNQLvGnLgZBWE9079qD2U4C lazulita@minerales.network"
    # jade: add its key here once it is generated on the phone
  ];

  # shortcut: the old key that unlocks the cobalto initrd stays there until an unlock with an
  # infra key is tested after a reboot; then delete this list and use `infra` for the initrd.
  transitional = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBM2hEBu4cWTnBMbGdu2bG+sAZu5kBMtc75NFhShmX21"
  ];

  authorized = infra;
  initrd = infra ++ transitional;
}
