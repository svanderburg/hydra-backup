#!/usr/bin/env perl -w

use strict;
use warnings;
use JSON;
use File::Find;
use List::MoreUtils qw/ uniq /;
use List::BinarySearch qw( :all );
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

# Determine the output path
my $outDir = $cfg->{'outDir'};

# Read all paths that are actually used
my @paths;

sub readPaths {
    my $file = $_;
    
    if( -f $file) {
        open(my $fh, '<', $file) or die "Cannot read closure text file!";
        
        while (<$fh>) {
            chomp;
            my $path = $_;
            push @paths, $path;
        }
        
        close $fh;
    }
}

find(\&readPaths, $outDir."/releases");

@paths = uniq @paths;
@paths = sort @paths;

# Determine which NARs are not in use

my @obsoleteNARFiles;
my @obsoleteNARInfoFiles;

sub determineUnusedFiles {
    my $file = $_;
    
    if($file =~ m/.narinfo$/) {
        my $narInfoFile = $outDir."/cache/".$file;
        open(my $fh, '<', $narInfoFile) or die "Cannot read $file";
        
        my $narFile;
        my $storePath;
        
        # Parse relevant properties from the narinfo file
        while (<$fh>) {
            chomp;
            my $line = $_;
            
            if($line =~ m/URL:/) {
                $narFile = $outDir."/cache/".substr $line, length "URL: ";
            }
            
            if($line =~ m/StorePath:/) {
                $storePath = substr $line, length "StorePath: ";
            }
        }
        
        # Check whether the path is in use
        
        if(!defined(binsearch {$a cmp $b} $storePath, @paths)) {
            
            # If not in use, schedule NAR and narinfo files for removal
            
            push @obsoleteNARFiles, $narFile;
            push @obsoleteNARInfoFiles, $narInfoFile;
        }
        
        close $fh;
    }
}

find(\&determineUnusedFiles, $outDir."/cache");

# Remove all obsolete NAR files

for my $narFile (@obsoleteNARFiles) {
    if (-f $narFile) {
        print "Deleting obsolete NAR file: $narFile\n";
        unlink($narFile);
    } else {
        print "WARNING: Obsolete NAR file: $narFile already deleted!\n";
    }
}

# Remove all obsolete narinfo files

for my $narInfoFile (@obsoleteNARInfoFiles) {
    if (-f $narInfoFile) {
        print "Deleting obsolete narinfo file: $narInfoFile\n";
        unlink($narInfoFile);
    } else {
        print "WARNING: Obsolete narinfo file: $narInfoFile already deleted!\n";
    }
}
