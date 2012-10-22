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

Get method for forwards by uid. This method return a Net::LDAP::Entry of Forward.

=cut 

sub forwards {
    my ($self, $uid) = @_;

    # Defino la base de búsqueda.
    $self->base($self->forwards_base);

    my $filter = $self->filter_append( 
            $self->forwards_filter,
            $self->forwards_dn_attr . '=' . $uid
        );

    # Returns list of forwards for the mail account in $c->user->mail
    my $resp = $self->search($filter);

    $self->_message($resp);

    if ($resp->count){
        return $resp->shift_entry;    
    } else {
        return undef; 
    }
}

=head2 forward_list

Return forward list

=cut

sub forward_list {
    my ($self, $uid) = @_;

    if (my $e = $self->forwards($uid)){
        my @forwards = $e->get_value( $self->forwards_mail_dst );
        return @forwards;
    } else {
        return undef;
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

=head2 forward_new_entry

=over

=item Return Net::LDAP::Entry for Forwards

=item Require as parameters: C<forward( $rfc822_mail, $uid )>

=back

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

=head2 forwards_mail_dst

Return attr that store mail dst of forwards

=cut 

sub forwards_mail_dst {
    my $self = shift; 

    return $self->config->{'Correo::Reenvios'}->{'attrs'}->{'miembro_correo'}; 
}

1;
