package Peribeco::LDAP::Correo;
use base qw/Catalyst::Model::LDAP::Connection Peribeco::LDAP/;
use Net::LDAP::Entry;
use common::sense;
use Data::Dumper;

=head1 NAME

Peribeco::LDAP::Correo

=head1 DESCRIPTION

This is a data model representatio and operations over Mail entries in
LDAP

=head1 METHODS

=head2 forwards

Get method for forwards by uid. This method return a Net::LDAP::Entry of Forward.

=head3 EXAMPLE

 my $model = $c->model('LDAP::Correo');
 my $forward_entry = $model->forwards($uid);

=cut

sub forwards {
    my ($self, $uid) = @_;

    # Defino la base de búsqueda.
    $self->base($self->forwards_base);

    my $filter = $self->filter_append( 
            $self->forwards_filter,
            $self->forwards_dn_attr . '=' . $uid
        );

    # Returns list of forwards for the mail account in $c->user->mail
    my $resp = $self->search($filter);

    $self->_message($resp);

    if ($resp->count){
        return $resp->shift_entry;
    } else {
        return undef;
    }
}

=head2 forward_list

Return forward list

=head3 EXAMPLE

 my $model = $c->model('LDAP::Correo');
 my @forwards_mailrfc822 = $model->forward_list($uid);

=cut

sub forward_list {
    my ($self, $uid) = @_;

    if (my $e = $self->forwards($uid)){
        my @forwards = $e->get_value( $self->forwards_mail_dst );
        return @forwards;
    } else {
        return undef;
    }

}

=head2 forward_create

Create forward entry

=head3 EXAMPLE

 my $model = $c->model('LDAP::Correo');

 if ($model->forward_create(['correo1@cantv.com.ve','correo2@cantv.com.ve'],'emujic')){
     print "Entry created";
 } else {
     print "Message is: " , $model->_message;    
 }

=cut

sub forward_create {
    my ($self, $uid, $localcopy, $forward) = @_;
    
    if ($localcopy){
        my $localcopy_str = chr(92) . $uid;
        push @{$forward}, $localcopy_str 
            unless grep {/$localcopy_str/} @{$forward};  
    }

    my $e = $self->forward_new_entry($forward, $uid);

  print Dumper $e->dump;

    my $resp = $self->add($e);

    $self->_message($resp);

    if ($resp->is_error){
        return undef;
    } else {
        return 1; 
    }
}

=head2 forward_update 

This method update forwards mail address

=head3 EXAMPLE

 my $model = $c->model('LDAP::Correo');

 my @forwards = qw/user@example.com user2@example.com/; 

 my $uid = $c->user->uid;

 $model->forward_update($uid, @forwards);

=cut

sub forward_update {
    my ($self, $uid, $localcopy, $forwards) = @_; 

    my $e = $self->forwards($uid);
    
    if ($localcopy){
        my $localcopy_str = chr(92) . $uid;
        push @{$forwards}, $localcopy_str 
            unless grep {/$localcopy_str/} @{$forwards};  
    }

    if ($e){

        $e->replace(
            $self->forwards_mail_dst => $forwards,
        );

        my $resp = $e->update($self);

        $self->_message($resp);

        if ($resp->is_error){
            return undef;
        } else {
            return 1; 
        }
    } else {
        return undef;
    }
}

=head2 forward_new_entry

=over

=item Return Net::LDAP::Entry for Forwards

=item Require as parameters: C<forward( $rfc822_mail, $uid )>

=back

=cut

sub forward_new_entry {
    my ($self, $forward, $uid) = @_;
    
    $self->base($self->forwards_base);

    my $dn = $self->forwards_dn_attr . '=' . $uid . ',' . $self->base;

    my $e = Net::LDAP::Entry->new; 

    $e->dn($dn);

    $e->add( objectClass => [ $self->forwards_objectclass ]);

    my $attrs = $self->forwards_default_attrs;

    # Atributos Valuados
    my $values = {
        $self->forwards_dn_attr => $uid, 
        $self->forwards_mail_dst =>  $forward,
    };

    foreach (keys %{$attrs}){
        unless ($attrs->{$_}){
            $attrs->{$_} = $values->{$_};
        }
        $e->add($_ => $attrs->{$_}); 
    }

    return $e;
}

