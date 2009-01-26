package Perl::Dist::WiX::Directory;

#####################################################################
# Perl::Dist::WiX::Files::Directory - Class for a <Directory> tag.
#
# Copyright 2009 Curtis Jewell
#
# License is the same as perl. See Wix.pm for details.

use 5.006;
use strict;
use warnings;
use Carp                              qw{ croak confess                  };
use Params::Util                      qw{ _IDENTIFIER _STRING _NONNEGINT };
use Data::UUID                        qw{ NameSpace_DNS                  };
use File::Spec                        qw{};
use Perl::Dist::WiX::Base::Component  qw{};
use Perl::Dist::WiX::Base::Entry      qw{};
use Perl::Dist::WiX::Files::Component qw{};
use Perl::Dist::WiX::Misc             qw{};

use vars qw{$VERSION @ISA};
BEGIN {
    $VERSION = '0.11_06';
    @ISA = qw (Perl::Dist::WiX::Base::Component
               Perl::Dist::WiX::Base::Entry
               Perl::Dist::WiX::Misc
              );
}

#####################################################################
# Accessors:
#   name, path, special: See constructor.
#   files: Returns an arrayref of the Files::Component objects 
#     contained in this object.
#   directories: Returns an arrayref of the other Direcotry objects 
#     contained in this object.

use Object::Tiny qw{
    name
    path
    special
    files
    directories
};

#####################################################################
# Constructor for Directory
#
# Parameters: [pairs]
#   name: The name of the directory to create.
#   path: The path to and including the directory on the local filesystem.
#   special: [integer] defaults to 0, 1 = , 2= 

sub new {
    my $self = shift->Perl::Dist::WiX::Base::Component::new(@_);

    # Check parameters.
    if (not defined _NONNEGINT($self->special)) {
        $self->{special} = 0;
    }
    if (($self->special == 0) && (not _STRING($self->path))) {
        croak 'Missing or invalid path';
    }
    if ((not defined _STRING($self->guid)) && (not defined _STRING($self->id))) {
        $self->create_guid_from_path;
        $self->{id} = $self->{guid};
        $self->{id} =~ s{-}{_}g;
    }

    # Initialize arrayrefs.
    $self->{directories} = [];
    $self->{files}       = [];
    
    return $self;
}

#####################################################################
# Main Methods

########################################
# search($path_to_find, $trace, $quick)
# Parameters:
#   $filename: Filename being searched for
#   $quick: 
# Returns: [Directory object]
#   Directory object if this is the object for this directory OR
#   ( if a object contained in this object is AND $quick is not defined and true. )

sub search {
    my ($self, $path_to_find, $trace, $quick) = @_;

    my $path = $self->path;

    if (not defined $trace) { $trace = 0; }
    if (not defined $quick) { $quick = 0; }
    
    if ($trace) {
        print '[Directory ' . __LINE__ . "] Looking for $path_to_find\n";
        print '[Directory ' . __LINE__ . "]   in: $path.\n";
        print '[Directory ' . __LINE__ . "]   quick: $quick.\n";
    }
    
    # If we're at the correct path, exit with success!
    if ((defined $path) && ($path_to_find eq $path)) {
        if ($trace) {
            print '[Directory ' . __LINE__ . "] Found $path.\n";
        }
        return $self;
    }
    
    # Quick exit if required.
    if ((defined $quick) and $quick) {
        return undef;
    }
    
    # Do we want to continue searching down this direction?
    my $subset = "$path_to_find\\" =~ m/\A\Q$path\E\\/;
    if ($trace && !$subset) {
        print '[Directory ' . __LINE__ . "] Not a subset\n";
        print '[Directory ' . __LINE__ . "]   in: $path.\n";
        print '[Directory ' . __LINE__ . "]   To find: $path_to_find.\n";
    }
    
    return undef if not $subset;
    
    # Check each of our branches.
    my $count = scalar @{$self->{directories}};
    my $answer;
    if ($trace) {
        print '[Directory ' . __LINE__ . "] Number of directories to search: $count\n";
    }
    foreach my $i (0 .. $count - 1) {
        if ($trace ) {
            print '[Directory ' . __LINE__ . "] Searching directory #$i\n";
        }
        $answer = $self->{directories}->[$i]->search($path_to_find, $trace);
        if (defined $answer) {
            return $answer;
        }
    }
    
    # If we get here, we did not find a lower directory.
    return $self; 
}

########################################
# search_file($filename)
# Parameters:
#   $filename: File being searched for
# Returns: [arrayref]
#   [0] WiX::Files::DirectoryRef or WiX::Directory object representing
#       the path containing the file being searched for.
#   [1] The index of that file within the object returned in [0].
#   undef if unsuccessful.

