package VCS::Lite::Store::YAML;

use 5.006;
use strict;
use warnings;

use base qw(VCS::Lite::Store);
use YAML qw(:all);

our $VERSION = '0.01';

sub load {
    my ($self,$path) = @_;

    LoadFile($path);
}

sub save {
    my ($self,$obj) = @_;
    my $storep = $self->store_path($obj->path);
    DumpFile($storep, $obj);
}

sub repos_name {
    my ($self,$ele,$ext) = @_;

    $ext ||= 'yml';
    $ele ? "${ele}_$ext" : "VCSControl.$ext";
}

1;
