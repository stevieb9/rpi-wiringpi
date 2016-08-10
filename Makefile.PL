use 5.018002;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'RPi::WiringPi',
    VERSION_FROM      => 'lib/RPi/WiringPi.pm',
    PREREQ_PM         => {
        'RPi::WiringPi::Core'   => 0.01, 
    },
    ($] >= 5.005 ?
      (ABSTRACT_FROM  => 'lib/RPi/WiringPi.pm',
       AUTHOR         => 'Steve Bertrand <steveb@cpan.org>') : ()),
    LIBS              => ['-lwiringPi'],
    DEFINE            => '',
    INC               => '-I.',
    OBJECT            => '$(O_FILES)', # link all the C files too
);
