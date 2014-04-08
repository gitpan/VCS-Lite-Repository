package VCS::Lite::Common;

use strict;
use warnings;

our $VERSION = '0.10';

#----------------------------------------------------------------------------

our $username = $ENV{VCSLITE_USER} || $ENV{USER};
our $default_store = 'Storable';

use File::Spec::Functions qw(splitpath splitdir);

#----------------------------------------------------------------------------

sub path {
    my $self = shift;

    return $self->{path} unless @_;

    my $newpath = shift;

    if ($self->{path} ne $newpath) {
        $self->{path} = $newpath;
        $self->save;
    }
}

sub name {
    my $self = shift;
    my ($vol, $dir, $fil) = splitpath($self->path);

    $fil || (splitdir $dir)[-1];
}

sub store {
    my $self = shift;

    $self->{store};
}

sub save {
    my ($self) = @_;

    $self->store->save($self);
}

sub _mumble {
    my ($self,$msg) = @_;

    print $msg,"\n" if exists($self->{verbose}) && $self->{verbose};
}

sub latest {
    my ($self,$base) = @_;

    $base .= '.' if $base && $base =~ /\d$/;
    $base ||= '';
    return 0 if !exists($self->{latest});
    $self->{latest}{$base} || 0;
}

sub up_generation {
    my ($self,$gen) = @_;

    $gen =~ s/\.0$// or $gen =~ s/([1-9]\d*)$/$1-1/e or return undef;
    $gen;
}

sub user {
    my $obj = shift;
    @_ ? ($username = shift) : $username;
}

sub default_store {
    my $obj = shift;
    @_ ? ($default_store = shift) : $default_store;
}

sub parent {
    my $self = shift;

    return undef unless exists $self->{parent};

    $self->{parent_store}->retrieve($self->{parent});
}

1;

__END__

=head1 BUGS, PATCHES & FIXES

There are no known bugs at the time of this release. However, if you spot a
bug or are experiencing difficulties that are not explained within the POD
documentation, please send an email to barbie@cpan.org or submit a bug to the
RT system (see link below). However, it would help greatly if you are able to
pinpoint problems or even supply a patch.

http://rt.cpan.org/Public/Dist/Display.html?Name=VCS-Lite-Repository

Fixes are dependent upon their severity and my availability. Should a fix not
be forthcoming, please feel free to (politely) remind me.

=head1 AUTHOR

  Original Author: Ivor Williams (RIP)          2002-2009
  Current Maintainer: Barbie <barbie@cpan.org>  2014

=head1 COPYRIGHT

  Copyright (c) Ivor Williams, 2002-2009
  Copyright (c) Barbie,        2014

=head1 LICENCE

This distribution is free software; you can redistribute it and/or
modify it under the Artistic Licence v2.

=cut
