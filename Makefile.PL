use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'VCS::Lite::Repository',
    'VERSION_FROM'	=> 'lib/VCS/Lite/Repository.pm', # finds $VERSION
    'PREREQ_PM'		=> {VCS::Lite => 0.05,
    				YAML => 0,
    				Time::Piece => 0}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'lib/VCS/Lite/Repository.pm', # retrieve abstract from module
       AUTHOR     => 'Ivor Williams') : ()),
);
