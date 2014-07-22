#!/usr/bin/env perl -w

use strict;
use warnings;
use DBI;
use JSON;

if($#ARGV < 0) {
    die "You must specify a JSON configuration file as a parameter!";
}

my $filename = $ARGV[0];

if($#ARGV < 1) {
    die "You must provide an evaluation id!";
}

my $evalId = $ARGV[1];

if($#ARGV < 2) {
    die "You must provide a release name!";
}

my $releaseName = $ARGV[2];

if($#ARGV < 3) {
    die "You must provide a description!";
}

my $description = $ARGV[3];

# Read the JSON configuration file

my $cfgJson = do {
    open(my $json_fh, "<:encoding(UTF-8)", $filename) or die "Can't open JSON configuration!\n";
    local $/;
    <$json_fh>
};

my $cfg = from_json($cfgJson, { utf8 => 1 });

# Connect to the Hydra database
my $dbh = DBI->connect($cfg->{'dbiConnection'}) or die "Can't connect to the Hydra database: $DBI::errstr";

# Select the builds part of the evaluation
my $sth = $dbh->prepare("select project from jobsetevals where id = ?") or die "Cannot prepare select jobsetevals statement";
$sth->execute($evalId) or die "Cannot execute select jobseteval statement: ".$sth->errstr;

while(my @evaluation = $sth->fetchrow_array()) {
    my $project = $evaluation[0];
    print "project: $project\n";

    my $sth2 = $dbh->prepare("insert into releases values (?, ?, date_part('epoch', CURRENT_TIMESTAMP)::int, ?)") or die "Cannot prepare insert release statement";
    $sth2->execute($project, $releaseName, $description) or die "Cannot execute insert release statement: ".$sth2->errstr;

    $sth2 = $dbh->prepare("select jobsetevalmembers.build, builds.job ".
        "from jobsetevalmembers inner join builds on jobsetevalmembers.build = builds.id ".
        "where jobsetevalmembers.eval = ? and builds.buildstatus = 0") or die "Cannot prepare select jobsetevalmembers statement";
    $sth2->execute($evalId) or die "Cannot execute select build statement: ".$sth2->errstr;

    while(my @evalmember = $sth2->fetchrow_array()) {
        my $build = $evalmember[0];
        my $job = $evalmember[1];
        print "build: $build, job: $job\n";
        
        my $sth3 = $dbh->prepare("insert into releasemembers values (?, ?, ?, ?)") or die "Cannot prepare insert releasemember statement";
        $sth3->execute($project, $releaseName, $build, $job) or die "Cannot execute insert releasemember statement: ".$sth2->errstr;
    }
}

# Disconnect from Hydra database
$dbh->disconnect();
