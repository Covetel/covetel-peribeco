package Peribeco::Controller::AJAX;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller::REST'; }
use utf8;

__PACKAGE__->config(
  'default'   => 'application/json',
);

=head1 NAME

Peribeco::Controller::AJAX - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->body('Matched Peribeco::Controller::AJAX in AJAX.');
}

sub grupos : Local : ActionClass('REST') {}

sub personas : Local : ActionClass('REST') {}

sub listas : Local : ActionClass('REST') {}

sub quota : Local : ActionClass('REST') {}

sub groupmembers : Local : ActionClass('REST') {}

sub usuario_exists : Path('usuario/exists') Args(1) ActionClass('REST') {}

sub mail_exists : Path('mail/exists') Args(1) ActionClass('REST') {}

sub addMember : Path('grupos/add') Args ActionClass('REST') {}

sub delMember : Path('grupos/del') Args ActionClass('REST') {}

sub delete_groups : Path('delete/groups') Args ActionClass('REST') {}

sub delete_persons : Path('delete/persons') Args ActionClass('REST') {}

sub quotaset : Path('quota/set') Args ActionClass('REST') {}

sub delete_lista : Path('delete/lista') Args ActionClass('REST') {}

sub utf8_decode {
    my ($str) = @_;
    utf8::decode($str);
    return $str;
}

sub grupos_GET {
	my ($self, $c) = @_;
    my %datos; 
    
    my $ldap = Covetel::LDAP->new;
    my @lista = $ldap->group();

    $datos{aaData} = [
        map {
            [

                ($_->nombre eq 'Administradores') ? '' 
                : '<input type="checkbox" name="del" value="'.$_->gidNumber.'">', 
                $_->gidNumber, 
                &utf8_decode($_->nombre), 
                $_->description ? &utf8_decode($_->description) : 'No definido', 
                '<a href="/grupos/detalle/' . $_->gidNumber . '"> Ver detalle </a>', 
            ]
          } @lista,
    ];

	$self->status_ok($c, entity => \%datos);
}

sub personas_GET {
    my ( $self, $c ) = @_;
    
    my $ldap = Covetel::LDAP->new;
    my @lista = $ldap->person();

    my %datos; 
    
    $datos{aaData} = [
        map {
            [ 
            '<input type="checkbox" name="del" value="'.$_->uid.'">', 
            &utf8_decode($_->firstname), 
            &utf8_decode($_->lastname), 
            $_->ced, 
            $_->email,  
            $_->uidNumber, 
            $_->uid, 
            '<a href="/personas/detalle/' . $_->uid . '"> Ver detalle </a>', 
            ]
        } grep { !($_->uid eq 'root') } @lista, 
    ];

	$self->status_ok($c, entity => \%datos);
}

