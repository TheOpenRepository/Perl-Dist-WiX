package Perl::Dist::VanillaWiX;

=pod

=head1 NAME

Perl::Dist::VanillaWiX - Minimal distribution of Perl, useful only for testing.

=head1 VERSION

This document describes Perl::Dist::VanillaWiX version 1.101.

=head1 DESCRIPTION

This package is the upgrade to Perl::Dist based on Windows Installer XML 
technology, instead of Inno Setup.

Perl distributions built with this module have the option of being created
as Windows Installer databases (otherwise known as .msi files)

=head1 SYNOPSIS

	# Sets up a distribution with the following options
	my $distribution = Perl::Dist::VanillaWiX->new(
		msi               => 1,
		trace             => 1,
		cpan              => URI->new(('file://C|/minicpan/')),
		image_dir         => 'C:\myperl',
		download_dir      => 'C:\cpandl',
		output_dir        => 'C:\myperl_build',
		temp_dir          => 'C:\temp',
	);

	# Creates the distribution
	$distribution->run();

=head1 INTERFACE

=cut

use 5.008001;
use strict;
use warnings;
use parent qw(Perl::Dist::WiX);

our $VERSION = '1.100_001';
$VERSION =~ s/_//ms;

#####################################################################
# Constructor

sub new {
	my $class = shift;
	my %args;

	# Check for the correct version of Perl::Dist::WiX.
	Perl::Dist::WiX->VERSION(1.100001);

	if ( @_ == 1 && 'HASH' eq ref $_[0] ) {
		%args = %{ $_[0] };
	} elsif ( 0 == @_ % 2 ) {
		%args = (@_);
	} else {
		PDWiX->throw(
			'Parameters incorrect (not a hashref or hash) for ::Asset::*');
	}

	%args = (
		trace             => 2,
		app_publisher_url => 'http://strawberryperl.com/',
		app_id            => 'vanilla-perl',
		app_name          => 'Vanilla Perl',
		app_publisher     => 'Vanilla Perl Project',
		image_dir         => 'C:\WiXTest',
		build_number      => 20,
		%args,
	);

	return $class->SUPER::new( \%args );
} ## end sub new

# Default the versioned name to an unversioned name
sub _build_app_ver_name {
	my $self = shift;

	return $self->{app_ver_name} =
	  'Vanilla Perl version ' . $self->build_number();
}

# Default the output filename to the id plus the current date
sub _build_output_base_filename {
	my $self = shift;

	return $self->{output_base_filename} =
	    $self->app_id() . q{-}
	  . $self->build_number() . q{-}
	  . $self->output_date_string()
	  . ( 64 == $self->bits ) ? q{-64bit} : q{};
}

1;

__END__

=pod

=head1 DIAGNOSTICS

See L<Perl::Dist::WiX::Diagnostics|Perl::Dist::WiX::Diagnostics> for a list of
exceptions that this module can throw.

=head1 DEPENDENCIES

Perl 5.8.1 is the mimimum version of perl that this module will run on.

Other modules that this module depends on are a working version of 
L<Perl::Dist::WiX|Perl::Dist::WiX>.

=head1 BUGS AND LIMITATIONS (SUPPORT)

Bugs should be reported via: 

1) The CPAN bug tracker at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Perl-Dist-WiX>
if you have an account there.

2) Email to E<lt>bug-Perl-Dist-WiX@rt.cpan.orgE<gt> if you do not.

For other issues, contact the topmost author.

=head1 AUTHORS

Curtis Jewell E<lt>csjewell@cpan.orgE<gt>

=head1 SEE ALSO

L<Perl::Dist::WiX|Perl::Dist::WiX>, L<http://csjewell.comyr.com/perl/>

=head1 COPYRIGHT AND LICENSE

Copyright 2009 Curtis Jewell.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
