#!/usr/bin/env perl -w

use strict;
use warnings;
use DBI;
use JSON;
use File::Path;
use File::Basename;

# Read the JSON configuration file

if($#ARGV < 0) {
    die "You must specify a JSON configuration file as a parameter!";
}

my $filename = $ARGV[0];

my $cfgJson = do {
    open(my $json_fh, "<:encoding(UTF-8)", $filename) or die "Can't open JSON configuration!\n";
    local $/;
    <$json_fh>
};

my $cfg = from_json($cfgJson, { utf8 => 1 });

# Connect to the Hydra database
my $dbh = DBI->connect($cfg->{'dbiConnection'}) or die "Can't connect to the Hydra database: $DBI::errstr";

# Determine the output path
my $outDir = $cfg->{'outDir'};

# Backup each release in the config

sub backupRelease {
    my ($project, $name, $method) = @_;
    
    print "Processing project: $project, release name: $name using method: $method\n";

    # Query the builds part of a release

    my $sth = $dbh->prepare("select builds.drvpath, buildoutputs.path ".
        "from releases ".
        "inner join releasemembers on releases.project = releasemembers.project and releases.name = releasemembers.release_ ".
        "inner join builds on releasemembers.build = builds.id ".
        "inner join buildoutputs on builds.id = buildoutputs.build ".
        "where releases.project = ? and releases.name = ? and buildoutputs.name = 'out' ".
        "order by builds.id") or die "Cannot prepare select release statement";
    $sth->execute($project, $name) or die "Cannot execute select release statement: ".$sth->errstr;

    my @release;
    my @drvPaths;
    my @outPaths;
    
    # Determine ids and derivation paths of all the builds belonging to a release

    while(@release = $sth->fetchrow_array()) {
        my $drvPath = $release[0];
        my $outPath = $release[1];
        
        push @drvPaths, $drvPath;
        push @outPaths, $outPath;
    }
    
    # Determine query method
    my $storeParam;
    
    if($method eq "binary") {
        $storeParam = "--use-output";
    } elsif($method eq "cached") {
        $storeParam = "--include-outputs";
    } else {
        die "Unknown deployment method: ".$method;
    }
    
    # Query requisites of the build
    my $reqPathsString;
        
    if($method eq "binary") {
        $reqPathsString = join(' ', @outPaths);
    } else {
        $reqPathsString = join(' ', @drvPaths);
    }
    
    my $pathsString = `nix-store --query --requisites $storeParam $reqPathsString`;
    my @paths = split('\n', $pathsString);
    $pathsString =~ s/\n/ /g;
    
    # Compose output paths
    my $cachePath = $outDir."/cache";
    my $closurePath = $outDir."/releases/".$project."/".$name;
    
    mkpath($cachePath);
    mkpath($closurePath);
    
    # Export the closure of the release by pushing a binary cache
    
    my $status = system("nix-push --dest ".$cachePath." ".$pathsString);
    if($status != 0) {
        die "Cannot push paths: ".$pathsString;
    }
    
    # Also record the store paths that have been exported
    open(my $fh, '>', $closurePath."/closure.txt") or die "Cannot write closure text file!";
    foreach my $path (@paths) {
        print $fh $path."\n";
    }
    close $fh;
}

# Backup releases

foreach my $releaseConfig (@{$cfg->{'releases'}}) {
    my $project = $releaseConfig->{'project'};
    my $name = $releaseConfig->{'name'};
    my $method = $releaseConfig->{'method'};
    
    backupRelease($project, $name, $method);
}

# Disconnect from Hydra database
$dbh->disconnect();
