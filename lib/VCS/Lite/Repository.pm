package VCS::Lite::Repository;

use 5.006;
use strict;
use warnings;

use Carp;
use File::Spec::Functions qw(:ALL !path);
use Time::Piece;
use VCS::Lite::Element;
use Params::Validate qw(:all);
use Cwd qw(abs_path);

our $VERSION = '0.06';
our $username = $ENV{VCSLITE_USER} || $ENV{USER};
our $hidden_repos_dir = '.VCSLite';

$hidden_repos_dir = '_VCSLITE' if $^O =~ /vms/i;

use base qw(VCS::Lite::Common);

sub new {
    my $pkg = shift;
    my $path = shift;
    my %args = validate ( @_, {
                   verbose => 0,
               } );
    my $verbose = $args{verbose};

    if (-d $path) {
    } elsif (-f $path) {
        croak "Invalid path '$path' must be a directory";
    } else {
        mkdir $path or croak "Failed to create directory: $!";
    }

    my $abspath = abs_path($path);
    my $repos_path = catdir($path,$hidden_repos_dir);
    my $repos_ctrl = catfile($repos_path,'VCSControl.yml');
    my $repos = bless {path => $abspath,
    		creator	=> $username,
    		created => localtime->datetime,
    		verbose => $verbose,
    		contents => []},$pkg;

    if (-d $repos_path) {
	$repos = $pkg->_load_ctrl(path => $repos_ctrl,
		package => $pkg);
	$repos->_update_ctrl( path => $abspath)
		if $repos->{path} ne $abspath;
    } else {
	croak 'Author not specified' unless $username;
	$repos->_mumble("Create repository $abspath");
    	mkdir $repos_path or croak "Unable to make repository: $!";
    	$repos->_save_ctrl(path => $repos_ctrl);
    }

    $repos->{author} = $username;
    $repos->{verbose} = $verbose;
    $repos;
}

sub add {
    my $self = shift;
    my ($file) = validate_pos(@_, { type => SCALAR });

    my $path = $self->path;
    my ($vol,$dirs,$fil) = splitpath($file);
    my $absfile;
    my $remainder;
    if ($dirs) {
        my ($top,@dirs) = splitdir($dirs);
        pop @dirs if $dirs[-1] eq '';
        $absfile = abs_path(catfile($path,$top));
        mkdir $absfile unless -d $absfile;
        $remainder = @dirs ? catpath($vol,catdir(@dirs),$fil) : $fil;
        $file = $top;
    }
    else {
        $absfile = catfile($path,$fil);
    }

    unless (($file eq updir) ||
           ($file eq curdir) ||
           grep {$file eq $_} @{$self->{contents}}) {
	$self->_mumble("Add $file to $path");
	my @newlist = sort(@{$self->{contents}},$file);
	$self->{transactions} ||= [];
	my @trans = (@{$self->{transactions}}, ['add',$file]);
	$self->_update_ctrl( contents => \@newlist,
			transactions => \@trans);
    }

    my $newobj = (-d $absfile) ? VCS::Lite::Repository->new($absfile) :
    		VCS::Lite::Element->new($absfile);
    $remainder ? $newobj->add($remainder) : $newobj;
}

sub add_element {
    my ($self,$file) = @_;
    (-d $file) ? undef : add(@_);
}

sub add_repository {
    my ($self,$dir) = @_;
    return undef if -f $dir;

    mkdir catfile($self->{path},$dir);
    add(@_);
}

sub remove {
    my $self = shift;
    my ($file) = validate_pos(@_, { type => SCALAR });

    my @contents;
    my $doit = 0;

    for (@{$self->{contents}}) {
	if ($file eq $_) {
	    $doit++;
	} else {
	    push @contents,$_;
	}
    }
    return undef unless $doit;

    $self->_mumble("Remove $file from " . $self->path);
    $self->{transactions} ||= [];
    my @trans = (@{$self->{transactions}}, ['remove',$file]);
    $self->_update_ctrl( contents => \@contents,
			transactions => \@trans);
    1;
}

