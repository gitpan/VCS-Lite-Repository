package VCS::Lite::Store::Storable;

use 5.006;
use strict;
use warnings;

use base qw(VCS::Lite::Store);
use Storable qw(nstore);

our $VERSION = '0.01';

sub load {
    my ($self,$path) = @_;

    Storable::retrieve($path);
}

sub save {
    my ($self,$obj) = @_;
    my $storep = $self->store_path($obj->path);
    nstore($obj, $storep);
}

sub repos_name {
    my ($self,$ele,$ext) = @_;

    $ext ||= 'st';
    $ele ? "${ele}_$ext" : "VCSControl.$ext";
}

1;
