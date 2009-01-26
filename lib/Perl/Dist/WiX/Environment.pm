package Perl::Dist::WiX::Environment;

####################################################################
# Perl::Dist::WiX::Environment - Fragment & Component that contains
#  <Environment> tags
#
# Copyright 2009 Curtis Jewell
#
# License is the same as perl. See Wix.pm for details.

use 5.006;
use strict;
use warnings;
use Carp                              qw{ croak               };
use Params::Util                      qw{ _IDENTIFIER _STRING };
use Perl::Dist::WiX::Base::Fragment   qw{};
use Perl::Dist::WiX::EnvironmentEntry qw{};

use vars qw{$VERSION @ISA};
BEGIN {
    $VERSION = '0.11_06';
    @ISA = 'Perl::Dist::WiX::Base::Fragment';
}

use Object::Tiny qw{
    sitename
};


#####################################################################
# Constructor for Environment

sub new {
    my ($class, %params) = @_;

    # Apply defaults
    unless ( defined $params{id} ) {
        $params{id} = 'Environment';
    }

    my $self = $class->SUPER::new(%params);

    $self->{entries} = [];
    
    return $self;
}

sub search_file {
    return undef;
}

sub check_duplicates {
    return undef;
}

sub add_entry {
    my $self = shift;
    
    my $i = scalar @{$self->{entries}};
    
    $self->{entries}->[$i] = Perl::Dist::WiX::EnvironmentEntry->new(@_);
    
    return $self;
}

sub get_component_array {
    my $self = shift;

    return $self->{id};
}

########################################
# as_string
# Parameters:
#   None.
# Returns:
#   String containing <Fragment> and <Component> tags defined by this object
#   and <Environment> tags defined by objects contained in this object.

sub as_string {
    my ($self) = shift;
    
    # getting the number of items in the array referred to by $self->{components}
    my $count = scalar @{$self->{components}};
    my $string;
    my $s;
    
    my $guidgen = Data::UUID->new();
    # Make our own namespace...
    my $uuid = $guidgen->create_from_name(Data::UUID::NameSpace_DNS, $self->sitename);
    #... then use it to create a GUID out of the ID.
    my $guid = uc $guidgen->create_from_name_str($uuid, $self->{id});

    $string = <<"EOF";
<?xml version='1.0' encoding='windows-1252'?>
<Wix xmlns='http://schemas.microsoft.com/wix/2006/wi'>
  <Fragment Id='Fr_$self->{id}'>
    <DirectoryRef Id='TARGETDIR'>
      <Component Id='C_$self->{id}' Guid='$guid'>
EOF

    foreach my $i (0 .. $count - 1) {
        $s = $self->{Entries}->[$i]->as_string;
        $string .= $self->indent(8, $s);
        $string .= "\n";
    }

    $string .= <<'EOF';
      </Component>
    </DirectoryRef>
  </Fragment>
</Wix>
EOF

    return $string;
}

1;