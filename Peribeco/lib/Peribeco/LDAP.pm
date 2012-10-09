package Peribeco::LDAP;
use base qw/Peribeco/;
use common::sense;
use Data::Dumper;

=head1 NAME 
    
    Peribeco::LDAP

=head1 METHODS

=head2 filter_append

$self->filter_append($filter,"uid=walter");

=cut 

sub filter_append {
    my ($self, $filter, $tail) = @_;
    
    my $op;
    # Operator is | or ( 
    ($op) = ( $filter =~ /(^\(&|\|)/ );

    $op =~ s/\(//;
   
    # if no op so op is &.
    $op = $op // "&"; 

    # Fields of filter
    my @fields = ( $filter =~ /(\w+=\w+)/g );

    # Add new field to list
    push @fields, $tail;

    # Agrego los parentesis a los campos
    map { $_ = "($_)" } @fields;

    my $fields = join '', @fields;
    
    # Build filter again
    $filter = '(' . $op . $fields . ')';

    return $filter;
}

1;
