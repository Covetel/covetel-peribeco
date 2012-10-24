package Peribeco::Controller::AJAX;
use Moose;
use IO::Socket::INET;
use Net::LDAP::Entry;
use Net::LDAP;
use Net::LDAP::Search;
use Net::LDAP::Message;
use namespace::autoclean;
use Mail::RFC822::Address qw(valid);
use Data::Dumper;
use v5.10;

BEGIN {extends 'Catalyst::Controller::REST'; }
use utf8;
my %quo = {};

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

sub listamembers : Local : ActionClass('REST') {}

sub listadirecciones : Local : ActionClass('REST') {}

sub usuario_exists : Path('usuario/exists') Args(1) ActionClass('REST') {}

sub mail_exists : Path('mail/exists') Args(1) ActionClass('REST') {}

sub addMember : Path('grupos/add') Args ActionClass('REST') {}

sub addListaMembers : Path('listas/add') Args ActionClass('REST') {}

sub addforward : Path('reenvios/add') Args ActionClass('REST') {}

sub forwardcc : Path('reenvios_cc/set') Args ActionClass('REST') {}

sub forwardcca : Path('info/forward_cc') Args(1) ActionClass('REST') {}

sub modify_rol : Path('listas/modify_rol') Args ActionClass('REST') {}

sub delMember : Path('grupos/del') Args ActionClass('REST') {}

sub delListaMembers : Path('listas/del') Args ActionClass('REST') {}

sub delforward : Path('reenvios/del') Args ActionClass('REST') {}

sub delete_groups : Path('delete/groups') Args ActionClass('REST') {}

sub delete_persons : Path('delete/persons') Args ActionClass('REST') {}

sub quotaset : Path('quota/set') Args ActionClass('REST') {}

sub global_quota : Path('quota/global_quota') Args ActionClass('REST') {}

sub getquota : Path('quota/use') Args(1) ActionClass('REST') {}

sub info_persona : Path('info/persona') Args(1) ActionClass('REST') {}

sub delete_lista : Path('delete/lista') Args ActionClass('REST') {}

sub autocomplete_usuarios : Path('autocomplete/usuarios') Args ActionClass('REST') {}

sub autocomplete_mail : Path('autocomplete/mail') Args ActionClass('REST') {}

sub vacations : Path('info/vacations') Args(1) ActionClass('REST') {}

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

    my $filter;
    
    if ($c->config->{domain} =~ /cantv/) {
    
        my $moderator_f = $c->config->{'Correo::Listas'}->{'attrs'}->{'moderador'};
        $filter = $c->config->{'Correo::Listas'}->{'filter'};
        my $uid = $c->user->uid;

        $filter = $c->controller('REST')->filter_append($c,$filter,"$moderator_f=$uid");
        $c->log->debug($filter);

    }else{
        $filter = $c->config->{'Correo::Listas'}->{'filter'};
    }

    if ($c->check_user_roles(qw/Administradores/)) {
        $filter = $c->config->{'Correo::Listas'}->{'filter'};
    }
    $c->log->debug($filter);

    my $mesg = $ldap->search({ 
            filter => $filter,
            base => $c->config->{'Correo::Listas'}->{'basedn'},
            attrs => ['*']
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
                    '<div class="members_div" id="'.$_->get_value($id).'">' . $self->remove_domain($_->get_value($member_mail)) . '</div>',
                    '<a href="/correo/listas/detalle/' . $_->get_value($id) . '"> Ver detalle </a>',
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
            attrs => ['*']
        });

    my %datos;
    
    my $account = $c->config->{'Correo::Quota'}->{'attrs'}->{'account'};
    my $cname = $c->config->{'Correo::Quota'}->{'attrs'}->{'nombre'};
    my $quota_size = $c->config->{'Correo::Quota'}->{'attrs'}->{'quota'};
    my $size = $c->config->{'Correo::Quota'}->{'attrs'}->{'size'};
    
    if ($mesg->count){
        $datos{aaData} = [
            map {
            &quotaget($_->get_value($account), $c);
            my $usage = $quo{$_->get_value($account)} ? $quo{$_->get_value($account)} : "0";
            my $usage_mb = int($usage/1024);
                [ 
                '<input type="checkbox" name="del" value="'.$_->get_value($account).'">', 
                &utf8_decode($_->get_value($cname)), 
                $_->get_value($account), 
                $_->get_value($quota_size) ? $_->get_value($quota_size)." ".$size : "0 $size",
                '<div class="progressbar" id="progressbar-'.$_->get_value($account).'-'.$_->get_value($quota_size).'"></div>', 
                '<div class="usage" id="usage-'.$_->get_value($account).'"></div>'
                ]
            } grep { !($_->get_value($account) eq 'root') } $mesg->entries,
        ];
    }

    $self->status_ok($c, entity => \%datos);
}

