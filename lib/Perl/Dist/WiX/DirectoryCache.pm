package Perl::Dist::WiX::DirectoryCache;

#####################################################################
# Perl::Dist::WiX::DirectoryCache - Class containing cache of
#   <Directory> tags objects.
#
# Copyright 2009 Curtis Jewell
#
# License is the same as perl. See Wix.pm for details.
#
#<<<
use 5.008001;
use vars qw( $VERSION );
use MooseX::Singleton;
use WiX3::XML::Directory;
use MooseX::AttributeHelpers;
use version; $VERSION = version->new('1.100')->numify;
#>>>
#####################################################################
# Accessors:
#   root: Returns the root of the directory tree created by new.

has _cache => (
	metaclass => 'Collection::Hash',
	is        => 'rw',
	isa       => 'HashRef[Perl::Dist::WiX::Fragment::Files]',
	default   => sub { {} },
    provides  => {
        'set'    => '_set_cache_entry',
        'get'    => '_get_cache_entry',
		'exists' => '_exists_cache_entry',
        'delete' => '_delete_cache_entry',
	},
);

sub add_to_cache {
	my $self = shift;
	my $directory = shift || undef;
	my $fragment = shift || undef;
	
	# TODO: If $directory is not a WiX3::XML::Directory, throw an exception. 
	# TODO: If $fragment is not a Perl::Dist::WiX::Fragment::Files, throw an exception.
	# TODO: If the guid exists, throw an exception.
	
	$self->_set_cache_entry($directory->get_guid(), $fragment);
	
	return;
}

sub exists_in_cache {
	my $self = shift;
	my $directory = shift || undef;
	
	# TODO: If $directory is not a WiX3::XML::Directory, throw an exception. 

	return _exists_cache_entry($directory->get_guid());
}

sub get_previous_fragment {
	my $self = shift;
	my $directory = shift || undef;
	
	# TODO: If $directory is not a WiX3::XML::Directory, throw an exception. 

	return _get_cache_entry($directory->get_guid());
}

sub delete_cache_entry {
	my $self = shift;
	my $directory = shift || undef;
	
	# TODO: If $directory is not a WiX3::XML::Directory, throw an exception. 

	return _delete_cache_entry($directory->get_guid());
}

1;

__END__