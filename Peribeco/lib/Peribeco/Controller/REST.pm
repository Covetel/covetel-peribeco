package Peribeco::Controller::REST;
use Moose;
use namespace::autoclean;
use Net::LDAP;
use Net::LDAP::Entry;
use Data::Dumper;

BEGIN { extends 'Catalyst::Controller::REST'; }

#__PACKAGE__->config(
#  'default'   => 'application/json',
#);

=head1 NAME

Peribeco::Controller::REST - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

sub auto : Private {
    my ($self, $c) = @_;
   
    $self->{vacation} = {
        active  => $c->config->{'Correo::Vacations'}->{'attrs'}->{'active'}, 
        info    => $c->config->{'Correo::Vacations'}->{'attrs'}->{'mensaje'}, 
    };
   
    $self->{ldap} = Covetel::LDAP->new;

    $self->{user_ldap_entry} = $c->user->ldap_entry;

}

=head2 in_vacation

Return true if user is in vacation

=cut

sub in_vacation : Private {
    my ($self, $c) = @_;
    
    my $active = $self->{user_ldap_entry}->get_value($self->{vacation}->{active});

    return $active eq 'TRUE' ? 1 : 0;
}

=head2 update_vacation_info

$self->update_vacation_info({ active => 1, info => 'string'});

=cut

sub update_vacation_info : Private {
    my ($self, $c, $vacation) = @_;

    my $e = $c->user->ldap_entry;

    $vacation->{active} =~ s/1/TRUE/;
    $vacation->{active} =~ s/0/FALSE/;

    foreach (keys %{$vacation}){
        my $action = $e->exists( $self->{vacation}->{$_} ) ? 'replace' : 'add'; 
        $e->$action( $self->{vacation}->{$_} => $vacation->{$_} );
    }

    my $server = $self->{ldap}->server;

    my $r = $e->update($server);

    if ($r->is_error){
        return 0;
    } else {
        return 1;
    }

    #TODO: Validar la $resp.
}

=head2 get_vacation_info

Get the vacation info/message from user

=cut

sub get_vacation_info : Private {
    my ($self, $c) = @_;
    
    if ($self->in_vacation){
        my $info = $self->{user_ldap_entry}->get_value($self->{vacation}->{info});
        return $info;
    } else {
        return 0;
    } 
}

=head2 vacation 

=cut

sub vacation : Local : ActionClass('REST') {}

=head2 vacation_POST

Set vacation info about an user

=cut

sub vacation_POST {
    my ($self, $c) = @_;
    
    my $data = $c->req->data;

    my $vacation = { 
        active  => $data->{active}, 
        info    => $data->{info} 
    };  

    if ($self->update_vacation_info($c, $vacation)){
        $self->status_ok( $c, entity => { mensaje => "Vacation status set" } );
    } else {
        $self->status_bad_request($c, message => "Error in update_vacation_info"); 
    }
}

=head2 vacation_GET 

=cut

sub vacation_GET {
    my ($self, $c, $param) = @_;
        
    $self->status_ok(
        $c,
        entity => {
            vacation => $self->in_vacation,
            message  => $self->get_vacation_info,
        }
    );
}

=head2 vacation_PUT

Change vacation status

=cut

sub vacation_PUT {
    my ($self, $c) = @_;
    
}

=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->body('Matched Peribeco::Controller::REST in REST.');
}


=head1 AUTHOR

,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
