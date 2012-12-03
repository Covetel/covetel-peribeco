package Peribeco::Controller::Personas;
use Moose;
use namespace::autoclean;
use Net::LDAP;
use Net::LDAP::Extension::SetPassword;
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

=head2 index

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;
    $c->response->redirect( $c->uri_for('/personas/lista') );
}

sub lista : Local {
    my ( $self, $c ) = @_;
    if ($c->config->{'Modulos'}->{'Personas'}->{'Active'} == 1 && $c->config->{'Modulos'}->{'Personas'}->{'Administrar'} == 1) {
        if ( $c->assert_user_roles(qw/Administradores/) ) {
            my $ldap  = Covetel::LDAP->new;
            my @lista = $ldap->person();
            $c->stash->{personas} = \@lista;
            $c->stash->{modules} = $c->config->{'Modulos'}; 
        }else{
            $c->res->body('No tiene permisos para ver esta información <a class="enlace" href="/personas/detalle/'.$c->user->uid.'" alt="Regresar"> Regresar </a>');
        }
    }else{
        $c->res->body('Modulo no disponible <a class="enlace" href="/personas/lista" alt="Regresar a lista de Personas"> Regresar </a>');
    }
}

sub eliminar : Local {
    my ( $self, $c, $uid ) = @_;
    if ($c->config->{'Modulos'}->{'Personas'}->{'Active'} == 1 && $c->config->{'Modulos'}->{'Personas'}->{'Administrar'} == 1) {
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
    }else{
        $c->res->body('Modulo no disponible <a class="enlace" href="/personas/lista" alt="Regresar a lista de Personas"> Regresar </a>');
    }
   $c->stash->{modules} = $c->config->{'Modulos'}; 
}