sub search_file {
    my ($self, $filename) = @_;

    my $path = $self->path;
    
    # Do we want to continue searching down this direction?
    my $subset = $filename =~ m/\A\Q$path\E/;
    return undef if not $subset;

    # Check each of our branches.
    my $count = scalar @{$self->{files}};
    my $answer;
    foreach my $i (0 .. $count - 1) {
        next if (not defined $self->{files}->[$i]);
        $answer = $self->{files}->[$i]->is_file($filename);
        if ($answer) {
            return [$self, $i];
        }
    }

    $count = scalar @{$self->{directories}};
    $answer = undef;
    foreach my $i (0 .. $count - 1) {
        $answer = $self->{directories}->[$i]->search_file($filename);
        if (defined $answer) {
            return $answer;
        }
    }

    return undef;
}

########################################
# delete_filenum($i)
# Parameters:
#   $i: Index of file to delete
# Returns:
#   Object being operated on. (chainable)

sub delete_filenum {
    my ($self, $i) = @_;
    
    $self->{files}->[$i] = undef;
    
    return $self;
}

########################################
# add_directories_id(($id, $name)...)
# Parameters: [repeatable in pairs]
#   $id:   ID of directory object to create.
#   $name: Name of directory to create object for.
# Returns:
#   Object being operated on. (chainable)

sub add_directories_id {
    my ($self, @params) = @_;
    
    # We need id, name pairs passed in. 
    if ($#params % 2 != 1) {     # The test is weird, but $#params is one less than the actual count.
        croak ('Odd number of parameters to add_directories_id');
    }
    
    # Add each individual id and name.
    my ($id, $name);
    while ($#params > 0) {
        $id   = shift @params;
        $name = shift @params;
        if ($name =~ m{\\}) {
            $self->add_directory({id => $id, path => $name});
        } else {
            $self->add_directory({id => $id, path => $self->path . '\\' . $name, name => $name});
        }
    }
    
    return $self;
}

########################################
# add_directories_init(@dirs)
# Parameters: 
#   $sitename:  Name of site to download installer from.
#   @dirs: List of directories to create object for.
# Returns:
#   Object being operated on. (chainable)

sub add_directories_init {
    my ($self, @params) = @_;
    
    my $name;
    while ($#params >= 0) {
        $name = shift @params;
        next if not defined $name;
        if (substr($name, -1) eq '\\') {
            $name = substr($name, 0, -1);
        }
        $self->add_directory({
            path => $self->path . '\\' . $name
        });
    }
    
    return $self;
}

########################################
# add_directory_path($path)
# Parameters: 
#   @path: Path of directories to create object(s) for.
# Returns:
#   Directory object created.

