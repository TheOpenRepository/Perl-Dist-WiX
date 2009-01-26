package Perl::Dist::WiX::Filelist;

####################################################################
# Perl::Dist::WiX::Filelist - This package provides for handling 
# files lists for Perl::Dist::WiX.
#
# Copyright 2009 Curtis Jewell
#
# License is the same as perl. See Wix.pm for details.

use 5.008;
use strict;
use warnings;
use Carp                   qw( verbose croak confess );
use Params::Util           qw();
use IO::Dir                qw();
use IO::File               qw();
use File::Spec::Functions  qw( catdir catfile );
use List::MoreUtils        qw( indexes );

use vars qw($VERSION);
BEGIN {
	$VERSION = '0.11_06';
}

#####################################################################
# Accessors:
#   files: Returns the list of files as an arrayref. 

use Object::Tiny qw {
    files
};

#####################################################################
# Constructors for Filelist
#

########################################
# new
# Parameters:
#   None.

sub new {
    my $self = shift->SUPER::new();

    $self->{files} = [];
    
    return $self;
}

########################################
# clone
# Parameters:
#   $source: [Filelist object] Object to copy.

sub clone {
    my $self = shift->SUPER::new();
    my $source = shift;
    
    $self->{files} = [];
    push @{$self->{files}}, @{$source->{files}};
    
    return $self;
}

#####################################################################
# Main Methods

########################################
# clear
# Parameters:
#   None.
# Returns:
#   Object being acted upon (chainable) 
# Action:
#   Clears this filelist.

sub clear {
    my $self = shift;
    
    $self->{files} = [];
    
    return $self;
}

########################################
# readdir($dir)
# Parameters:
#   $dir: Directory containing a files and subdirectories to add to this filelist. 
# Returns:
#   Object being acted upon (chainable) 
# Action:
#   Adds the files in $dir to our filelist.

sub readdir {
    my ($self, $dir) = @_;
    
    # Open directory.
    my $dir_object = IO::Dir->new($dir);
    if (!defined $dir_object) {
        croak "Error reading directory $dir: $!";        
    }
    
    my $file = $dir_object->read();
    
    while (defined $file) {
        if (($file ne q{.}) and ($file ne q{..})) {
            my $filespec = catfile($dir, $file);
            if (-d $filespec) {
                $self->readdir($filespec);
            } else {
                push @{$self->files}, $filespec;
            }
        }

        # Next one, please?
        $file = $dir_object->read();
    }

     return $self;
}

########################################
# load_array($packlist)
# Parameters:
#   $packlist: File containing a list of files to add to this filelist. 
# Returns:
#   Object being acted upon (chainable) 
# Action:
#   Adds the files listed in the file in $packlist to our filelist.

sub load_file {
    my ($self, $packlist) = @_; 

    my $fh = IO::File->new($packlist, 'r');
    if (not defined $fh)
    {
        croak "File Error: $!";
    }
    my @files = <$fh>;
    $fh->close;

    @{$self->files} = map { chomp $_; $_ } @files;
    
    return $self;
}

########################################
# load_array(@files)
# Parameters:
#   @files: Files to add to this filelist. 
# Returns:
#   Object being acted upon (chainable) 
# Action:
#   Adds the files listed in @files to our filelist.

sub load_array {
    my ($self, @files) = @_;
    
    foreach my $file (@files) {
        next if -d $file;
        push @{$self->files}, $file;
    }

    return $self;
}

########################################
# add_file($file)
# Parameters:
#   $file: File to add to this filelist. 
# Returns:
#   Object being acted upon (chainable) 
# Action:
#   Adds the file listed in $file to our filelist.

sub add_file {
    my ($self, $file) = @_;
    
    push @{$self->files}, $file;

    return $self;
}

########################################
# subtract($subtrahend)
# Parameters:
#   $subtrahend: [Filelist object] A filelist to remove from this one. 
# Returns:
#   Object being acted upon (chainable) 
# Action:
#   Removes the files listed in $subtrahend from our filelist.

sub subtract {
    my ($self, $subtrahend) = @_;

    my @loc;
    my @files = @{$self->files};
    my @files2;
    my $f;
    
    foreach my $f (@{$subtrahend->files}) {
        @loc = indexes { $_ eq $f } @files;
        if (@loc) {
            delete @files[@loc];
            undef @loc;

            # 'compress' @files;
            undef @files2;
            while ($#files > -1) {
                $f = shift @files;
                push @files2, $f if defined($f);
            }
            @files = @files2; 
        }
    }

    $self->clear->load_array(@files);
    
    return $self;
}

########################################
# add($term)
# Parameters:
#   $term: [Filelist object] A filelist to add to this one. 
# Returns:
#   Object being acted upon (chainable) 
# Action:
#   Adds the files listed in $term to our filelist.

sub add {
    my ($self, $term) = @_;

    push @{$self->files}, @{$term->files};

    return $self;
}

########################################
# move($from, $to)
# Parameters:
#   $from: the file or directory that has been moved on disk. 
#   $to: The location being moved to.
# Returns:
#   Object being acted upon (chainable) 
# Action:
#   Substitutes $to for $from in the filelist.

sub move {
    my ($self, $from, $to) = @_;

    my @loc = indexes { $_ =~ m/\A\Q$from\E\z/ } @{$self->files};
    if (@loc) {
        foreach my $loc (@loc) {
            $self->files->[$loc] = $to;
        }
    }

    return $self;    
}

########################################
# filter(@re_list)
# Parameters:
#   @re_list: Array of strings to use as regular 
#     expressions of filenames to filter out.
#     The strings are quotemeta'd as they are used.
# Returns:
#   Object being acted upon (chainable) 
# Action:
#   Removes files satisfying the filters in @re_list
#   from the object.

sub filter {
    my ($self, @re_list) = @_;

    # Define variables to use.
    my @loc;
    my @files = @{$self->files};
    my @files2;
    my $f;
    
    # Check the filelist against each filter.
    foreach my $re (@re_list) {
        my @loc = indexes { $_ =~ m/\A\Q$re\E/ } @files;
        if (@loc) {
            # Delete files found.
            delete @files[@loc];
            undef @loc;

            # 'compress' @files by removing the deleted files each time a file is removed.
            undef @files2;
            while ($#files > -1) {
                $f = shift @files;
                push @files2, $f if defined($f);
            }
            @files = @files2; 
        }
    }

    # Reload 
    $self->clear->load_array(@files);
    
    return $self;    
}

########################################
# as_string
# Parameters:
#   None.
# Returns:
#   List of filenames in this object joined 
#   by newlines for debugging purposes.

sub as_string {
    my $self = shift;

    return join "\n", @{$self->files};
}

1;