sub contents {
    my $self = shift;

    map {my $file = catfile($self->{path},$_); 
	(-d $file) ? 
	    VCS::Lite::Repository->new($file, verbose => $self->{verbose})
	    : VCS::Lite::Element->new($file, verbose => $self->{verbose});} 
    	@{$self->{contents}};
}

sub elements {
    my $self = shift;

    grep {$_->isa('VCS::Lite::Element')} $self->contents;
}

sub repositories {
    my $self = shift;

    grep {$_->isa('VCS::Lite::Repository')} $self->contents;
}

sub traverse {
    my ($self,$func,@args) = @_;

    for ($self->contents) {
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
    my $self = shift;
    my ($newpath) = validate_pos(@_, { type => SCALAR });

    $self->_mumble("Cloning " . $self->path . " to $newpath");
    $self->{transactions} ||= [];
    my $newrep = VCS::Lite::Repository->new($newpath, 
    	verbose => $self->{verbose});
    $newrep->_update_ctrl( parent => $self->{path},
    			contents => $self->{contents},
    			original_contents => $self->{contents},
    			parent_baseline => $self->latest);
    $self->traverse('_clone_member',$newpath);
    VCS::Lite::Repository->new($newpath, verbose => $self->{verbose}); 
    # This is different from the $newrep object, as it is fully populated.
}

sub parent {
    my $self = shift;

    return undef unless $self->{parent};
    VCS::Lite::Repository->new($self->{parent}, verbose => $self->{verbose});
}

sub check_in {
    my $self = shift;
    my %args = validate ( @_, {
                   check_in_anyway => 0,
                   description => { type => SCALAR },
               } );

    $self->_mumble("Checking in " . $self->path);
    if (($self->{transactions} && @{$self->{transactions}}) 
		|| $args{check_in_anyway}) {
        $self->_mumble("Updating directory changes");
	my $newgen = $args{generation} || $self->latest;
	$newgen =~ s/(\d+)$/$1+1/e;
	$self->{generation} ||= {};
	my %gen = %{$self->{generation}};
	$gen{$newgen} = {
		author => $username,
		description => $args{description},
		updated => localtime->datetime,
		transactions => $self->{transactions},
		contents => $self->{contents},
	};

	$self->{latest} ||= {};
	my %lat = %{$self->{latest}};
	$newgen =~ /(\d+\.)*\d+$/;
	my $base = $1 || '';
	$lat{$base}=$newgen;
	delete $self->{transactions};

	$self->_update_ctrl( generation => \%gen, 
    			latest => \%lat);
    }
    $self->traverse('check_in',%args);
}

sub commit {
    my ($self,$parent) = @_;

    my $path = $self->path; 
    my $repos_name = (splitdir($self->path))[-1];
    my $parent_repos_path = $self->{parent} || catdir($parent,$repos_name);
    $self->_mumble("Committing $path to $parent_repos_path");
    my $parent_repos = VCS::Lite::Repository->new($parent_repos_path, 
    		verbose => $self->{verbose});

    my $orig = VCS::Lite->new($repos_name,undef,$parent_repos->{contents});
    my $changed = VCS::Lite->new($repos_name,undef,$self->{contents});

    $parent_repos->_apply($orig->delta($changed),$path);
    $self->traverse('commit', $self->{parent} || catdir($parent,$repos_name));
}

sub update {
    my ($self,$srep) = @_;

    my $file = $self->path;
    my $repos_name = (splitdir($file))[-1];
    $self->{parent} ||= catdir($srep,$repos_name);
    my $parent = $self->{parent};
    $self->_mumble("Updating $file from $parent");
    my $baseline = $self->{baseline} || 0;
    my $parbas = $self->{parent_baseline};

    my $orig = $self->fetch( generation => $baseline);
    my $parele = VCS::Lite::Repository->new($parent, 
    	verbose => $self->{verbose});
    my $parfrom = $parele->fetch( generation => $parbas);
    my $parlat = $parele->latest; # was latest($parbas) - buggy
    my $parto = $parele->fetch( generation => $parlat);
    my $origplus = $parfrom->merge($parto,$orig);

    my $chg = VCS::Lite->new($repos_name,undef,$self->{contents});
    my $merged = $orig->merge($origplus,$chg);
    $self->_apply($chg->delta($merged),$parent);

    $self->_update_ctrl(baseline => $self->latest,
        parent_baseline => $parlat);

    
    $self->traverse('update', $parent);
}

sub fetch {
    my $self = shift;
    my %args = validate ( @_, {
                   time => 0,
                   generation => 0,
               } );

    my $gen = exists($args{generation}) ? $args{generation} : $self->latest;

    if ($args{time}) {
	my $latest_time = '';
	my $branch = $args{generation} || '';
	$branch .= '.' if $branch;

	for (keys %{$self->{generation}}) {
            next unless /^$branch\d+$/;
	    next if $self->{generation}{$_}{updated} > $args{time};
	    ($latest_time,$gen) = ($self->{generation}{$_}{updated}, $_)
		if $self->{generation}{$_}{updated} > $latest_time;
	}
	return undef unless $latest_time;
    }
    return undef if $gen && $self->{generation} && !$self->{generation}{$gen};

    my $cont = $gen ? 
		$self->{generation}{$gen}{contents} :
		$self->{original_contents} || [];
    my $file = $self->{path};
    $gen ||= 0;
    VCS::Lite->new("$file\@\@$gen",undef,$cont);
}
                                                                      
sub _apply {
    my ($self,$delt,$srcpath) = @_;

    return undef unless $delt;

    my $path = $self->path;
    
    for (map {@$_} $delt->hunks) {
	my ($ind,$lin,$val) = @$_;
	if ($ind eq '-') {
	    $self->remove($val);
	} elsif ($ind eq '+') {
	    my $destname = catdir($path,$val);
	    my $srcname = catdir($srcpath,$val); 
	    # $srcname is false if catdir can't construct a dir, e.g.
	    # if on VMS and $val contains a dot
	    mkdir $destname if $srcname && -d $srcname;
	    $self->add($val);
	}
    }
}
    
sub _clone_member {
    my ($self,$newpath) = @_;

    my $repos_name = (splitdir($self->path))[-1];
    my $newrep = VCS::Lite::Repository->new($newpath, 
    	verbose => $self->{verbose});
    my $new_repos = catdir($newpath,$repos_name);

    $self->clone($new_repos);
}

sub _load_ctrl {
    my ($pkg,@args) = @_;
    my $repos = $pkg->SUPER::_load_ctrl(@args);

# Upgrade from version 0.02. $repos->{elements} replaced by $repos->{contents}

    if ($repos->{elements}) {
	$repos->{contents} ||= $repos->{elements};
	delete $repos->{elements};
    }

    $repos;
}

sub _update_ctrl {
    my ($self,%args) = @_;

    my $path = $args{path} || $self->{path};
    my $ctrl = catfile($path,$hidden_repos_dir,'VCSControl.yml');
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
.VCSLite inside the associated directory (_VCSLITE on VMS as dots are
not allowed in directory names on this platform), and these are in 
L<YAML> format. The repository directory can contain VCS::Lite elements 
(which are version controlled), other repository diretories, and also files
and directories which are not version controlled.

=head2 add

  my $ele = $rep->add('foobar.pl');
  my $ele = $rep->add('mydir');

If given a directory, returns a VCS::Lite::Repository object for the 
subdirectory. If this does not already have a repository, one is created.

Otherwise it returns the VCS::Lite::Element object corresponding to a file 
of that name. The element is added to the list of elements inside the 
repository. If the file does not exist, it is created as zero length.
If the file does exist, its contents become the generation 0 baseline for
the element, otherwise generation 0 is the empty file.

The methods add_element and add_repository do the same thing, but check
to make sure that the paremeter is a plain file (or a directory in the case
of add_repository) and return undef if this is not the case. Add_repository
will also create the directory if it does not exist.

=head2 remove

   $rep->remove('foobar.pl');

This is the opposite of add. It does not delete any files, merely removes the
association between the repository and the element or subrepository.

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

Integration with L<VCS> suite.

=head1 COPYRIGHT

   Copyright (C) 2003-2004 Ivor Williams (IVORW (at) CPAN {dot} org)
   All rights reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<VCS::Lite::Element>, L<VCS::Lite>, L<YAML>.

=cut
