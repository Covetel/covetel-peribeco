#!/usr/bin/env perl
use HTTP::Request;
use LWP::UserAgent;
use JSON;

my $hash = { active => 1, info => "Me voy de vacaciones. 
    test

    test

    Walter Vargas"};

my $data = encode_json($hash);

my $url = "http://localhost:3000/rest/vacation/";

my $req = HTTP::Request->new(POST => $url);
$req->header("Cookie" => "peribeco_session=c614676f4ceeaf09f8153b70de7ddaad8edb80cc");
$req->content_type('application/json');
$req->content($data);

my $ua = LWP::UserAgent->new; # You might want some options here
my $res = $ua->request($req);
print $data , "\n";
print $res->decoded_content , "\n";
# $res is an HTTP::Response, see the usual LWP docs.
