
use strict;
use Test::More  tests => 3;
use File::Spec::Functions qw(splitpath);

#01
use_ok 'VCS::Lite::Repository';

my $rep = VCS::Lite::Repository->new('example');

#02
isa_ok($rep, 'VCS::Lite::Repository', "Successful return from new");

my %latest;

$rep->traverse( \&listout);

sub listout {
    my $ele = shift;
    if ($ele->isa('VCS::Lite::Element')) {
	my ($vol,$dir,$file) = splitpath($ele->path);
	$latest{$file} = $ele->latest;
    } else {
        $ele->traverse (\&listout);
    }
}

#03
is_deeply(\%latest, {
	'mariner.txt' => 3,
	'vldiff.pl' => 0,
	'vlpatch.pl' => 0,
	'vlmerge.pl' => 0 }, "Latest generations match expected");
