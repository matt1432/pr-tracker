{
  lib,
  openssl,
  pkg-config,
  stdenv,
  systemd,
  rustPlatform,
  libiconv ? {},
  ...
}: let
  inherit (builtins.fromTOML (builtins.readFile ../Cargo.toml)) package;
in
  rustPlatform.buildRustPackage {
    pname = package.name;
    inherit (package) version;

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
