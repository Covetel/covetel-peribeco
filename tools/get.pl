#!/usr/bin/env perl
use HTTP::Request;
use LWP::UserAgent;
use JSON;

my $hash = { vacation => 1, message => ""};

my $data = encode_json($hash);

my $url = "http://localhost:3000/rest/vacation/";

my $req = HTTP::Request->new(GET => $url);
$req->header("Cookie" =>
"peribeco_session=46cd19352ee20b96029bf4021d98a701107ad50b");
$req->content_type('application/json');
#$req->content($data);

my $ua = LWP::UserAgent->new; # You might want some options here
my $res = $ua->request($req);
print $res->decoded_content , "\n";
# $res is an HTTP::Response, see the usual LWP docs.


