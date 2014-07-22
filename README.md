hydra-backup
============
This package contains a collection of scripts allowing me to conveniently make
backups of [Hydra](http://nixos.org/hydra) releases and store them on different
media.

All the scripts use a JSON configuration file that may have the following
structure:

    {
      "dbiConnection": "dbi:Pg:dbname=hydra;host=localhost;user=hydra;",
  
      "outDir": "/home/sander/hydrabackup",
  
      "releases": [
        {
          "project": "disnix",
          "name": "disnix-0.3",
          "method": "binary"
        }
      ]
    }

The configuration file defines an object with three fields:
* _dbiConnection_ contains the Perl DBI connection string that connects to Hydra's PostgreSQL database instance.
* _outDir_ refers to a path in which the binary cache and other backup files will be stored. This path could also refer to for example another partition or network drive.
* _releases_ is an array of objects defining which releases must be exported. The method field determines the deployment type of the closure that needs to be serialized, which can be either a binary or cache deployment.

Usage
=====
This package contains a number of command-line utilities:

hydra-backup
------------
`hydra-backup` creates a backup consisting of a binary cache and a collection of
text files capturing the closures of all builds belonging to a release:

    $ hydra-backup config.json

hydra-restore
-------------
`hydra-restore` restores all the closures of the builds belonging to a release
from a backup generated with `hydra-backup`:

    $ hydra-restore config.json

hydra-collect-backup-garbage
----------------------------
Removes all files from the binary cache that are not in any release's closure:

    $ hydra-collect-backup-garbage config.json

hydra-release-eval
------------------
Automatically adds all builds from an evaluation (having an evaluation id) to a
specific release with a description:

    $ hydra-release-eval config.json 3 "disnix-0.3" "Disnix 0.3"

License
=======
The contents of this package is available under the terms and conditions of the
GPLv3 license or (at your opinion) any later version.
