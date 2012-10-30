#!/usr/bin/perl
use IO::Socket::INET;
use Data::Dumper;

$|=1;

my $socket = IO::Socket::INET->new( 
    PeerAddr    => '192.168.22.44',
    PeerPort    => '4950',
    Proto       => 'tcp',

) || die "Error open socket";

$socket->autoflush(1);

$uids = "dovecotprueba2 dovecotprueba rleon";

$socket->send( $uids . "\n");

my @resp = <$socket>;

map {chomp} @resp;

for (@resp){
    my ($uid,$quota) = split ",",$_;
    print "UID: $uid QUOTA: $quota\n";
}

$socket->close;
