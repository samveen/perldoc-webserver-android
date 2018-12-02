#!/usr/bin/perl -w

use IO::Socket;
use Getopt::Long;

use in::Samveen::Logger;

my $EOL = "\015\012";
my $root = "docroot";
my $PORT = 8080; # pick something not in use

sub spawn ($);

my $result;

set_log_level("info");

$result = GetOptions ( "porti|p=i" => \$PORT,
                       "root|r=s" => \$root,
                       "loglevel|l=s" => sub ($$) { my ($discard,$level)=@_ ; set_log_level($level);},
                       "<>" => sub ($) { my ($option)=@_; print "extra option/value ".$option.". Ignoring it.\n"; }
		     );

$server = IO::Socket::INET->new( Proto => 'tcp',
                                 LocalPort => $PORT,
                                 Listen => SOMAXCONN,
                                 Reuse => 1);

die logger ERROR, "can't setup server" unless $server;

logger INFO, "Server $0 started on port $PORT. Accepting clients";

while ($client = $server->accept()) {
    $client->autoflush(1);
    logger INFO, "[Connect from ".$client->peerhost."]";
    print $client "Hello there, ".$client->peerhost.", it's now ".scalar(localtime).$EOL;
    $return=qx#/data/local/bin/fortune#;
    print $client $return;
    close $client;
}


