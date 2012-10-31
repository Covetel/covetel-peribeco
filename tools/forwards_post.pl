#!/usr/bin/env perl
use HTTP::Request;
use LWP::UserAgent;
use JSON;
use Data::Dumper;

my $hash = { forward => [
      'rdeoli01@cantv.com.ve',
      'aba@cantv.com.ve',
      'mariposa@cantv.com.ve',
      'mensjes@cantv.com.ve'
    ], localcopy => 0};

my $json = JSON->new; 

my $data = encode_json($hash);

my $url = "http://localhost:3000/rest/forwards/";

my $req = HTTP::Request->new(POST => $url);
$req->header("Cookie" =>
    "peribeco_session=7716a49679e022e21e090bfd9a40b9e834029f14");
$req->content_type('application/json');
$req->content($data);

my $ua = LWP::UserAgent->new; # You might want some options here
my $res = $ua->request($req);
print $json->pretty->encode($json->decode($res->decoded_content)) , "\n";
print $res->code , "\n";
# $res is an HTTP::Response, see the usual LWP docs.






