
# Before running this test, run the following tests:
#
# 00_clear.t - Remove ./test
# 01_basic.t - Create fresh ./test
# 03_subsidiary.t - Create test/parent, test/session1, test/session2

use strict;

use Test::More  tests => 13;
use File::Spec::Functions qw(catdir updir catfile);
use File::Find;

#01
use_ok 'VCS::Lite::Repository';

{
    no warnings;
    $VCS::Lite::Repository::username = 'test';  # for tests on non-Unix platforms
}

# The purpose of this test is to replicate a problem found when
# a parent repository is created from scratch.
#
# This uses test/parent, blowing away the repository files underneath
# it, and re-creating the repository.
#
# This may invalidate some of tests 02_traverse.t through 06_binary.t


chdir 'test';

find ( {
    bydepth => 1,
    wanted => sub {
        return unless $File::Find::name =~ /.VCSLite/;

        if (-d $_) {
            rmdir $_;
        } else {
            1 while unlink $_;
        }
    } }, 'parent');


my $rep = VCS::Lite::Repository->new('parent');

#02
isa_ok($rep, 'VCS::Lite::Repository','Created new');

#03
isa_ok($rep->add('mariner.txt'), 'VCS::Lite::Element', 'Add a text file');

my $screp = $rep->add('scripts');

#04
isa_ok($screp->add('vldiff.pl'), 'VCS::Lite::Element', 'Add vldiff.pl');

#05
isa_ok($screp->add('vlpatch.pl'), 'VCS::Lite::Element', 'Add vlpatch.pl');

#06
isa_ok($screp->add('vlmerge.pl'), 'VCS::Lite::Element', 'Add vlmerge.pl');

my $tpath = catfile(updir,qw/t 04_repository.t/);

#07
isa_ok($screp->add($tpath), 'VCS::Lite::Element', 'Add a test');

$rep = VCS::Lite::Repository->new('parent');
$rep->check_in( description => 'Initial version');

my @repc = $rep->fetch->text;

#08
is_deeply(\@repc, [ qw/ mariner.txt scripts t / ], "Top level contents");

my $sess = $rep->clone('session3');

#09
isa_ok($sess, 'VCS::Lite::Repository', 'Clone returns');

#10
is( scalar($sess->contents), 3, 'Correct number of members before update');

$sess->update;

$sess = VCS::Lite::Repository->new('session3');

#11
is( scalar($sess->contents), 3, 'Correct number of members after update');

#12
isa_ok($sess, 'VCS::Lite::Repository', 'reconstruction');

@repc = $sess->fetch->text;

#13
is_deeply(\@repc, [ qw/ mariner.txt scripts t / ], "Top level contents");


