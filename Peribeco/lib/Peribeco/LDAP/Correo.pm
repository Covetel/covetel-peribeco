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

=head2 forward_create

Crea una entrada de tipo Reenvío.

=head3 SINOPSYS

 my $model = $c->model('LDAP::Correo');

 if ($model->forward_create('rdeoli01cantv.com.ve','emujic')){
 } else {
     print "Message is: " , $model->_message;    
 }

=cut

sub forward_create {
    my ($self, $forward, $uid) = @_;

    $DB::single=1;
    
    my $e = $self->forward_new_entry($forward,$uid);

    my $resp = $self->add($e);

    $self->_message($resp);

    if ($resp->is_error){
        return undef;
    } else {
        return 1; 
    }
}

sub forward_new_entry {
    my ($self, $forward, $uid) = @_;
    

    # Defino la base de búsqueda.
    $self->base($self->forwards_base);

    my $dn = $self->forwards_dn_attr . '=' . $uid . ',' . $self->base;

    my $e = Net::LDAP::Entry->new; 

    $e->dn($dn);

    $e->add( objectClass => [ $self->forwards_objectclass ]);

    my $attrs = $self->forwards_default_attrs;

    # Atributos Valuados
    my $values = {
        sendmailMTAKey => $uid, 
        sendmailMTAAliasValue => $forward,
    };

    foreach (keys %{$attrs}){
        unless ($attrs->{$_}){
            $attrs->{$_} = $values->{$_};
        }
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

sub forwards_dn_attr {
    my $self = shift;

    return $self->config->{'Correo::Reenvios'}->{'entry'}->{'dn_attr'};
}

sub forwards_objectclass {
    my $self = shift;
    
    my $string = $self->config->{'Correo::Reenvios'}->{'entry'}->{'objectclass_attr'}; 
    my @objectClass = split ' ',$string;

    return @objectClass;
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
