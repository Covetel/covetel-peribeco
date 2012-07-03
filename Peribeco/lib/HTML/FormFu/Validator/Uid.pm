package HTML::FormFu::Validator::Uid;
use strict;
use warnings;
use base 'HTML::FormFu::Validator';
use utf8;
use Covetel::LDAP;

sub validate_value {
    my ( $self, $value, $params ) = @_;

    my $c = $self->form->stash->{context};

    my $ldap = Covetel::LDAP->new;
    
    my $filter = "(uid=$value)";

    my $mesg_member = $ldap->search({
                filter => $filter,
            });
    if ($mesg_member->count){
         return 1;
    }

    die HTML::FormFu::Exception::Validator->new({
        message => 'El uid que está intentando ingresar no existe',
    });
}

1;
