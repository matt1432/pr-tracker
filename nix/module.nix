self: {
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) concatStringsSep escapeShellArg getExe mkEnableOption mkIf mkOption optionalAttrs types;

  cfg = config.services.pr-tracker;

  pr-trackerPkg = self.packages.${pkgs.system}.default;
in {
  options.services.pr-tracker = {
    enable = mkEnableOption "pr-tracker";

    package = mkOption {
      type = types.package;
      default = pr-trackerPkg;
    };

    githubApiTokenFile = mkOption {
      type = types.path;
      description = ''
        Path to a file containing your GitHub API token like so:

        ```env
        PR_TRACKER_GITHUB_TOKEN=ghp_...
        ```
      '';
    };

    userAgent = mkOption {
      type = types.str;
      default = "pr-tracker instance";
      description = ''
        The User-Agent string to use when contacting the GitHub API.
      '';
    };

    sourceUrl = mkOption {
      type = types.str;
      default = "https://github.com/matt1432/pr-tracker";
      description = ''
        The URL where users can download the program's source code.
      '';
    };

    user = mkOption {
      default = "pr-tracker";
      type = types.str;
      description = ''
        User account under which pr-tracker runs.

        ::: {.note}
        If left as the default value this user will automatically be created
        on system activation, otherwise you are responsible for
        ensuring the user exists before the pr-tracker service starts.
        :::
      '';
    };

    group = mkOption {
      default = "pr-tracker";
      type = types.str;
      description = ''
        Group account under which pr-tracker runs.

        ::: {.note}
        If left as the default value this user will automatically be created
        on system activation, otherwise you are responsible for
        ensuring the user exists before the pr-tracker service starts.
        :::
      '';
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/pr-tracker";
      description = ''
        The data directory for pr-tracker.

        ::: {.note}
        If left as the default value this directory will automatically be created
        before the pr-tracker server starts, otherwise you are responsible for ensuring
        the directory exists with appropriate ownership and permissions.
        :::
      '';
    };
  };

  config = let
    prestart = pkgs.writeShellScript "pr-tracker-pre" ''
      if [ ! -d ./nixpkgs ]; then
          ${getExe pkgs.git} clone https://github.com/NixOS/nixpkgs.git
      fi
    '';
  in
    mkIf cfg.enable {
      users.users = optionalAttrs (cfg.user == "pr-tracker") {
        pr-tracker = {
          group = cfg.group;
          home = cfg.dataDir;
          isSystemUser = true;
        };
      };

      users.groups = optionalAttrs (cfg.group == "pr-tracker") {
        pr-tracker = {};
      };

      networking.firewall.allowedTCPPorts = [3000];

      systemd.sockets.pr-tracker = {
        listenStreams = ["0.0.0.0:3000"];
        wantedBy = ["sockets.target"];
      };

      systemd.services.pr-tracker = {
        path = [pkgs.git];

        serviceConfig = {
          User = cfg.user;
          Group = cfg.group;
          Restart = "always";

          StateDirectory = builtins.baseNameOf cfg.dataDir;
          WorkingDirectory = cfg.dataDir;
          LimitNOFILE = "1048576";
          PrivateTmp = true;
          PrivateDevices = true;
          StateDirectoryMode = "0700";

          ExecStartPre = prestart;

          ExecStart = concatStringsSep " " [
            (getExe cfg.package)
            "--source-url ${escapeShellArg cfg.sourceUrl}"
            "--user-agent ${escapeShellArg cfg.userAgent}"
            "--path nixpkgs"
            "--remote origin"
          ];

          EnvironmentFile = cfg.githubApiTokenFile;

          # Hardening
          CapabilityBoundingSet = "";
          LockPersonality = true;
          MemoryDenyWriteExecute = true;
          PrivateUsers = true;
          ProtectClock = true;
          ProtectControlGroups = true;
          ProtectHome = true;
          ProtectHostname = true;
          ProtectKernelLogs = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          ProtectProc = "invisible";
          ProcSubset = "pid";
          ProtectSystem = "strict";
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
            "AF_NETLINK"
          ];
          RestrictNamespaces = true;
          RestrictRealtime = true;
          SystemCallArchitectures = "native";
          SystemCallFilter = [
            "@system-service"
            "@pkey"
          ];
          UMask = "0077";
        };
      };

      systemd.timers.pr-tracker-update = {
        wantedBy = ["timers.target"];
        timerConfig = {
          OnBootSec = "30m";
          OnUnitActiveSec = "30m";
        };
      };

      systemd.services.pr-tracker-update = {
        script = ''
          set -eu
          ${getExe pkgs.git} -C nixpkgs fetch
          ${getExe pkgs.curl} http://localhost:3000/update
        '';

        serviceConfig = {
          Requires = "pr-tracker";
          User = cfg.user;
          Group = cfg.group;
          Type = "oneshot";

          EnvironmentFile = cfg.githubApiTokenFile;

          StateDirectory = builtins.baseNameOf cfg.dataDir;
          WorkingDirectory = cfg.dataDir;
          LimitNOFILE = "1048576";
          PrivateTmp = true;
          PrivateDevices = true;
          StateDirectoryMode = "0700";
          ExecStartPre = prestart;
        };
      };
    };
}
