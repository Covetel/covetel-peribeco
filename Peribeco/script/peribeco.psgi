#!/usr/bin/env perl
use strict;

use Plack::Builder;
use PERIBECO;

PERIBECO->setup_engine('PSGI');
my $app = sub { PERIBECO->run(@_) };

builder {
    enable_if { $_[0]->{REMOTE_ADDR} eq '127.0.0.1' }
        "Plack::Middleware::ReverseProxy";
    $app;
};
