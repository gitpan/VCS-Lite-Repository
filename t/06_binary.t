
# Run test 00_clear.t first

# This test creates directory ./test as a repository
# and does rudimentary operations on a standalone repository.

# Note: the test directory is used by subsequent tests

use strict;

use Test::More  tests => 9;
use File::Spec::Functions qw(:ALL);
use File::Copy;

#01
use_ok 'VCS::Lite::Element::Binary';

{
    no warnings;
    $VCS::Lite::Repository::username = 'test'; # For tests on non-Unix platforms
}

chdir 'test';

my $bin_ele = VCS::Lite::Element::Binary->new('rook.bmp');

#02
isa_ok($bin_ele,'VCS::Lite::Element::Binary','Construction');

#03
is($bin_ele->latest,0,"Latest generation of new element = 0");

copy updir."/example/rook1.bmp", "rook.bmp";

$bin_ele->check_in( description => 'Initial version');

#04
is($bin_ele->latest,1,"Latest generation following check-in = 1");

copy updir."/example/rook2.bmp", "rook.bmp";

$bin_ele->check_in(description => 'Black rook');

#05
is($bin_ele->latest,2,"Latest generation following second check-in = 2");

my $lit = $bin_ele->fetch( generation => 1);

#06
isa_ok($lit,'VCS::Lite',"fetch generation 1 returns");

chdir updir;
my $orig = VCS::Lite::Element::Binary->_slurp_lite('example/rook1.bmp');

#07
ok(!$lit->delta($orig),"Fetch returned generation 1 OK");

$lit = $bin_ele->fetch( generation => 2);

#08
isa_ok($lit,'VCS::Lite',"fetch generation 2 returns");

$orig = VCS::Lite::Element::Binary->_slurp_lite('example/rook2.bmp');

#09
ok(!$lit->delta($orig),"Fetch returned generation 2 OK");

my @txt1 = $lit->text;
my @txt2 = $orig->text;

