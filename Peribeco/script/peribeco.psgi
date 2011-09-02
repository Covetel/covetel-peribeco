#!/usr/bin/env perl
use strict;
use warnings;

use lib qw{/home/Peribeco/Peribeco/lib};
use Plack::Builder;
use Peribeco;

Peribeco->setup_engine('PSGI');
my $app = sub { Peribeco->run(@_) };

builder {
 enable_if { $_[0]->{REMOTE_ADDR} eq '127.0.0.1' }
        "Plack::Middleware::ReverseProxy";
 $app;
};
