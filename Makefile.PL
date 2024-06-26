# This Makefile.PL for MarpaX-ESLIF was generated by
# Dist::Zilla::Plugin::MakeMaker::Awesome 0.49.
# Don't edit it but the dist.ini and plugins used to construct it.

use strict;
use warnings;

use 5.010;
use ExtUtils::MakeMaker;

use Config;
use ExtUtils::Constant qw /constant_types C_constant XS_constant autoload/;
use File::Find;
use File::Spec;
use IO::Handle;
use Probe::Perl;
use Try::Tiny;

$| = 1;

#
# Generate constant types
#
my $fh;
open($fh, '>', 'c-constant-types.inc') || die "Cannot open c-constant-types.inc, $!";
print $fh constant_types();
close($fh) || warn "Failed to close c-constant-types.inc, $!";
my %types = ( 'event' => { pkg => 'MarpaX::ESLIF::Event::Type', constants => [qw/MARPAESLIF_EVENTTYPE_NONE MARPAESLIF_EVENTTYPE_COMPLETED MARPAESLIF_EVENTTYPE_NULLED MARPAESLIF_EVENTTYPE_PREDICTED MARPAESLIF_EVENTTYPE_BEFORE MARPAESLIF_EVENTTYPE_AFTER MARPAESLIF_EVENTTYPE_EXHAUSTED MARPAESLIF_EVENTTYPE_DISCARD/] }, 'value' => { pkg => 'MarpaX::ESLIF::Value::Type', constants => [qw/MARPAESLIF_VALUE_TYPE_UNDEF MARPAESLIF_VALUE_TYPE_CHAR MARPAESLIF_VALUE_TYPE_SHORT MARPAESLIF_VALUE_TYPE_INT MARPAESLIF_VALUE_TYPE_LONG MARPAESLIF_VALUE_TYPE_FLOAT MARPAESLIF_VALUE_TYPE_DOUBLE MARPAESLIF_VALUE_TYPE_PTR MARPAESLIF_VALUE_TYPE_ARRAY MARPAESLIF_VALUE_TYPE_BOOL MARPAESLIF_VALUE_TYPE_STRING MARPAESLIF_VALUE_TYPE_ROW MARPAESLIF_VALUE_TYPE_TABLE MARPAESLIF_VALUE_TYPE_LONG_DOUBLE/] }, 'loggerLevel' => { pkg => 'MarpaX::ESLIF::Logger::Level', constants => [qw/GENERICLOGGER_LOGLEVEL_TRACE GENERICLOGGER_LOGLEVEL_DEBUG GENERICLOGGER_LOGLEVEL_INFO GENERICLOGGER_LOGLEVEL_NOTICE GENERICLOGGER_LOGLEVEL_WARNING GENERICLOGGER_LOGLEVEL_ERROR GENERICLOGGER_LOGLEVEL_CRITICAL GENERICLOGGER_LOGLEVEL_ALERT GENERICLOGGER_LOGLEVEL_EMERGENCY/] }, 'rulePropertyBitSet' => { pkg => 'MarpaX::ESLIF::Rule::PropertyBitSet', constants => [qw/MARPAESLIF_RULE_IS_ACCESSIBLE MARPAESLIF_RULE_IS_NULLABLE MARPAESLIF_RULE_IS_NULLING MARPAESLIF_RULE_IS_LOOP MARPAESLIF_RULE_IS_PRODUCTIVE/] }, 'symbolPropertyBitSet' => { pkg => 'MarpaX::ESLIF::Symbol::PropertyBitSet', constants => [qw/MARPAESLIF_SYMBOL_IS_ACCESSIBLE MARPAESLIF_SYMBOL_IS_NULLABLE MARPAESLIF_SYMBOL_IS_NULLING MARPAESLIF_SYMBOL_IS_PRODUCTIVE MARPAESLIF_SYMBOL_IS_START MARPAESLIF_SYMBOL_IS_TERMINAL/] }, 'symbolEventBitSet' => { pkg => 'MarpaX::ESLIF::Symbol::EventBitSet', constants => [qw/MARPAESLIF_SYMBOL_EVENT_COMPLETION MARPAESLIF_SYMBOL_EVENT_NULLED MARPAESLIF_SYMBOL_EVENT_PREDICTION/] }, 'symbol' => { pkg => 'MarpaX::ESLIF::Symbol::Type', constants => [qw/MARPAESLIF_SYMBOLTYPE_TERMINAL MARPAESLIF_SYMBOLTYPE_META/] });

