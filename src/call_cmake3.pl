#!env perl
use Alien::Build;
use Env::Path;
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
find({ wanted => \&wanted, no_chdir => 1 }, File::Spec->curdir);

sub wanted {
    my $fullname = File::Spec->canonpath($File::Find::name);
    my $basename = basename($fullname);

    if ($basename =~ /^(.+)-src.tar.gz$/) {
        my $envvar = 'CMAKE_HELPERS_DEPEND_' . uc($1) . '_FILE';
        print "Setting environment variable $envvar to $fullname\n";
        $ENV{$envvar} = $fullname;
    }
}

print "Building marpaESLIF\n";
$ENV{PKG_CONFIG_PATH} ||= '';
my $inc_dir   = File::Spec->catdir(File::Spec->curdir, 'inc');
my $alienfile = File::Spec->catfile($inc_dir, 'marpaESLIF', 'alienfile');
my $prefix    = File::Spec->catdir($inc_dir, 'local');
my $stage     = File::Spec->catdir($inc_dir, 'stage');

my $build = Alien::Build->load($alienfile);
$build->load_requires('configure');
$build->set_prefix($prefix);
$build->set_stage($stage);
$build->load_requires($build->install_type);
$build->download;
$build->build;

exit(EXIT_SUCCESS);
