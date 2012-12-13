use strict;
use warnings;
use Test::More;


use Catalyst::Test 'Peribeco';
use Peribeco::Controller::Applications;

ok( request('/applications')->is_success, 'Request should succeed' );
done_testing();
