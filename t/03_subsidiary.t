
# Before running this test, run the following tests:
#
# 00_clear.t - Remove ./test
# 01_basic.t - Create fresh ./test

use Test::More  tests => 19;
use File::Spec::Functions qw(splitpath catdir updir catfile);

#01
use_ok VCS::Lite::Repository;

{
    no warnings;
    $VCS::Lite::Repository::username = 'test';  # for tests on non-Unix platforms
}

my $from = VCS::Lite::Repository->new('example');

#02
isa_ok($from, VCS::Lite::Repository, "Successful return from new");

chdir 'test';
my $parent = $from->clone('parent');

#03
isa_ok($parent, VCS::Lite::Repository, "Successful return from clone");

my $child1 = $parent->clone('session1');

#04
isa_ok($child1, VCS::Lite::Repository, "Successful clone of clone");

#05
is_deeply($child1->parent,$parent, "Return from parent method");

my $child2 = $parent->clone('session2');

#06
isa_ok($child2, VCS::Lite::Repository, "Successful clone of clone");

#07
is_deeply($child2->parent,$parent, "Return from parent method");

my $scriptdir = catdir(qw(session1 scripts));
my $scriptrep = VCS::Lite::Repository->new($scriptdir);

#08
isa_ok($scriptrep, VCS::Lite::Repository, "Script directory");

my $ele;

chdir $scriptdir;
for (glob '*.*') {
	next if /VCSLITE/i;	# for VMS

	$ele = VCS::Lite::Element->new($_);

#09 11 13
	isa_ok($ele, VCS::Lite::Element, "Element for script $_");

	my $lit = $ele->fetch;

#10 12 14
	isa_ok($lit, VCS::Lite, "fetch from element $_");

	my $script = $lit->text;
	# Alter the shebang line as a test
	$script =~ s!/usr/local/bin/perl!/usr/bin/perl!;
	
	my $fil;
	open $fil,'>',$_ or die "Failed to write $_, $!";
	print $fil $script;
}

$child1->check_in( description => 'Alter shebang lines');

$ele = VCS::Lite::Element->new('vldiff.pl');

#15
is($ele->latest,1,"Generation has been checked in");

$child1->commit;

$parent->check_in( description => 'Alter shebang lines');

chdir updir;
chdir updir;

my $scriptcheck = catfile(qw(parent scripts vldiff.pl));
my $checkele = VCS::Lite::Element->new($scriptcheck);

#16
isa_ok($checkele, VCS::Lite::Element, "Element in parent");

#17
is($checkele->latest,1,"Generation has been checked in to parent");

my $otheredit = catfile(qw(session2 scripts vldiff.pl));
my $fil;
open $fil,'>>',$otheredit or die "Failed to write to $otheredit, $!";
print $fil '# Here is another edit';
close $fil;

$child2->update;
$child2->check_in( description => 'Apply changes from parent');

$scriptcheck = catfile(qw(session2 scripts vldiff.pl));
$checkele = VCS::Lite::Element->new($scriptcheck);

#18
isa_ok($checkele, VCS::Lite::Element, "Element in parent");

#19
is($checkele->latest,1,"Generation has been checked in to parent");

