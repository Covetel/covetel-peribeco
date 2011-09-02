package Peribeco::View::HTML;

use strict;
use warnings;
use utf8;

use base 'Catalyst::View::TT';

__PACKAGE__->config(
    TEMPLATE_EXTENSION => '.tt',
    INCLUDE_PATH => [ 
        Peribeco->path_to('root', 'lib'),  
        Peribeco->path_to('root', 'src') 
    ], 
    render_die => 1,
    WRAPPER => 'header.tt', 
    CATALYST_VAR => 'c', 
    ENCODING     => 'utf-8',
    
);

=head1 NAME

Peribeco::View::HTML - TT View for Peribeco

=head1 DESCRIPTION

TT View for Peribeco.

=head1 SEE ALSO

L<Peribeco>

=head1 AUTHOR

ApHu,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