foreach (sort keys %types) {
  my $pkg = $types{$_}->{pkg};
  print "Generating $pkg C $_ types\n";
  open($fh, '>', "c-$_-types.inc") || die "Cannot open c-$_-types.inc, $!";
  print $fh C_constant($pkg, "${_}_constant", undef, undef, undef, undef, @{$types{$_}->{constants}});
  close($fh) || warn "Failed to close c-$_-types.inc, $!";
  #
  # This is a bit vicious but in our case these are NOT macros but ENUMS !
  # We know what were are doing and replace all #ifdef MARPAESLIF_xxx and #ifdef GENERICLOGGER_xxx by #if 1
  #
  print "Tweaking $pkg C $_ types to work with enums\n";
  open($fh, '<', "c-$_-types.inc") || die "Failed to open c-$_-types.inc, $!";
  my $content = do { local $/; <$fh> };
  close($fh) || warn "Failed to close c-$_-types.inc, $!";
  $content =~ s/^#\s*ifdef\s+(?:MARPAESLIF_|GENERICLOGGER_).*?$/#if 1/smg;
  open($fh, '>', "c-$_-types.inc") || die "Failed to open c-$_-types.inc, $!";
  print $fh $content;
  close($fh) || warn "Failed to close c-$_-types.inc, $!";

  print "Generating $pkg XS $_ types\n";
  open($fh, '>', "xs-$_-types.inc") || die "Cannot open xs-$_-types.inc, $!";
  print $fh XS_constant($pkg, 'IV', 'constant', "${_}_constant");
  close($fh) || warn "Failed to close xs-$_-types.inc, $!";

  print "Generating $pkg AUTOLOAD\n";
  my $autoload = replace_autoload_tabs(autoload($pkg, '5.10', 1));

  my @pkg = split(/::/, $pkg);
  $pkg[-1] .= '.pm';
  my $pkgfile = File::Spec->catfile('lib', @pkg);
  print "Pushing AUTOLOAD into $pkgfile\n";
  open($fh, '<', $pkgfile) || die "Failed to open $pkgfile, $!";
  $content = do { local $/; <$fh> };
  close($fh) || warn "Failed to close $pkgfile, $!";
  $content =~ s/^#\s*AUTOLOAD.*?$/\n$autoload\n/sm;
  open($fh, '>', $pkgfile) || die "Failed to open $pkgfile, $!";
  print $fh $content;
  close($fh) || warn "Failed to close $pkgfile, $!";
}

#
# Build marpaESLIF
#
my $perl_exe = Probe::Perl->find_perl_interpreter();
my @args = ($perl_exe, File::Spec->catfile('etc', 'compile_marpaESLIF.pl'));
system(@args) == 0 || die "$!";
#
# Recuperate eventual OTHERLDFLAGS
#
my $otherldflags = 'OTHERLDFLAGS.txt';
my @OTHERLDFLAGS = ();
open(my $otherldflags_fd, '<', $otherldflags) || die "Cannot open $otherldflags, $!";
while (defined(my $line = <$otherldflags_fd>)) {
    $line =~ s/[\r\n]+//g;
    push(@OTHERLDFLAGS, $line);
}
close($otherldflags_fd) || warn "Cannot close $otherldflags, $!";
print "ESLIF compilation says \@OTHERLDFLAGS = @OTHERLDFLAGS\n";
#
# Recuperate eventual CFLAGS
#
my $cflags = 'CFLAGS.txt';
my $CFLAGS = '';
open(my $cflags_fd, '<', $cflags) || die "Cannot open $cflags, $!";
do { local $/; $CFLAGS = <$cflags_fd> };
$CFLAGS =~ s/[\r\n]+/ /g;
close($cflags_fd) || warn "Cannot close $cflags, $!";
print "ESLIF compilation says \$CFLAGS = $CFLAGS\n";

my @ldfrom = ();
find({ wanted => sub { push(@ldfrom, $_) if (-f $_) }, no_chdir => 1 }, 'objs');

sub replace_autoload_tabs {
    my ($autoload) = @_;
    $autoload =~ s/^\t/        /mg; # For the cases we know for pretty indentation
    $autoload =~ s/\t/    /g; # For all the other cases
    return $autoload;
}

