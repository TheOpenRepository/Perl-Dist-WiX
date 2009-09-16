package Perl::Dist::WiX::Util::Machine;

=pod

=head1 NAME

Perl::Dist::WiX::Util::Machine - Generate an entire set of related distributions

=head1 DESCRIPTION

Perl::Dist::WiX::Util::Machine is a Perl::Dist multiplexor.

It provides the functionality required to generate several
variations of a distribution at the same time.

=head1 SYNOPSIS

	# This is what Perl::Dist::Strawberry does, as of version 2.00_02.

	# Create the machine
	my $machine = Perl::Dist::WiX::Util::Machine->new(
		class => 'Perl::Dist::Strawberry',
		common => [ forceperl => 1 ],
	);

	# Set the different versions
	$machine->add_dimension('version');
	$machine->add_option('version',
		perl_version => '589',
	    build_number => 2,
	);
	$machine->add_option('version',
		perl_version => '5101',
	);
	$machine->add_option('version',
		perl_version => '5100',
		portable     => 1,
	);

	# Set the different paths
	$machine->add_dimension('drive');
	$machine->add_option('drive',
		image_dir => 'C:\strawberry',
	);
	$machine->add_option('drive',
		image_dir => 'D:\strawberry',
		msi       => 1,
		zip       => 0,
	);

	$machine->run();
	# Creates 6 distributions (really 5, because you can't have
	# portable => 1 and zip => 0 for the same distribution.)	

=head1 INTERFACE

=head2 new

	my $machine = Perl::Dist::WiX::Util::Machine->new(
		class => 'Perl::Dist::WiX',
		common => [ forceperl => 1, ],
		output => 'C:\',
	);

This method creates a new machine to generate multiple distributions, 
using two required parameters and one optional parameter.

=head3 class (required)

This parameter specifies the class that the machine uses to create 
distributions.

It must be a subclass of L<Perl::Dist::WiX|Perl::Dist::WiX>.

=head3 common (required)

This parameter specifies the parameters that are common to all the 
distributions that will be created.

=head3 output (optional)

This is the directory where all the output files will be copied to.

If none is specified, it defaults to what L<File::HomeDir|File::HomeDir>
thinks is the desktop.

=cut

use 5.008001;
use Moose 0.90;
use MooseX::Types::Moose qw( Str ArrayRef HashRef Bool );
use Params::Util qw( _IDENTIFIER _HASH0 _DRIVER );
use File::Copy qw();
use File::HomeDir qw();

our $VERSION = '1.090_103';
$VERSION = eval $VERSION;

has class => (
	is => 'ro',
	isa => Str,
	required => 1,
    reader => '_get_class',	
);

has dimensions => (
	traits   => ['Array'],
	is       => 'bare',
	isa      => ArrayRef,
	default  => sub { return []; },
	init_arg => undef,
    handles  => {
	    '_add_dimension' => 'push',
		'_get_dimensions' => 'elements',
		
		
	},
);

has options => (
	traits   => ['Hash'],
	is       => 'bare',
	isa      => HashRef,
	default  => sub { return {}; },
	init_arg => undef,
    handles  => {
	    '_add_option'    => 'set',
		'_option_exists' => 'exists',
		'_get_option'    => 'get',
		
	},
);

has state => (
	traits   => ['Hash'],
	is       => 'ro',
	isa      => HashRef,
	default  => sub { return {} },
	init_arg => undef,
	reader   => '_get_state',
    handles  => {
	    '_has_state'   => 'count',
        '_next_state'  => 'inc',
	},
);

has eos => (
	traits   => ['Bool'],
	is       => 'ro',
	isa      => Bool,
	default  => 0,
	init_arg => undef,
	reader   => '_get_eos',
    handles => {
        '_set_eos' => 'set',
	},
);

has output (
	is      => 'ro',
	isa     => Str,
	default => sub { return File::HomeDir->my_desktop; },
	reader  => '_get_output',
);

has common (
	traits   => ['Array'],
	is       => 'bare',
	isa      => ArrayRef,
	required => 1,
	handles  => {
		'_get_common' => 'elements',
	},
);

#####################################################################
# Constructor

sub BUILDARGS {
	my $class = shift;
	my %args;

	if ( @_ == 1 && 'HASH' eq ref $_[0] ) {
		%args = %{ $_[0] };
	} elsif ( 0 == @_ % 2 ) {
		%args = (@_);
	} else {
		PDWiX->throw(
			'Parameters incorrect (not a hashref or hash) for Perl::Dist::WiX::Util::Machine');
	}
		
	if ( _HASH0($args{common}) ) {
		$args{common} = [ %{ $args{common} } ];
	}

	return \%args;
}

