{
  inputs = {
    nixpkgs = {
      type = "github";
      owner = "NixOS";
      repo = "nixpkgs";
      ref = "nixos-unstable";
    };

    rust-overlay = {
      type = "github";
      owner = "oxalica";
      repo = "rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    devshell = {
      type = "github";
      owner = "numtide";
      repo = "devshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    rust-overlay,
    devshell,
    ...
  }: let
    supportedSystems = [
      "x86_64-linux"
      "aarch64-linux"
    ];

    perSystem = attrs:
      nixpkgs.lib.genAttrs supportedSystems (system:
        attrs (import nixpkgs {
          inherit system;
          overlays = [
            devshell.overlays.default
            rust-overlay.overlays.default
          ];
        }));
  in {
    packages = perSystem (pkgs: let
      rustPlatform = let
        toolchain = pkgs.rust-bin.selectLatestNightlyWith (toolchain: toolchain.default);
      in (pkgs.makeRustPlatform {
        cargo = toolchain;
        rustc = toolchain;
      });
    in {
      pr-tracker = pkgs.callPackage ./nix/package.nix {inherit rustPlatform;};
      default = self.packages.${pkgs.system}.pr-tracker;
    });

    formatter = perSystem (pkgs: pkgs.alejandra);

    devShells = perSystem (pkgs: let
      mainPackage = self.packages.${pkgs.system}.default;
    in {
      default = pkgs.devshell.mkShell {
        inherit (mainPackage) name;

        imports = [
          "${devshell}/extra/language/c.nix"
          "${devshell}/extra/language/rust.nix"
        ];
        language.c.libraries = with pkgs; [
          systemd
          openssl
        ];
        language.c.includes = with pkgs; [
          openssl
        ];

        packages =
          mainPackage.buildInputs
          ++ [
            pkgs.pkg-config
            pkgs.rust-analyzer
          ];
      };
    });
  };
}
