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

# Restore all paths part of the releases
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

for my $path(@paths) {
    print "Trying to restore path: $path\n";
    
    my $status = system("nix-store --option binary-caches file://".$outDir."/cache --realise ".$path);
    if($status != 0) {
        die("Failed to restore path: $path\n");
    }
}
