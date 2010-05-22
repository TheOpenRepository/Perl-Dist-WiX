#!/usr/bin/perl

use strict;
use Perl::Dist::WiX::DirectoryTree2;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use Test::More;
BEGIN {
	if ( $^O eq 'MSWin32' ) {
		plan tests => 14;
	} else {
		plan skip_all => 'Not on Win32';
	}
}

# Test 1.

my $tree = Perl::Dist::WiX::DirectoryTree2->new(
    app_dir => 'C:\\test', 
    app_name => 'Test Perl', 
#    sitename => 'www.test.site.invalid',
#    trace    => 0,
);
ok($tree, '->new returns true');

# Test 2.
              
my $string = $tree->as_string;

is($string, q{    <Directory Id='TARGETDIR' Name='SourceDir' />}, 'Stringifies correctly when uninitialized');    

my $string_test = '    <Directory Id=\'TARGETDIR\' Name=\'SourceDir\'>
      <Directory Id=\'INSTALLDIR\'>
        <Directory Id=\'D_Perl\' Name=\'perl\'>
          <Directory Id=\'D_PerlSite\' Name=\'site\'>
            <Directory Id=\'D_PerlSiteBin\' Name=\'bin\' />
            <Directory Id=\'D_PerlSiteLib\' Name=\'lib\'>
              <Directory Id=\'D_NTU5MTE4NT\' Name=\'auto\' />
            </Directory>
          </Directory>
          <Directory Id=\'D_MTA5MzA3NDUxNw\' Name=\'bin\' />
          <Directory Id=\'D_MTEwODI1NDU4MA\' Name=\'lib\'>
            <Directory Id=\'D_NDI3MzczODQzMQ\' Name=\'auto\' />
          </Directory>
          <Directory Id=\'D_MjE5ODA2NjYzOA\' Name=\'vendor\'>
            <Directory Id=\'D_ODU0NTcwNz\' Name=\'lib\'>
              <Directory Id=\'D_MTY3MDgzMjkxNg\' Name=\'auto\'>
                <Directory Id=\'D_MjE3NDcxODY0Nw\' Name=\'share\'>
                  <Directory Id=\'D_MjQ0Njg4NTAwNQ\' Name=\'dist\' />
                  <Directory Id=\'D_Mjk5NjgyNzY1Mg\' Name=\'module\' />
                </Directory>
              </Directory>
            </Directory>
          </Directory>
        </Directory>
        <Directory Id=\'D_Toolchain\' Name=\'c\'>
          <Directory Id=\'D_Mjg5NjQ2NzU5OA\' Name=\'bin\' />
          <Directory Id=\'D_OTQ0MTI1ND\' Name=\'include\' />
          <Directory Id=\'D_Mjk0NTI1MTI0Nw\' Name=\'lib\' />
          <Directory Id=\'D_MzQ4NDYzNDEwOQ\' Name=\'libexec\' />
          <Directory Id=\'D_NDI2MDE0OTU4Mg\' Name=\'mingw32\' />
          <Directory Id=\'D_ODU1OTExNz\' Name=\'share\' />
        </Directory>
        <Directory Id=\'D_License\' Name=\'licenses\' />
        <Directory Id=\'D_Cpan\' Name=\'cpan\'>
          <Directory Id=\'D_CpanSources\' Name=\'sources\' />
        </Directory>
        <Directory Id=\'D_Win32\' Name=\'win32\' />
      </Directory>
      <Directory Id=\'ProgramMenuFolder\'>
        <Directory Id=\'D_App_Menu\' Name=\'Test Perl\'>
          <Directory Id=\'D_App_Menu_Tools\' Name=\'Tools\' />
          <Directory Id=\'D_App_Menu_Websites\' Name=\'Related Websites\' />
        </Directory>
      </Directory>
    </Directory>';
# Test 3

$tree->initialize_tree('589'); $string = $tree->as_string;

# This is here for data collection when the tree contents change.
# require Data::Dumper;
# my $d = Data::Dumper->new([$string], [qw(string)]);
# print $d->Indent(1)->Dump();
# exit;

is($string, $string_test, 'Stringifies correctly once initialized');    

# Tests 4-7 are successful finds.

my @tests_1 = (
    [
        {
            path_to_find => 'C:\\test\\perl\\site\\bin',
            exact => 1,
            descend => 1,
        },
        'C:\\test\\perl\\site\\bin',
        'descend=1 exact=1'
    ],
    [
        {
            path_to_find => 'C:\\test\\win32',
            exact => 1,
            descend => 0,
        },
        'C:\\test\\win32',
        'descend=0 exact=1'
    ],
    [
        {
            path_to_find => 'C:\\test\\perl\\site\\bin\\x',
            exact => 0,
            descend => 1,
        },
        'C:\\test\\perl\\site\\bin',
        'descend=1 exact=0'
    ],
    [
        {
            path_to_find => 'C:\\test\\win32\\x',
            exact => 0,
            descend => 0,
        },
        'C:\\test\\win32',
        'descend=0 exact=0'
    ],
);

foreach my $test (@tests_1)
{
    my $dir = $tree->search_dir(%{$test->[0]});
    is($dir->get_path, $test->[1], "Successful search, $test->[2]");
}

my @tests_2 = (
    [
        {
            path_to_find => 'C:\\xtest\\perl\\site\\bin\\x',
            exact => 1,
            descend => 1,
        },
        'descend=1 exact=1'
    ],
    [
        {
            path_to_find => 'C:\\test\\win32\\x',
            exact => 1,
            descend => 0,
        },
        'descend=0 exact=1'
    ],
    [
        {
            path_to_find => 'C:\\xtest\\perl\\site\\bin\\x',
            exact => 0,
            descend => 1,
        },
        'descend=1 exact=0'
    ],
    [
        {
            path_to_find => 'C:\\xtest\\win33',
            exact => 0,
            descend => 0,
        },
        'descend=0 exact=0'
    ],
);

foreach my $test (@tests_2)
{
    my $dir = $tree->search_dir(%{$test->[0]});
    ok((not defined $dir), "Unsuccessful search, $test->[1]");
}

my $dirobj = $tree->get_directory_object('D_Win32');
isa_ok( $dirobj, 'Perl::Dist::WiX::Tag::Directory', 'A directory object retrieved from the tree');

$dirobj = $tree->get_directory_object('Win32');
is($dirobj, undef, 'Directory object with invalid id is not defined.');

is($tree, Perl::Dist::WiX::DirectoryTree2->instance(), 'Directory tree is a singleton.');