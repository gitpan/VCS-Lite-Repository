package VCS::Lite::Common;

use 5.006;
use strict;
use warnings;

use YAML qw(:all);

our $VERSION = '0.01';

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

sub latest {
    my ($self,$base) = @_;

    $base .= '.' if $base && $base =~ /\d$/;
    $base ||= '';
    return 0 if !exists($self->{latest});
    $self->{latest}{$base} || 0;
}

