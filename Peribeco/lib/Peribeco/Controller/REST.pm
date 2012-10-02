package Peribeco::Controller::REST;
use Moose;
use namespace::autoclean;
use Net::LDAP;
use Net::LDAPS;
use Net::LDAP::Entry;
use Data::Dumper;

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config(
  'default'   => 'application/json',
);

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
   
    $self->{ldap} = $self->ldap_server($c);

    $self->{user_ldap_entry} = $c->user->ldap_entry;

}



sub ldap_server : Private {
        my ($self, $c) = @_; 
        my $host = $c->config->{'authentication'}->{'realms'}->{'ldap'}->{'store'}->{'ldap_server'};
        my $dn = $c->config->{'authentication'}->{'realms'}->{'ldap'}->{'store'}->{'binddn'};
        my $pw = $c->config->{'authentication'}->{'realms'}->{'ldap'}->{'store'}->{'bindpw'};
        my $ldap;       
        if ( $c->config->{'authentication'}->{'realms'}->{'ldap'}->{'store'}->{'start_tls'} ){
                $ldap = Net::LDAPS->new($host);
        } else {
                $ldap = Net::LDAP->new($host);
        }
        $ldap->bind( $dn, password => $pw );    

        return $ldap;
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

    my $ldap = $self->{ldap};

    my $resp = $e->update($ldap);

    if ($resp->is_error){
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

=head2 maillist

REST API for maillist.

=cut
sub maillist : Local : ActionClass('REST') {}

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

=head2 maillist_GET


=cut 

sub maillist_GET {
    my ($self, $c) = @_;
    
    my @maillist = $self->maillist_fetch($c);

    if (@maillist){
        while  (my $e = shift @maillist){
                $c->log->debug(Dumper({$e->dump}));
        }
    } else {
    
    }
    
    $self->status_ok( $c, entity => { mensaje => "Vacation status set" } );
}


=head2 maillist_fetch

Retrive maillist entries by uid

=cut

sub maillist_fetch : Private {
    my ($self, $c) = @_;

    my ($op);

    my $uid = $c->user->uid;

    my $ldap = $self->{ldap};

    my $filter = $c->config->{'Correo::Listas'}->{'filter'};

    my $moderator_f = $c->config->{'Correo::Listas'}->{'attrs'}->{'moderador'};

    if ($moderator_f){
        # Operator is | or ( 
        ($op) = ( $filter =~ /(^\(&|\|)/ );

        $op =~ s/\(//;
       
        # if no op so op is &.
        $op = $op // "&"; 

        # Fields of filter
        my @fields = ( $filter =~ /(\w+=\w+)/g );

        # Add new field to list
        push @fields, "$moderator_f=$uid";

        # Agrego los parentesis a los campos
        map { $_ = "($_)" } @fields;

        my $fields = join '', @fields;
        
        # Build filter again
        $filter = '(' . $op . $fields . ')';
    }

    $c->log->debug($filter);

    my $mesg = $ldap->search(
            filter => $filter,
            base => $c->config->{'Correo::Listas'}->{'basedn'},
            attrs => ['*'],
    );
    
    if ($mesg->count){
        return $mesg->entries;
    } else { 
        return 0;
    }
}

=head2 maillist_POST

Modify maillist members

=cut

sub maillist_POST {
    my ($self, $c) = @_;

    my $data = $c->req->data;
    
    my $maillist = { 
        members  => $data->{members}, 
    };  

    if ($self->maillist_update_members($c, $maillist)){
        $self->status_ok( $c, entity => { mensaje => "Members modifed" } );
    } else {
        $self->status_bad_request($c, message => "Error in
            maillist_update_members"); 
    }
}

=head2 maillist_update_members : Private

$self->maillist_update_members($c, $maillist);

=cut

sub maillist_update_members {
    my ($self, $c, $maillist) = @_;
   

    1;
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
