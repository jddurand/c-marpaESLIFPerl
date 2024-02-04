#!env perl
use Alien::Build;
use POSIX qw/EXIT_SUCCESS/;

print "Checking CMake\n";
$ENV{PKG_CONFIG_PATH} ||= '';
my $inc_dir   = File::Spec->catdir(File::Spec->curdir, 'inc');
my $alienfile = File::Spec->catfile($inc_dir, 'cmake3', 'alienfile');
my $prefix    = File::Spec->catdir($inc_dir, 'local');
my $stage     = File::Spec->catdir($inc_dir, 'stage');

my $build = Alien::Build->load($alienfile);
$build->load_requires('configure');
$build->set_prefix($prefix);
$build->set_stage($stage);
$build->load_requires($build->install_type);
$build->download;
$build->build;

my $cmake;
my $install_type = $build->runtime_prop->{install_type} // '';
if($install_type eq 'system') {
    $cmake = $build->runtime_prop->{command};
} elsif($install_type eq 'share') {
    $cmake = $build->runtime_prop->{command};
    if (! File::Spec->file_name_is_absolute($cmake)) {
        $cmake = File::Spec->catfile($stage, $cmake);
    }
} else {
    die "Unknown install type $install_type";
}

print "$cmake\n";

exit(EXIT_SUCCESS);
