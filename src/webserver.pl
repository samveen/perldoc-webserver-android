#!/usr/bin/perl -w
## Perldoc-Webserver-Android: Barebones webserver for local serving of perldoc
## on an android device using Perl and SL4A

use IO::Socket;
use Getopt::Long;
use in::Samveen::Logger;

my $EOL = "\015\012";
my $root;
my $PORT = 8080; # pick something not in use

## Content type hash. Indexed by file extension
my %Content_type = (
    "css"  => "text\/css",
    "html" => "text\/html",
    "htm"  => "text\/html",
    "js"   => "text\/javascript",
    "png"  => "image/png",
    "gif"  => "image/gif",
    "ico"  => "image/x-icon"
);

my $result;

set_log_level("debug");

## Parameter handling
$result = GetOptions ( "port|p=i" => \$PORT,
                       "root|r=s" => \$root,
                       "loglevel|l=s" => sub ($$) { my ($discard,$level)=@_ ; set_log_level($level);},
                       "help" => sub () { print "Usage: $0 {[{--port|-p} <port> (def:8080)] {--root|-r} <perldoc_root> [{--loglevel|-l} {debug|info|error} (def:debug)] | --help}\n"; exit() ;},
                       "<>" => sub ($) { my ($option)=@_; print "extra option/value ".$option.". Ignoring it.\n"; }
		     );
## Webserver root is essential option
die logger ERROR, "Missing parameter document root (--root|-r)." if (!$root);

opendir($ROOT, $root) || die logger ERROR, "Missing document root: $root";
closedir($ROOT);

chdir($root);

logger DEBUG, "Setting Log Level Debug";

## Create server socket
$server = IO::Socket::INET->new( Proto => 'tcp',
                                 LocalPort => $PORT,
                                 Listen => SOMAXCONN,
                                 Reuse => 1);

die logger ERROR, "can't setup server" unless $server;

logger INFO, "Server $0 started on port $PORT. Accepting clients";

## Accept connections and service them sequentially. As server is just for serving perldoc
## locally, there is no need for concurrent handling of multiple requests
while ($client = $server->accept()) {

    $client->autoflush(1);

    my @request;

    while (my $l=<$client>) {
        $l =~ s/\r\n$// ;
        $l =~ s/\r$// ;
        $l =~ s/\n$// ;
        last if ($l =~ /^$/);
        push @request, $l;
    }

    # Request Handling
    my ($method, $original_url, $HTTP_VER)=split (/ /, $request[0]);
    my %headers;
    map { my ($n,$v)=split /: / ; $headers{$n}=$v; } @request[1 .. (scalar @request - 1)];

    logger INFO, "Request $method for '$original_url' from ".$client->peerhost.":";

    logger DEBUG, "Request:"; 
    logger DEBUG, "$method $original_url $HTTP_VER"; 
    logger DEBUG, "Details:"; 
    map {my $l=$_; logger DEBUG, "$l: $headers{$l}" ;} keys (%headers) ;

    my ($url,$return) = split /\?/, $original_url;

    ## MISSING: Removal of server name from requests in case clients believes this server to be a 
    ## Virtual host. eg. GET http://www.google.com/index.html HTTP/1.0

    ## Strip away all leading slashes and dots.
    $url =~ s/^[\.\/]+// ;
    $url="/".$url;

    ## MISSING: Handling of default documents in case request is a directory.

    ## Request Paramaters
    my %params;
    map { my ($n,$v)=split /=/ ; $params{$n}=$v; } split(/&/, $return) if ($return);

    ## Extension extraction for content type in response
    my $extn = do {my @tmp = split /\./, $url ;  my $l=pop @tmp;};

    ## Handle only the GET and POST methods. Everything else generates "not implemented".
    if ($method =~ /^GET$/ or $method =~ /^POST$/) {
        if (open ($file, "< .$url")) {
            logger INFO, "Response with '$url' and Status 200 (Content-type: $Content_type{$extn})";
            print $client "HTTP/1.0 200".$EOL;
            print $client "Content-type: ".$Content_type{$extn}.$EOL;
            print $client $EOL;
            map { print $client $_; } <$file>;
            print $client $EOL.$EOL;
        } else {
            logger INFO, "Response with Status 404 as '$url' missing";
            print $client "HTTP/1.0 404".$EOL.$EOL;
        }
    } else {
        logger INFO, "Response with Status 501 as method '$method' unimplemented";
        print $client "HTTP/1.0 501".$EOL.$EOL;
    }

    close $client;
}
