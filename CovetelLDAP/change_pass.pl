#!/usr/bin/env perl
use strict;
use warnings;
use Covetel::LDAP;
use Covetel::LDAP::Person;
use Data::Dumper;
use utf8;

my $ldap = Covetel::LDAP->new;
my $person = Covetel::LDAP::Person->new(
    { 
		uid => 'cparedes',		
        ldap => $ldap        
	}
);

if ($person->change_pass('321321...')){
	print "The person ".$person->dn."has change pass \n";
#    $person->notify();
} else {
	$person->ldap->print_error();
}

