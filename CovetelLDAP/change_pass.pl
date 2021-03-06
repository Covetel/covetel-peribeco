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

my $persona = $ldap->person({uid => 'cparedes'});
my $dn = $persona->dn;

my $new_pass = 'aphu'; 

if ($person->change_pass($new_pass, $dn)){
	print "The person ".$person->dn." has change pass \n";
#    $person->notify();
} else {
	$person->ldap->print_error();
}

