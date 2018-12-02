#!/data/local/bin/perl

use strict;

use Carp;
use Socket;
use Getopt::Long;

use in::Samveen::Logger;

my $EOL = "\015\012";
my $root = "docroot";
my $port = 8080;

sub spawn ($);

my $result;

set_log_level("info");

$result = GetOptions ( "port|p=i" => \$port,
                       "root|r=s" => \$root,
                       "loglevel|l=s" => sub ($$) { my ($discard,$level)=@_ ; set_log_level($level);},
                       "<>" => sub ($) { my ($option)=@_; print "extra option/value ".$option.". Ignoring it.\n"; }
		     );

my $proto = getprotobyname('tcp');

socket(Server, PF_INET, SOCK_STREAM, $proto) || die logger ERROR, "socket: $!";
setsockopt(Server, SOL_SOCKET, SO_REUSEADDR,
                               pack("l", 1)) || die logger ERROR, "setsockopt: $!";
bind(Server, sockaddr_in($port, INADDR_ANY)) || die logger ERROR, "bind: $!";
listen(Server,SOMAXCONN)                     || die logger ERROR, "listen: $!";

#my $paddr = accept(Client, Server) || do {
#    # try again if accept() returned because a signal was received
#    die "accept: $!" unless $!{EINTR};
#};
#my ($port, $iaddr) = sockaddr_in($paddr);
#my $name = gethostbyaddr($iaddr, AF_INET);
#logger INFO, "connection from $name [".inet_ntoa($iaddr)."] at port $port";

logger INFO, "server started on port $port";

my $waitedpid = 0;;
my $paddr;;

use POSIX ":sys_wait_h";;
use Errno;;

sub REAPER {
    local $!; # don't let waitpid() overwrite current error
    while ((my $pid = waitpid(-1,WNOHANG)) > 0 && WIFEXITED($?)) {
        logger DEBUG, "reaped $waitedpid" . ($? ? " with exit $?" : '');
    }
    $SIG{CHLD} = \&REAPER; # loathe sysV
}

$SIG{CHLD} = \&REAPER;

while(1) {
    $paddr = accept(Client, Server) || do {
        # try again if accept() returned because a signal was received
        next if $!{EINTR};
        die "accept: $!";
    };
    my ($port, $iaddr) = sockaddr_in($paddr);
    my $name = gethostbyaddr($iaddr, AF_INET);
    logger INFO, "connection from $name [".inet_ntoa($iaddr)."] at port $port";
    spawn sub () {
        $|=1;
        print "Hello there, $name, it's now ".scalar(localtime).$EOL;
        exec '/data/local/bin/fortune' # XXX: "wrong" line terminators
            or confess "can't exec fortune: $!";
    };


    close Client;
}

sub spawn ($) {
    my $coderef = shift;
    unless (scalar(@_) == 0 && $coderef && ref($coderef) eq 'CODE') {
        confess "usage: spawn CODEREF";
    }
    my $pid;
    if (! defined($pid = fork)) {
        logger ERROR, "cannot fork: $!";
        return;
    } elsif ($pid) {
        logger DEBUG, "begat $pid";
        return; # I'm the parent
    }
    # else I'm the child --go spawn
    open(STDIN, "<&Client") || die logger ERROR, "can't dup client to stdin";
    open(STDOUT, ">&Client") || die logger ERROR, "can't dup client to stdout";
    ## open(STDERR, ">&STDOUT") || die logger ERROR, "can't dup stdout to stderr";
    exit &$coderef();
}
