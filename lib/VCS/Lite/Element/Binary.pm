
package VCS::Lite::Element::Binary;
use strict;

use vars qw/$VERSION @CARP_NOT/;

$VERSION = '0.02';
@CARP_NOT = qw/VCS::Lite::Element/;

use base qw/VCS::Lite::Element/;
use Carp;
use File::Spec::Functions qw/:ALL !path/;
use Params::Validate qw(:all);

=head1 NAME

VCS::Lite::Element::Binary - Support for version control of binary files 

=head1 SYNOPSIS

  use VCS::Lite::Element::Binary;

  my $bin_ele = VCS::Lite::Element::Binary->new('foo.jpg', recordsize => 16);

=head1 DESCRIPTION

This module is a subclass of VCS::Lite::Element to handle versioning of 
binary files

=head1 BUGS

Please post reports of bugs to rt.cpan.org

=head1 AUTHOR

	Ivor Williams	
	ivorw at CPAN (dot) org

=head1 COPYRIGHT

Copyright (C) 2004 Ivor Williams

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.


=head1 SEE ALSO

L<VCS::Lite::Element>, L<VCS::Lite::Repository>

=head1 METHODS

See L<VCS::Lite::Element> for the list of object methods available.

=over 4

=item B<new>

  my $obj = VCS::Lite::Element::Binary->new( $filename, [param => value...]);

Constructs a VCS::Lite::Element::Binary object for a given file. Note, if
the object has an existing YAML, it will return the existing object.

If you want to create a new binary element in a repository, call C<new> then
add it to the repository.

=cut

sub new {
    my $pkg = shift;
    my $name = shift;
    my %args = validate ( @_, {
    		   store => 0,		# Handled by SUPER::new
                   verbose => 0,
                   recordsize => { type => SCALAR, default => 128 },
               } );
    $pkg->SUPER::new($name,%args);
}

sub _slurp_lite {
    my $self = shift;
    my $name = shift;
    my $recsiz = $self->{recordsize};

    my $in;

    open $in,'<',$name or croak "$name: $!";
    binmode $in;
    my @fil;
    my $buff;
    while (sysread($in,$buff,$recsiz)) {
       push @fil,$buff;
    }
    VCS::Lite->new($name,undef,\@fil);
}

sub _contents {
    my $self = shift;

    my $recsiz = $self->{recordsize};
    my $bin = $self->{store}->store_path($self->path,'vbin');
    my $cont;              
    if (@_) {
        $cont = shift;
        my $out;
        open $out,'>',$bin or croak "$bin: $!";
        binmode $out;
        for (@$cont) {
            my $str = pack 'n',length $_;
            syswrite($out,$str.$_);
        }
    }
    else {
        return [] unless -f $bin;
        my $in;

        open $in,'<',$bin or croak "$bin: $!";
        binmode $in;
        my @fil;
        my $buff;
        while (sysread($in,$buff,2)) {
            my $rsz = unpack 'n',$buff;
            sysread($in,$buff,$rsz);
            push @fil,$buff;
        }
        $cont = \@fil;
    }
    $cont;
}
        
1; #this line is important and will help the module return a true value
__END__

