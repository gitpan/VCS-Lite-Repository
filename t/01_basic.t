
use Test::More  tests => 16;
use File::Spec::Functions qw(rel2abs);

#01
use_ok VCS::Lite::Repository;

{
    no warnings;
    $VCS::Lite::Repository::username = 'test'; # For tests on non-Unix platforms
}

# Duff args

#02 - File instead of directory
eval {VCS::Lite::Repository->new('MANIFEST')};
like ($@, qr(Invalid path), "File as path croaks");

#03 - Garbage filespec in any O/S
eval {VCS::Lite::Repository->new('/\/\~~#&')};
like ($@, qr(Failed to create directory), "Invalid filespec croaks");

my $rep = VCS::Lite::Repository->new('test');

#04
isa_ok($rep, VCS::Lite::Repository, "Successful return from new");

#05
my $hwtest = $rep->add_element('helloworld.c');
isa_ok($hwtest, VCS::Lite::Element, 'add_element');

#06
my @eleret = $rep->elements;
is (@eleret,1,'elements returned one element');

#07
isa_ok($eleret[0], VCS::Lite::Element, 'member of array returned by elements');

#08
is($hwtest->latest,0,"Latest generation of new element = 0");

chdir 'test';

my $hworld = <<EOF;

#include <stdio.h>

main() {

    printf("Hello World\\n");
}

EOF

open TEST,'>','helloworld.c';
print TEST $hworld;
close TEST;

$hwtest->check_in( description => 'Initial version');

#09
is($hwtest->latest,1,"Latest generation following check-in = 1");

$hworld =~ s/Hello World/Bonjour Le Monde/;
open TEST,'>','helloworld.c';
print TEST $hworld;
close TEST;

$hwtest->check_in(description => 'Change text to French');

#10
is($hwtest->latest,2,"Latest generation following second check-in = 2");

my $lit1 = $hwtest->fetch( generation => 1);

#11
isa_ok($lit1,'VCS::Lite',"fetch generation 1 returns");

my $lit2 = $hwtest->fetch( generation => 2);

#12
isa_ok($lit1,'VCS::Lite',"fetch generation 2 returns");

my $diff=$lit1->delta($lit2)->udiff;

$diff =~ s/(@@\d+)\s/$1/g;	# Fix spurious trailing blanks from udiff

my $absfile = rel2abs("helloworld.c");

my $expected = <<END;
--- $absfile\@\@1
+++ $absfile\@\@2
\@\@ -6,1 +6,1 \@\@
-    printf("Hello World\\n");
+    printf("Bonjour Le Monde\\n");
END

#13
is($diff,$expected,"Compare diff with expected results");

my $foorep = $rep->add_repository('foobar');

#14
isa_ok($foorep,VCS::Lite::Repository,"Return from add_repository");

my @cont = $rep->contents;

#15
is(@cont, 2, "Objects returned by contents");

$rep->remove('foobar');
@cont = $rep->contents;

#16
is(@cont, 1, "Only one object after remove");