sub quotaget {
    $|=1;

    my $socket = IO::Socket::INET->new( 
        PeerAddr => $_[1]->config->{'Correo::Quota'}->{'quota_info'}->{'server'}, 
        PeerPort => $_[1]->config->{'Correo::Quota'}->{'quota_info'}->{'port'}, 
        Proto    => $_[1]->config->{'Correo::Quota'}->{'attrs'}->{'proto'}, 
    ) || die "Error open socket";

    $socket->autoflush(1);

    $socket->send( $_[0] . "\n");

    my @resp = <$socket>;

    map {chomp} @resp;

    for (@resp){
           my ($uid, $quota) = split ",", $_;
           print "$uid = $quota\n";
           %quo = ( $uid => $quota );
       }

    $socket->close;
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

        my $mesg = $ldap->server->modify(
           $entry->dn, 
           replace => {
                   mailQuotaSize => $size, 
               }
         );
    }
}

sub global_quota_PUT {
    my ($self, $c) = @_;

    my $size = $c->req->data->{size};

    print $size."\n";

    my $ldap = Covetel::LDAP->new;
    my $base = $ldap->config->{'Covetel::LDAP'}->{'base_personas'};
    my $account = $c->config->{'Correo::Quota'}->{'attrs'}->{'account'},

    my $mesg = $ldap->search({ 
            filter => $c->config->{'Correo::Quota'}->{'filter'},
            base => $c->config->{'Correo::Quota'}->{'basedn'},
            attrs => ['uid'], 
        });

    if ($mesg->count){
        foreach ($mesg->entries) {
            my $persona = $ldap->person( { uid => $_->get_value($account) } );
            my $dn = $persona->dn;
            my $entry = $persona->entry;

            my $mesg = $ldap->server->modify(
                $entry->dn, 
                replace => {
                    mailQuotaSize => $size, 
                }
            );
        }
    }
}

sub getquota_GET {
    my ( $self, $c, $uids ) = @_;

    $|=1;

    my $socket = IO::Socket::INET->new( 
        PeerAddr => $c->config->{'Correo::Quota'}->{'quota_info'}->{'server'}, 
        PeerPort => $c->config->{'Correo::Quota'}->{'quota_info'}->{'port'},
        Proto    => $c->config->{'Correo::Quota'}->{'attrs'}->{'proto'}, 
    ) || die "Error open socket";

    $socket->autoflush(1);

    $socket->send( $uids . "\n");

    my @resp = <$socket>;

    map {chomp} @resp;

    for (@resp){
        my ($uid,$quota) = split ",",$_;
        print "UID: $uid QUOTA: $quota\n";
    }

    $self->status_ok($c, entity => \@resp);

    $socket->close;
}

sub info_persona_GET {
    my ( $self, $c, $uid ) = @_;

    my $ldap = Covetel::LDAP->new;
    my $person = $ldap->person({ uid => $uid });
    
    my $datos = $person->firstname.",".$person->lastname.",".$person->ced;
    
    push (my @persona, $datos);

    $self->status_ok($c, entity => \@persona);
}

