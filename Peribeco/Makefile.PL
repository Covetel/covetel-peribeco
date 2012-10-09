#!/usr/bin/env perl
# IMPORTANT: if you delete this file your app will not work as
# expected.  You have been warned.
use inc::Module::Install;
use Module::Install::Catalyst; # Complain loudly if you don't have
                               # Catalyst::Devel installed or haven't said
                               # 'make dist' to create a standalone tarball.
name 'Peribeco';
all_from 'lib/Peribeco.pm';

requires 'Catalyst::Runtime' => '5.80025';
requires 'Catalyst::Plugin::ConfigLoader';
requires 'Catalyst::Plugin::Static::Simple';
requires 'Catalyst::Action::RenderView';
requires 'Moose';
requires 'namespace::autoclean';

requires 'Catalyst::Plugin::Authorization::ACL';
requires 'Catalyst::Plugin::Session::Store::FastMmap';
requires 'Catalyst::Plugin::Static::Simple'; 
requires 'Catalyst::Plugin::ConfigLoader';
requires 'Catalyst::Plugin::Unicode::Encoding';
requires 'YAML::XS';
requires 'Catalyst::Authentication::Store::LDAP';

# Walter Vargas <walter@covetel.com.ve>
# Tue Sep 25 21:30:41 VET 2012

requires 'Mail::RFC822::Address';
requires 'Catalyst::Controller::REST';
requires 'Catalyst::Controller::HTML::FormFu';
requires 'Email::Sender::Simple';
requires 'Email::MIME::Creator';

# Walter Vargas <walter@covetel.com.ve>
# Tue Oct  9 09:26:36 VET 2012

requires 'Catalyst::Model::LDAP';


requires 'Config::General'; # This should reflect the config file format you've chosen
                 # See Catalyst::Plugin::ConfigLoader for supported formats
test_requires 'Test::More' => '0.88';
catalyst;

install_script glob('script/*.pl');
auto_install;
WriteAll;
