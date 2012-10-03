#!/usr/bin/env perl
use HTTP::Request;
use LWP::UserAgent;
use JSON;

my $hash = { nombre => "walter", apellido => "vargas"};

my $data = encode_json($hash);

my $url = "http://localhost:3000/rest/vacation/";

my $req = HTTP::Request->new(PUT => $url);
$req->header("Cookie" => "peribeco_session=f0a55fbfa3fc0c223ca297e4db90c7451a991c57");
$req->content_type('application/json');
$req->content($data);

my $ua = LWP::UserAgent->new; # You might want some options here
my $res = $ua->request($req);
print $res->decoded_content;
# $res is an HTTP::Response, see the usual LWP docs.
