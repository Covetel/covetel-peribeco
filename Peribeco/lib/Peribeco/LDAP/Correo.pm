package Peribeco::LDAP::Correo;
use base qw/Catalyst::Model::LDAP::Connection Peribeco::LDAP/;
use Net::LDAP::Entry;
use common::sense;
use Data::Dumper;

=head1 NAME 
    
    Peribeco::LDAP::Correo

=head1 DESCRIPTION

    This is a data model representation and operations over Mail entries in
    LDAP

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

Create forward entry

=head3 SINOPSYS

 my $model = $c->model('LDAP::Correo');

 if ($model->forward_create('rdeoli01cantv.com.ve','emujic')){
     print "Entry created";
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

=head2 forwrad_new_entry($rfc822_mail,$uid);

Return Net::LDAP::Entry for Forwards

=cut

sub forward_new_entry {
    my ($self, $forward, $uid) = @_;
    
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

=head2 forwards_base 

Return Forwards search base.

=cut

sub forwards_base {
    my $self = shift; 

    return $self->config->{'Correo::Reenvios'}->{'basedn'};
}

=head2 forwards_filter 

Return Forwards LDAP filter

=cut

sub forwards_filter {
    my $self = shift;

    return $self->config->{'Correo::Reenvios'}->{'filter'}; 
}

=head2 forwards_dn_attr 

Return attribute for RDN creation. 

=cut 

sub forwards_dn_attr {
    my $self = shift;

    return $self->config->{'Correo::Reenvios'}->{'entry'}->{'dn_attr'};
}

=head2 forwards_objectclass 

Return ObjectClass list

=cut

sub forwards_objectclass {
    my $self = shift;
    
    my $string = $self->config->{'Correo::Reenvios'}->{'entry'}->{'objectclass_attr'}; 
    my @objectClass = split ' ',$string;

    return @objectClass;
}

=head2 forwards_default_attrs

Return default attributes of Forward entry

=cut 

sub forwards_default_attrs {
    my $self = shift; 

    return $self->config->{'Correo::Reenvios'}->{'entry'}->{'default_attrs'}; 
}

1;
