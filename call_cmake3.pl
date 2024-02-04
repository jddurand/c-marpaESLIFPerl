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

$ENV{PKG_CONFIG_PATH} ||= '';
my $inc_dir   = File::Spec->catdir(File::Spec->curdir, 'inc');
my $alienfile = File::Spec->catfile($inc_dir, 'marpaESLIFPerl', 'alienfile');
my $prefix    = File::Spec->catdir($inc_dir, 'local');
my $stage     = File::Spec->catdir($inc_dir, 'stage');

#
# We want to control where things are installed
#
$ENV{DESTDIR} = abs_path(File::Spec->catdir(File::Spec->curdir, 'marpaESLIF_install'));
my $build = Alien::Build->load($alienfile);
$build->load_requires('configure');
$build->set_prefix($prefix);
$build->set_stage($stage);
$build->load_requires($build->install_type);
$build->download;
$build->build;

exit(EXIT_SUCCESS);
