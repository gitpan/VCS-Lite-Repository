
# Before running this test, run the following tests:
#
# 00_clear.t - remove ./test
# 01_clear.t - create fresh ./test
# 03_subsidiary.t - create repositories test/parent, test/session2, test/session2

use strict;
use Test::More  tests => 22;
use File::Spec::Functions qw(catdir catfile updir rel2abs);
use File::Copy;

#01
use_ok 'VCS::Lite::Repository';

{
    no warnings;
    $VCS::Lite::Repository::username = 'test';  # for tests on non-Unix platforms
}

my $testfile = rel2abs(catfile(qw! t 04_repository.t !));

chdir 'test';

my $child1 = VCS::Lite::Repository->new('session1');

#02
isa_ok($child1, 'VCS::Lite::Repository', "session1 still available from previous tests");

my $child2 = VCS::Lite::Repository->new('session2');

#03
isa_ok($child2, 'VCS::Lite::Repository', "session2 still available from previous tests");

chdir 'session1';

my $testrep = $child1->add_repository('t');

#04
isa_ok($testrep, 'VCS::Lite::Repository', "add_repository return");

my $testele = $testrep->add('04_repository.t');

#05
isa_ok($testele, 'VCS::Lite::Element', "add return");

copy($testfile,'t');

my $scriptrep = VCS::Lite::Repository->new('scripts');

#06
isa_ok($scriptrep, 'VCS::Lite::Repository', "Script directory");

#07
ok($scriptrep->remove('vlmerge.pl'), "remove");

chdir updir;
$child1 = VCS::Lite::Repository->new('session1');

#08
isa_ok($child1, 'VCS::Lite::Repository', "Read back repository");

$child1->check_in( description => 'Test add and remove');

my @cont1 = $child1->contents;

#09
is(@cont1, 3, "contents returns 3 objects");

chdir 'session1';
$testrep = VCS::Lite::Repository->new('t');

#10
isa_ok($testrep, 'VCS::Lite::Repository', "test repository still there");

my @test1 = $testrep->contents;

#11
is(@test1, 1, "contents returns 1 object");

$scriptrep = VCS::Lite::Repository->new('scripts');

#12
isa_ok($scriptrep, 'VCS::Lite::Repository', "script repository still there");

my @script1 = $scriptrep->contents;

#13
is(@script1, 2, "contents returns 2 objects");

$child1->commit;

chdir updir;

my $parent = VCS::Lite::Repository->new('parent');

$parent->check_in( description => 'Test add and remove');

my @contp = $child1->contents;

#14
is(@contp, 3, "contents returns 3 objects");

chdir 'parent';
$testrep = VCS::Lite::Repository->new('t');

#15
isa_ok($testrep, 'VCS::Lite::Repository', "test repository in parent");

my @testp = $testrep->contents;

#16
is(@testp, 1, "contents returns 1 object");

$scriptrep = VCS::Lite::Repository->new('scripts');

#17
isa_ok($scriptrep, 'VCS::Lite::Repository', "script repository in parent");

my @scriptp = $scriptrep->contents;

#18
is(@scriptp, 2, "contents returns 2 objects");

$child2->update;
$child2->check_in( description => 'Test add and remove');

chdir updir;

$child2 = VCS::Lite::Repository->new('session2');

chdir 'session2';

$testrep = VCS::Lite::Repository->new('t');

#19
isa_ok($testrep, 'VCS::Lite::Repository', "test repository in session2");

my @test2 = $testrep->contents;

#20
is(@test2, 1, "contents returns 1 object");

$scriptrep = VCS::Lite::Repository->new('scripts');

#21
isa_ok($scriptrep, 'VCS::Lite::Repository', "script repository in session2");

my @script2 = $scriptrep->contents;

#22
is(@script2, 2, "contents returns 2 objects");

$child2->commit;

