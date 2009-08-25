package Perl::Dist::WiX::BuildPerl;

=pod

=head1 NAME

Perl::Dist::WiX::BuildPerl - 4th generation Win32 Perl distribution builder

=head1 VERSION

This document describes Perl::Dist::WiX::BuildPerl version 1.000.

=head1 DESCRIPTION

This module provides the routines that Perl::Dist::WiX uses in order to
build Perl itself.  

=head1 SYNOPSIS

	# This module is not to be used independently.

=head1 INTERFACE

=cut

use     5.008001;
use     strict;
use     warnings;
use     Archive::Zip             qw( :ERROR_CODES               );
use     English                  qw( -no_match_vars             );
use     List::MoreUtils          qw( any none                   );
use     Params::Util             qw( _HASH _STRING _INSTANCE    );
use     Readonly                 qw( Readonly                   );
use     File::Spec::Functions    qw(
	catdir catfile catpath tmpdir splitpath rel2abs curdir
);
use     Archive::Tar        1.42 qw();
use     File::Remove             qw();
use     File::pushd              qw();
use     File::ShareDir           qw();
use     File::Copy::Recursive    qw();
use     File::PathList           qw();
use     HTTP::Status             qw();
use     IO::String               qw();
use     IO::Handle               qw();
use     LWP::UserAgent           qw();
use     LWP::Online              qw();
use     Module::CoreList    2.17 qw();
use     PAR::Dist                qw();
use     Probe::Perl              qw();
use     SelectSaver              qw();
use     Storable                 qw( retrieve );
use     Template                 qw();
use     Win32                    qw();
use Perl::Dist::WiX::Asset::Perl qw();
require Perl::Dist::Util::Toolchain;
require File::List::Object;


our $VERSION = '1.100';
$VERSION = eval { return $VERSION };


Readonly my %MODULE_FIX => (
	'CGI.pm'               => 'CGI',
	'Fatal'                => 'autodie',
	'Filter::Util::Call'   => 'Filter',
	'Locale::Maketext'     => 'Locale-Maketext',
	'Pod::Man'             => 'Pod',
	'Text::Tabs'           => 'Text',
	'PathTools'            => 'Cwd',
	'TermReadKey'          => 'Term::ReadKey',
	'Term::ReadLine::Perl' => 'Term::ReadLine',
	'libwww::perl'         => 'LWP',
	'Scalar::List::Utils'  => 'List::Util',
	'libnet'               => 'Net',
	'encoding'             => 'Encode',
	'IO::Scalar'           => 'IO::Stringy',
);

Readonly my @MODULE_DELAY => qw(
  CPANPLUS::Dist::Build
  File::Fetch
  Thread::Queue
);

#####################################################################
# CPAN installation and upgrade support

# NOTE: "The object that called it" is supposed to be a Perl::Dist::WiX 
# object.

=head2 install_cpan_upgrades

The C<install_cpan_upgrades> method is provided to upgrade all the
modules that were installed with Perl that were not upgraded by the
L<install_perl_toolchain|/install_perl_toolchain> subroutine.

Returns true (technically, the object that called it), or throws an exception.

=cut

