#!/usr/bin/env perl
use strict;
use warnings;
use Covetel::LDAP;
use Covetel::LDAP::Person;
use Data::Dumper;
use utf8;

my $uid = 'cparedes';
my $ldap = Covetel::LDAP->new;
my $person = Covetel::LDAP::Person->new(
    { 
		uid => $uid,		
        ldap => $ldap        
	}
);
my $persona = $ldap->person({uid => $uid});
my $dn = $persona->dn;

if ($person->timecreate($dn)){
	print "The person ".$person->dn." has change pass \n";
#    $person->notify();
} else {
	$person->ldap->print_error();
}

