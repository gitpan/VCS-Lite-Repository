package VCS::Lite::Repository;

use 5.006;
use strict;
use warnings;

use Carp;
use File::Spec::Functions qw(catdir catfile rel2abs splitdir);
use Time::Piece;
use YAML qw(:all);
use VCS::Lite::Element;

our $VERSION = '0.02';
our $username = $ENV{VCSLITE_USER} || $ENV{USER};

sub new {
    my ($pkg,$path,%args) = @_;


    if (-d $path) {
    } elsif (-f $path) {
        croak "Invalid path '$path' must be a directory";
    } else {
        mkdir $path or croak "Failed to create directory: $!";
    }

    my $abspath = rel2abs($path);
    my $repos_path = catdir($path,'.VCSLite');
    my $repos_ctrl = catfile($repos_path,'VCSControl.yml');
    my $repos = bless {path => $abspath,
    		creator	=> $username,
    		created => localtime->datetime,
    		elements => []},$pkg;

    if (-d $repos_path) {
	$repos = _load_ctrl(path => $repos_ctrl,
		package => $pkg);
	$repos->_update_ctrl( path => $abspath)
		if $repos->{path} ne $abspath;
    } else {
	croak 'Author not specified' unless $username;
    	mkdir $repos_path or croak "Unable to make repository: $!";
    	$repos->_save_ctrl(path => $repos_ctrl);
    }

    $repos->{author} = $username;
    $repos;
}

sub add_element {
    my ($self,$file) = @_;

    my $absfile = catfile($self->{path},$file);

    unless (grep {$file eq $_} @{$self->{elements}}) {
	my @newlist = sort(@{$self->{elements}},$file);
	$self->_update_ctrl( elements => \@newlist);
    }

    VCS::Lite::Element->new($absfile);
}

sub add_repository {
    my ($self,$file) = @_;

    my $absfile = catfile($self->{path},$file);

    unless (($file eq '.') || grep {$file eq $_} @{$self->{elements}}) {
	my @newlist = sort(@{$self->{elements}},$file);
	$self->_update_ctrl( elements => \@newlist);
    }

    VCS::Lite::Repository->new($absfile);
}
    
sub elements {
    my $self = shift;

    map {my $file = catfile($self->{path},$_); 
	(-d $file) ? VCS::Lite::Repository->new($file)
		: VCS::Lite::Element->new($file);} 
    	@{$self->{elements}};
}

sub traverse {
    my ($self,$func,@args) = @_;

    for ($self->elements) {
	if (ref $func) {
	    &$func($_,@args);
	} else {
	    $_->$func(@args);
	}
    }
}

sub path {
    my $self = shift;

    $self->{path};
}

sub clone {
    my ($self,$newpath) = @_;

    my $newrep = VCS::Lite::Repository->new($newpath);
    $newrep->_update_ctrl( parent => $self->{path});
    $self->traverse('_clone_member',$newpath);
    VCS::Lite::Repository->new($newpath); 
    # This is different from the $newrep object, as it is fully populated.
}

sub parent {
    my $self = shift;

    return undef unless $self->{parent};
    VCS::Lite::Repository->new($self->{parent});
}

sub check_in {
    my ($self,@args) = @_;

    $self->traverse('check_in',@args);
}

sub commit {
    my ($self,$parent) = @_;

    my $repos_name = (splitdir($self->path))[-1];
    
    $self->traverse('commit', $self->{parent} || catdir($parent,$repos_name));
}

sub update {
    my ($self,$parent) = @_;

    my $repos_name = (splitdir($self->path))[-1];
    
    $self->traverse('update', $self->{parent} || catdir($parent,$repos_name));
}

sub _clone_member {
    my ($self,$newpath) = @_;

    my $repos_name = (splitdir($self->path))[-1];
    my $newrep = VCS::Lite::Repository->new($newpath);
    $newrep->add_repository($repos_name);

    my $new_repos = catdir($newpath,$repos_name);

    $self->clone($new_repos);
}

sub _save_ctrl {
    my ($self,%args) = @_;

    DumpFile($args{path} ,$self);
}

sub _load_ctrl {
    my (%args) = @_;

# Note that this is not a method call. Also, LoadFile can bless into other
# classes than VCS::Lite::Repository, allowing inheritance.

    LoadFile($args{path});
}

sub _update_ctrl {
    my ($self,%args) = @_;

    my $path = $args{path} || $self->{path};
    my $ctrl = catfile($path,'.VCSLite','VCSControl.yml');
    for (keys %args) {
	$self->{$_} = $args{$_};
    }

    $self->{updated} = localtime->datetime;
    $self->_save_ctrl(path => $ctrl);
}
1;
__END__

=head1 NAME

VCS::Lite::Repository - Minimal version Control system - Repository object

=head1 SYNOPSIS

  use VCS::Lite::Repository;
  my $rep = VCS::Lite::Repository->new($ENV{VCSROOT});
  my $dev = $rep->clone('/home/me/dev');
  $dev->add_element('testfile.c');
  $dev->add_repository('sub');
  $dev->traverse(\&do_something);
  $dev->check_in( description => 'Apply change');
  $dev->update;
  $dev->commit;
  
=head1 DESCRIPTION

VCS::Lite::Repository is a freestanding version control system that is
platform independent. The module is pure perl, and only makes use of
other code that is available for all platforms.

=head2 new

  my $rep = VCS::Lite::Repository->new('/local/fileSystem/path');

A new repository object is created and associated with a directory on
the local file system. If the directory does not exist, it is created.
If the directory does not contain a repository, an empty repository
is created.

The control files associated with the repository live under a directory 
.VCSLite inside the associated directory, and these are in L<YAML> format.
The repository directory can contain VCS::Lite elements (which
are version controlled), other repository diretories, and also files
and directories which are not version controlled.

=head2 add_element

Returns a VCS::Lite::Element object corresponding to the file inside the
repository. The element is added to the list of elements inside the 
repository. If the file does not exist, it is created as zero length.

If the repository already contains an element of this name, the method
returns a VCS::Lite::Element object for the existing element.

When creating a new element, the existing file contents (or the empty file)
are used as the generation 0 start point for the file.  

=head2 add_repository

Similar to add_element is add_repository, which returns a VCS::Lite::Repository
object corresponding to a subdirectory.

=head2 traverse

  $rep->traverse(\&mysub,...);
  $rep->traverse('foo_method',...);

Apply a callback to each element and repository inside the repository.
Either call a sub directly, or supply a method name. This is used to
implement the check_in, commit and update methods for a repository.

=head2 check_in, commit, update

These methods use C<traverse> to iterate all elements in the repository,
and all subrepositories. See the documentation in L<VCS::Lite::Element>
for how these are applied to each element.

=head1 ENVIRONMENT VARIABLES

=head2 USER

The environment variable B<USER> is used to determine the author of
changes. In a Unix environment, this should be adequate for out-of-the-box
use. An additional environment variable, B<VCSLITE_USER> is also checked,
and this takes precedence.

Windows users will need to set one of these environment variables, or
the application will croak with "Author not specified".

For more dynamic applications (such as CGI scripts that run as WWW, but
receive the username from a cookie), you can set the package variable:
$VCS::Lite::Repository::username. Note: there could be some problems with
Modperl here - patches welcome.

=head1 TO DO

Support for binary files. (Subclass VCS::Lite::Element)

Integration with L<VCS> suite.

=head1 COPYRIGHT

   Copyright (C) 2003-2004 Ivor Williams (IVORW (at) CPAN {dot} org)
   All rights reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<VCS::Lite::Element>, L<VCS::Lite>, L<YAML>.

=cut