sub BUILD {
	my $self = shift;

	# Check params
	unless ( _DRIVER($self->class, 'Perl::Dist::WiX') ) {
		croak("Missing or invalid class param");
	}
	
	my $output = $self->_get_output();
	unless ( -d $output and -w $output ) {
		PDWiX->throw("The output directory '$output' does not exist, or is not writable");
	}

	return $self;
}




#####################################################################
# Setup Methods

=head2 add_dimension

	$machine->add_dimension('perl_version');

Adds a 'dimension' (a set of options for different distributions) to the 
machine. 

The options are added by L<add_option|/add_option> calls using this 
dimension name.

Note that dimensions are multiplicative, so that if there are 3 dimensions 
defined in the machine, and they each have 3 options, 27 distributions will be 
generated.

=cut

sub add_dimension {
	my $self = shift;
	my $name = _IDENTIFIER(shift) or PDWiX->throw("Missing or invalid dimension name");
	if ( $self->_has_state() ) {
		PDWiX->throw("Cannot alter params once iterating");
	}
	if ( $self->_option_exists($name) ) {
		PDWiX->throw("The dimension '$name' already exists");
	}
	
	$self->_add_dimension($name);
	$self->_add_option( $name => [ ] );
	return 1;
}

=head2 add_option

Adds a 'option' (a set of parameters that can change) to a dimension. 

=cut

sub add_option {
	my $self = shift;
	my $name = _IDENTIFIER(shift) or PDWiX->throw("Missing or invalid dimension name");
	if ( $self->_has_state() ) {
		PDWiX->throw("Cannot alter params once iterating");
	}
	unless ( $self->_option_exists($name) ) {
		croak("The dimension '$name' does not exist");
	}
	my $option = $self->_get_options($name);
	push @{$option}, [ @_ ];
	$self->_set_options($name => $option);
	return 1;
}




#####################################################################
# Iterator Methods

sub _increment_state {
	my $self = shift;
	my $name = shift;
	
	my $number = $self->_get_state($name);
	$self->set_state($name, ++$number);
	
	return;
}

=head2 all

	my @dists = $machine->all();

Returns an array of objects that create all the possible 
distributions configured for this machine. 

=cut

sub all {
	my $self    = shift;
	my @objects = ();
	while ( 1 ) {
		my $object = $self->next() or last;
		push @objects, $object;
	}
	return @objects;
}

=head2 next

	my $dist = $machine->next();

Returns an objects that creates the next possible 
distribution that is configured for this machine. 

=cut

sub next {
	my $self = shift;
	if ( $self->_get_eos() ) {
		# Already at last state
		return undef;
	}

	# Initialize the iterator if needed
	my $options = $self->_get_options();
	if ( $self->_has_state() ) {
		# Move to the next position
		my $found = 0;
		foreach my $name ( $self->_get_dimensions() ) {
			unless ( $self->_get_state($name) == $#{ $self->_get_options($name) } ) {
				# Normal iteration
				$self->_increment_state($name);
				$found = 1;
				last;
			}

			# We've hit the end of a dimension.
			# Loop the state to the start, so the
			# next dimension will iterate to the
			# correct value.
			$self->_set_state($name => 0);
		}
		unless ( $found ) {
			$self->_set_eos();
			return undef;
		}
	} else {
		# Initialize to the first position
		my %state;
		foreach my $name ( $self->_get_dimensions() ) {
			unless ( @{ $self->_get_options($name) } ) {
				PDWiX->throw("No options for dimension '$name'");
			}
			$state{$name} = 0;
		}
		$self->_set_state(%state);
		
	}

	# Create the param-set
	my @params = $self->_get_common();
	foreach my $name ( $self->_get_dimensions() ) {
		my $i = $self->_get_state($name);
		push @params, @{ $self->_get_options($name)->[ $i ] };
	}

	# Create the object with those params
	return $self->_get_class()->new( @params );
}





#####################################################################
# Execution Methods

=head2 run

	$machine->run();

Tries to create and execute each object that can be created by this 
machine.

=cut

sub run {
	my $self = shift;
	my $success;
	my $output_dir = $self->_get_output();
	
	while ( my $dist = $self->next() ) {
		$dist->prepare();
		my $success = eval { $dist->run(); 1; };

		if ($success) {
			# Copy the output products for this run to the
			# main output area.
			foreach my $file ( @{ $dist->output_file() } ) {
				File::Copy::move( $file, $output_dir );
			}
		};
		
		# Flush out the image dir for the next run
		File::Remove::remove(\1, $dist->image_dir());
	}
	return 1;
}

1;

=pod

=head1 SUPPORT

Bugs should be reported via the CPAN bug tracker at

L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Perl-Dist-WiX>

For other issues, contact the author.

=head1 AUTHOR

Curtis Jewell E<lt>adamk@cpan.orgE<gt>

Adam Kennedy E<lt>adamk@cpan.orgE<gt>

=head1 COPYRIGHT

Copyright 2009 Curtis Jewell.

Copyright 2007 - 2009 Adam Kennedy.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut