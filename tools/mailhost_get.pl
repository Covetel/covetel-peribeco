#!/usr/bin/env perl
use HTTP::Request;
use LWP::UserAgent;
use JSON;

my $hash = { uid => 'emujic'};

my $data = encode_json($hash);

my $url = "http://localhost:3000/rest/mailhost/";

my $req = HTTP::Request->new(GET => $url);
$req->header("Cookie" =>
"peribeco_session=64fdc46fb9bf6bd5a77253623cb2b26f612e23e5");
$req->content_type('application/json');
#$req->content($data);

my $ua = LWP::UserAgent->new; # You might want some options here
my $res = $ua->request($req);
print $res->decoded_content , "\n";
# $res is an HTTP::Response, see the usual LWP docs.


