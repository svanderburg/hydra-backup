{ nixpkgs ? <nixpkgs>
, systems ? [ "i686-linux" "x86_64-linux" ]
}:

let
  pkgs = import nixpkgs {};
in
{
  build = pkgs.lib.genAttrs systems (system:
    let
      pkgs = import nixpkgs { inherit system; };
      
      hydraBackupDeps = pkgs.buildEnv {
        name = "hydra-backup-deps";
        paths = [
          pkgs.perlPackages.JSON
          pkgs.perlPackages.DBDPg
          pkgs.perlPackages.ListMoreUtils
          pkgs.perlPackages.ListBinarySearch
        ];
      };
    in
    pkgs.stdenv.mkDerivation {
      name = "hydra-backup";
      src = ./.;
      buildInputs = [ pkgs.perl pkgs.makeWrapper hydraBackupDeps ];
      installPhase = ''
        mkdir -p $out/bin
        install -m755 scripts/hydra-backup.pl $out/bin/hydra-backup
        wrapProgram $out/bin/hydra-backup \
            --prefix PERL5LIB : $PERL5LIB
        install -m755 scripts/hydra-collect-backup-garbage.pl $out/bin/hydra-collect-backup-garbage
        wrapProgram $out/bin/hydra-collect-backup-garbage \
            --prefix PERL5LIB : $PERL5LIB
        install -m755 scripts/hydra-restore.pl $out/bin/hydra-restore
        wrapProgram $out/bin/hydra-restore \
            --prefix PERL5LIB : $PERL5LIB
      '';
    }
  );
}
