package Peribeco::LDAP::Correo;
use base qw/Catalyst::Model::LDAP::Connection Peribeco::LDAP/;
use Net::LDAP::Entry;
use common::sense;
use Data::Dumper;

=head1 NAME 
    
    Peribeco::LDAP::Correo

=head1 METHODS

=head2 forwards

Get method for forwards by uid

=cut 

sub forwards {
    my ($self, $mail) = @_;

    # Defino la base de búsqueda.
    $self->base($self->forwards_base);

    my $filter = $self->filter_append( $self->forwards_filter, $self->forwards_rcpto . '=' . $mail );

    # Returns list of forwards for the mail account in $c->user->mail
    my $resp = $self->search($filter);

    if ($resp->count){
        return $resp->entries;    
    } else {
        return (); 
    }
}

sub forward_create {
    my ($self, $forward, $mail) = @_;
    
    # Defino la base de búsqueda.
    $self->base($self->forwards_base);

    my $objectclass_string = "top CourierMailAccount sendmailMTA sendmailMTAMap sendmailMTAMapObject"; 

    my @objectClass = split ' ', $objectclass_string;

    my $dn = 'mail=' . $forward . $self->base;

    my $e = Net::LDAP::Entry->new; 

    $e->add( dn => $dn);

    my $attrs = $self->forwards_default_attrs;

    foreach (keys %{$attrs}){
        $e->add($_ => $attrs->{$_}); 
    }

    return $e;


}


sub forwards_base {
    my $self = shift; 

    return $self->config->{'Correo::Reenvios'}->{'basedn'};
}

sub forwards_filter {
    my $self = shift;

    return $self->config->{'Correo::Reenvios'}->{'filter'}; 
}

sub forwards_rcpto {
    my $self = shift; 

    return $self->config->{'Correo::Reenvios'}->{'attrs'}->{'rcpto'}; 
}

sub forwards_default_attrs {
    my $self = shift; 

    return $self->config->{'Correo::Reenvios'}->{'entry'}->{'default_attrs'}; 
}

1;
