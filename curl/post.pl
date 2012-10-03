#!/usr/bin/env perl
use HTTP::Request;
use LWP::UserAgent;
use JSON;

my $hash = { active => 1, info => "Me jui de vacaciones, chao"};

my $data = encode_json($hash);

my $url = "http://localhost:3000/rest/vacation/";

my $req = HTTP::Request->new(POST => $url);
$req->header("Cookie" =>
    "peribeco_session=e5fa191433b8a9bd5b7ea1e76ee5d1e4458051b1");
$req->content_type('application/json');
$req->content($data);

my $ua = LWP::UserAgent->new; # You might want some options here
my $res = $ua->request($req);
print $data , "\n";
print $res->decoded_content , "\n";
# $res is an HTTP::Response, see the usual LWP docs.


