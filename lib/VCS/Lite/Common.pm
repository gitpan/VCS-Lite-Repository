package VCS::Lite::Common;

use 5.006;
use strict;
use warnings;

our $VERSION = '0.04';
our $username = $ENV{VCSLITE_USER} || $ENV{USER};
our $default_store = 'Storable';

use File::Spec::Functions qw(splitpath splitdir);

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
