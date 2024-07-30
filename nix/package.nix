{
  lib,
  openssl,
  pkg-config,
  stdenv,
  systemd,
  rustPlatform,
  rev ? "dirty",
  libiconv ? {},
  ...
}: let
  inherit (builtins.fromTOML (builtins.readFile ../Cargo.toml)) package;
in
  rustPlatform.buildRustPackage {
    pname = package.name;
    version =
      if rev == "release"
      then package.version
      else "${package.version}-${rev}";

    src = lib.cleanSourceWith {
      filter = name: _type: let
        baseName = baseNameOf (toString name);
      in
        !(lib.hasSuffix ".nix" baseName);
      src = lib.cleanSource ../.;
    };

    cargoLock.lockFile = ../Cargo.lock;

    nativeBuildInputs = [pkg-config];
    buildInputs =
      [
        systemd
        openssl
      ]
      ++ lib.optionals stdenv.isDarwin [
        libiconv
      ];

    meta.mainProgram = package.name;
  }
