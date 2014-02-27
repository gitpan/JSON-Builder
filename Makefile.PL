use 5.008008;
use ExtUtils::MakeMaker;

my %pm = map { $_ => "\$(INST_LIB)/$_" } ('IPC/MPS.pm', 'IPC/MPS/Event.pm', 'IPC/MPS/EV.pm');


WriteMakefile(
    NAME              => 'JSON::Builder',
    VERSION_FROM      => 'JSON/Builder.pm', # finds $VERSION
    PREREQ_PM         => { 
		'JSON::XS'       => 0,
		'Compress::Zlib' => 0,
		'MIME::Base64'   => 0,
	}, # e.g., Module::Name => 1.1
	PM => { "JSON/Builder.pm" => "\$(INST_LIB)/JSON/Builder.pm" },
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'JSON/Builder.pm', # retrieve abstract from module
       AUTHOR         => 'Nick Kostyria <kni@cpan.org>') : ()),
);