sub remove_domain {
    my ($self, @list) = @_;
    map {s/@.*$//} @list;
    my $str = join(",",@list);
    return $str;
    
}

sub listas_GET {
    my ( $self, $c ) = @_;
    
    my $ldap = Covetel::LDAP->new;
    
    my $mesg = $ldap->search({ 
            filter => $c->config->{'Correo::Listas'}->{'filter'},
            base => $c->config->{'Correo::Listas'}->{'basedn'},
            attrs => '*'
        });

    my %datos;

    my $id = $c->config->{'Correo::Listas'}->{'attrs'}->{'nombre'};
    my $desc = $c->config->{'Correo::Listas'}->{'attrs'}->{'descripcion'};
    my $mail = $c->config->{'Correo::Listas'}->{'attrs'}->{'correo'};
    my $member_mail = $c->config->{'Correo::Listas'}->{'attrs'}->{'miembro_correo'};

    if ($mesg->count){
        $datos{aaData} = [
            map {
                [ 
                    '<input type="checkbox" name="del" value="'.$_->get_value($id).'">', 
                    $_->get_value($mail), 
                    &utf8_decode($_->get_value($desc)), 
                    $self->remove_domain($_->get_value($member_mail)),
                    '<a href="/personas/detalle/' . $_->get_value($id) . '"> Ver detalle </a>', 
                ]
                } $mesg->entries,
        ];
        
    }

    
	$self->status_ok($c, entity => \%datos);
}

sub quota_GET {
    my ( $self, $c ) = @_;
    
    my $ldap = Covetel::LDAP->new;
    
    my $mesg = $ldap->search({ 
            filter => $c->config->{'Correo::Quota'}->{'filter'},
            base => $c->config->{'Correo::Quota'}->{'basedn'},
            attrs => '*'
        });

    my %datos;

    my $account = $c->config->{'Correo::Quota'}->{'attrs'}->{'account'};
    my $cname = $c->config->{'Correo::Quota'}->{'attrs'}->{'nombre'};
    my $quota_size = $c->config->{'Correo::Quota'}->{'attrs'}->{'quota'};
    my $size = $c->config->{'Correo::Quota'}->{'attrs'}->{'size'};
    
    if ($mesg->count){
        $datos{aaData} = [
            map {
                [ 
                '<input type="checkbox" name="del" value="'.$_->get_value($account).'">', 
                &utf8_decode($_->get_value($cname)), 
                $_->get_value($account), 
                $_->get_value($quota_size) ? $_->get_value($quota_size)."
                ".$size : "0 $size",
                '<div class="progressbar"
                id="progressbar-'.$_->get_value($account).'-'.$_->get_value($quota_size).'-'. int(rand(2048)) .'"></div>', 
                ]
            } grep { !($_->get_value($account) eq 'root') } $mesg->entries,
        ];
    }

	$self->status_ok($c, entity => \%datos);
}

sub quotaset_PUT {
    my ($self, $c) = @_;

    my $personas = $c->req->data->{personas};
    my $size = $c->req->data->{size};

    my $ldap = Covetel::LDAP->new;
    my $base = $ldap->config->{'Covetel::LDAP'}->{'base_personas'};
   
    foreach (@{$personas}) {
        my $persona = $ldap->person( { uid => $_ } );
        my $dn = $persona->dn;
        my $entry = $persona->entry;

        print Dumper($entry);
   
        my $mesg = $ldap->server->modify(
           $entry->dn, 
           replace => {
                   mailQuotaSize => $size, 
               }
         );
    }
}

sub usuario_exists_GET {
    my ( $self, $c, $uid ) = @_;
    $c->log->debug($uid);
    my $resp = {};


    my $ldap = Covetel::LDAP->new;
    if ($ldap->person({uid => $uid})){
        $resp->{exists} = 1;
    } else {
        $resp->{exists} = 0;
    }
	
    $self->status_ok($c, entity => $resp);

}

sub mail_exists_GET {
    my ( $self, $c, $uid ) = @_;
    $c->log->debug($uid);
    my $resp = {};


    my $ldap = Covetel::LDAP->new;

    my $mail = $uid =~ m/@/ ? $uid : $uid . '@' . $c->config->{domain};

    my $mesg = $ldap->search({filter => "mail=$mail"});

    if ($mesg->count){
        $resp->{exists} = 1;
    } else {
        $resp->{exists} = 0;
    }
	
    $self->status_ok($c, entity => $resp);

}

sub groupmembers_GET {
    my ($self, $c, $gid) = @_;
    my %datos; 
    my @person;
    
    my $ldap = Covetel::LDAP->new;
    my $grupo = $ldap->group({gidNumber => $gid});

    if ($grupo) {
        my $members = $grupo->members;
        use Data::Dumper;
        $c->log->debug(Dumper($members));
        foreach (@{$members}) {
            $c->log->debug($_);
            my $p = $ldap->person({uid => $_});
            if ($p) {
                push @person,  $p;
            }
        }
    }
   

    $datos{aaData} = [
        map {
            [ 
            '<input type="checkbox" name="del" value="'.$_->uid.'">', 
            &utf8_decode($_->firstname), 
            &utf8_decode($_->lastname), 
            $_->ced, 
            $_->email,  
            $_->uidNumber, 
            $_->uid, 
            ]
        } grep { !($_->uid eq 'root') } @person, 
    ];

	$self->status_ok($c, entity => \%datos);
}


sub addMember_PUT {
    my ($self, $c) = @_;
    my $ldap = Covetel::LDAP->new;

    my $personas = $c->req->data->{personas};
    my $gid = $c->req->data->{gid};
    my $g = $ldap->group({gidNumber => $gid});
	my %datos;
    my @usuarios;
    foreach (@{$personas}){
        s/\s+//g;
        if ($ldap->person({uid => $_})){
            if ($g) {
                $g->add_member($_);
                if ($g->update){
                    push @usuarios, $_;
                }
            }
        } else {
            $self->status_not_found(
               $c,
               message => "No se pudo encontrar el usuario $_",
             );
        }
    }
    $datos{usuarios} = \@usuarios;
	$self->status_ok($c, entity => \%datos);

}

sub delMember_DELETE {
    my ($self, $c) = @_;
    my $ldap = Covetel::LDAP->new;
    my %datos;
    my $del = $c->req->data->{personas};
    my $gid = $c->req->data->{gid};
    my $g = $ldap->group({gidNumber => $gid});
    my $members = $g->members();
    my $new_members;
    map { push @{$new_members} , $_ unless $_ ~~ @{$del} } @{$members};
    $c->log->debug(Dumper($new_members));
    $g->members($new_members);
    $g->update;
    $self->status_ok($c, entity => \%datos);
}

sub delete_groups_DELETE {
    my ( $self, $c ) = @_;
    my $ldap = Covetel::LDAP->new;
    my %resp;

    my $gids = $c->req->data->{gids};

    my $status = 1;

    foreach (@{$gids}){
        my $g = $ldap->group({gidNumber => $_});
        if ($g){
            unless($g->del()){
                $self->status_bad_request(
                    $c,
                    message => "No fue posible eliminar el registro",
                );
            }
        }
    }

    $resp{estatus} = $status;
    $self->status_ok($c, entity => \%resp);
}

=head2 delete_lista_DELETE

This method delete an entry of distribution list.

=cut 

sub delete_lista_DELETE {
    my ( $self, $c ) = @_;
    my $ldap = Covetel::LDAP->new;
    my %resp;

    my $ids = $c->req->data->{ids};

    # Busco cada una de las listas en LDAP
    # TODO: Esto debería estar en una modelo. Catalyst::Model::LDAP

    # Busco el filtro de búsqueda utilizado para las listas en la
    # configuración. 
    
    my $filter = $c->config->{'Correo::Listas'}->{'filter'};
    my $nombre = $c->config->{'Correo::Listas'}->{'attrs'}->{'nombre'};

    #$filter = '(&' . $filter . '('. $nombre .'='.  .'))';

    my @entries; # entradas que van a ser eliminadas.
    
    foreach my $id (@{$ids}){
        
        my $cf = "(&$filter($nombre=$id))";
        my $mesg = $ldap->search({ filter => $cf });

        if ($mesg->count){

            push @entries, $mesg->shift_entry;
            
        } else {
            # No se encontraron elementos, se responde con 404
            $self->status_not_found(
               $c,
               message => "No se encontro la lista: $id",
            );
            return;
        }
    }

    # sleep 6; sleep utilizado para simular que se rompe el LDAP

    foreach my $e (@entries){
        my $resp = $ldap->server->delete($e);

        if ($resp->is_error){
            $self->status_bad_request(
               $c,
               message => "No se pudo eliminar la lista " . $e->dn . ", errores ldap: "
               . $resp->error . ' ' . $resp->code . ' ' .
               $resp->error_text . ' ' . $resp->error_desc,
            );
            return;
        }         
    }

    $self->status_ok($c, entity => { status => 1 });
}

sub delete_persons_DELETE {
    my ( $self, $c ) = @_;
    my $ldap = Covetel::LDAP->new;
    my %resp;
    my $uids = $c->req->data->{uids};
    my $status = 1;

    foreach (@{$uids}){
        my $p = $ldap->person({uid => $_});
        if ($p){
            unless($p->del()){
                $self->status_bad_request(
                    $c,
                    message => "No fue posible eliminar el registro",
                );
            }
        }
    }
    
    $resp{estatus} = $status;
    $self->status_ok($c, entity => \%resp);
}

=head1 AUTHOR

Walter Vargas

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
