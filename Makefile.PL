use strict;
use warnings;
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
    EXE_FILES         => [ map "bin/$_", qw(
            pinmap
            pidentify
            pimeta
            pimetaerase
        )
    ],
    META_MERGE => {
        'meta-spec' => { version => 2 },
        resources   => {
            bugtracker => {
                web => 'https://github.com/stevieb9/rpi-wiringpi/issues',
            },
            repository => {
                type => 'git',
                url => 'https://github.com/stevieb9/rpi-wiringpi.git',
                web => 'https://github.com/stevieb9/rpi-wiringpi',
            },
        },
    },
    MIN_PERL_VERSION   => 5.010,
    LICENSE => 'perl_5',
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker'   => 6.72,
    },
    PREREQ_PM         => {
        'parent'                    => 0,
        'File::Touch'               => 0,
        'GPSD::Parse'               => 1.04,
        'IPC::Shareable'            => 1.20,
        'JSON::XS'                  => 0,
        'String::CRC32'             => 0,
        'RPi::Accelerometer::ADXL335' => 0.01,
        'RPi::ADC::ADS'             => 1.04,
        'RPi::ADC::MCP3008'         => 3.1802,
        'RPi::Const'                => 1.07,
        'RPi::BMP180'               => 3.1802,
        'RPi::DAC::MCP4922'         => 3.1802,
        'RPi::DigiPot::MCP4XXXX'    => 3.1802,
        'RPi::DHT11'                => 1.06,
        'RPi::EEPROM::AT24C32'      => '1.00',
        'RPi::EEPROM::AT24C256'     => 0.01,
        'RPi::GPIOExpander::MCP23017' => 1.04,
        'RPi::Gyro::MPU6050'        => 0.01,
        'RPi::HCSR04'               => 3.1802,
        'RPi::I2C'                  => 3.1803,
        'RPi::LCD'                  => 3.1802,
        'RPi::OLED::SSD1306::128_64'=> 3.1802,
        'RPi::Pin'                  => 3.1803,
        'RPi::PWM::PCA9685'         => 0.02,
        'RPi::Radar::RCWL0516'      => 0.01,
        'RPi::RTC::DS3231'          => 0.04,
        'RPi::Serial'               => 3.03,
        'RPi::SPI'                  => 3.1802,
        'RPi::StepperMotor'         => 3.1802,
        'RPi::StepperMotor::A4988'  => 3.1801,
        'RPi::SysInfo'              => 1.03,
        'RPi::TFT::ST7735S'         => 3.1801,
        'WiringPi::API'             => 3.1804,
    },
);

# Regenerate derived docs before packaging so every distribution ships current
# copies: POD -> markdown (docs/pod/*.md, README.md) and the test-platform
# pinout/schematic artifacts. Hooked as a prerequisite of create_distdir so the
# freshly generated files are in place before manicopy assembles the tarball.

sub MY::postamble {
    return <<"MAKE_FRAG";
regen_docs :
\t\$(NOECHO) \$(ECHO) "Regenerating derived docs before packaging"
\t\$(PERLRUN) scripts/gen-pod-md.pl
\t\$(PERLRUN) scripts/gen-test-platform.pl

create_distdir : regen_docs
MAKE_FRAG
}
