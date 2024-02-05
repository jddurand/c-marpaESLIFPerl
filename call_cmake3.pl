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
# We want to control where things are installed on both Windows and Unix using DESTDIR and prefix
#
$ENV{PKG_CONFIG_PATH} ||= '';
my $inc_dir   = abs_path(File::Spec->catdir(File::Spec->curdir, 'inc'));
my $alienfile = File::Spec->catfile($inc_dir, 'marpaESLIFPerl', 'alienfile');
my $prefix    = File::Spec->catdir($inc_dir, 'local');
my $stage     = File::Spec->catdir($inc_dir, 'stage');

delete $ENV{DESTDIR};
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
