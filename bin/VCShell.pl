#!/usr/bin/perl

use strict;
use warnings;

use Term::ReadLine;
use VCS::Lite::Repository;

my $prompt = 'VCSLite> ';
my $term = Term::ReadLine->new('VCS Lite');

if (@ARGV) {
	execute_command(join ' ',@ARGV);
	exit(0);
}

while (defined (my $input = $term->readline($prompt))) {
	execute_command($input);
}

sub execute_command {
    local $_ = shift;

    /^prompt (.*)/ && (($prompt = $1), return);

    /^cd (.*)/ && (chdir($1),return);

    /^(add|commit|update)\s+(\S*)/ && (VCS_function($1,$2),return);

    /^ci (\S*)/ && (VCS_check_in($1,$term),return);

    /^fetch -g (\S+) (\S*)/ && (VCS_fetch($1,$2),return);
    
    system($_);
}

sub VCS_function {
    my ($func,$elename) = @_;

    if ($func eq 'add') {
    
	my $repos = VCS::Lite::Repository->new('.');

	if (-d $elename) {
	    $repos->add_repository($elename);
	} else {
	    $repos->add_element($elename);
	}
    } else {
	my $repos = VCS::Lite::Repository->new($elename || '.');

	$repos->$func;
    }
}

sub VCS_check_in {
    my ($elename,$term) = @_;

    my $OUT = $term->OUT || \*STDOUT;
    my $ele = (-d $elename) ? VCS::Lite::Repository->new($elename) :
    				VCS::Lite::Element->new($elename);

    print $OUT "Enter a description of the change made to $elename\n";
    print $OUT "Terminate with a dot\n";
    my $remark = '';
    
    while ((my $input = $term->readline('> ')) ne '.') {
	$remark .= $input . "\n";
    }
    
    $ele->check_in( description => $remark);
}

sub VCS_fetch {
    my ($gen,$elename) = @_;

    my $ele = VCS::Lite::Element->new($elename);

    print $ele->fetch( generation => $gen)->text;
}