=head2 forwards_localcopy

Return true if localcopy is set, undef is not set.

=cut 

sub forwards_localcopy {
    my ($self, $uid) = @_;

    my @forwards = $self->forward_list($uid); 
    if (grep {/\\/} @forwards){
        return 1;
    } else {
        return 0;
    }
}

=head2 forwards_localcopy_str

Return localcopy string

=cut 

sub forwards_localcopy_str {
    my ($self, $uid) = @_;
    return chr(92) . $uid; 
}


=head2 forwards_base 

Return Forwards search base.

=cut

sub forwards_base {
    my $self = shift; 

    return $self->config->{'Correo::Reenvios'}->{'basedn'};
}

=head2 forwards_filter 

Return Forwards LDAP filter

=cut

sub forwards_filter {
    my $self = shift;

    return $self->config->{'Correo::Reenvios'}->{'filter'}; 
}

=head2 forwards_dn_attr 

Return attribute for RDN creation. 

=cut 

sub forwards_dn_attr {
    my $self = shift;

    return $self->config->{'Correo::Reenvios'}->{'entry'}->{'dn_attr'};
}

=head2 forwards_objectclass 

Return ObjectClass list

=cut

sub forwards_objectclass {
    my $self = shift;
    
    my $string = $self->config->{'Correo::Reenvios'}->{'entry'}->{'objectclass_attr'}; 
    my @objectClass = split ' ',$string;

    return @objectClass;
}

=head2 forwards_default_attrs

Return default attributes of Forward entry

=cut 

sub forwards_default_attrs {
    my $self = shift; 

    return $self->config->{'Correo::Reenvios'}->{'entry'}->{'default_attrs'}; 
}

=head2 forwards_mail_dst

Return attr that store mail dst of forwards

=cut 

sub forwards_mail_dst {
    my $self = shift; 

    return $self->config->{'Correo::Reenvios'}->{'attrs'}->{'miembro_correo'}; 
}

=head2 maillist_fetch

Return list of maillist by uid

=cut 

sub maillist_fetch {
   my ($self, $uid) = @_; 
    
   my $filter = $self->config->{'Correo::Listas'}->{'filter'};
   my $moderator_f = $self->config->{'Correo::Listas'}->{'attrs'}->{'moderador'};

   if ($moderator_f){
       $filter = $self->filter_append($filter,"$moderator_f=$uid");
   }

   $self->base($self->config->{'Correo::Listas'}->{'basedn'});

   my $mesg = $self->search($filter);
    
   $self->_message($mesg);
   
   if ($mesg->count){
       return $mesg->entries;
   } else { 
       return undef;
   }

}

=head2 maillist_update
 
Update maillist members

=cut

sub maillist_update {
    my ($self, @entries) = @_;
    foreach (@entries) {
        my $resp = $_->update($self); 
        $self->_message($resp); 
        if ($resp->is_error){
            return undef; 
        } else {
            return 1;
        }
    }
}

=head2 maillist_attr_members

Return atributo for store mail members

=cut

sub maillist_attr_members {
    my $self = shift; 

    return $self->config->{'Correo::Listas'}->{'attrs'}->{'miembro_correo'};
}

=head2 maillist_attr_mail

Return atributo for store mail

=cut

sub maillist_attr_mail {
    my $self = shift; 

    return $self->config->{'Correo::Listas'}->{'attrs'}->{'correo'};
}

=head mailhost

Return mailhost by user, when mailhost in not equal in the conf file change
mailhost in LDAP

=cut

sub mailhost {
    my ($self, $uid) = @_;
    my $mailhost;

    my $user_field = $self->config->{'authentication'}->{'realms'}->{'ldap'}->{'store'}->{'user_field'}; 
    #my $self->base($self->config->{'authentication'}->{'realms'}->{'ldap'}->{'store'}->{'user_basedn'});

    my $filter = $self->filter_append(
        '(ObjectClass=person)',
        $user_field.'='.$uid
    );

    my $result = $self->search ($filter);

    if ($result->count > 0) {
        foreach my $entry ($result->entries) {
            $mailhost = $entry->get_value("mailhost");
        }
    }

    return $mailhost;
}