sub crear : Local : FormConfig {
    my ( $self, $c ) = @_;
    if ($c->config->{'Modulos'}->{'Personas'}->{'Active'} == 1 && $c->config->{'Modulos'}->{'Personas'}->{'Administrar'} == 1) {
        if ( $c->assert_user_roles(qw/Administradores/) ) {
        $c->stash->{modules} = $c->config->{'Modulos'}; 
    
            # Clases para los campos requeridos.
            my $form = $c->stash->{form};
            $form->auto_constraint_class('constraint_%t');
    
            if ( $form->submitted_and_valid ) {
                my $uid       = $c->req->param("uid");
                my $firstname = $c->req->param("nombre");
                my $lastname  = $c->req->param("apellido");
                my $password  = $c->req->param("passwd");
                my $ced       = $c->req->param("ced");
                my $email     = $c->req->param("mail");
                my $pass_tmp  = "RyimOov5";
    
                my $person = Covetel::LDAP::Person->new(
                    {
                        uid          => $uid,
                        firstname    => $firstname,
                        lastname     => $lastname,
                        ced          => $ced,
                        email        => $email,
                        mailhost     => $c->config->{Personas}->{Values}->{mailhost},
                        quota        => $c->config->{Personas}->{Values}->{quota},
                    }
                );
    
                $person->password($pass_tmp);
    
                my $dn = $person->dn();
    
                if ( $person->add ) {
                    # Password con Net::LDAP::Extension::SetPassword
                    my $ldap = Covetel::LDAP->new;
                    my $mesg = $ldap->server->set_password( user => $dn,
                                                    newpasswd => $password,
                                                  );
                    die "error: ",  $mesg->code(),  ": ",  $mesg->error() if ($mesg->code());
                    $c->stash->{mensaje} = "La persona $firstname $lastname ha sido
                ingresada exitosamente";
                    $c->stash->{sucess} = 1;
                }
                else {
                    $c->stash->{error} = 1;
                    $c->stash->{mensaje} =
                      "<strong> Error Crítico en LDAP:</strong>"
                      . $person->ldap->error_str();
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
    }else{
        $c->res->body('Modulo no disponible <a class="enlace" href="/personas/lista" alt="Regresar a lista de Personas"> Regresar </a>');
    }
    $c->stash->{modules} = $c->config->{'Modulos'}; 
}

sub detalle : Local {
    my ( $self, $c, $uid ) = @_;
    if ($uid eq $c->user->uid || $c->assert_user_roles(qw/Administradores/) ) {
        if ($c->config->{'Modulos'}->{'Personas'}->{'Active'} == 1 && $c->config->{'Modulos'}->{'Personas'}->{'Detalle'} == 1) {
            my $ldap = Covetel::LDAP->new;
            my %person = ();

            my $filter =  '(&(objectClass=person)(uid='.$uid.'))';
            my $base = $c->config->{authentication}->{realms}->{ldap}->{store}->{user_basedn};

            my $result = $ldap->search({
                filter => $filter,
                base => $base,
                attrs => ['*'],
            });

            if ($result->count > 0) {
                my $entry = $result->shift_entry;
                foreach my $attr (keys %{$c->config->{Personas}->{Detalle}->{attrs}}) {
                    if ($attr eq 'dn') {
                        $person{$attr} = $entry->dn;
                    }else{
                        $person{$attr} = $entry->get_value($attr);
                    }
                }
            }

            my $person = \%person;
            $c->stash->{persona} = $person;
            $c->stash->{modules} = $c->config->{'Modulos'}; 
        }else{
            $c->res->body('Modulo no disponible <a class="enlace" href="/personas/lista" alt="Regresar a lista de Personas"> Regresar </a>');
        }
    }else{
        $c->res->body('No tiene permisos para ver esta información <a class="enlace" href="/personas/detalle/'.$c->user->uid.'" alt="Regresar"> Regresar </a>');
    }
}

sub modify_data : Local : FormConfig {
    my ( $self, $c, $uid ) = @_;
    if ($uid eq $c->user->uid) {
        $uid = $c->user->uid;
    }
    if ($uid eq $c->user->uid || $c->assert_user_roles(qw/Administradores/) ) {
        if ($c->config->{'Modulos'}->{'Personas'}->{'Modificar'} == 1) {
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
    
                #capturando campos
                $uid = $c->req->param("uid");
                my $nombre   = $c->req->param("nombre");
                my $apellido = $c->req->param("apellido");
                my $ced      = $c->req->param("ced");
    
                my $ldap = Covetel::LDAP->new;
                my $base = $ldap->config->{'Covetel::LDAP'}->{'base_personas'};
    
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
    
                my $mesg = $ldap->server->modify(
                    $entry->dn,
                    replace => {
                        givenName => $nombre,
                        sn        => $apellido,
                        pager	  => $ced,
                    }
                  );
    
                if (! $mesg->is_error ) {
                    $c->stash->{mensaje} = "Datos Actualizados";
                }
                else {
                    $c->stash->{error}   = 1;
                    $c->stash->{mensaje} = "Error al actualizar ". $mesg->error_text . " " . $mesg->error_desc . " " . $mesg->error;
                }
            }
        }
    }else{
        $c->res->body('No tiene permisos para ver esta información <a class="enlace" href="/personas/detalle/'.$c->user->uid.'"alt="Regresar"> Regresar </a>');
    }
    $c->stash->{modules} = $c->config->{'Modulos'}; 
}

sub change_pass : Local : FormConfig {
    my ( $self, $c ) = @_;
    my $uid = $c->user->uid;

    if ($uid eq $c->user->uid || $c->check_user_roles(qw/Administradores/) ) {
        if ($c->config->{'Modulos'}->{'Personas'}->{'Modificar'} == 1) {
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
                    # Cambiando password con libreria Net::LDAP::Extension::SetPassword
                    if ( $ldap->server->set_password( user => $dn, oldpasswd => $pass_actual, newpasswd => $new_pass) ) {
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
                $c->stash->{mensaje} = "Ha ocurrido un error en el campo <span class='strong'> $label </span> ";
            }
        }
    }else{
        $c->res->body('No tiene permisos para ver esta información <a class="enlace" href="/personas/detalle/'.$c->user->uid.'" alt="Regresar"> Regresar </a>');
    }
    $c->stash->{modules} = $c->config->{'Modulos'}; 
}

sub reset_pass : Local : FormConfig {
    my ( $self, $c, $uid ) = @_;
    if ( $c->assert_user_roles(qw/Administradores/) ) {
        if ($c->config->{'Modulos'}->{'Personas'}->{'Password'} == 1) {
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
                    #if ( $person->change_pass( $new_pass, $dn ) ) {
                    # Reset password con libreria Net::LDAP::Extension::SetPassword
                    if ( $ldap->server->set_password( user => $dn, newpasswd => $new_pass) ) {
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
"Ha ocur    rido un error en el campo <span class='strong'> $label </span> ";
            }
        }
    }
    $c->stash->{modules} = $c->config->{'Modulos'}; 
}

=head1 AUTHOR

ApHu,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
