use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

open BACK,'>backends.pl';

if (eval {require YAML; 1;}) {
	print BACK "sub test_stores {qw/YAML Storable/;} 1;\n";
}
else {
	warn "Tests for in situ YAML will be skipped as YAML is not installed";
	print BACK "sub test_stores {qw/Storable/;} 1;\n";
}
close BACK;

my @exe;

if (eval {require Parse::RecDescent; 1;}) {
	push @exe, 'bin/VCShell';
}
else {
    warn "Parse::RecDescent not available, so VCShell will not be installed";
}

WriteMakefile(
    'NAME'		=> 'VCS::Lite::Repository',
    'VERSION_FROM'	=> 'lib/VCS/Lite/Repository.pm', # finds $VERSION
    'PREREQ_PM'		=> {VCS::Lite => 0.05,
    				Time::Piece => 0,
    				Params::Validate => 0,
    				Test::More => 0,
    				Cwd => 2.19,
    				},
    'EXE_FILES'		=> \@exe,
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'lib/VCS/Lite/Repository.pm', 
       AUTHOR     => 'Ivor Williams') : ()),
);
