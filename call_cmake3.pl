#!env perl
use Alien::Build;
use Cwd qw/abs_path/;
use Env::Path qw/PATH/;
use File::Basename;
use File::Find;
use File::Spec;
use POSIX qw/EXIT_SUCCESS/;

my $cmake3_exe = shift || die "Usage: $0 cmake3_exe";
#
# Make sure we use /this/ cmake executable
#
PATH->Append(dirname($cmake3_exe));
#
# Collect the tarballs: our CMakeLists.txt will use cmake-helpers
# that has a hook preventing network access
#
find({ wanted => \&wanted, no_chdir => 1 }, 'inc/marpaESLIFPerl/tarballs');

sub wanted {
    my $fullname = File::Spec->canonpath($File::Find::name);
    my $basename = basename($fullname);
    my $absolute = abs_path($fullname);

    if ($basename =~ /^(.+)-src.tar.gz$/) {
        my $envvar = 'CMAKE_HELPERS_DEPEND_' . uc($1) . '_FILE';
        $envvar =~ s/[^a-zA-Z0-9_]/_/g;
        print "Setting environment variable $envvar to $absolute\n";
        $ENV{$envvar} = $absolute;
    }
}
#
# When symlinks are supported, installation will create symlinks for share and module
# libraries. But then ExtUtils::Manifest will die because it uses File::Find that, by
# default, dislike very much the presence of symlinks, c.f.
# https://github.com/Perl-Toolchain-Gang/ExtUtils-Manifest/issues/16
#
print "Setting environment variable CMAKE_HELPERS_NAMELINK_SKIP to 1\n";
$ENV{CMAKE_HELPERS_NAMELINK_SKIP} = 1;
#
# The environment variable CMAKE_HELPERS_WIN32_PACKAGING will force our cmake-helpers library
# to install all dependencies in addition to the top-level target
#
print "Setting environment variable CMAKE_HELPERS_WIN32_PACKAGING to 1\n";
$ENV{CMAKE_HELPERS_WIN32_PACKAGING} = 1;
#
# Alien is quite pkgconfig oriented. The following will silence a lot of things.
#
print "Setting environment variable PKG_CONFIG_PATH to empty string if not yet defined\n";
$ENV{PKG_CONFIG_PATH} ||= '';
my $alienfile = 'inc/marpaESLIF/alienfile';
my $prefix = '/usr/local';
my $stage = File::Spec->catdir(abs_path(File::Spec->curdir), 'stage');

print "[Alien::marpaESLIF] Loading $alienfile\n";
my $build = Alien::Build->load($alienfile);
print "[Alien::marpaESLIF] Configuring\n";
$build->load_requires('configure');
print "[Alien::marpaESLIF] Set prefix to $prefix\n";
$build->set_prefix($prefix);
print "[Alien::marpaESLIF] Set stage to $stage\n";
$build->set_stage($stage);
print "[Alien::marpaESLIF] Load install type requirements\n";
$build->load_requires($build->install_type);
print "[Alien::marpaESLIF] Download\n";
$build->download;
print "[Alien::marpaESLIF] Build\n";
$build->build;

exit(EXIT_SUCCESS);
