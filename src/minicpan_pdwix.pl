#! perl

use warnings;
use strict;
use 5.010;
use IO::Handle;
use File::Copy;
use File::HomeDir;
use File::Spec::Functions qw(catdir catfile);

STDOUT->autoflush(1);
STDERR->autoflush(1);

say "Updated: ", scalar localtime;

require CPAN::Mini::Devel;

CPAN::Mini::Devel->update_mirror(
  remote => 'http://cpan.hexten.net/',
  local  => 'C:\minicpan',
  trace  => 1,
  path_filters => [
    sub { filters($_[0]); }
  ]
);

say "Finished: ", scalar localtime;

exit 0;

sub filters {
	my $mod = shift;
	
	# Perl::Dist::Bootstrap stuff;
    return 0 if $mod =~ m{/JUERD/DBIx-Simple-};
    return 0 if $mod =~ m{/FLORA/Algorithm-C3-};
    return 0 if $mod =~ m{/FLORA/Class-C3-};
	return 0 if $mod =~ m{/FLORA/MRO-Compat-};
	return 0 if $mod =~ m{/ADAMK/Task-Weaken-};
	return 0 if $mod =~ m{/CHOCOLATE/Scope-Guard-};
	return 0 if $mod =~ m{/NUFFIN/Devel-GlobalDestruction-};
	return 0 if $mod =~ m{/XMATH/Sub-Name-};
    return 0 if $mod =~ m{/DROLSKY/Class-MOP-};
    return 0 if $mod =~ m{/DROLSKY/Moose-};
	return 0 if $mod =~ m{/SARTAK/MooseX-AttributeHelpers-};
	return 0 if $mod =~ m{/CSJEWELL/};
    return 0 if $mod =~ m{/ADAMK/Module-Install-};
	return 0 if $mod =~ m{/ROODE/Readonly};
	return 0 if $mod =~ m{/DMUEY/File-Copy-Recursive-};
	return 0 if $mod =~ m{/RCLAMP/File-Find-Rule-};
	return 0 if $mod =~ m{/DAGOLDEN/File-pushd-};
	return 0 if $mod =~ m{/ADAMK/File-};
	return 0 if $mod =~ m{/TJENNESS/File-Temp-};
	return 0 if $mod =~ m{/ADAMK/LWP-Online-};
	return 0 if $mod =~ m{/ADAMK/Object-Tiny-};
	return 0 if $mod =~ m{/ADAMK/YAML-Tiny-};
	return 0 if $mod =~ m{/ADAMK/Params-Util-};
	return 0 if $mod =~ m{/ADAMK/Process-};
	return 0 if $mod =~ m{/MJD/Tie-File-};
	return 0 if $mod =~ m{/MSCHWERN/Test-Simple-};
	return 0 if $mod =~ m{/ADAMK/Win32-File-Object-};
	return 0 if $mod =~ m{/ADAMK/Portable-};
	return 0 if $mod =~ m{/ABW/Template-Toolkit-2};
	return 0 if $mod =~ m{/REYNOLDS/IO-Capture-};
	return 0 if $mod =~ m{/ADAMK/Perl-Dist-};
	return 0 if $mod =~ m{/RJBS/Data-UUID-};
	return 0 if $mod =~ m{/RJBS/Data-OptList-};
	return 0 if $mod =~ m{/RJBS/Sub-Install-};
	return 0 if $mod =~ m{/RJBS/Sub-Exporter-};
	return 0 if $mod =~ m{/RGARCIA/Module-CoreList-};
	return 0 if $mod =~ m{/SMUELLER/PAR-Dist-};
	return 0 if $mod =~ m{/SMUELLER/Module-ScanDeps-};
	return 0 if $mod =~ m{/VPARSEVAL/List-MoreUtils-};
	return 0 if $mod =~ m{/ABW/AppConfig-};
	return 0 if $mod =~ m{/DROLSKY/Exception-Class-};
	return 0 if $mod =~ m{/DROLSKY/File-Slurp-};
	return 0 if $mod =~ m{/DROLSKY/Devel-StackTrace-};
	return 0 if $mod =~ m{/SEKIMURA/LWP-UserAgent-WithCache-};
	return 0 if $mod =~ m{/BDFOY/Test-Output-};
	return 0 if $mod =~ m{/KWILLIAMS/Probe-Perl-};
	return 0 if $mod =~ m{/RGARCIA/Test-LongString-};
	return 0 if $mod =~ m{/ISHIGAKI/Tie-Slurp-};
	return 0 if $mod =~ m{/ISHIGAKI/Test-UseAllModules-};
	return 0 if $mod =~ m{/JJORE/B-Utils-};
	return 0 if $mod =~ m{/YVES/Data-Dump-Streamer-};
	return 0 if $mod =~ m{/ADAMK/Test-Script-};
	return 0 if $mod =~ m{/ROBIN/PadWalker-};
	return 0 if $mod =~ m{/JDHEDDEN/Object-InsideOut-};
	return 0 if $mod =~ m{/SHLOMIF/Error-};
	return 0 if $mod =~ m{/JSWARTZ/Cache-Cache-};
	return 0 if $mod =~ m{/ADAMK/Class-Inspector-};
	return 0 if $mod =~ m{/TMTM/Class-Data-Inheritable-};
	return 0 if $mod =~ m{/ADAMK/File-IgnoreReadonly-};
	return 0 if $mod =~ m{/ADAMK/LWP-Online-};
	return 0 if $mod =~ m{/RRWO/Pod-Readme-};
	return 0 if $mod =~ m{/ABIGAIL/Regexp-Common-};
	return 0 if $mod =~ m{/MLEHMANN/JSON-XS-};
	return 0 if $mod =~ m{/MAKAMAKA/JSON-};

	# Perl::Dist::Strawberry
	return 0 if $mod =~ m{/JDB/Win32-File-\d};
	return 0 if $mod =~ m{/ADAMK/Win32-File-Object-};
	return 0 if $mod =~ m{/COSIMO/Win32-API-};
	return 0 if $mod =~ m{/SMUELLER/Win32-Exe-};
	return 0 if $mod =~ m{/TELS/math/Math-BigInt-GMP-};
	return 0 if $mod =~ m{/MSERGEANT/XML-Parser-};
	return 0 if $mod =~ m{/PAJAS/XML-LibXML-};
	return 0 if $mod =~ m{/GAAS/libwww-perl-};
	return 0 if $mod =~ m{/SMUELLER/PAR-Dist-InstallPPD-};
    return 0 if $mod =~ m{/DAGOLDEN/Sub-Uplevel-};
	return 0 if $mod =~ m{/ADIE/Test-Exception-};
	return 0 if $mod =~ m{/DSKOLL/IO-stringy-};
    return 0 if $mod =~ m{/DAVECROSS/Array-Compare-};
    return 0 if $mod =~ m{/COGENT/Tree-DAG_Node-};
	return 0 if $mod =~ m{/CHORNY/Test-Warn-};
	return 0 if $mod =~ m{/FDALY/Test-Deep-};
	return 0 if $mod =~ m{/RKINYON/DBM-Deep-};
	return 0 if $mod =~ m{/ADAMK/YAML-Tiny-};
	return 0 if $mod =~ m{/SMUELLER/AutoLoader-};
	return 0 if $mod =~ m{/SMUELLER/PAR-};
	return 0 if $mod =~ m{/SMUELLER/PAR-Repository-Query-};
	return 0 if $mod =~ m{/SMUELLER/PAR-Repository-Client-};
	return 0 if $mod =~ m{/ADAMK/pler-};
	return 0 if $mod =~ m{/ADAMK/pip-};
	return 0 if $mod =~ m{/TIMB/DBI-};
	return 0 if $mod =~ m{/ADAMK/DBD-SQLite-};
    return 0 if $mod =~ m{/GBARR/CPAN-DistnameInfo-};
	return 0 if $mod =~ m{/RKOBES/CPAN-SQLite-};
	return 0 if $mod =~ m{/MJEVANS/DBD-ODBC-};
    return 0 if $mod =~ m{/FDALY/Test-Tester-};
    return 0 if $mod =~ m{/GRANTM/XML-SAX-};
    return 0 if $mod =~ m{/ANDK/CPAN-Checksums-};
    return 0 if $mod =~ m{/ADAMK/CPAN-Inject-};
    return 0 if $mod =~ m{/DCANTRELL/Data-Compare-};
    return 0 if $mod =~ m{/RCLAMP/Number-Compare-};
    return 0 if $mod =~ m{/PINYAN/File-chmod-};
    return 0 if $mod =~ m{/DAGOLDEN/File-pushd-};
    return 0 if $mod =~ m{/RCLAMP/File-Find-Rule-};
    return 0 if $mod =~ m{/ADAMK/File-Remove-};
    return 0 if $mod =~ m{/SMUELLER/PAR-Dist-};
    return 0 if $mod =~ m{/SMUELLER/PAR-Dist-FromPPD-};
    return 0 if $mod =~ m{/ADAMK/Params-Util-};
    return 0 if $mod =~ m{/KWILLIAMS/Probe-Perl-};
    return 0 if $mod =~ m{/AUDREYT/Parse-Binary-};
    return 0 if $mod =~ m{/PHISH/XML-LibXML-Common-};
    return 0 if $mod =~ m{/(?:RBERJON|PERIGRIN)/XML-NamespaceSupport-};
    return 0 if $mod =~ m{/FDALY/Test-NoWarnings-};
    return 0 if $mod =~ m{/ADAMK/Test-Script-};
    return 0 if $mod =~ m{/(?:RSCHUPP|RJBS)/IPC-Run3-};
    return 0 if $mod =~ m{/APEIRON/local-lib-};

	# Perl::Dist::WiX upgrades
    return 0 if $mod =~ m{/KANE/Archive-Extract-};
	return 0 if $mod =~ m{/SMUELLER/Attribute-Handlers-};
	return 0 if $mod =~ m{/SMUELLER/AutoLoader-};
	return 0 if $mod =~ m{/RURBAN/B-Debug-};
	return 0 if $mod =~ m{/JJORE/B-Lint-};
	return 0 if $mod =~ m{/KANE/CPANPLUS-};
	return 0 if $mod =~ m{/MHX/Devel-PPPort-};
	return 0 if $mod =~ m{/GAAS/Digest-};
	return 0 if $mod =~ m{/DANKOGAI/Encode-\d};
	return 0 if $mod =~ m{/FERREIRA/Exporter-};
	return 0 if $mod =~ m{/SMUELLER/Filter-Simple-};
	return 0 if $mod =~ m{/JV/Getopt-Long-};
	return 0 if $mod =~ m{/GBARR/IO-};
	return 0 if $mod =~ m{/KANE/IPC-Cmd-};
	return 0 if $mod =~ m{/FERREIRA/Locale-Maketext-};
	return 0 if $mod =~ m{/KANE/Log-Message-};
	return 0 if $mod =~ m{/GAAS/MIME-Base64-};
	return 0 if $mod =~ m{/TELS/math/Math-BigInt-};
	return 0 if $mod =~ m{/TELS/math/Math-BigInt-FastCalc-};
	return 0 if $mod =~ m{/TELS/math/Math-BigRat-};
	return 0 if $mod =~ m{/JHI/Math-Complex-};
	return 0 if $mod =~ m{/RGARCIA/Module-CoreList-};
	return 0 if $mod =~ m{/KANE/Module-Load-};
	return 0 if $mod =~ m{/KANE/Module-Load-Conditional-};
	return 0 if $mod =~ m{/KANE/Module-Loaded-};
	return 0 if $mod =~ m{/SIMONW/Module-Pluggable-};
	return 0 if $mod =~ m{/FLORA/NEXT-};
	return 0 if $mod =~ m{/KANE/Object-Accessor-};
	return 0 if $mod =~ m{/MAREKR/Pod-Parser-};
	return 0 if $mod =~ m{/FERREIRA/Pod-Perldoc-};
	return 0 if $mod =~ m{/ARANDAL/Pod-Simple-};
	return 0 if $mod =~ m{/RGARCIA/Safe-};
	return 0 if $mod =~ m{/SMUELLER/SelfLoader-};
	return 0 if $mod =~ m{/AMS/Storable-};
	return 0 if $mod =~ m{/RGARCIA/Switch-};
	return 0 if $mod =~ m{/KANE/Term-UI-};
	return 0 if $mod =~ m{/MSCHWERN/Test-Harness-Straps-};
	return 0 if $mod =~ m{/CHORNY/Text-ParseWords-};
	return 0 if $mod =~ m{/JDHEDDEN/Thread-Semaphore-};
	return 0 if $mod =~ m{/NUFFIN/Tie-RefHash-};
	return 0 if $mod =~ m{/JHI/Time-HiRes-};
	return 0 if $mod =~ m{/DROLSKY/Time-Local-};
	return 0 if $mod =~ m{/MSERGEANT/Time-Piece-};
	return 0 if $mod =~ m{/JDB/Win32-\d};
	return 0 if $mod =~ m{/SAPER/XSLoader-};
	return 0 if $mod =~ m{/TELS/math/bignum-};
	return 0 if $mod =~ m{/SAPER/constant-};
	return 0 if $mod =~ m{/JDHEDDEN/threads-};
	return 0 if $mod =~ m{/JDHEDDEN/threads-shared-};
	return 0 if $mod =~ m{/LDS/CGI.pm-};
	return 0 if $mod =~ m{/PJF/autodie-};
	return 0 if $mod =~ m{/PMQS/Filter-};
	return 0 if $mod =~ m{/RRA/podlators-};
	return 0 if $mod =~ m{/RRA/ANSIColor-};
	return 0 if $mod =~ m{/MUIR/modules/Text-Tabs\+Wrap-};
	return 0 if $mod =~ m{/JDHEDDEN/Thread-Queue-};
	return 0 if $mod =~ m{/KANE/File-Fetch-};
	return 0 if $mod =~ m{/BINGOS/CPANPLUS-Dist-Build-};

	# Toolchain
	return 0 if $mod =~ m{/MSCHWERN/ExtUtils-MakeMaker-};
	return 0 if $mod =~ m{/DLAND/File-Path-};
	return 0 if $mod =~ m{/RKOBES/ExtUtils-Command-};
	return 0 if $mod =~ m{/CHORNY/Win32API-File-};
	return 0 if $mod =~ m{/YVES/ExtUtils-Install-};
	return 0 if $mod =~ m{/RKOBES/ExtUtils-Manifest-};
	return 0 if $mod =~ m{/ANDYA/Test-Harness-};
	return 0 if $mod =~ m{/MSCHWERN/Test-Simple-};
	return 0 if $mod =~ m{/(?:KWILLIAMS|DAGOLDEN)/ExtUtils-CBuilder-};
	return 0 if $mod =~ m{/KWILLIAMS/ExtUtils-ParseXS-};
	return 0 if $mod =~ m{/JPEACOCK/version-};
	return 0 if $mod =~ m{/GBARR/Scalar-List-Utils-};
	return 0 if $mod =~ m{/PMQS/Compress-Raw-Zlib-};
	return 0 if $mod =~ m{/PMQS/Compress-Raw-Bzip2-};
	return 0 if $mod =~ m{/PMQS/IO-Compress-};
	return 0 if $mod =~ m{/ARJAY/Compress-Bzip2-};
	return 0 if $mod =~ m{/TOMHUGHES/IO-Zlib-};
	return 0 if $mod =~ m{/SMUELLER/PathTools-};
	return 0 if $mod =~ m{/TJENNESS/File-Temp-};
	return 0 if $mod =~ m{/JDB/Win32-WinError-};
	return 0 if $mod =~ m{/BLM/Win32API-Registry-};
	return 0 if $mod =~ m{/ADAMK/Win32-TieRegistry-};
	return 0 if $mod =~ m{/ADAMK/File-HomeDir-};
	return 0 if $mod =~ m{/PEREINAR/File-Which-};
	return 0 if $mod =~ m{/ADAMK/Archive-Zip-};
	return 0 if $mod =~ m{/KANE/Package-Constants-};
	return 0 if $mod =~ m{/GAAS/IO-String-};
	return 0 if $mod =~ m{/KANE/Archive-Tar-};
	return 0 if $mod =~ m{/FERREIRA/Compress-unLZMA-};
	return 0 if $mod =~ m{/(?:SMUELLER|ADAMK)/Parse-CPAN-Meta-};
	return 0 if $mod =~ m{/INGY/YAML-};
	return 0 if $mod =~ m{/GBARR/libnet-};
	return 0 if $mod =~ m{/GAAS/Digest-MD5-};
	return 0 if $mod =~ m{/GAAS/Digest-SHA1-};
	return 0 if $mod =~ m{/MSHELOR/Digest-SHA-};
	return 0 if $mod =~ m{/(?:EWILHELM|KWILLIAMS|DAGOLDEN)/Module-Build-};
	return 0 if $mod =~ m{/JSTOWE/Term-Cap-};
	return 0 if $mod =~ m{/ANDK/CPAN-};
	return 0 if $mod =~ m{/JSTOWE/TermReadKey-};
	return 0 if $mod =~ m{/ILYAZ/modules/Term-ReadLine-Perl-};
	return 0 if $mod =~ m{/RCLAMP/Text-Glob-};
	return 0 if $mod =~ m{/(?:SMUELLER|ILYAM)/Data-Dumper-};
	return 0 if $mod =~ m{/GAAS/URI-};
	return 0 if $mod =~ m{/PETDANCE/HTML-Tagset-};
	return 0 if $mod =~ m{/GAAS/HTML-Parser-};
	return 0 if $mod =~ m{/GAAS/libwww-perl-};
	
	return 1;
}