sub mailhost_set {
    my ($self, $uid) = @_;
    my $mailhost;

    my $user_field = $self->config->{'authentication'}->{'realms'}->{'ldap'}->{'store'}->{'user_field'}; 
    #my $self->base($self->config->{'authentication'}->{'realms'}->{'ldap'}->{'store'}->{'user_basedn'});

    my $filter = $self->filter_append(
        '(ObjectClass=person)',
        $user_field.'='.$uid
    );

    my $result = $self->search ($filter);

    if ($result->count > 0) {
        foreach my $entry ($result->entries) {
            if ($entry->get_value("mailhost") ne $self->config->{'Personas'}->{'Correo'}->{'attrs'}->{'mailhost'}) {
                $entry->replace(
                                mailhost => $self->config->{'Personas'}->{'Correo'}->{'attrs'}->{'mailhost'} 
                               );

                $entry->update($self);

                $mailhost = $self->config->{'Personas'}->{'Correo'}->{'attrs'}->{'mailhost'};
            }else{
                $mailhost = $entry->get_value("mailhost");
            }
        }
    }

    return $mailhost;
}

sub forward_AD {
    my ($self, $uid) = @_;
    my %n;
    my $entry;
    my $entry_user;
    my $base = $self->config->{'authentication'}->{'realms'}->{'ad'}->{'store'}->{'user_basedn'};

    #Conexion AD
    my $ad = Net::LDAP->new($self->config->{'authentication'}->{'realms'}->{'ad'}->{'store'}->{'ad_server'});
     $ad->bind(
        $self->config->{'authentication'}->{'realms'}->{'ad'}->{'store'}->{'binddn'},
        password=>$self->config->{'authentication'}->{'realms'}->{'ad'}->{'store'}->{'bindpw'},
    );

    #Busco entrada
    my $result = $ad->search(
                base => $base,
                scope => 'sub',
                filter => '(&(ObjectClass=person)(sAMAccountName='.$uid.'))',
    );

    my %contact=();

    if ($result->count > 0) {
        foreach $_ ($result->entries) {
            $contact{objectClass} = [ 'contact', 'organizationalPerson', 'person', 'top' ], ;
            $contact{cn} = $_->get_value("cn").' Mailstore';
            $contact{displayName} = $_->get_value("givenName");
            $contact{givenName} = $_->get_value("givenName");
            $contact{sn} = $_->get_value("sn");
            $contact{mail} = $_->get_value("mail");
            $contact{targetAddress} = 'SMTP:'.$_->get_value("sAMAccountName").'@'.$self->config->{'AD::Forwards'}->{'attrs'}->{'maildomain'};
            $contact{internetEncoding} = '1310720';
            $contact{mailNickname} = $contact{givenName}.$contact{sn};
            $contact{name} = $contact{cn};
            $entry_user = $_;
        }

        my $resp = $ad->search(
            base => 'CN=Users,DC=cantv,DC=com,DC=ve',
            scope => 'sub',
            filter => '(&(ObjectClass=contact)(mail='.$contact{mail}.'))',
            attrs => ['mail'],
        );

        unless ($resp->count > 0) {
            $entry = Net::LDAP::Entry->new;

            my $dn = 'CN='.$contact{cn}.','.$base;
            $entry->dn($dn);

            $entry->add(
                %contact,
            );

            my $mesg = $ad->add($entry);
            if ($mesg->is_error) {
                $n{0}="Error al crear atributo el contacto en el AD";
            }else{
               $entry_user->replace(
                   altRecipient => $entry->dn,
               );

               my $mesg = $entry_user->update($ad);
               if ($mesg->is_error) {
                    $n{0}="Error al crear atributo altRecipient en la cuenta AD";
               }
               $n{1}="Se ha creado el forward";
            }
        }else{
            foreach ($resp->entries) {
                $entry = $_;
            }
            $entry_user->replace(
                altRecipient => $entry->dn,
            );

            my $mesg = $entry_user->update($ad);
            if ($mesg->is_error) {
                 $n{0}="Error al crear atributo altRecipient en la cuenta AD";
            }else{
                $n{1}="Se ha creado el forward";
            }

        }
    }else{
        $n{0}="No se encuentra el usuario en el AD";
    }

    return \%n;
}

1;
