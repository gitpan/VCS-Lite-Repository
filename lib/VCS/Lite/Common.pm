package VCS::Lite::Common;

use 5.006;
use strict;
use warnings;

use YAML qw(:all);

our $VERSION = '0.02';

sub path {
    my $self = shift;

    $self->{path};
}

sub _save_ctrl {
    my ($self,%args) = @_;

    DumpFile($args{path} ,$self);
}

sub _load_ctrl {
    my ($pkg,%args) = @_;

    LoadFile($args{path});
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
