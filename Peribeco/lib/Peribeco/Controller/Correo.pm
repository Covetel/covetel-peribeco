package Peribeco::Controller::Correo;
use Moose;
use namespace::autoclean;
use Net::LDAP;
use Net::LDAP::Entry;
use Covetel::LDAP;
use Covetel::LDAP::Person;
use Data::Dumper;
use utf8;

BEGIN { extends 'Catalyst::Controller::HTML::FormFu'; }

=head1 NAME

Peribeco::Controller::Personas - Catalyst Controller

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

sub quota : Path('quota') {
    my ( $self, $c ) = @_;
    if ( $c->assert_user_roles(qw/Administradores/) ) {
        $c->stash->{template} = 'correo/quota/lista.tt';
    }
}

sub eliminar : Local {
    my ( $self, $c, $uid ) = @_;
    if ( $c->assert_user_roles(qw/Administradores/) ) {
        my $ldap = Covetel::LDAP->new;
        my $person = $ldap->person( { uid => $uid } );
        if ($person) {
            if ( $person->del() ) {
                $c->stash->{mensaje} = "El registro de la persona
                " . $person->firstname . " fue eliminado exitosamente";
            }
        }
        else {
            $c->stash->{error}   = 1;
            $c->stash->{mensaje} = "No se encontro la persona";
        }
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

            # DN 
            my $dn
                = $c->config->{'Correo::Listas'}->{'attrs'}->{'nombre'} . '='
                . $uid . ","
                . $base;

            $lista->dn($dn);

            my $objectClass = $c->config->{'Correo::Listas'}->{'objectClass'};

            my @objectclass = split ' ', $objectClass;

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

sub detalle : Local {
    my ( $self, $c, $uid ) = @_;
    my $ldap = Covetel::LDAP->new;
    my $person = $ldap->person( { uid => $uid } );
    $c->stash->{persona} = $person;
}

sub modify_data : Local : FormConfig {
    my ( $self, $c, $uid ) = @_;
    my $form = $c->stash->{form};
    $form->auto_constraint_class('constraint_%t');
    if ( $form->submitted_and_valid ) {

        #capturando campos
        my $nombre   = $c->req->param("nombre");
        my $apellido = $c->req->param("apellido");
        my $ced      = $c->req->param("ced");

        my $ldap = Covetel::LDAP->new;
        my $base = $ldap->config->{'Covetel::LDAP'}->{'base_personas'};
        $uid = $c->user->uid;

        my $persona = $ldap->person( { uid => $uid } );
        my $dn      = $persona->dn;
        my $entry   = $persona->entry;

        #$entry->replace(
        #    givenName => $nombre,
        #    sn        => $apellido,
        #    mail      => $email,
        #    ced       => $ced,
        #);
        #print Dumper( $nombre, $apellido, $ced, $email );
        print Dumper($entry);

        my $mesg = $ldap->server->modify(
            $entry->dn,
            replace => {
                givenName => $nombre,
                sn        => $apellido,
                pager	  => $ced,
            }
          );

        #if ( $entry->update($ldap->server) ) {
        if (! $mesg->is_error ) {
            $c->stash->{mensaje} = "Datos Actualizados";
        }
        else {
            $c->stash->{error}   = 1;
            $c->stash->{mensaje} = "Error al actualizar ". $mesg->error_text . " " . $mesg->error_desc . " " . $mesg->error;
        }
    }
}

sub change_pass : Local : FormConfig {
    my ( $self, $c, $uid ) = @_;
    $uid = $c->user->uid;
    my $form = $c->stash->{form};
    $form->auto_constraint_class('constraint_%t');
    if ( $form->submitted_and_valid ) {

        #capturo campos
        my $pass_actual  = $c->req->param("pass_actual");
        my $new_pass     = $c->req->param("new_pass");
        my $con_new_pass = $c->req->param("con_new");

        #valido que el password del user logeado para el cambio de pass
        if ( $c->user->check_password($pass_actual) ) {
            my $ldap   = Covetel::LDAP->new;
            my $person = Covetel::LDAP::Person->new(
                {
                    uid  => $uid,
                    ldap => $ldap
                }
            );
            my $persona = $ldap->person( { uid => $uid } );
            my $dn = $persona->dn;
            if ( $person->change_pass( $new_pass, $dn ) ) {
                $c->stash->{mensaje} = "Contraseña Actualizada";
            }
            else {
                $c->stash->{error}   = 1;
                $c->stash->{mensaje} = "Error al actualizar contraseña";
            }
        }
        else {
            $c->stash->{error}   = 1;
            $c->stash->{mensaje} = "Contraseña Invalida";
        }
    }
    elsif ( $form->has_errors && $form->submitted ) {
        my @err_fields = $form->has_errors;
        my $label      = $form->get_field( $err_fields[0] )->label;
        $c->stash->{error} = 1;
        $c->stash->{mensaje} =
"Ha ocurrido un error en el campo <span class='strong'> $label </span> ";
    }
}

sub reset_pass : Local : FormConfig {
    my ( $self, $c, $uid ) = @_;
    if ( $c->assert_user_roles(qw/Administradores/) ) {
        my $form = $c->stash->{form};

        #Obtengo elemento fieldset
        my $fieldset = $form->get_element( { type => 'Fieldset' } );

        #Creo elemento oculto con el uid en el formulario
        my $element = $fieldset->element(
            {
                type  => 'Text',
                name  => 'uid',
                value => $uid
            }
        );

        $element->add_attrs( { class => 'input_text oculto' } );
        $element->add_attrs( { id    => 'uid_field' } );

        $form->auto_constraint_class('constraint_%t');

        if ( $form->submitted_and_valid ) {

            #capturo campos
            $uid = $c->req->param("uid");
            my $new_pass     = $c->req->param("new_pass");
            my $con_new_pass = $c->req->param("con_new");

            #valido que el password del user logeado para el cambio de pass
            if ( $c->check_user_roles(qw/Administradores/) ) {
                my $ldap   = Covetel::LDAP->new;
                my $person = Covetel::LDAP::Person->new(
                    {
                        uid  => $uid,
                        ldap => $ldap
                    }
                );
                my $persona = $ldap->person( { uid => $uid } );
                my $dn = $persona->dn;
                if ( $person->change_pass( $new_pass, $dn ) ) {
                    $c->stash->{mensaje} = "Contraseña Actualizada";
                }
                else {
                    $c->stash->{error}   = 1;
                    $c->stash->{mensaje} = "Error al actualizar contraseña";
                }
            }
            else {
                $c->stash->{error}     = 1,
                  $c->stash->{mensaje} = 'Ud no puede realizar esta operación';
            }
        }
        elsif ( $form->has_errors && $form->submitted ) {
            my @err_fields = $form->has_errors;
            my $label      = $form->get_field( $err_fields[0] )->label;
            $c->stash->{error} = 1;
            $c->stash->{mensaje} =
"Ha ocurrido un error en el campo <span class='strong'> $label </span> ";
        }
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
