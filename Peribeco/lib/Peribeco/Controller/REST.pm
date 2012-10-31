package Peribeco::Controller::REST;
use Moose;
use namespace::autoclean;
use Net::LDAP;
use Net::LDAPS;
use Net::LDAP::Entry;
use JSON;

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
   
    $self->{ldap} = $self->ldap_server($c);

    $self->{user_ldap_entry} = $c->user->ldap_entry;

    $self->{model} = $c->model('LDAP::Correo');

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


    my $server = $self->{ldap};

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

=head2 maillist

REST API for maillist.

=cut

sub maillist : Local : ActionClass('REST') {}

=head2 Forwards

REST API for Forwards

=cut

sub forwards : Local : ActionClass('REST') {}

=head2 vacation_POST

Set vacation info about an user

=cut

sub vacation_POST {
    my ($self, $c) = @_;
    
    my $data = $c->req->data;

    my $vacation = { 
        active  => $data->{vacation}, 
        info    => $data->{message} 
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

    my $all = []; 
    
    if (@maillist){

        while ($_ = shift @maillist){
            push @{$all}, {
                cn => $_->get_value("cn"),
                members => [ $_->get_value("sendmailMTAAliasValue") ],
                mail => $_->get_value("mail"),
                sendmailMTAKey => $_->get_value("sendmailMTAKey"),   
            }; 
        }

        $self->status_ok( $c, entity => $all );

    } else {
        $self->status_not_found(
            $c, 
            message => "Lists not found"
        ); 
    }
}


=head2 maillist_fetch

Retrive maillist entries by uid

=cut

sub maillist_fetch : Private {
    my ($self, $c) = @_;

    my $uid = $c->user->uid;
    my $ldap = $self->ldap_server($c);
    my $filter = $c->config->{'Correo::Listas'}->{'filter'};
    my $moderator_f = $c->config->{'Correo::Listas'}->{'attrs'}->{'moderador'};

    if ($moderator_f){

        $filter = $self->filter_append($c, $filter,"$moderator_f=$uid");

    }

    my $mesg = $ldap->search(
            filter => $filter,
            base => $c->config->{'Correo::Listas'}->{'basedn'},
            attrs => ['*'],
    );
    
    if ($mesg->count){
        return $mesg->entries;
    } else { 
        return;
    }
}

=head2 maillist_fetch_by_mail 

$self->maillist_fetch_by_mail($c,"aba@covetel.com.ve");

=cut

sub maillist_fetch_by_mail : Private {
    my ($self, $c, $mail) = @_;
    
    my $uid = $c->user->uid;
    my $ldap = $self->{ldap};
    my $filter = $c->config->{'Correo::Listas'}->{'filter'};
    my $moderator_f = $c->config->{'Correo::Listas'}->{'attrs'}->{'moderador'};
    my $mail_f = $c->config->{'Correo::Listas'}->{'attrs'}->{'correo'};

    $filter = $self->filter_append($c, $filter, "$mail_f=$mail");
    
    my $mesg = $ldap->search(
            filter => $filter,
            base => $c->config->{'Correo::Listas'}->{'basedn'},
            attrs => ['*'],
    );
    
    if ($mesg->count){
        return $mesg->shift_entry;
    } else { 
        return;
    }
}

=head2 filter_append

$self->filter_append($c,$filter,"uid=walter");

=cut

sub filter_append : Private {
    my ($self, $c, $filter, $tail) = @_;
    
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


=head2 maillist_POST

Modify maillist members

=cut

sub maillist_POST {
    my ($self, $c) = @_;

    my $data = $c->req->data;

    my $maillist = $data->{maillist};

    $self->status_ok( $c, entity => { mensaje => "Members modifed" } );
    
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

    my $members_f = $c->config->{'Correo::Listas'}->{'attrs'}->{'miembro_correo'};

    my $maillist_entry = $self->maillist_fetch_by_mail($c, $maillist->{mail});

    $maillist_entry->replace( $members_f => $maillist->{members});

    my $r = $maillist_entry->update($self->{ldap});

    if ($r->is_error){
        return 0;
    } else {
        return 1;
    }

}


=head2 forwards_GET 

Return Forwards list

=cut

sub forwards_GET {
    my ($self, $c) = @_;

    my $m = $self->{'model'};

    my $uid = $c->user->uid;
    my $localcopy = 0;

    if (my @forwards = $m->forward_list($c->user->uid)){

        if ($m->forwards_localcopy($uid)){
            $localcopy = 1;
            @forwards = grep { !/\\/ } @forwards; 
        }
        $self->status_ok(
            $c,
            entity => {
                forward   => \@forwards,
                localcopy => $localcopy
            }
        );
    } else {
        $self->status_not_found(
            $c, 
            message => "Forwards not found"
        ); 
    }
}

=head2 forwards_POST

Update / Create Forwards

=cut

sub forwards_POST {
    my ($self, $c) = @_;

    my $m = $self->{'model'};
    
    my $uid = $c->user->uid;
    my $data = $c->req->data;
    my $forward = $data->{'forward'}; 
    my $localcopy = $data->{'localcopy'}; 

    if ($m->forwards($uid)){
         if ($m->forward_update($uid, $localcopy, $forward)){
            $self->status_ok( $c, entity => { message => "Forwards Updated" } );
         } else {
            $self->status_bad_request(
                $c,
                message => "Error in forward_update"
            );
        }
    } else {
         if ($m->forward_create($uid, $localcopy, $forward)){
            $self->status_ok( $c, entity => { message => "Forwards Created" } );
         } else {
            $self->status_bad_request(
                $c,
                message => "Error in forward_create"
            );
        }
    }
}

=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->body('Matched Peribeco::Controller::REST in REST.');
}


=head1 AUTHOR

Walter Vargas,<water@covetel.com.ve>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
