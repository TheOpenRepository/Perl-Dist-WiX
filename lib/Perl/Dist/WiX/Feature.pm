package Perl::Dist::WiX::Feature;

####################################################################
# Perl::Dist::WiX::Feature - Object representing <Feature> tag.
#
# Copyright 2009 Curtis Jewell
#
# License is the same as perl. See Wix.pm for details.

use 5.006;
use strict;
use warnings;
use Carp                        qw{ croak verbose                };
use Params::Util                qw{ _CLASSISA _STRING _NONNEGINT };
use Perl::Dist::WiX::Misc       qw{};

use vars qw{$VERSION @ISA};
BEGIN {
    $VERSION = '0.11_06';
    @ISA = 'Perl::Dist::WiX::Misc';
}

use Object::Tiny qw{
    features
    componentrefs
    
    id
    title
    description
    default
    idefault
    display
    directory
    absent
    advertise
    level
};

=pod

        $self->features->[0] = Perl::Dist::WiX::Feature->new(
            id          => 'Complete', 
            title       => $parent->app_ver_name,
            description => 'The complete package.',
#            default     => 'install',          # TypicalDefault
#            idefault    => 'local',            # InstallDefault
#            display     => 'expand',           
#            directory   => 'INSTALLDIR',       # ConfigurableDirectory
#            absent      => 'disallow'
#            advertise   => 'no'                # Allowadvertise
            level       => 1,
        );

=cut

# http://wix.sourceforge.net/manual-wix3/wix_xsd_feature.htm

sub new {
    my $self = shift->SUPER::new(@_);

    # Check required parameters.
    unless (_STRING($self->id)) {
        croak 'Missing or invalid id parameter';
    }
    unless (_STRING($self->title)) {
        croak 'Missing or invalid title parameter';
    }
    unless (_STRING($self->description)) {
        croak 'Missing or invalid description parameter';
    }
    unless (_NONNEGINT($self->level)) {
        croak 'Missing or invalid level parameter';
    }

    my $default_settings = 0;
    
    # Set defaults
    unless (_STRING($self->default)) {
        $self->{default} = 'install';
        $default_settings++;
    }
    unless (_STRING($self->idefault)) {
        $self->{idefault} = 'local';
        $default_settings++;
    }
    unless (_STRING($self->display)) {
        $self->{display} = 'expand';
        $default_settings++;
    }
    unless (_STRING($self->directory)) {
        $self->{directory} = 'INSTALLDIR';
        $default_settings++;
    }
    unless (_STRING($self->absent)) {
        $self->{absent} = 'disallow';
        $default_settings++;
    }
    unless (_STRING($self->advertise)) {
        $self->{advertise} = 'no';
        $default_settings++;
    }

    $self->{default_settings} = $default_settings;

    # Set up empty arrayrefs
    $self->{features} = [];
    $self->{componentrefs} = [];
    
    return $self;
}

sub add_feature {
    my ($self, $feature) = @_;
    
    unless (_CLASSISA($feature, 'Perl::Dist::WiX::Fragment')) {
        croak 'Not adding valid feature';
    }
    
    push @{$self->features}, $feature;
    
    return $self;
}

sub add_components {
    my ($self, @componentids) = @_;
    
    push @{$self->componentrefs}, @componentids;
    
    return $self;
}

sub search {
    my ($self, $id_to_find) = @_;

    unless (_STRING($id_to_find)) {
        croak 'Missing or invalid id to find';
    }

    my $id = $self->id;

    # Success!
    if ($id_to_find eq $self->id) {
        return $self;
    }
    
    # Check each of our branches.
    my $count = scalar @{$self->features};
    my $answer;
    foreach my $i (0 .. $count - 1) {
        $answer = $self->features->[$i]->search($id_to_find);
        if (defined $answer) {
            return $answer;
        }
    }
    
    # If we get here, we did not find a feature.
    return undef; 
}

########################################
# as_string
# Parameters:
#   None.
# Returns:
#   String representation of the <Feature> tag represented
#   by this object and the <Feature> and <ComponentRef> tags 
#   contained in this object.

sub as_string {
    my $self = shift;

    my $f_count = scalar @{$self->features};
    my $c_count = scalar @{$self->componentrefs};
    
    my ($string, $s);
    
    $string = q{<Feature Id='}  . $self->id
        . q{' Title='}          . $self->title
        . q{' Description='}    . $self->description
        . q{' Level='}          . $self->level
    ;

    my %hash = (
        advertise => $self->advertise,
        absent    => $self->absent,
        directory => $self->directory,
        display   => $self->display,
        idefault  => $self->idefault,
        default   => $self->default,
    );
    
    foreach my $key (keys %hash) {
        if (not defined $hash{$key}) {
            print "$key in feature $self->{id} is undefined.\n";
        }
    }
    
    if ($self->{default_settings} != 6) {
        $string .= 
              q{' AllowAdvertise='} . $self->advertise
            . q{' Absent='}         . $self->absent
            . q{' ConfigurableDirectory='}
                                    . $self->directory
            . q{' Display='}        . $self->display
            . q{' InstallDefault='} . $self->idefault
            . q{' TypicalDefault='} . $self->default
        ;
    }

# TODO: Allow condition subtags.
    
    if (($c_count == 0) and ($f_count == 0)) {
        $string .= qq{' />\n};
    } else {
        $string .= qq{'>\n};
        
        foreach my $i (0 .. $f_count - 1) {
            $s  .= $self->features->[$i]->as_string;
        }
        if (defined $s) {
            $string .= $self->indent(2, $s);
        }
        $string .= $self->_componentrefs_as_string;
        $string .= qq{\n};
        
        $string .= qq{</Feature>\n};
    }
        
    return $string;
}

sub _componentrefs_as_string {
    my $self = shift;

    my ($string, $ref);
    my $c_count = scalar @{$self->componentrefs};

    if ($c_count == 0) { 
        return q{};
    }
    
    foreach my $i (0 .. $c_count - 1) {
        $ref     = $self->componentrefs->[$i];
        $string .= qq{<ComponentRef Id='C_$ref' />\n};
    }
    
    return $self->indent(2, $string);
}

1;