#!/usr/bin/env perl
use HTTP::Request;
use LWP::UserAgent;
use JSON;
use Data::Dumper;

my $hash = { maillist => {
        mail => 'aba@cantv.com.ve',
        members => [
         'gmujic@cantv.com.ve',
         'ovaler@cantv.com.ve',
         'lmarqu@cantv.com.ve',
         'walter@cantv.com.ve',
        ]
    }};

my $json = JSON->new; 

my $data = encode_json($hash);

my $url = "http://localhost:3000/rest/maillist/";

my $req = HTTP::Request->new(POST => $url);
$req->header("Cookie" =>
    "peribeco_session=0e470fa896e537b495724735a530884251c56982");
$req->content_type('application/json');

$req->content($data);

my $ua = LWP::UserAgent->new; # You might want some options here
my $res = $ua->request($req);
print "Datos Enviados: \n";
print $json->pretty->encode($hash), "\n";

print "Datos Recibidos: \n";
print $json->pretty->encode($json->decode($res->decoded_content)) , "\n";
print "HTTP Code: " , $res->code , "\n";
