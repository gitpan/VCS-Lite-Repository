package VCS::Lite::Element;

use 5.006;
use strict;
use warnings;

our $VERSION = '0.03';
our $username;  # Aliased to $VCS::Lite::Repository::username
*VCS::Lite::Element::username = \$VCS::Lite::Repository::username;

our $hidden_repos_dir = '.VCSLite';

$hidden_repos_dir = '_VCSLITE' if $^O =~ /vms/i;

use File::Spec::Functions qw(splitpath catfile rel2abs);
use Time::Piece;
use Carp;
use VCS::Lite;

use base qw(VCS::Lite::Common);

sub new {
    my ($pkg,$file,%args) = @_;
    my $lite = $file;

    if (!ref $lite) {
	unless (-f $file) {
	    open FIL, '>', $file or croak("Failed to create $file, $!");
	    close FIL;
	}
	$lite = VCS::Lite->new($file);
    } else {
	$file = $lite->id;
    }
    
    $file = rel2abs($file);
    my ($vol,$dir,$fil) = splitpath($file);
    my $ctrl = catfile(
    	$vol ? ($vol,$dir) : $dir
    	,'.VCSLite',"${fil}_yml");
    my $ele;

    if (-f $ctrl) {
	$ele = $pkg->_load_ctrl(path => $ctrl,
                	package => $pkg);
        $ele->_update_ctrl( path => $file) if $ele->{path} ne $file;
    } else {
	return undef unless $username;
	
	$ele = bless {path => $file,
		author => $username}, $pkg;
	$ele->_assimilate($lite);
	$ele->_save_ctrl(path => $ctrl);
    }
    $ele;
}

sub check_in {
    my ($self,%args) = @_;
    my $file = $self->{path};

    my $lite = VCS::Lite->new($file);

    my $newgen = $self->_assimilate($lite);
    return undef if !$newgen && !$args{check_in_anyway};
    $self->{generation} ||= {};
    my %gen = %{$self->{generation}};
    $gen{$newgen} = {
    	author => $username,
    	description => $args{description},
	updated => localtime->datetime,
    };
    $self->{latest} ||= {};
    my %lat = %{$self->{latest}};
    $newgen =~ /(\d+\.)*\d+$/;
    my $base = $1 || '';
    $lat{$base}=$newgen;
    
    $self->_update_ctrl( generation => \%gen, latest => \%lat);
    $newgen;
}

sub repository {
    my $self = shift;

    my ($vol,$dir,$fil) = splitpath($self->{path});
    my $repos_path = $vol ? catdir($vol,$dir) : $dir;

    VCS::Lite::Repository->new($repos_path);
}

sub fetch {
    my ($self,%args) = @_;

    my $gen = $args{generation} || $self->latest;
    
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
    return undef if $self->{generation} && !$self->{generation}{$gen};
    
    my $skip_to;
    my @out;
    for (@{$self->{contents}}) {
	if ($skip_to) {
		if (/^=$skip_to$/) {
		    undef $skip_to;
		}
		next;
	}
	if (my ($type,$gensel) = /^([+-])(.+)/) {
		if (_is_parent_of($gensel,$gen) ^ ($type eq '+')) {
		    $skip_to = $gensel;
		}
		next;
	}
	next if /^=/;
	if (/^ /) {
	    	push @out,substr($_,1);
	}
    }
    my $file = $self->{path};
    VCS::Lite->new("$file\@\@$gen",undef,\@out);
}

sub commit {
    my ($self,$parent) = @_;

    my ($vol,$dir,$file) = splitpath($self->path);
    my $updfile = catfile($parent,$file);
    my $out;
    open $out,'>',$updfile or croak "Failed to open $file for committing, $!";
    print $out $self->fetch->text;
}

sub update {
    my ($self,$parent) = @_;

    my $file = $self->path;
    my ($vol,$dir,$fil) = splitpath($file);
    my $fromfile = catfile($parent,$fil);
    my $baseline = $self->{baseline} || 0;
    my $parbas = $self->{parent_baseline};

    my $orig = $self->fetch( generation => $baseline);
    my $parele = VCS::Lite::Element->new($fromfile);
    my $parfrom = $parele->fetch( generation => $parbas);
    my $parlat = $parele->latest($parbas);
    my $parto = $parele->fetch( generation => $parlat);
    my $origplus = $parfrom->merge($parto,$orig);

    my $chg = VCS::Lite->new($file);
    my $merged = $orig->merge($origplus,$chg);
    my $out;
    open $out,'>',$file or croak "Failed to write back merge of $fil, $!";
    print $out $merged->text;
    $self->_update_ctrl(baseline => $self->latest,
		parent_baseline => $parlat);
}

sub _clone_member {
    my ($self,$newpath) = @_;

    my $repos = VCS::Lite::Repository->new($newpath);
    my ($vol,$dir,$fil) = splitpath($self->path);
    my $newfil = catfile($newpath,$fil);
    my $out;
    open $out,'>',$newfil or croak "Failed to clone $fil, $!";
    print $out $self->fetch->text;
    close $out;

    my $pkg = ref $self;
    $pkg->new($newfil);
}

