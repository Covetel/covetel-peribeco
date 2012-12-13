package Peribeco::Controller::Applications;
use Moose;
use namespace::autoclean;
use Data::Dumper;
use Net::SMTP;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

Peribeco::Controller::Applications - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->body('Matched Peribeco::Controller::Applications in Applications.');
}

sub send_mail : Path('send_mail') {
    my ($self, $c, $mail) = @_;

    print Dumper($c);

    my $server = $c->config->{'Mail::Server'}->{'server'};
    my $host = $c->config->{'Mail::Server'}->{'host'};
    my $port = $c->config->{'Mail::Server'}->{'port'};
    my $account = $c->config->{'Mail::Server'}->{'account'};
    my $pass = $c->config->{'Mail::Server'}->{'pass'};

    my $subject = $c->config->{'Mail::Server'}->{'mail'}->{'subject'};
    my $message = $c->config->{'Mail::Server'}->{'mail'}->{'message'};

    my $smtp;

    if ($account && $pass) {
        $smtp = new Net::SMTP($server, 
            Hello => $host, 
            Port  => $port, 
            User  => $account, 
            Password => $pass);
    }else{
        $smtp = new Net::SMTP($server, 
            Hello => $host, 
            Port  => $port, 
        );
    }

    $smtp->mail($account);
    $smtp->to($mail);
    $smtp->data;
    $smtp->datasend("To: ".$mail."\n");
    $smtp->datasend("From: ".$account);
    $smtp->datasend("\n");

    $smtp->datasend("Subject: ".$subject."\n");
    $smtp->datasend("\n");
    $smtp->datasend($message."\n");
    $smtp->dataend();
    $smtp->quit;
}

=head1 AUTHOR

Carlos Paredes,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