sub install_cpan_upgrades {
	my $self = shift;
	unless ( $self->bin_perl ) {
		PDWiX->throw(
			'Cannot install CPAN modules yet, perl is not installed');
	}

	# Get list of modules to be upgraded. 
	# (The list is saved as a Storable arrayref of CPAN::Module objects.)
	my $cpan_info_file = $self->_get_cpan_upgrades_list();
	my $module_info = retrieve $cpan_info_file;

	my $force;
	my @delayed_modules;
	require CPAN;
  MODULE:
	for my $module ( @{$module_info} ) {
		$force = $self->force;

		next MODULE if $self->_skip_upgrade($module);

		# Net::Ping seems to require that a web server be
		# available on localhost in order to pass tests.
		if ( $module->cpan_file =~ m{/Net-Ping-\d}msx ) {
			$self->_install_cpan_module( $module, 1 );
			next MODULE;
		}
		
		# Safe seems to have problems inside a build VM, but
		# not outside.  Forcing to be safe.
		if ( $module->cpan_file =~ m{/Safe-\d}msx ) {
			$self->_install_cpan_module( $module, 1 );
			next MODULE;
		}

		# Locale::Maketext::Simple 0.20 has a test bug. Forcing.
		if ( $module->cpan_file =~ m{/Locale-Maketext-Simple-0\.20}msx ) {
			$self->_install_cpan_module( $module, 1 );
			next MODULE;
		}

		if (    ( $module->cpan_file =~ m{/Module-Install-\d}msx )
			and ( $module->cpan_version > 0.79 ) )
		{
			# We need a few more modules.
			$self->install_modules(qw( File::Remove YAML::Tiny ));
			$self->_install_cpan_module( $module, $force );
			next MODULE;
		}

		if (    ( $module->cpan_file =~ m{/ExtUtils-MakeMaker-\d}msx )
			and ( $module->cpan_version > 6.50 ) )
		{
			$self->remove_file(qw{perl lib ExtUtils MakeMaker bytes.pm});
			$self->remove_file(qw{perl lib ExtUtils MakeMaker vmsish.pm});			
			$self->_install_cpan_module( $module, $force );
			next MODULE;
		}

		if (    ( $module->cpan_file =~ m{/podlators-\d}msx )
			and ( $module->cpan_version > 2.00 )
			and ( $self->perl_version < 5100 ) )
		{
			$self->install_modules(qw( Pod::Escapes Pod::Simple ));
			$self->_install_cpan_module( $module, $force );
			next MODULE;
		}

		if ( $self->_delay_upgrade($module) ) {

			# Delay these module until last.
			unshift @delayed_modules, $module;
			next MODULE;
		}

		$self->_install_cpan_module( $module, $force );
	} ## end for my $module ( @{$module_info...})

	for my $module (@delayed_modules) {
		$self->_install_cpan_module( $module, $force );
	}
	
	# Getting modules for autodie support installed.
	# Yes, I know that technically it's a core module with 
	# non-core dependencies, and that's ugly. I've just got 
	# to live with it.
	my $autodie_location =
		catfile( $self->image_dir, qw(perl lib autodie.pm) );

	if ( -e $autodie_location ) {
		$self->install_modules(qw( Win32::Process IPC::System::Simple ));
	}

	# Getting CPANPLUS config file installed if required.
	my $cpanp_config_location =
	  catfile( $self->image_dir, qw(perl lib CPANPLUS Config.pm) );

	if ( -e $cpanp_config_location ) {
		$self->trace_line( 1,
			"Getting CPANPLUS config file ready for patching\n" );

		$self->patch_file(
			'perl/lib/CPANPLUS/Config.pm' => $self->image_dir,
			{ dist => $self, } );
	}

	return $self;
} ## end sub install_cpan_upgrades

