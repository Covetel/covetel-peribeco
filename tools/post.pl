#!/usr/bin/env perl
use HTTP::Request;
use LWP::UserAgent;
use JSON;

my $hash = { vacation => 1, message => "Me jui de vacaciones, chao"};

my $data = encode_json($hash);

my $url = "http://localhost:3000/rest/vacation/";

my $req = HTTP::Request->new(POST => $url);
$req->header("Cookie" =>
"peribeco_session=c97e67b4a9292a58bd808c6f1d20412087372208");
$req->content_type('application/json');
$req->content($data);

my $ua = LWP::UserAgent->new; # You might want some options here
my $res = $ua->request($req);
print $data , "\n";
print $res->decoded_content , "\n";
# $res is an HTTP::Response, see the usual LWP docs.


