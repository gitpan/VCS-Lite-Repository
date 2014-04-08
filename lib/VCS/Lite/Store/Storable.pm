package VCS::Lite::Store::Storable;

use strict;
use warnings;

our $VERSION = '0.10';

#----------------------------------------------------------------------------

use base qw(VCS::Lite::Store);
use Storable qw(nstore);

#----------------------------------------------------------------------------

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
