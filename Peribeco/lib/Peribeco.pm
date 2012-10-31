package Peribeco;
use Moose;
use namespace::autoclean;

use Catalyst::Runtime 5.80;

# Set flags and add plugins for the application
#
#         -Debug: activates the debug mode for very useful log messages
#   ConfigLoader: will load the configuration from a Config::General file in the
#                 application's home directory
# Static::Simple: will serve static files from the application's root
#                 directory

use Catalyst qw/
    Unicode::Encoding
    -Debug
    ConfigLoader
    Static::Simple

    Authentication
    Session
    Session::Store::FastMmap
    Session::State::Cookie

    Authorization::Roles
    Authorization::ACL
    
    
/;

extends 'Catalyst';

our $VERSION = '0.2-15';
$VERSION = eval $VERSION;

# Configure the application.
#
# Note that settings in Peribeco.conf (or other external
# configuration file that you set up manually) take precedence
# over this when using ConfigLoader. Thus configuration
# details given here can function as a default configuration,
# with an external configuration file acting as an override for
# local deployment.

__PACKAGE__->config(
    name => 'Peribeco',
    # Disable deprecated behavior needed by old applications
    disable_component_resolution_regex_fallback => 1,
);

__PACKAGE__->config(
    'Plugin::ConfigLoader' => { file => 'configuracion.yml' },
);

# Start the application
__PACKAGE__->setup();


=head1 NAME

Covetel Peribeco - Gestion de Plataforma Corporativa

=head1 SYNOPSIS

    script/Peribeco_server.pl

=head1 DESCRIPTION

=head2 Modulos Disponibles

=over

=item Gestion de Usuarios

=item Gestion de Grupos

=item Gestion de Listas de Correo

=item Fuera de Oficina

=item Reenvios de Correo

=item Gestion de Quotas

=back

=head1 AUTHOR

Cooperativa Venezolana de Tecnologias Libres R.S., <info@covetel.com.ve> 

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
