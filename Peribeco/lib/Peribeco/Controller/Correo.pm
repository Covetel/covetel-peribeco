package Peribeco::Controller::Correo;
use Moose;
use namespace::autoclean;
use Net::LDAP;
use Net::LDAP::Entry;
use Covetel::LDAP;
use Covetel::LDAP::Person;
use Data::Dumper;
use v5.10;
use utf8;

BEGIN { extends 'Catalyst::Controller::HTML::FormFu'; }

=head1 NAME

Peribeco::Controller::Correo - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 auto 

=cut 

sub auto :Private {
    my ( $self, $c ) = @_;
    my $covetel_ldap = Covetel::LDAP->new;
    
    my $ldap = $covetel_ldap->server;

    $self->{ldap} = $ldap;

}

=head2 index

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;
    $c->response->redirect( $c->uri_for('/correo/listas') );
}

sub listas : Path('listas') {
    my ( $self, $c ) = @_;
    if ( $c->assert_user_roles(qw/Administradores/) ) {
        $c->stash->{template} = 'correo/listas/lista.tt';
    }
}

sub quota : Path('quota') :FormConfig('correo/quota.yml') {
    my ( $self, $c ) = @_;
    if ( $c->assert_user_roles(qw/Administradores/) ) {
        $c->stash->{template} = 'correo/quota/lista.tt';
    }
}

sub quotaglobal : Path('quota/global_quota') :FormConfig('correo/quota_global.yml') {
    my ( $self, $c ) = @_;
    if ( $c->assert_user_roles(qw/Administradores/) ) {
        $c->stash->{template} = 'correo/quota/quota_global.tt';
    }
}

sub crear :Path('listas/crear') :FormConfig('correo/listas_crear.yml') {
    my ( $self, $c ) = @_;
    
    # En donde esta la plantilla ?
    $c->stash->{template} = 'correo/listas/crear.tt';
    $c->stash->{error} = 0;

    if ( $c->assert_user_roles(qw/Administradores/) ) {

        # Clases para los campos requeridos.
        my $form = $c->stash->{form};
        $form->auto_constraint_class('constraint_%t');

        if ( $form->submitted_and_valid ) {

            # Creo la entrada de la lista en LDAP
            # TODO: Esto se debe poner en un método. 
            
            my $uid         = $c->req->param('uid');
            my $desc        = $c->req->param('desc');
            my $moderator_uid = $c->req->param('moderator');

            # Busco el usuario moderador
            my $moderator = $c->user->{store}->get_user($moderator_uid, $c);

            my $lista = Net::LDAP::Entry->new;

            # Base de busqueda LDAP
            my $base = $c->config->{'Correo::Listas'}->{'basedn'};

            #Determina ObjectClass
            my $objectClass = $c->config->{'Correo::Listas'}->{'objectClass'};
            
            my @objectclass = split ' ', $objectClass;

            #Switch que evalua objectclass y limita atributos
            foreach my $objc (@objectclass) {
                given ($objc) {
                    when ('qmailGroup') {
                        # DN 
                        my $dn
                            = $c->config->{'Correo::Listas'}->{'attrs'}->{'nombre'} . '='
                            . $uid . ","
                            . $base;
            
                        $lista->dn($dn);
            
                        $lista->add( objectClass => [ @objectclass ] );
            
                        # Construyo la cadena del correo
                        my $mail = $uid . '@' . $c->config->{domain};
            
                        # Atributos MUST de la entrada. 
                        $lista->add( 
                            mailMessageStore => '/dev/null',
                            mailAlternateAddress => $mail,
                            $c->config->{'Correo::Listas'}->{'attrs'}->{'correo'} => $mail,
                            $c->config->{'Correo::Listas'}->{'attrs'}->{'miembro'} => $moderator->dn,
                            $c->config->{'Correo::Listas'}->{'attrs'}->{'nombre'} => $uid,
                        );
    
                        # Datos del moderador
                        $lista->add(
                            $c->config->{'Correo::Listas'}->{'attrs'}->{'moderador'} => $moderator->dn,
                            $c->config->{'Correo::Listas'}->{'attrs'}->{'miembro_correo'} => $moderator->mail,
                        );
                    }
                    when ('sendmailMTA') {
                        # Construyo la cadena del correo
                        my $mail = $uid . '@' . $c->config->{domain};

                        # DN 
                        my $dn
                            =
                            $c->config->{'Correo::Listas'}->{'attrs'}->{'correo'} . '='
                            . $mail . ","
                            . $base;
            
                        $lista->dn($dn);
            
                        $lista->add( objectClass => [ @objectclass ] );
            
                        # Datos del moderador
                        $lista->add( 
                            homeDirectory => '/dev/null',
                            $c->config->{'Correo::Listas'}->{'attrs'}->{'correo'} => $mail,
                            $c->config->{'Correo::Listas'}->{'attrs'}->{'nombre'} => $uid,
                        );
    
                        # Datos de los miembros
                        $lista->add(
                            $c->config->{'Correo::Listas'}->{'attrs'}->{'miembro_correo'} => $moderator->mail,
                            $c->config->{'Correo::Listas'}->{'attrs'}->{'mailhost'} => $c->config->{'Correo::Listas'}->{'values'}->{'mailhost'},
                        );
                    }
                }
            }

            # Agrego la lista al ldap. 
            my $resp = $self->{ldap}->add($lista);

            if ( $resp->is_error ) {
                $c->stash->{error} = 1;
                $c->stash->{mensaje} = "Error agregando la lista a LDAP." . $resp->error_text; 
            }
            else {
                $c->stash->{mensaje} = "La lista de correo ha sido registrada exitosamente";
                $c->stash->{sucess} = 1;
            }
        }
        elsif ( $form->has_errors && $form->submitted ) {

            # Obtengo el campo que fallo
            my @err_fields = $form->has_errors;
            my $label      = $form->get_field( $err_fields[0] )->label;

            $c->stash->{error} = 1;
            $c->stash->{mensaje} =
"Ha ocurrido un error en el campo <span class='strong'> $label </span> ";
        }
    }
}

sub detalle : Path('listas/detalle'){
    my ( $self, $c, $lid ) = @_;
    $c->stash->{template} = 'correo/listas/detalle.tt';
    if ($c->assert_user_roles(qw/Administradores/)) {
        my $ldap = Covetel::LDAP->new;

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
                        attrs => ['cn', 'description']
                    });
            
                    if($mesg->count) {
                        my $resp = $mesg->shift_entry;
                        my $lista = { nombre => $resp->get_value('cn'),
                                      description => $resp->get_value('description') };
                        $c->stash->{lista} = $lista;
                    }
                }
                when ('sendmailMTA') {
                    my $filter = '(&' .
                                 $c->config->{'Correo::Listas'}->{'filter'} .
                                 "(sendmailMTAKey=$lid)" .
                                 ')';
            
                    my $mesg = $ldap->search({
                        filter => $filter,
                        base => $c->config->{'Correo::Listas'}->{'basedn'},
                        attrs => ['sendmailMTAKey']
                    });
            
                    if($mesg->count) {
                        my $resp = $mesg->shift_entry;
                        my $lista = { nombre => $resp->get_value('sendmailMTAKey') };
                        $c->stash->{lista} = $lista;
                    }
                }
            }
        }
    }
}

sub reenvios : Path('reenvios') {
    my ( $self, $c ) = @_;
    if ( $c->assert_user_roles(qw/Administradores/) ) {
        $c->stash->{template} = 'correo/reenvios/lista.tt';
    }
}

            
=head1 AUTHOR

ApHu,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