sub add_directory_path {
    my ($self, $path) = @_;

    if (substr($path, -1) eq '\\') {
        $path = substr($path, 0, -1);
    }
    
    if (! $self->path =~ m{\A\Q$path\E}) {
        croak q{Can't add the directories required};
    }

    # Get list of directories to add.   
    my $path_to_remove = $self->path;
    $path =~ s{\A\Q$path_to_remove\E\\}{};
    my @dirs = File::Spec->splitdir($path);
    
    # Get rid of empty entries at the beginning.
    while ($dirs[-1] eq q{}) {
        pop @dirs;
    }
    
    my $directory_obj = $self;
    my $path_create = $self->path;
    my $name_create;
    while ($#dirs != -1) {
        $name_create = shift @dirs;
        $path_create = File::Spec->catdir($path_create, $name_create);
        
        $directory_obj = $directory_obj->add_directory({
            sitename => $self->sitename, 
            name => $name_create,
            path => $path_create
        });
    }
    
    return $directory_obj;    
}

########################################
# add_directory($params_ref)
# Parameters: [hashref in $params_ref]
#   see new.
# Returns:
#   Directory object created.

sub add_directory {
    my ($self, $params_ref) = @_;
    
    # This way we don't need to pass in the sitename.
    $params_ref->{sitename} = $self->sitename;
    
    # If we have a name or a special code, we create it under here.
    if ((defined $params_ref->{name}) || (defined $params_ref->{special})) {
        my $i = scalar @{$self->{directories}};
        $self->{directories}->[$i] = Perl::Dist::WiX::Directory->new(%{$params_ref});
        return $self->{directories}->[$i];
    } else {
        my $path = $params_ref->{path};
        
        # Find the directory object where we want to create this directory.
        my ($volume, $directories, undef) = File::Spec->splitpath( $path, 1 );
        my @dirs = File::Spec->splitdir($directories);
        my $name = pop @dirs; # to eliminate the last directory.
        $directories = File::Spec->catdir(@dirs);
        my $directory = $self->search(File::Spec->catpath($volume, $directories, q{}));
        if (not defined $directory) {
            confess q{Can't create intermediate directories.};
        }
        
        # Add the directory there.
        $params_ref->{name} = $name;
        $directory->add_directory($params_ref);
        return $directory;
    }
}

########################################
# is_child_of($directory_obj)
# Parameters:
#   $directory_obj [WiX::Directory object]: 
#     Directory object to compare against.
# Returns:
#   0 if a 'special' or we are not a child 
#     of the directory passed in.
#   1 otherwise.

sub is_child_of {
    my ($self, $directory_obj) = @_;
    
    my $path = $directory_obj->path;
    if (not defined $path) {
        return 0;
    }
    return ($self->path =~ m{\A$path})
}

########################################
# add_file(...)
# Parameters: [pairs]
#   See Files::Component->new. 
# Returns:
#   Files::Component object created.

sub add_file {
    my ($self, @params) = @_;

    my $i = scalar @{$self->{files}};
    $self->{files}->[$i] = Perl::Dist::WiX::Files::Component->new(@params);
    return $self->{files}->[$i];
}

########################################
# create_guid_from_path
# Parameters: 
#   None. 
# Returns:
#   Object being operated on. (chainable)
# Action:
#   Creates a GUID and sets $self->{guid} to it.

sub create_guid_from_path {
    my $self = shift;

    unless ( _STRING($self->sitename) ) {
        croak("Missing or invalid sitename param - cannot generate GUID without one");
    }
    unless ( _STRING($self->path) ) {
        croak("Missing or invalid id param - cannot generate GUID without one");
    }
    my $guidgen = Data::UUID->new();
    # Make our own namespace...
    my $uuid = $guidgen->create_from_name(Data::UUID::NameSpace_DNS, $self->sitename);
    #... then use it to create a GUID out of the path.
    $self->{guid} = uc $guidgen->create_from_name_str($uuid, $self->path);
    
    return $self;
}

########################################
# get_component_array
# Parameters:
#   None
# Returns:
#   Array of Ids attached to the contained directory and file objects.

sub get_component_array {
    my $self = shift;
    
    my $count = scalar @{$self->{directories}};
    my @answer;
    my $id;

    # Get the array for each descendant.
    foreach my $i (0 .. $count - 1) {
        push @answer, $self->{directories}->[$i]->get_component_array;
    }

    $count = scalar @{$self->{files}};
    foreach my $i (0 .. $count - 1) {
        next if (not defined $self->{files}->[$i]);
        push @answer, $self->{files}->[$i]->id;
    }

    return @answer;
}

########################################
# as_string
# Parameters:
#   $tree: 1 if printing directory tree. [i.e. DO print empty directories.]
# Returns:
#   String representation of the <Directory> tag represented
#   by this object, and the <Directory> and <File> tags
#   contained in it.

sub as_string {
    my ($self, $tree) = @_;
    my ($count, $answer); 
    my $string = q{};
    if (not defined $tree) { $tree = 0; }
    
    # Get string for each subdirectory.
    $count = scalar @{$self->{directories}};
    foreach my $i (0 .. $count - 1) {
        $string .= $self->{directories}->[$i]->as_string;
    }
    
    # Get string for each file this directory contains.
    $count = scalar @{$self->{files}};
    foreach my $i (0 .. $count - 1) {
        next if (not defined $self->{files}->[$i]);
        $string .= $self->{files}->[$i]->as_string;
    }

    # Short circuit...
    if (($string eq q{}) and ($self->special == 0) and (not $tree)) { return q{}; }
    
    # Now make our own string, and put what we've already got within it. 
    if (defined $string) {
        if ($self->special == 2) {
            $answer = "<Directory Id='D_$self->{id}'>\n";
            $answer .= $self->indent(2, $string);
            $answer .= "\n</Directory>\n";
        } elsif ($self->id eq 'TARGETDIR') {
            $answer = "<Directory Id='$self->{id}' Name='$self->{name}'>\n";
            $answer .= $self->indent(2, $string);
            $answer .= "\n</Directory>\n";
        } else {
            $answer = "<Directory Id='D_$self->{id}' Name='$self->{name}'>\n";
            $answer .= $self->indent(2, $string);
            $answer .= "\n</Directory>\n";
        }
    } else {
        if ($self->special == 2) {
            $answer = "<Directory Id='D_$self->{id}' />\n";
        } else {
            $answer = "<Directory Id='D_$self->{id}' Name='$self->{name}' />\n";
        }
    }

    return $answer;
}

1;