sub usuario_exists_GET {
    my ( $self, $c, $uid ) = @_;
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
        foreach (@{$members}) {
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

sub modify_rol_PUT{
    my($self, $c) = @_;
    my $ldap = Covetel::LDAP->new;

    my $personas = $c->req->data->{personas};
    my $lid = $c->req->data->{lid};
    my $tipo = $c->req->data->{tipo};

    my %datos;
    $datos{'respuesta'} = 0;

    my $filter = '(&' .
                 '(objectClass=groupOfNames)' .
                 $c->config->{'Correo::Listas'}->{'filter'} .
                 "(cn=$lid)" .
                 ')';

    my $attr_moderador = $c->config->{'Correo::Listas'}->{'attrs'}->{'moderador'};
    my $attr_miembro = $c->config->{'Correo::Listas'}->{'attrs'}->{'miembro'};
    my $attr_correo = $c->config->{'Correo::Listas'}->{'attrs'}->{'correo'};
    #my $attr_tipo = $c->config->{'Correo::Listas'}->{'attrs'}->{$tipo};

    my $mesg_lista = $ldap->search({
        filter => $filter,
        base => $c->config->{'Correo::Listas'}->{'basedn'},
        attrs => [ $attr_moderador, $attr_miembro ]
    });

    if(!$mesg_lista->is_error) {
       my $lista = $mesg_lista->shift_entry;

       foreach my $persona (@{$personas}) {
           my $mesg_member = $ldap->search({
                filter => "($attr_correo=$persona)",
                #attrs => [$attr_correo]
            });

            if ($mesg_member->count){
                my $entry = $mesg_member->shift_entry;

                my @array = $lista->get_value($attr_moderador);
                if($tipo =~ /miembro/ && $entry->dn ~~ @array) {
                    if($#array + 1 > 1) {
                        $lista->delete(
                            $attr_moderador => $entry->dn
                        );
                    } else {
                        $self->status_ok($c, entity => \%datos);
                    }
                }

                @array = $lista->get_value($attr_miembro);
                if($tipo =~ /moderador/ && $entry->dn ~~ @array) {
                    $lista->add(
                        $attr_moderador => $entry->dn
                    );
                }

                my $mesg_action = $lista->update($ldap->server);

                if ($mesg_action->is_error) {
                    $self->status_not_found(
                       $c,
                       message => "No se pudo actualizar la entrada, el servidor LDAP no responde",
                    );
                    return;
                }

                $datos{'respuesta'} = 1;
            } else {
                $self->status_not_found(
                   $c,
                   message => "no se encontro al miembro: $persona",
                );
                return;
            }
       }
    } else {
        $self->status_not_found(
           $c,
           message => "No se encontro la lista: $lid",
        );
        return;
    }

    $self->status_ok($c, entity => \%datos);
}

sub listamembers_GET {
    my ($self, $c, $lid) = @_;
    my %datos;
    my $ldap = Covetel::LDAP->new;

    my $attr_miembro_correo = $c->config->{'Correo::Listas'}->{'attrs'}->{'miembro_correo'};
    my $attr_moderador = $c->config->{'Correo::Listas'}->{'attrs'}->{'moderador'};
    my $attr_miembro = $c->config->{'Correo::Listas'}->{'attrs'}->{'miembro'};
    my $attr_correo = $c->config->{'Correo::Listas'}->{'attrs'}->{'correo'};
 
    #Determina ObjectClass
    my $objectClass = $c->config->{'Correo::Listas'}->{'objectClass'};
    
    my @objectclass = split ' ', $objectClass;
 
    #Switch que evalua objectclass y limita atributos
    foreach my $objc (@objectclass) {
        given ($objc) {
             when ('qmailGroup') {

                 my $filter = '(&' .
                              '(objectClass=groupOfNames)' .
                              $c->config->{'Correo::Listas'}->{'filter'} .
                              "(cn=$lid)" .
                              ')';
                 
                 my $mesg = $ldap->search({
                     filter => $filter,
                     base => $c->config->{'Correo::Listas'}->{'basedn'},
                     attrs => [ $attr_miembro, $attr_moderador, $attr_miembro_correo ]
                 });
                 
                 my @entries;
                 if($mesg->count) {
                     my $resp = $mesg->shift_entry;
                     my @members = $resp->get_value($attr_miembro);
                     my @moderators = $resp->get_value($attr_moderador);
                     my @rfcmembers = $resp->get_value($attr_miembro_correo);
                 
                     foreach (@rfcmembers) {
                         $mesg = $ldap->search({
                             filter => "($attr_correo=" . $_ . ')',
                             attrs => ['givenName', 'sn', 'mail', 'uid']
                         });
                 
                         my $entry = $mesg->shift_entry;
                         if (defined $entry) {
                             $entry->add(
                                 tipo    => $entry->dn ~~ @moderators ? "Moderador" : "Miembro"
                             );
                         } else {
                             $entry = Net::LDAP::Entry->new;
                             $entry->add(
                                 tipo      => 'Externo',
                                 givenName => '-',
                                 sn        => '-',
                                 mail      => $_,
                                 uid       => '-',
                             )
                         }
                         push @entries, $entry;
                 
                     }
                 
                     foreach my $entry (@entries) {
                     }
                 } else {
                     # No se encontraron elementos, se responde con 404
                     $self->status_not_found(
                        $c,
                        message => "No se encontro la lista: $lid",
                     );
                     return;
                 }
                 
                 $datos{aaData} = [
                     map {
                     [
                         '<input type="checkbox" name="del" value="'.$_->get_value($attr_correo).'">',
                         $_->get_value('tipo'),
                         $_->get_value($attr_correo),
                         &utf8_decode($_->get_value('givenName')),
                         &utf8_decode($_->get_value('sn')),
                         $_->get_value('uid'),
                     ]
                     } grep { !($_->{uid} eq 'root') } @entries,
                 ];
                 
                 $self->status_ok($c, entity => \%datos);
             }
             when ('sendmailMTA') {
                 
                 my $field = $c->config->{'Correo::Listas'}->{'attrs'}->{'nombre'};
                 my $filter = $c->config->{'Correo::Listas'}->{'filter'};

                 $filter = $c->controller('REST')->filter_append($c,$filter,"$field=$lid");

                 my $mesg = $ldap->search({
                     filter => $filter,
                     base => $c->config->{'Correo::Listas'}->{'basedn'},
                     attrs => [ $attr_miembro_correo, $attr_moderador ]
                 });
                 
                 my @entries;
                 if($mesg->count) {
                     my $resp = $mesg->shift_entry;
                     my @rfcmembers = $resp->get_value($attr_miembro_correo);
                     my @moderators = $resp->get_value($attr_moderador);

                     foreach (@rfcmembers) {
                         $mesg = $ldap->search({
                             filter => "($attr_correo=" . $_ . ')',
                             attrs => ['givenName', 'sn', 'mail', 'uid']
                         });
                 
                         my $entry = $mesg->shift_entry;
                         if (defined $entry) {
                            if ($entry->dn =~ /^mail/) {
                                my $mgn = $entry->get_value('givenName') ? $entry->get_value('givenName') : '-'; 
                                my $msn = $entry->get_value('sn') ? $entry->get_value('sn') : '-'; 
                                my $muid = $entry->get_value('uid') ?
                                $entry->get_value('uid') : '-'; 
                                $entry->add(
                                    tipo      => 'Cuenta Virtual',
                                    givenName => $mgn,
                                    sn        => $msn,
                                    uid       => $muid,
                                )
                            }else{
                                $entry->add(
                                    tipo    => $entry->get_value($attr_moderador) ~~ @moderators ? "Moderador" : "Miembro",
                                );
                            }
                         } else {
                             $entry = Net::LDAP::Entry->new;
                             $entry->add(
                                 tipo      => 'Externo',
                                 givenName => '-',
                                 sn        => '-',
                                 mail      => $_,
                                 uid       => '-',
                             )
                         }
                         push @entries, $entry;
                 
                     }
                 
                 } else {
                     # No se encontraron elementos, se responde con 404
                     $self->status_not_found(
                        $c,
                        message => "No se encontro la lista: $lid",
                     );
                     return;
                 }
                 
                 $datos{aaData} = [
                     map {
                     [
                         '<input type="checkbox" name="del" value="'.$_->get_value($attr_correo).'">',
                         $_->get_value('tipo'),
                         $_->get_value($attr_correo),
                         &utf8_decode($_->get_value('givenName')),
                         &utf8_decode($_->get_value('sn')),
                         $_->get_value('uid'),
                     ]
                     } grep { !($_->{uid} eq 'root') } @entries,
                 ];
                 
                 $self->status_ok($c, entity => \%datos);
             }
        }
    }
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

sub addListaMembers_PUT {
    my($self, $c) = @_;
    my $ldap = Covetel::LDAP->new;

    my $personas = $c->req->data->{personas};
    my $lid      = $c->req->data->{lid};

    my $attr_miembro_correo = $c->config->{'Correo::Listas'}->{'attrs'}->{'miembro_correo'};
    my $attr_moderador = $c->config->{'Correo::Listas'}->{'attrs'}->{'moderador'};
    my $attr_miembro = $c->config->{'Correo::Listas'}->{'attrs'}->{'miembro'};
    my $attr_correo = $c->config->{'Correo::Listas'}->{'attrs'}->{'correo'};

   #Determina ObjectClass
   my $objectClass = $c->config->{'Correo::Listas'}->{'objectClass'};
   
   my @objectclass = split ' ', $objectClass;

   #Switch que evalua objectclass y limita atributos
   foreach my $objc (@objectclass) {
       given ($objc) {
            when ('qmailGroup') {
                my $filter = '(&' .
                '(objectClass=groupOfNames)' .
                $c->config->{'Correo::Listas'}->{'filter'} .
                "(cn=$lid)" .
                ')';

                my $mesg_lista = $ldap->search({
                    filter => $filter,
                    base => $c->config->{'Correo::Listas'}->{'basedn'},
                    attrs => ['rfc822member', 'member']
                });
                
                if($mesg_lista->is_error){
                     $self->status_not_found(
                         $c,
                         message => "No se encontro la lista: $lid",
                     );
                     return;
                }
                
                my $lista = $mesg_lista->shift_entry;
                
                my %datos;
                my @usuarios;
                foreach (@{$personas}){
                    s/\s+//g;
                    my $mesg = $ldap->search({
                        filter => "(|(uid=$_)($attr_correo=$_))",
                        attrs => [$attr_correo]
                    });
                    if ($mesg->count){
                        my $entry = $mesg->shift_entry;
                        $lista->add(
                               $attr_miembro_correo => $entry->get_value($attr_correo),
                               $attr_miembro => $entry->dn
                           )->update($ldap->server);
                    } else {
                        if(valid $_) {
                            $lista->add(
                               $attr_miembro_correo => $_
                           )->update($ldap->server);
                        } else {
                            $self->status_not_found(
                               $c,
                               message => "No se pudo encontrar el usuario $_",
                             );
                        }
                    }
                    push @usuarios, $_;
                }
                $datos{usuarios} = \@usuarios;
                $self->status_ok($c, entity => \%datos);
             }
             when ('sendmailMTA') {
                 my $filter = '(&' .
                 $c->config->{'Correo::Listas'}->{'filter'} .
                 "(sendmailMTAKey=$lid)" .
                 ')';

                 my $mesg_lista = $ldap->search({
                     filter => $filter,
                     base => $c->config->{'Correo::Listas'}->{'basedn'},
                     attrs => [$c->config->{'Correo::Listas'}->{'attrs'}->{'miembro_correo'}]
                 });
             
                 if($mesg_lista->is_error){
                      $self->status_not_found(
                          $c,
                          message => "No se encontro la lista: $lid",
                      );
                      return;
                 }
             
                 my $lista = $mesg_lista->shift_entry;
             
                 my %datos;
                 my @usuarios;
                 foreach (@{$personas}){
                     s/\s+//g;
                     my $mesg = $ldap->search({
                         filter => "(|(uid=$_)($attr_correo=$_))",
                         attrs => [$attr_correo]
                     });
                     if ($mesg->count){
                         my $entry = $mesg->shift_entry;
                         $lista->add(
                                $attr_miembro_correo => $entry->get_value($attr_correo),
                            )->update($ldap->server);
                     } else {
                         if(valid $_) {
                             $lista->add(
                                $attr_miembro_correo => $_
                            )->update($ldap->server);
                         } else {
                             $self->status_not_found(
                                $c,
                                message => "No se pudo encontrar el usuario $_",
                              );
                         }
                     }
                     push @usuarios, $_;
                 }
                 $datos{usuarios} = \@usuarios;
                 $self->status_ok($c, entity => \%datos);
             }
       }
   }
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
    $g->members($new_members);
    $g->update;
    $self->status_ok($c, entity => \%datos);
}

sub delListaMembers_DELETE {
    my($self, $c) = @_;
    my $ldap = Covetel::LDAP->new;

    my %datos;
    my $del = $c->req->data->{personas};
    my $lid = $c->req->data->{lid};

    my $attr_miembro_correo = $c->config->{'Correo::Listas'}->{'attrs'}->{'miembro_correo'};
    my $attr_moderador = $c->config->{'Correo::Listas'}->{'attrs'}->{'moderador'};
    my $attr_miembro = $c->config->{'Correo::Listas'}->{'attrs'}->{'miembro'};
    my $attr_correo = $c->config->{'Correo::Listas'}->{'attrs'}->{'correo'};

    #Determina ObjectClass
    my $objectClass = $c->config->{'Correo::Listas'}->{'objectClass'};
    
    my @objectclass = split ' ', $objectClass;

    #Switch que evalua objectclass y limita atributos
    foreach my $objc (@objectclass) {
        given ($objc) {
            when ('qmailGroup') {
                my $filter = '(&' .
                             '(objectClass=groupOfNames)' .
                             $c->config->{'Correo::Listas'}->{'filter'} .
                             "(cn=$lid)" .
                             ')';
              
              
                my $mesg_lista = $ldap->search({
                    filter => $filter,
                    base => $c->config->{'Correo::Listas'}->{'basedn'},
                    attrs => [ $attr_miembro_correo, $attr_moderador, $attr_miembro ]
                });
              
                if(!$mesg_lista->is_error) {
                   my $lista = $mesg_lista->shift_entry;
              
                     foreach (@{$del}) {
                         print $_;
                        my $mesg_member = $ldap->search({
                            filter => "($attr_correo=$_)",
                            attrs => [$attr_correo]
                        });
                        if ($mesg_member->count){
                            my $entry = $mesg_member->shift_entry;
              
                   # TODO: Evaluar el valor de retorno $mesg de las operaciones update. 
                   # si es un error, utilizar $self->status_bad_request 
              
                            $lista->delete(
                                   $attr_miembro_correo => $entry->get_value($attr_correo),
                                   $attr_miembro => $entry->dn
                               )->update($ldap->server);
                        } else {
                            if(valid $_) {
                                $lista->delete(
                                   $attr_miembro_correo => $_
                               )->update($ldap->server);
                            } else {
                                $self->status_not_found(
                                   $c,
                                   message => "No se pudo verificar/validar usuario $_",
                                );
                            }
                        }
                     }
                } else {
                    $self->status_not_found(
                       $c,
                       message => "No se encontro la lista: $lid",
                    );
                    return;
                }
              
                $self->status_ok($c, entity => \%datos);
            }
            when ('sendmailMTA') {
                my $filter = '(&' .
                             $c->config->{'Correo::Listas'}->{'filter'} .
                             "(sendmailMTAKey=$lid)" .
                             ')';
              
              
                my $mesg_lista = $ldap->search({
                    filter => $filter,
                    base => $c->config->{'Correo::Listas'}->{'basedn'},
                    attrs => [ $attr_miembro_correo, $attr_moderador ]
                });
              
                if(!$mesg_lista->is_error) {
                   my $lista = $mesg_lista->shift_entry;
                   my @moderators = $lista->get_value($attr_moderador);
              
                     foreach (@{$del}) {
                        my $mesg_member = $ldap->search({
                            filter => "($attr_correo=$_)",
                            attrs => [$attr_correo, 'uid']
                        });
                        if ($mesg_member->count){
                            my $entry = $mesg_member->shift_entry;
              
                   # TODO: Evaluar el valor de retorno $mesg de las operaciones update. 
                   # si es un error, utilizar $self->status_bad_request 
              
                            if ( $entry->get_value('uid') ne $c->user->uid ) {
                                $lista->delete(
                                       $attr_miembro_correo => $entry->get_value($attr_correo),
                                   )->update($ldap->server);
                            }else{
                                $self->status_bad_request(
                                    $c,
                                    message => "",
                                );
                                return;
                            }
                        } else {
                            if(valid $_) {
                                $lista->delete(
                                   $attr_miembro_correo => $_
                               )->update($ldap->server);
                            } else {
                                $self->status_not_found(
                                   $c,
                                   message => "No se pudo verificar/validar usuario $_",
                                );
                                return;
                            }
                        }
                     }
                } else {
                    $self->status_not_found(
                       $c,
                       message => "No se encontro la lista: $lid",
                    );
                    return;
                }
              
                $self->status_ok($c, entity => \%datos);
            }
        }
    }
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
    if ( $c->assert_user_roles(qw/Administradores/) ) {
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

         #sleep 6; # sleep utilizado para simular que se rompe el LDAP

        foreach my $e (@entries){
            my $resp = $ldap->server->delete($e);

            if ($resp->is_error){
                $self->status_bad_request(
                   $c,
                   message => "No se pudo eliminar la lista " . $e->get_value($nombre) . ", errores ldap: "
                   . $resp->error . ' ' . $resp->code . ' ' .
                   $resp->error_text . ' ' . $resp->error_desc,
                );
                return;
            }         
        }

        $self->status_ok($c, entity => { status => 1 });
    }
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

sub autocomplete_usuarios_GET {
    my($self, $c) = @_;
    my $ldap = Covetel::LDAP->new;
    my $autoc = lc($c->req->params->{term});

    my $filter = "(uid=$autoc*)";

    my $mesg = $ldap->search({
        filter => $filter,
        attrs => ['uid']
    });

    if($mesg->is_error) {
        return;
    }

    my @entries = $mesg->entries;

    my @datos;
    foreach my $entry (@entries) {
        push @datos, $entry->get_value('uid');
    }

    $self->status_ok($c, entity => \@datos);
}

sub listadirecciones_GET {
    my ($self, $c, $lid) = @_;
    my %datos;
    my $ldap = Covetel::LDAP->new;

    my $attr_miembro_correo = $c->config->{'Correo::Reenvios'}->{'attrs'}->{'miembro_correo'};
    my $attr_correo = $c->config->{'Correo::Reenvios'}->{'attrs'}->{'correo'};
 
    #Determina ObjectClass
    my $objectClass = $c->config->{'Correo::Reenvios'}->{'objectClass'};
    
    my @objectclass = split ' ', $objectClass;
 
    #Switch que evalua objectclass y limita atributos
    foreach my $objc (@objectclass) {
        given ($objc) {
             when ('qmailGroup') {
                 #Se desconoce metodo para llevar los forward con el objectClass qmailGroup
             }
             when ('sendmailMTA') {
                 my $filter = '(&' .
                              $c->config->{'Correo::Reenvios'}->{'filter'} .
                              "(sendmailMTAKey=$lid)" .
                              ')';
                 
                 my $mesg = $ldap->search({
                     filter => $filter,
                     base => $c->config->{'Correo::Reenvios'}->{'basedn'},
                     attrs => [ $attr_miembro_correo ]
                 });
                 
                 my @entries;
                 if($mesg->count) {
                     my $resp = $mesg->shift_entry;
                     my @rfcmembers = $resp->get_value($attr_miembro_correo);
                 
                     foreach (@rfcmembers) {
                         unless ( $_ eq '\\root') {
                             $mesg = $ldap->search({
                                 filter => "($attr_correo=" . $_ . ')',
                                 attrs => ['mail', 'uid']
                             });
                 
                             my $entry = $mesg->shift_entry;

                             push @entries, $entry;
                         }    
                 
                     }
                 
                 } else {
                     # No se encontraron elementos, se responde con 404
                     $self->status_not_found(
                        $c,
                        message => "No se encontro la lista: $lid",
                     );
                     return;
                 }

                 $datos{aaData} = [
                     map {
                         [
                             '<input type="checkbox" name="del" value="'.$_->get_value($attr_correo).'">',
                             $_->get_value($attr_correo),
                             $_->get_value('uid'),
                         ]
                     } grep { !($_->{uid} eq 'root') } @entries,
                 ];
                 
                 $self->status_ok($c, entity => \%datos);
             }
        }
    }
}

sub addforward_PUT {
    my($self, $c) = @_;
    my $ldap = Covetel::LDAP->new;

    my $direccion = $c->req->data->{direcciones};
    my $lid      = $c->req->data->{lid};

    my $attr_miembro_correo = $c->config->{'Correo::Reenvios'}->{'attrs'}->{'miembro_correo'};
    my $attr_correo = $c->config->{'Correo::Reenvios'}->{'attrs'}->{'correo'};

   #Determina ObjectClass
   my $objectClass = $c->config->{'Correo::Reenvios'}->{'objectClass'};
   
   my @objectclass = split ' ', $objectClass;

   #Switch que evalua objectclass y limita atributos
   foreach my $objc (@objectclass) {
       given ($objc) {
            when ('qmailGroup') {
                 #Covetel no utiliza ningun metodo para este objectclass
            }
            when ('sendmailMTA') {
                my $filter = '(&' .
                $c->config->{'Correo::Reenvios'}->{'filter'} .
                "(sendmailMTAKey=$lid)" .
                ')';

                my $mesg_lista = $ldap->search({
                    filter => $filter,
                    base => $c->config->{'Correo::Reenvios'}->{'basedn'},
                    attrs => [$c->config->{'Correo::Reenvios'}->{'attrs'}->{'miembro_correo'}]
                });

            
                if(!$mesg_lista->count){
                     my $lista = Net::LDAP::Entry->new;
         
                     # Base de busqueda LDAP
                     my $base = $c->config->{'Correo::Reenvios'}->{'basedn'};

                     # Construyo la cadena del correo
                     my $mail = $lid . '@' . $c->config->{domain};

                     # DN 
                     my $dn
                         =
                         $c->config->{'Correo::Reenvios'}->{'attrs'}->{'correo'} . '='
                         . $mail . ","
                         . $base;
            
                     $lista->dn($dn);
            
                     $lista->add( objectClass => [ @objectclass ] );
            
                     # Datos del moderador
                     $lista->add( 
                         homeDirectory => '/dev/null',
                         $c->config->{'Correo::Reenvios'}->{'attrs'}->{'correo'} => $mail,
                         $c->config->{'Correo::Reenvios'}->{'attrs'}->{'nombre'} => $lid,
                     );
    
                     # Datos de los miembros
                     $lista->add(
                         $c->config->{'Correo::Reenvios'}->{'attrs'}->{'miembro_correo'} => $mail,
                         $c->config->{'Correo::Reenvios'}->{'attrs'}->{'mailhost'} => $c->config->{'Correo::Reenvios'}->{'values'}->{'mailhost'},
                         sendmailMTAAliasGrouping => $c->config->{'Correo::Reenvios'}->{'values'}->{'sendmailMTAAliasGrouping'},
                     );

                    # Agrego la lista al ldap. 
                    my $resp = $ldap->server->add($lista);

                    if ( $resp->is_error ) {
                        $c->stash->{error} = 1;
                        $c->stash->{mensaje} = "Error agregando la lista a LDAP." . $resp->error_text; 
                    }
                    else {
                        $c->stash->{mensaje} = "La lista de correo ha sido registrada exitosamente";
                        $c->stash->{sucess} = 1;
                    }
                }

                my $mesg_reenvio = $ldap->search({
                    filter => $filter,
                    base => $c->config->{'Correo::Reenvios'}->{'basedn'},
                    attrs => [$c->config->{'Correo::Reenvios'}->{'attrs'}->{'miembro_correo'}]
                });

                if($mesg_reenvio->is_error){
                    $self->status_not_found(
                         $c,
                         message => "No se encontro la lista para reenvio: $lid",
                     );
                     return;
                }

                my $reenvio = $mesg_reenvio->shift_entry;
             
                my %datos;
                my @direcciones;
                foreach (@{$direccion}){
                    s/\s+//g;
                    my $mesg = $ldap->search({
                        filter => "($attr_correo=$_)",
                        attrs => [$attr_correo]
                    });
                    if ($mesg->count){
                        my $entry = $mesg->shift_entry;
                        $reenvio->add(
                               $attr_miembro_correo => $entry->get_value($attr_correo),
                           )->update($ldap->server);
                    } else {
                        if (($_ =~  $c->config->{domain}) || ($_ =~ $c->config->{'Correo::Reenvios'}->{'values'}->{'domain'})) {
                            $reenvio->add(
                               $attr_miembro_correo => $_
                           )->update($ldap->server);
                        } else {
                            $self->status_not_found( $c, message => "No se pudo encontrar el usuario $_", );
                        }
                    }
                    push @direcciones, $_;
                }
                $datos{direcciones} = \@direcciones;
                $self->status_ok($c, entity => \%datos);
             }
       }
   }
}

sub delforward_DELETE {
    my($self, $c) = @_;
    my $ldap = Covetel::LDAP->new;

    my %datos;
    my $del = $c->req->data->{direcciones};
    my $lid = $c->req->data->{lid};

    my $attr_miembro_correo = $c->config->{'Correo::Reenvios'}->{'attrs'}->{'miembro_correo'};
    my $attr_correo = $c->config->{'Correo::Reenvios'}->{'attrs'}->{'correo'};

    #Determina ObjectClass
    my $objectClass = $c->config->{'Correo::Reenvios'}->{'objectClass'};
     
    my @objectclass = split ' ', $objectClass;

    #Switch que evalua objectclass y limita atributos
    foreach my $objc (@objectclass) {
        given ($objc) {
            when ('qmailGroup') {
                 #Covetel no utiliza ningun metodo para este objectclass
            }
            when ('sendmailMTA') {
                my $filter = '(&' .
                             $c->config->{'Correo:Reenvios'}->{'filter'} .
                             "(sendmailMTAKey=$lid)" .
                             ')';
              
                my $mesg_reenvio = $ldap->search({
                    filter => $filter,
                    base => $c->config->{'Correo:Reenvios'}->{'basedn'},
                    attrs => [ $attr_miembro_correo ]
                });
                
                if(!$mesg_reenvio->is_error) {
                   my $lista = $mesg_reenvio->shift_entry;
                   # TODO: no se permiten suicidios. 
                   # Un moderator no puede eliminarse a si mismo si no hay más attr_moderadores.
                   # si esto ocurre devuelva un mensaje de error. 
              
                     foreach (@{$del}) {
                         print $_;
                        my $mesg_member = $ldap->search({
                            filter => "($attr_correo=$_)",
                            attrs => [$attr_correo]
                        });
                        if ($mesg_member->count){
                            my $entry = $mesg_member->shift_entry;
              
                   # TODO: Evaluar el valor de retorno $mesg de las operaciones update. 
                   # si es un error, utilizar $self->status_bad_request 
              
                            $lista->delete(
                                   $attr_miembro_correo => $entry->get_value($attr_correo),
                               )->update($ldap->server);
                        } else {
                            if(valid $_) {
                                $lista->delete(
                                   $attr_miembro_correo => $_
                               )->update($ldap->server);
                            } else {
                                $self->status_not_found(
                                   $c,
                                   message => "No se pudo verificar/validar usuario $_",
                                );
                            }
                        }
                     }
                } else {
                    $self->status_not_found(
                       $c,
                       message => "No se encontro la lista: $lid",
                    );
                    return;
                }

                $self->status_ok($c, entity => \%datos);

                my $mesg_delete = $ldap->search({
                    filter => $filter,
                    base => $c->config->{'Correo:Reenvios'}->{'basedn'},
                    attrs => [ 'dn', $attr_miembro_correo ]
                });

                my $forws = $mesg_delete->shift_entry; 
                if (!$forws->get_value($attr_miembro_correo)) {
                    my $resp_del = $ldap->server->delete($forws->dn);
                }
            }
        }
    }
}

sub autocomplete_mail_GET {
    my($self, $c) = @_;
    my $ldap = Covetel::LDAP->new;
    my $autoc = lc($c->req->params->{term});

    my $filter = "(mail=$autoc*)";

    my $mesg = $ldap->search({
        filter => $filter,
        attrs => ['mail']
    });

    if($mesg->is_error) {
        return;
    }

    my @entries = $mesg->entries;

    my @datos;
    foreach my $entry (@entries) {
        push @datos, $entry->get_value('mail');
    }

    $self->status_ok($c, entity => \@datos);
}

sub vacations_GET {
    my ( $self, $c, $uid ) = @_;

    my $ldap = Covetel::LDAP->new;
    my $base = $ldap->config->{'Covetel::LDAP'}->{'base_personas'};
    my $filter = '(&'.$c->config->{'Correo:Reenvios'}->{'filter'}."(uid=$uid)".')';
    
    my $mesg = $ldap->search({ 
            filter => $filter, 
            base => $c->config->{'Correo::Vacations'}->{'basedn'},
            attrs => ['*'], 
        });
    
    if ($mesg->count){
        foreach ($mesg->entries) {
            my $datos = $_->get_value($c->config->{'Correo::Vacations'}->{'attrs'}->{'active'}).",".$_->get_value($c->config->{'Correo::Vacations'}->{'attrs'}->{'mensaje'});
            
            push (my @info, $datos);

            $self->status_ok($c, entity => \@info);
        }
    }
}

sub forwardcc_PUT {
    my($self, $c) = @_;
    my $ldap = Covetel::LDAP->new;

    my $lid = $c->req->data->{lid};

    my $opt = $c->req->data->{opt};
    my $forward;

    my $filter = '(&' .
    $c->config->{'Correo::Reenvios'}->{'filter'} .
    "(sendmailMTAKey=$lid)" .
    ')';

    my $mesg = $ldap->search({
        filter => $filter,
        base => $c->config->{'Correo::Reenvios'}->{'basedn'},
        attrs => ['*']
    });

    if ($mesg->count) {
        my $forward = $mesg->shift_entry;
            if ($forward->get_value('sendmailMTAAliasValue') ne $lid && $opt == 1) {
                $forward->add($c->config->{'Correo::Reenvios'}->{'attrs'}->{'miembro_correo'}=>"\\$lid",)->update($ldap->server);
            }
            if ($forward->get_value('sendmailMTAAliasValue') ne $lid && $opt == 0) {
                $forward->delete($c->config->{'Correo::Reenvios'}->{'attrs'}->{'miembro_correo'}=>"\\$lid",)->update($ldap->server);
            }    
    }
}

sub forwardcca_GET {
    my ( $self, $c, $uid ) = @_;

    my $ldap = Covetel::LDAP->new;
    my $datos;
    
    my $filter = '(&' .
    $c->config->{'Correo::Reenvios'}->{'filter'} .
    "(sendmailMTAKey=$uid)" .
    "(sendmailMTAAliasValue=\\\\$uid)" .
    ')';

    my $mesg = $ldap->search({
        filter => $filter,
        base => $c->config->{'Correo::Reenvios'}->{'basedn'},
        attrs => [$c->config->{'Correo::Reenvios'}->{'attrs'}->{'miembro_correo'}]
    });
    
    if ($mesg->count){
        $datos = 1;
    }else{
        $datos = 0;
    }
            
    push (my @info, $datos);
    
    $self->status_ok($c, entity => \@info);
}

=head1 AUTHOR

Walter Vargas

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