sub _assimilate {
    my ($self,$lite,%args) = @_;

    my @newgen = map { [' '.$_] } $lite->text;
    my (@oldgen,@openers,@closers,$skip_to);
    my $genbase = $args{generation} || $self->latest;

    if (exists $self->{contents}) {
	for (@{$self->{contents}}) {
	    if ($skip_to) {
		push @openers, $_;
		if (/^=$skip_to$/) {
		    undef $skip_to;
		}
		next;
	    }
	    if (my ($type,$gen) = /^([+-])(.+)/) {
		$oldgen[-1][2] = [@closers] if @closers;
		@closers = ();
		push @openers, $_;
		if (_is_parent_of($gen,$genbase) ^ ($type eq '+')) {
		    $skip_to = $gen;
		}
		next;
	    }
	    if (my ($gen) = /^=(.+)/) {
	    	push @closers, $_;
	    	next;
	    }
	    if (/^ /) {
		$oldgen[-1][2] = [@closers] if @closers;
	    	push @oldgen,[$_, [@openers]];
	    	@openers = @closers = ();
	    	next;
	    }
	    croak "Invalid format in element contents";
	}
	$oldgen[-1][2] = [@closers] if @closers;
    } else {
	$self->{contents} = [map $_->[0], @newgen];
	return 1;
    }
	
    $genbase =~ s/(\d+)$/$1+1/e;
    my @sd = Algorithm::Diff::sdiff( \@oldgen, \@newgen, sub { $_[0][0] });
    my (@newcont,@pending);
    my $prev = 'u';
    my $changed = 0;
    for (@sd) {
	my ($ind,$c1,$c2) = @$_;
	my @res1;
	if ($c1) {
	    @res1 = (@{$c1->[1]},$c1->[0]);
	    push @res1,@{$c1->[2]} if defined $c1->[2];
	}
	my $res2 = $c2->[0] if $c2;

	push @newcont,"=$genbase\n" if ($prev ne 'u') && ($ind ne $prev);
	if (@pending && ($ind ne 'c')) {
	    push @newcont, @pending, "=$genbase\n";
	    @pending=();
	}
	if (($prev =~ /[u+]/) && ($ind =~ /[c-]/)) {
	    push @newcont,"-$genbase\n";
	    $changed++;
	}
	if ($ind eq '+') {
	    push @newcont,"+$genbase\n" if ($prev ne $ind);
	    push @newcont, $res2;
	    $changed++;
	} else {
	    push @newcont, @res1;
	}
	if ($ind eq 'c') {
	    push @pending,"+$genbase\n" if ($prev ne $ind);
	    push @pending, $res2;
	}
	$prev = $ind;
    }
    push @newcont,"=$genbase\n" if ($prev ne 'u');
    return undef unless $changed;
    $self->{contents} = \@newcont;
    $genbase;
}

sub _is_parent_of {
    my ($gen1,$gen2) = @_;

    my @g1v = split /\./,$gen1;
    my @g2v = split /\./,$gen2;
    (shift @g1v,shift @g2v) while @g1v && @g2v && ($g1v[0] eq $g2v[0]);
    return 1 unless @g2v;
    return 0 unless @g1v;
    return 0 if @g1v > 1;
    $g1v[0] < $g2v[0];
}

sub _update_ctrl {
    my ($self,%args) = @_;

    my $path = $args{path} || $self->{path};
    my ($vol,$dir,$fil) = splitpath($path);
    my $ctrl = catfile( $vol ? ($vol,$dir) : $dir ,'.VCSLite',"${fil}_yml");
    $self->{$_} = $args{$_} for keys %args;
    $self->{updated} = localtime->datetime;
    $self->_save_ctrl(path => $ctrl);
}

1;
__END__

=head1 NAME

VCS::Lite::Element - Minimal Version Control System - Element object

=head1 SYNOPSIS

  use VCS::Lite::Element;
  my $ele=VCS::Lite::Element->new('/home/me/dev/testfile.c');
  my $lit=$ele->fetch( generation => 2);
  $ele->check_in( description => 'Fix the bug');
  $ele->update;
  $ele->commit;

=head1 DESCRIPTION

A VCS::Lite::Repository contains elements corresponding to the source
files being version controlled. The files are real files on the local file
system, but additional information about the element is held inside the
repository.

This information includes the history of the element, in terms of its
generations.

=head2 new

  my $ele=VCS::Lite::Element->new('/home/me/dev/testfile.c');

Constructs a VCS::Lite::Element for a given element in a repository.
Returns undef if the element is not found in the repository.

=head2 fetch

  my $lit=$ele->fetch( generation => 2);
  my $lit2=$ele->fetch( time => '2003-12-29T12:01:25');

The fetch method is used to retrieve generations from the repository.
If no time or generation is specified, the latest generation is retrieved. The
method returns a VCS::Lite object if successful or undef.

=head2 check_in

  $ele->check_in( description => 'Fix bug in foo method');

This method creates a new latest generation in the repository for the element.

=head2 update

  $ele->update;

This applies any changes to $ele which have happened in the parent repository,
i.e. the one that the current repository was cloned from.

=head2 commit

  $ele->commit;

Applies the latest generation change to the parent repository. Note: this
updates the file inside the parent file tree; a call to update is required
to update the repository.

=head1 COPYRIGHT

   Copyright (C) 2003-2004 Ivor Williams (IVORW (at) CPAN {dot} org)
   All rights reserved.

   This module is free software; you can redistribute it and/or modify it
   under the same terms as Perl itself.
   
=head1 SEE ALSO

L<VCS::Lite::Repository>, L<VCS::Lite>.

=cut
