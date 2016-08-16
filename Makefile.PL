use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'RPi::WiringPi',
    VERSION_FROM      => 'lib/RPi/WiringPi.pm',
    ($] >= 5.005 ?
      (ABSTRACT_FROM  => 'lib/RPi/WiringPi.pm',
       AUTHOR         => 'Steve Bertrand <steveb@cpan.org>') : ()),
    LIBS              => [],
    DEFINE            => '',
    INC               => '-I.',
    META_MERGE => {
        'meta-spec' => { version => 2 },
        resources   => {
            bugtracker => {
                web => 'https://github.com/stevieb9/p5-rpi-wiringpi/issues',
            },
            repository => {
                type => 'git',
                url => 'https://github.com/stevieb9/p5-rpi-wiringpi.git',
                web => 'https://github.com/stevieb9/p5-rpi-wiringpi',
            },
        },
    },
    PREREQ_PM         => {
        'WiringPi::API'       => 1.01,
        'RPi::WiringPi::Constant'   => 0.02,
    },
    #OBJECT            => '$(O_FILES)', # link all the C files too
);