sub _get_cpan_upgrades_list {
	my $self = shift;

	# Generate the CPAN installation script
	my $url = $self->cpan()->as_string();

	$url =~ s{file:///C:/}{file://C:/}msx;

	my $cpan_string = <<"END_PERL";
print "Loading CPAN...\\n";
use CPAN;
CPAN::HandleConfig->load unless \$CPAN::Config_loaded++;
\$CPAN::Config->{'urllist'} = [ '$url' ];
END_PERL
	$cpan_string .= <<'END_PERL';
print "Loading Storable...\n";
use Storable qw(nstore);

my ($module, %seen, %need, @toget);
	
my @modulelist = CPAN::Shell->expand('Module', '/./');

# Schwartzian transform from CPAN.pm.
my @expand;
@expand = map {
	$_->[1]
} sort {
	$b->[0] <=> $a->[0]
	||
	$a->[1]{ID} cmp $b->[1]{ID},
} map {
	[$_->_is_representative_module,
	 $_
	]
} @modulelist;

MODULE: for $module (@expand) {
	my $file = $module->cpan_file;
	
	# If there's no file to download, skip it.
	next MODULE unless defined $file;

	$file =~ s{^./../}{};
	my $latest  = $module->cpan_version;
	my $inst_file = $module->inst_file;
	my $have;
	my $next_MODULE;
	eval { # version.pm involved!
		if ($inst_file) {
			$have = $module->inst_version;
			local $^W = 0;
			++$next_MODULE unless CPAN::Version->vgt($latest, $have);
			# to be pedantic we should probably say:
			#    && !($have eq "undef" && $latest ne "undef" && $latest gt "");
			# to catch the case where CPAN has a version 0 and we have a version undef
		} else {
		   ++$next_MODULE;
		}
	};

	next MODULE if $next_MODULE;
	
	if ($@) {
		next MODULE;
	}
	
	$seen{$file} ||= 0;
	next MODULE if $seen{$file}++;
	
	push @toget, $module;
	
	$need{$module->id}++;
}

unless (%need) {
	print "All modules are up to date\n";
}
	
END_PERL

	my $cpan_info_file = catfile( $self->output_dir, 'cpan.info' );
	$cpan_string .= <<"END_PERL";
nstore \\\@toget, '$cpan_info_file';
print "Completed collecting information on all modules\\n";

exit 0;
END_PERL

	# Dump the CPAN script to a temp file and execute
	$self->trace_line( 1, "Running upgrade of all modules\n" );
	my $cpan_file = catfile( $self->build_dir, 'cpan_string.pl' );
  SCOPE: {
		my $CPAN_FILE;
		open $CPAN_FILE, '>', $cpan_file
		  or PDWiX->throw("CPAN script open failed: $!");
		print {$CPAN_FILE} $cpan_string
		  or PDWiX->throw("CPAN script print failed: $!");
		close $CPAN_FILE or PDWiX->throw("CPAN script close failed: $!");
	}
	$self->_run3( $self->bin_perl, $cpan_file )
	  or PDWiX->throw('CPAN script execution failed');
	PDWiX->throw('Failure detected during cpan upgrade, stopping')
	  if $CHILD_ERROR;

	return $cpan_info_file;
}

sub _install_cpan_module {
	my ( $self, $module, $force ) = @_;
	$force = $force or $self->force;
	my $perl_version = $self->perl_version_literal;
#<<<
	my $core =
	  exists $Module::CoreList::version{ $perl_version }{ $module->id }
	  ? 1
	  : 0;
	my $module_file = substr $module->cpan_file, 5;
	my $module_id = $self->_module_fix( $module->id );
	$self->install_distribution(
		name     => $module_file,
		mod_name => $module_id,
		$core
		  ? (
		      makefilepl_param => ['INSTALLDIRS=perl'],
			  buildpl_param => ['--installdirs', 'core'],
		    )
		  : (),
		$force
		  ? ( force => 1 )
		  : (),
	);
#>>>
	return 1;
} ## end sub _install_cpan_module

sub _skip_upgrade {
	my ( $self, $module ) = @_;

	# DON'T try to install Perl.
	return 1 if $module->cpan_file =~ m{/perl-5\.}msx;

	# DON'T try to install Term::ReadKey, we
	# already upgraded it.
	return 1 if $module->id eq 'Term::ReadKey';

	# If the ID is CGI::Carp, there's a bug in the index.
	return 1 if $module->id eq 'CGI::Carp';

	# If the ID is ExtUtils::MakeMaker, we've already installed it.
	# There were some files gotten rid of after 6.50, so
	# install_cpan_upgrades thinks that it needs to upgrade
	# those files using it.
	
	# This code is in here for safety as of yet.
	return 1 if $module->cpan_file =~ m{/ExtUtils-MakeMaker-6\.50}msx;

	return 0;
} ## end sub _skip_upgrade

sub _delay_upgrade {
	my ( $self, $module ) = @_;

	return ( any { $module->id eq $_ } @MODULE_DELAY ) ? 1 : 0;
}

sub _module_fix {
	my ( $self, $module ) = @_;

	return ( exists $MODULE_FIX{$module} ) ? $MODULE_FIX{$module} : $module;
}

=head2 install_perl_modules_*

(* = 1, 2, or 3)

The C<install_perl_modules_*> methods are stubs provided to allow sub-classed
distributions to install additional modules after perl is installed.

By default, C<install_perl_modules_1> calls 
L<install_cpan_upgrades|/install_cpan_upgrades> in order to upgrade all the 
modules included with perl. The others do nothing.

Returns true (technically, the object that called it), or throws an exception.

=cut

sub install_perl_modules_1 {
	my $self = shift;

	# Don't do anything here.
	return $self;
}

sub install_perl_modules_2 {
	my $self = shift;
	
	# Don't do anything here.
	return $self;
}

sub install_perl_modules_3 {
	my $self = shift;
	
	# Don't do anything here.
	return $self;
}

sub install_perl_modules_4 {
	my $self = shift;
	
	# Don't do anything here.
	return $self;
}

sub install_perl_modules_5 {
	my $self = shift;
	
	# Don't do anything here.
	return $self;
}

#####################################################################
# Perl installation support

=head2 install_perl

The C<install_perl> method is a minimal routine provided to call the 
correct L<install_perl_*|/install_perl_*> routine for the version of perl 
being created.

Returns true (technically, the object that called it), or throws an exception.

=cut

# Just hand off to the larger set of Perl install methods.
sub install_perl {
	my $self                = shift;
	my $install_perl_method = 'install_perl_' . $self->perl_version;
	unless ( $self->can($install_perl_method) ) {
		PDWiX->throw(
			"Cannot generate perl, missing $install_perl_method method in "
			  . ref $self );
	}
	$self->$install_perl_method(@_);

	$self->add_to_fragment( 'perl',
		[ catfile( $self->image_dir, qw(perl lib perllocal.pod) ) ] );

	return $self;
} ## end sub install_perl

#####################################################################
# Perl 5.8.8 Support

=head2 install_perl_* (* = 588, 589, or 5100)

	$self->install_perl_5100;

The C<install_perl_*> method provides a simplified way to install
Perl into the distribution.

It takes care of calling C<install_perl_*_bin> with the standard
params, and then calls C<install_perl_toolchain> to set up the
CPAN toolchain.

Returns true, or throws an exception on error.

=pod

=head2 install_perl_bin

	$self->install_perl_bin(
	  name       => 'perl',
	  dist       => 'RGARCIA/perl-5.10.0.tar.gz',
	  unpack_to  => 'perl',
	  license    => {
		  'perl-5.10.0/Readme'   => 'perl/Readme',
		  'perl-5.10.0/Artistic' => 'perl/Artistic',
		  'perl-5.10.0/Copying'  => 'perl/Copying',
	  },
	  install_to => 'perl',
	);

The C<install_perl_bin> method takes care of the detailed process
of building the Perl binary and installing it into the
distribution.

A short summary of the process would be that it downloads or otherwise
fetches the named package, unpacks it, copies out any license files from
the source code, then tweaks the Win32 makefile to point to the specific
build directory, and then runs make/make test/make install. It also
registers some environment variables for addition to the Inno Setup
script.

It is normally called directly by C<install_perl_*> rather than
directly from the API, but is documented for completeness.

It takes a number of parameters that are sufficiently detailed above.

Returns true (after 20 minutes or so) or throws an exception on
error.

=cut

#####################################################################
# Perl 5.8.9 Support

sub install_perl_589 {
	my $self = shift;

	# Prefetch and predelegate the toolchain so that it
	# fails early if there's a problem
	$self->trace_line( 1, "Pregenerating toolchain...\n" );
	my $toolchain = Perl::Dist::Util::Toolchain->new(
		perl_version => $self->perl_version_literal,
		cpan         => $self->cpan->as_string
	) or PDWiX->throw('Failed to resolve toolchain modules');
	unless ( eval { $toolchain->delegate; 1; } ) {
		PDWiX::Caught->throw(
			message => 'Delegation error occured',
			info    => defined($EVAL_ERROR) ? $EVAL_ERROR : 'Unknown error',
		);
	}
	if ( $toolchain->{errstr} ) {
		PDWiX::Caught->throw(
			message => 'Failed to generate toolchain distributions',
			info    => $toolchain->{errstr} );
	}

	# Make the perl directory if it hasn't been made alreafy.
	$self->make_path( catdir( $self->image_dir, 'perl' ) );

	# Install the main perl distributions
	$self->install_perl_bin(
		name       => 'perl',
		url        => 'http://strawberryperl.com/package/perl-5.8.9.tar.gz',
		unpack_to  => 'perl',
		install_to => 'perl',
		toolchain  => $toolchain,
		patch      => [ qw{
			  lib/CPAN/Config.pm
			  win32/config.gc
			  win32/config_sh.PL
			  }
		],
		license => {
			'perl-5.8.9/Readme'   => 'perl/Readme',
			'perl-5.8.9/Artistic' => 'perl/Artistic',
			'perl-5.8.9/Copying'  => 'perl/Copying',
		},
	);

	return 1;
} ## end sub install_perl_589

sub install_perl_bin {
	my $self = shift;
	my $perl = Perl::Dist::WiX::Asset::Perl->new(
		parent => $self,
		force  => $self->force,
		@_,
	);
	
	unless ( $self->bin_make ) {
		PDWiX->throw('Cannot build Perl yet, no bin_make defined');
	}
	
	$perl->install();
	
	# Should have a perl to use now.
	$self->{bin_perl} = catfile( $self->image_dir, qw/perl bin perl.exe/ );

	# Add to the environment variables
	$self->add_env_path( 'perl', 'bin' );

	return 1;
} ## end sub install_perl_589_bin


#####################################################################
# Perl 5.10.0 Support

sub install_perl_5100 {
	my $self = shift;

	# Prefetch and predelegate the toolchain so that it
	# fails early if there's a problem
	$self->trace_line( 1, "Pregenerating toolchain...\n" );
	my $toolchain = Perl::Dist::Util::Toolchain->new(
		perl_version => $self->perl_version_literal,
		cpan         => $self->cpan->as_string
	) or PDWiX->throw('Failed to resolve toolchain modules');
	unless ( eval { $toolchain->delegate; 1; } ) {
		PDWiX::Caught->throw(
			message => 'Delegation error occured',
			info    => defined($EVAL_ERROR) ? $EVAL_ERROR : 'Unknown error',
		);
	}
	if ( $toolchain->{errstr} ) {
		PDWiX::Caught->throw(
			message => 'Failed to generate toolchain distributions',
			info    => $toolchain->{errstr} );
	}

	$self->{toolchain} = $toolchain;
	
	# Make the perl directory if it hasn't been made already.
	$self->make_path( catdir( $self->image_dir, 'perl' ) );

	# Install the main binary
	$self->install_perl_bin(
		name      => 'perl',
		url       => 'http://strawberryperl.com/package/perl-5.10.0.tar.gz',
		unpack_to => 'perl',
		install_to => 'perl',
		toolchain  => $toolchain,
		patch      => [ qw{
			  lib/ExtUtils/Command.pm
			  lib/CPAN/Config.pm
			  win32/config.gc
			  win32/config_sh.PL
			  }
		],
		license => {
			'perl-5.10.0/Readme'   => 'perl/Readme',
			'perl-5.10.0/Artistic' => 'perl/Artistic',
			'perl-5.10.0/Copying'  => 'perl/Copying',
		},
	);

	return 1;
} ## end sub install_perl_5100


#####################################################################
# Perl Toolchain Support


=head2 install_perl_toolchain

The C<install_perl_toolchain> method is a routine provided to install the
"perl toolchain": the modules required for CPAN (and CPANPLUS on 5.10.x 
versions of perl) to be able to install modules.

Returns true (technically, the object that called it), or throws an exception.

=cut

sub install_perl_toolchain {
	my $self = shift;
	my $toolchain = $self->toolchain;

	my ( $core, $module_id );

	# Install the toolchain dists
	foreach my $dist ( @{ $toolchain->{dists} } ) {
		my $automated_testing = 0;
		my $release_testing   = 0;
		my $force             = $self->force;
		if ( $dist =~ /Scalar-List-Util/msx ) {

			# Does something weird with tainting
			$force = 1;
		}
		if ( $dist =~ /URI-/msx ) {

			# Can't rely on t/heuristic.t not finding a www.perl.bv
			# because some ISP's use DNS redirectors for unfindable
			# sites.
			$force = 1;
		}
		if ( $dist =~ /Term-ReadLine-Perl/msx ) {

			# Does evil things when testing, and
			# so testing cannot be automated.
			$automated_testing = 1;
		}
		if ( $dist =~ /TermReadKey-2\.30/msx ) {

			# Upgrading to this version, instead...
			$dist = 'STSI/TermReadKey-2.30.01.tar.gz';
		}
		if ( $dist =~ /CPAN-1\.9402/msx ) {

			# 1.9402 fails its tests... ANDK says it's a test bug.
			$force = 1;
		}
		if ( $dist =~ /ExtUtils-ParseXS-2\.20(?:02)?\.tar\.gz/msx ) {

			# 2.20 and 2.2002 are buggy on 5.8.9.
			$dist = 'DAGOLDEN/ExtUtils-ParseXS-2.20_05.tar.gz'
		}

		$module_id = $self->_name_to_module($dist);
		$core =
		  exists $Module::CoreList::version{ $self->perl_version_literal() }
		  {$module_id} ? 1 : 0;
#<<<
		$self->install_distribution(
			name              => $dist,
			mod_name          => $self->_module_fix($module_id),
			force             => $force,
			automated_testing => $automated_testing,
			release_testing   => $release_testing,
			$core
			  ? (
				  makefilepl_param => ['INSTALLDIRS=perl'],
				  buildpl_param => ['--installdirs', 'core'],
				)
			  : (),
		);
#>>>
	} ## end foreach my $dist ( @{ $toolchain...})

	return $self;
} ## end sub install_perl_toolchain

sub _name_to_module {
	my $self = shift;
	my $dist = shift;

	$self->trace_line( 3, "Trying to get module name out of $dist\n" );
	
#<<<
	my ( $module ) = $dist =~ m{\A  # Start the string...
					[A-Za-z/]*      # With a string of letters and slashes
					/               # followed by a forward slash. 
					(.*?)           # Then capture all characters, non-greedily 
					-\d*[.]         # up to a dash, a sequence of digits, and then a period.
					}smx;           # (i.e. starting a version number.)
#>>>
	$module =~ s{-}{::}msg;

	return $module;
} ## end sub _name_to_module



1;

__END__

=pod

=head1 DIAGNOSTICS

See L<Perl::Dist::WiX::Diagnostics|Perl::Dist::WiX::Diagnostics> for a list of
exceptions that this module can throw.

=head1 BUGS AND LIMITATIONS (SUPPORT)

Bugs should be reported via: 

1) The CPAN bug tracker at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Perl-Dist-WiX>
if you have an account there.

2) Email to E<lt>bug-Perl-Dist-WiX@rt.cpan.orgE<gt> if you do not.

For other issues, contact the topmost author.

=head1 AUTHORS

Curtis Jewell E<lt>csjewell@cpan.orgE<gt>

Adam Kennedy E<lt>adamk@cpan.orgE<gt>

=head1 SEE ALSO

L<Perl::Dist|Perl::Dist>, L<Perl::Dist::WiX|Perl::Dist::WiX>, 
L<http://ali.as/>, L<http://csjewell.comyr.com/perl/>

=head1 COPYRIGHT AND LICENSE

Copyright 2009 Curtis Jewell.

Copyright 2008 - 2009 Adam Kennedy.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this distribution.

=cut
