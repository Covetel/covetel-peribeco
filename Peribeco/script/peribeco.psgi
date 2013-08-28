#!/usr/bin/env perl
use strict;

use Plack::Builder;
use Peribeco;

my $app = Peribeco->psgi_app( @_ );

builder {
    enable_if { $_[0]->{REMOTE_ADDR} eq '127.0.0.1' }
        "Plack::Middleware::ReverseProxy";
    $app;
}
