
# Run the following tests before this test:
#
# 00_clear.t - remove ./test
# 01_basic.t - create fresh ./test

use strict;
use Test::More;
#use Test::More skip_all => "This test due for rewriting";

if ($^O =~ /vms|win/i) {
    plan skip_all => "Open3 not available on this platform";
}
else {
    plan tests => 24;
}

use File::Spec::Functions qw(rel2abs catfile curdir);
use IPC::Open3;
use IO::Select;
use Cwd;

my $debug = $ENV{DEBUG};

#01
use_ok 'VCS::Lite::Repository';

{
    no warnings;
    $VCS::Lite::Repository::username = 'test'; # For tests on non-Unix platforms
}

my ($wtr, $rdr, $err);
my $pid = open3($wtr,$rdr,$err,$^X,qw(-Iblib/lib -Iblib/arch/lib blib/script/VCShell));

#02
ok($pid, "Spawned subprocess for VCShell");

my $pmpt;
my $expmpt = 'VCSLite> ';

#03
ok(sysread($rdr,$pmpt,120), "sysread returned something");

#04
is($pmpt,$expmpt,"Prompt set correctly");

my $sel = IO::Select->new($rdr);

sub read_until_prompt {
    my ($prompt,$tim) = @_;
    my $out = '';

    while ($sel->can_read($tim)) {
        sysread($rdr,$out,10,length($out));
        last if $out =~ /$prompt/;
    }
    return undef unless $out =~ s/$prompt//;
    print "Subprocess returned: '$out'\n" if $debug;

    $out;
}

my $rep = VCS::Lite::Repository->new('test');

print $wtr "cd test\n";
chdir 'test';

my $buff = read_until_prompt($pmpt,1);

#05
ok(defined($buff), "Got output after chdir");

print $wtr "pwd\n";
$buff = read_until_prompt($pmpt,1);

#06
ok($buff, "Got output after pwd");

chomp $buff;

#07
is($buff,cwd,"Output was current directory");

print $wtr "add hworld.pl\n";
$buff = read_until_prompt($pmpt,1);

#08
ok($buff, "Got output after add");

#09
like($buff,qr/Add hworld\.pl.*test$/,"Got logging message");

$rep = VCS::Lite::Repository->new('.');
my @cont = $rep->contents;

#10
ok(scalar(grep {$_->path =~ /hworld.pl$/} @cont),"hworld.pl in the repository");

my $hworld = <<EOF;
#!/usr/bin/perl

use strict;
use warnings;

print "Hello World\\n";

EOF

open TEST,'>','hworld.pl';
print TEST $hworld;
close TEST;

print $wtr "ci hworld.pl\n";

$buff = read_until_prompt("Terminate with a dot\n",1);

#11
ok($buff, "Got output after ci");

#12
is($buff,"Enter a description of the change made\n","Intro message");

print $wtr "Initial version\n.\n";

$buff = read_until_prompt($pmpt,1);

#13
ok(defined($buff), "Got output after entering change desc");

TODO:
{
	todo_skip "Skip until logging hooks enabled", 1;
#14
like($buff,qr/^Check in .*hworld.pl$/,"ci response log message");
}

my $hw = VCS::Lite::Element->new('hworld.pl');

#15
is($hw->latest,1,"Check in worked, latest gen 1");

$hworld =~ s/Hello World/Bonjour Le Monde/;
open TEST,'>','hworld.pl';
print TEST $hworld;
close TEST;

print $wtr "ci hworld.pl\n";

$buff = read_until_prompt("Terminate with a dot\n",1);

#16
ok($buff, "Got output after second ci");

#17
is($buff,"Enter a description of the change made\n","Intro message");

print $wtr "Change text to French\n.\n";

$buff = read_until_prompt($pmpt,1);

#18
ok(defined($buff), "Got output after entering change desc");

TODO:
{
	todo_skip "Skip until logging hooks enabled", 1;
#19
like($buff,qr/^Check in .*hworld.pl$/,"ci response log message");
}

$hw = VCS::Lite::Element->new('hworld.pl');

#20
is($hw->latest,2,"Check in worked, latest gen 2");

print $wtr "diff hworld.pl\n";
$buff = read_until_prompt($pmpt,1);

my ($line1,$line2) = split /\n/,$buff;

#21
like($line1,qr/\-\-\-.*hworld.pl\@\@1/,"First file output from diff");

#22
like($line2,qr/\+\+\+.*hworld.pl\@\@2/,"Second file output from diff");

$buff =~ s/.*\@\@2\s*\n//s;

my $expected = <<END;
\@\@ -6,1 +6,1 \@\@
-print "Hello World\\n";
+print "Bonjour Le Monde\\n";
END

#23
is($buff,$expected,"print line changed");

close $wtr;

#24
ok(waitpid($pid,0),"Child process has closed down");
