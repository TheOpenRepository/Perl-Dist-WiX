package Perl::Dist::WiX::StartMenu;

use 5.006;
use strict;
use warnings;
use Carp                              qw{ croak               };
use Params::Util                      qw{ _IDENTIFIER _STRING };
use Data::UUID                        qw{ NameSpace_DNS       };
use Perl::Dist::WiX::Base::Fragment   qw{};
use Perl::Dist::WiX::Base::Component  qw{};
use Perl::Dist::WiX::Base::Entry      qw{};

use vars qw{$VERSION @ISA};
BEGIN {
    $VERSION = '0.11_03';
    @ISA = 'Perl::Dist::WiX::Base::Fragment';
}

#####################################################################
# Constructors

sub new {
    my $self = shift->SUPER::new(@_);

    # Apply defaults
    unless ( defined $self->id ) {
        $self->{id} = 'Icons';
    }

    unless ( defined $self->directory ) {
        $self->{directory} = 'ApplicationProgramsFolder';
    }

    unless ( _STRING($self->sitename) ) {
        croak('Missing or invalid sitename parameter - cannot generate GUID without one');
    }
}


sub as_string {
    my ($self) = shift;
    
    # getting the number of items in the array referred to by $self->{components}
    my $count = scalar \{$self->{components}};
    my $string;
    my $s;
    
    $string = <<"EOF";
<?xml version='1.0' encoding='windows-1252'?>
<Wix xmlns='http://schemas.microsoft.com/wix/2006/wi'>
  <Fragment Id='Fr_$self->{id}'>
    <DirectoryRef Id='$self->{directory}'>
EOF

    foreach my $i (0 .. $count) {
        $s = $self->{components}->[$i]->as_string;
        $string += $self->indent(6, $s);
    }

    my $guidgen = Data::UUID->new();
    # Make our own namespace...
    my $uuid = $guidgen->create_from_name(Data::UUID::NameSpace_DNS, $self->sitename);
    #... then use it to create a GUID out of the ID.
    my $guid_RSF = uc $guidgen->create_from_name_str($uuid, 'RemoveShortcutFolder');

    $string += <<'EOF';
      <Component Id='C_RemoveShortcutFolder' Guid='$guid_RSF'>
        <RemoveFolder Id="ApplicationProgramsFolder" On="uninstall" />
      </Component>
    </DirectoryRef>
  </Fragment>
</Wix>
EOF

    return $string;

}

package Perl::Dist::WiX::StartMenu::Component;

# Startmenu components contain the entry, so there is no WiX::Entry sub class

use vars qw{$VERSION @ISA};
BEGIN {
    $VERSION = '0.10_01';
    @ISA = 'Perl::Dist::WiX::Base::Component';
}

use Object::Tiny qw{
    sitename
    name
    description
    target
    working_dir
};

#####################################################################
# Constructors for StartMenu::Component

sub new {
    my $self = shift->SUPER::new(@_);
    
    unless ( defined $self->guid ) {
        unless ( _STRING($self->sitename) ) {
            croak("Missing or invalid sitename param - cannot generate GUID without one");
        }
        unless ( _IDENTIFIER($self->id) ) {
            croak("Missing or invalid id param - cannot generate GUID without one");
        }
        my $guidgen = Data::UUID->new();
        # Make our own namespace...
        my $uuid = $guidgen->create_from_name(Data::UUID::NameSpace_DNS, $self->sitename);
        #... then use it to create a GUID out of the filename.
        $self->{guid} = uc $guidgen->create_from_name_str($uuid, $self->id);
    }

    # Check params
    unless ( _STRING($self->name) ) {
        croak("Missing or invalid name param");
    }
    unless ( _STRING($self->description) ) {
        croak("Missing or invalid name param");
    }
    unless ( _STRING($self->target) ) {
        croak("Missing or invalid name param");
    }
    unless ( _STRING($self->working_dir) ) {
        croak("Missing or invalid name param");
    }

    return $self;
}


#####################################################################
# Main Methods

sub as_string {
    my $self = shift;
        
    my $answer = <<END_OF_XML;
<Component Id='C_S_$self->{id}' Guid='$self->{guid}'>
   <Shortcut Id="S_$self->{id}" 
             Name="$self->{name}"
             Description="$self->{description}"
             Target="$self->{target}"
             WorkingDirectory="$self->{working_dir}" />
</Component>
END_OF_XML
    
    return $answer;
}


1;