{
  inputs = {
  };

  outputs = {self, ...}: {
    nixosModules = {
      pr-tracker = import ./modules/pr-tracker.nix;

      default = self.nixosModules.pr-tracker;
    };
  };
}
