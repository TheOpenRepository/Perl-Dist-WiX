package Perl::Dist::WiX::Files::Entry;

#####################################################################
# Perl::Dist::WiX::Files::Entry - Class for a <File> tag.
#
# Copyright 2009 Curtis Jewell
#
# License is the same as perl. See Wix.pm for details.
#
# $Rev$ $Date$ $Author$ 
# $URL$

use 5.006;
use strict;
use warnings;
use Carp                  qw( croak               );
use Params::Util          qw( _IDENTIFIER _STRING );
use Data::UUID            qw( NameSpace_DNS       );
use File::Spec::Functions qw( splitpath           );
require Perl::Dist::WiX::Base::Entry;

use vars qw( $VERSION @ISA );
BEGIN {
    $VERSION = '0.13_01';
    @ISA = 'Perl::Dist::WiX::Base::Entry';
}

#####################################################################
# Accessors:
#   id: Returns the id parameter generated by new.
#   name, filename: Returns the name or filename parameter passed in to new.
#   sitename: Returns the sitename parameter passed in to new.

use Object::Tiny qw{
    id
    name
    sitename
};

sub filename { my $self = shift; return $self->name; }

#####################################################################
# Constructor for Files::Entry
#
# Parameters: [pairs]
#   sitename: The name of the site that is hosting the download.
#   id: ID attribute to the <File> tag.
#   name: Name attribute to the <File> tag.

sub new {
    my $self = shift->SUPER::new(@_);

    # Check params
    unless ( _STRING($self->name) or _STRING($self->{filename})) {
        croak("Missing or invalid name param");
    }
    if ((defined $self->{filename}) and (not defined $self->name)) {
        $self->{name} = $self->{filename};
    }
    unless ( _STRING($self->sitename) ) {
        croak("Missing or invalid sitename param - cannot generate GUID without one");
    }

    # Generate ID using name of file
    unless ( defined $self->id ) {
        my $guidgen = Data::UUID->new();
        # Make our own namespace...
        my $uuid = $guidgen->create_from_name(Data::UUID::NameSpace_DNS, $self->sitename);
        #... then use it to create a GUID out of the filename.
        $self->{id} = uc $guidgen->create_from_name_str($uuid, $self->filename);
        $self->{id} =~ s{-}{_}g;
    }

    return $self;
}

#####################################################################
# Main Methods

########################################
# as_string
# Parameters:
#   None
# Returns:
#   String representation of <File> tag represented by this object.

sub as_string {
    my $self = shift;
    my $answer;
    my $pathname = $self->name;
    
    if ($pathname =~ m(\.AAA\z)) {
        # If the file is a .AAA file, drop it in the original file's place.
        my (undef, undef, $filename) = splitpath($pathname);
        $filename = substr($filename, 0, -4);
        $answer = q{<File Id='F_} . $self->id .
            q{' Name='}           . $filename .
            q{' Source='}         . $pathname .
            q{' />};
    
    } else {
        # Name= parameter defults to the filename portion of the Source parameter,
        # so it isn't needed.
        $answer = q{<File Id='F_} . $self->id .
            q{' Source='}         . $pathname .
            q{' />};
    }
    
    return $answer;
}

1;