my %WriteMakefileArgs = (
  "ABSTRACT" => "ESLIF is Extended ScanLess InterFace",
  "AUTHOR" => "Jean-Damien Durand <jeandamiendurand\@free.fr>",
  "CONFIGURE_REQUIRES" => {
    "Archive::Tar" => 0,
    "Carp" => 0,
    "Config" => 0,
    "Config::AutoConf" => 0,
    "Cwd" => 0,
    "ExtUtils::CBuilder" => "0.280224",
    "ExtUtils::Constant" => 0,
    "ExtUtils::MakeMaker" => 0,
    "File::Basename" => 0,
    "File::Copy" => 0,
    "File::Find" => 0,
    "File::Path" => 0,
    "File::Spec" => 0,
    "File::Temp" => 0,
    "File::Which" => 0,
    "File::chdir" => 0,
    "IO::Handle" => 0,
    "POSIX" => 0,
    "Perl::OSType" => 0,
    "Probe::Perl" => 0,
    "Try::Tiny" => 0
  },
  "DISTNAME" => "MarpaX-ESLIF",
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.010",
  "NAME" => "MarpaX::ESLIF",
  "PREREQ_PM" => {
    "Carp" => 0,
    "Devel::GlobalDestruction" => 0,
    "Encode" => 0,
    "JSON::MaybeXS" => "1.004000",
    "Math::BigFloat" => 0,
    "Math::BigInt" => 0,
    "XSLoader" => 0,
    "constant" => 0,
    "namespace::clean" => 0,
    "overload" => 0,
    "parent" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "Data::Dumper" => 0,
    "ExtUtils::MakeMaker" => 0,
    "File::Spec" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "Log::Any" => 0,
    "Log::Any::Adapter" => 0,
    "POSIX" => 0,
    "Safe::Isa" => 0,
    "Test::Deep" => 0,
    "Test::Deep::NoTest" => 0,
    "Test::More" => 0,
    "Test::More::UTF8" => 0,
    "Try::Tiny" => 0,
    "diagnostics" => 0,
    "open" => 0,
    "threads" => 0,
    "threads::shared" => 0,
    "utf8" => 0
  },
  "VERSION" => "6.0.35.1",
  "test" => {
    "TESTS" => "t/*.t"
  }
);

%WriteMakefileArgs = (
    %WriteMakefileArgs,
    OBJECT => 'ESLIF$(OBJ_EXT)',
    INC => join(' ', "-I" . File::Spec->catdir('extract', 'marpaESLIF', 'include'), "-I" . File::Spec->catdir('extract', 'genericLogger', 'include'), "-I" . File::Spec->catdir('extract', 'genericStack', 'include')),
    LDFROM => join(' ', '$(OBJECT)', sort @ldfrom),
    dynamic_lib => { OTHERLDFLAGS => join(' ', @OTHERLDFLAGS) },
    CCFLAGS => "$Config::Config{ccflags} $CFLAGS",
);

my %FallbackPrereqs = (
  "Carp" => 0,
  "Data::Dumper" => 0,
  "Devel::GlobalDestruction" => 0,
  "Encode" => 0,
  "ExtUtils::MakeMaker" => 0,
  "File::Spec" => 0,
  "IO::Handle" => 0,
  "IPC::Open3" => 0,
  "JSON::MaybeXS" => "1.004000",
  "Log::Any" => 0,
  "Log::Any::Adapter" => 0,
  "Math::BigFloat" => 0,
  "Math::BigInt" => 0,
  "POSIX" => 0,
  "Safe::Isa" => 0,
  "Test::Deep" => 0,
  "Test::Deep::NoTest" => 0,
  "Test::More" => 0,
  "Test::More::UTF8" => 0,
  "Try::Tiny" => 0,
  "XSLoader" => 0,
  "constant" => 0,
  "diagnostics" => 0,
  "namespace::clean" => 0,
  "open" => 0,
  "overload" => 0,
  "parent" => 0,
  "strict" => 0,
  "threads" => 0,
  "threads::shared" => 0,
  "utf8" => 0,
  "warnings" => 0
);

# inserted by Dist::Zilla::Plugin::DynamicPrereqs 0.040
use Config;
if (! $Config{usethreads}) {
  foreach (qw/PREREQ_PM BUILD_REQUIRES TEST_REQUIRES/) {
    delete($WriteMakefileArgs{$_}{Thread}) if (exists($WriteMakefileArgs{$_}));
    delete($FallbackPrereqs{$_}{Thread})   if (exists($FallbackPrereqs{$_}));
  }
}

unless ( eval { ExtUtils::MakeMaker->VERSION('6.63_03') } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);
