{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf types;
  inherit (lib.lists) optionals;
  inherit (lib.attrsets) optionalAttrs;
  inherit (lib.strings) concatStringsSep escapeShellArg;
  inherit (lib.options) mkEnableOption mkOption mkPackageOption;

  cfg = config.services.pr-tracker;
in {
  options.services.pr-tracker = {
    enable = mkEnableOption "pr-tracker";

    package = mkPackageOption pkgs "pr-tracker" {};

    githubApiTokenFile = mkOption {
      type = types.path;
      description = ''
        Path to a file containing your GitHub API token like so:

        ```env
        ghp_...
        ```

        ::: {.note}
        The contents of this file will be the stdin of pr-tracker.
        :::
      '';
    };

    nixpkgsClone = {
      cloneDir = mkOption {
        type = types.path;
        default = "${cfg.dataDir}/nixpkgs";
        description = ''
          The path to the cloned nixpkgs pr-tracker will use.

          ::: {.note}
          If left as the default value this repo will automatically be cloned before
          the pr-tracker server starts, otherwise you are responsible for ensuring
          the directory exists with appropriate ownership and permissions.
          :::
        '';
      };

      remote = mkOption {
        type = types.str;
        default = "origin";
        description = ''
          The remote name in the repository corresponding to upstream Nixpkgs.
        '';
      };

      managedByModule = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Whether you want this service to manage a clone of the nixpkgs
          repo in ${cfg.dataDir}.
        '';
      };

      interval = mkOption {
        type = types.str;
        default = "30min";
        description = ''
          How often to fetch nixpkgs if `cfg.nixpkgsClone.managedByModule` is true.
        '';
      };
    };

    userAgent = mkOption {
      type = types.str;
      default = "pr-tracker by alyssais";
      description = ''
        The User-Agent string to use when contacting the GitHub API.
      '';
    };

    sourceUrl = mkOption {
      type = types.str;
      default = "https://git.qyliss.net/pr-tracker";
      description = ''
        The URL where users can download the program's source code.
      '';
    };

    mountPath = mkOption {
      type = with types; nullOr str;
      default = null;
      description = ''
        A "mount" path can be specified, which will be prefixed to all
        of the server's routes, so that it can be served at a non-root
        HTTP path.
      '';
    };

    user = mkOption {
      default = "pr-tracker";
      type = types.str;
      description = ''
        User account under which pr-tracker runs.

        ::: {.note}
        If left as the default value this user will automatically be created
        on system activation, otherwise you are responsible for ensuring the
        user exists before the pr-tracker service starts.
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
        on system activation, otherwise you are responsible for ensuring the
        user exists before the pr-tracker service starts.
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
    useClone = cfg.nixpkgsClone.managedByModule;

    prestart = "${pkgs.writeShellApplication {
      name = "pr-tracker-pre";
      runtimeInputs = [pkgs.git];

      text = ''
        if [ ! -d ${cfg.nixpkgsClone.cloneDir} ]; then
            git clone https://github.com/NixOS/nixpkgs.git ${cfg.nixpkgsClone.cloneDir}
        fi
      '';
    }}/bin/pr-tracker-pre";

    commonUnitSettings = {
      User = cfg.user;
      Group = cfg.group;

      StateDirectory = builtins.baseNameOf cfg.dataDir;
      WorkingDirectory = cfg.dataDir;
      LimitNOFILE = "1048576";
      PrivateTmp = true;
      PrivateDevices = true;
      StateDirectoryMode = "0700";
    };
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

        serviceConfig =
          optionalAttrs useClone {ExecStartPre = prestart;}
          // commonUnitSettings
          // {
            Restart = "always";

            StandardInput = "file:${cfg.githubApiTokenFile}";

            ExecStart = concatStringsSep " " ([
                "${cfg.package}/bin/pr-tracker"
                "--source-url ${escapeShellArg cfg.sourceUrl}"
                "--user-agent ${escapeShellArg cfg.userAgent}"
                "--path ${cfg.nixpkgsClone.cloneDir}"
                "--remote ${cfg.nixpkgsClone.remote}"
              ]
              ++ optionals (cfg.mountPath != null) [
                "--mount ${cfg.mountPath}"
              ]);

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

      systemd.timers.pr-tracker-update = optionalAttrs useClone {
        wantedBy = ["timers.target"];
        timerConfig = {
          OnBootSec = cfg.nixpkgsClone.interval;
          OnUnitActiveSec = cfg.nixpkgsClone.interval;
        };
      };

      systemd.services.pr-tracker-update = optionalAttrs useClone {
        path = with pkgs; [git curl];

        script = ''
          set -eu

          git -C ${cfg.nixpkgsClone.cloneDir} fetch
          curl http://localhost:3000/update
        '';

        serviceConfig =
          commonUnitSettings
          // {
            Requires = "pr-tracker";
            Type = "oneshot";
            ExecStartPre = prestart;
          };
      };
    };
}
