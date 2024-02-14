#!env perl
use strict;
use diagnostics;

my $have_cppguess;
BEGIN {
    use File::Spec;                     # Formally it is not necessary I believe to do it here
    # Make sure we have our 'inc' directory prepended the perl search path
    my $inc_dir = File::Spec->catdir(File::Spec->curdir, 'inc');
    unshift(@INC, $inc_dir);
    #
    # ExtUtils::CppGuess does not install everywhere.
    # This is why we provide it explicitely, we are ok if it fails at run-time
    # by enclosing its usage in try/catch
    #
    $have_cppguess = eval 'use ExtUtils::CppGuess 0.26; 1;';
}

use Config;
use Config::AutoConf;
use Config::AutoConf::INI;
use Cwd qw/abs_path/;
use ExtUtils::CBuilder 0.280224; # 0.280224 is to make sure we have the support of $ENV{CXX};
use File::Basename;
use File::Spec;
use File::Which;
use File::Temp;
use Perl::OSType qw/is_os_type/;
use POSIX qw/EXIT_SUCCESS WIFEXITED WEXITSTATUS/;
use Try::Tiny;

autoflush STDOUT 1;
autoflush STDERR 1;

#
# Our distribution have both C and CPP files, and we want to make sure that modifying
# CFLAGS will not affect cpp files. Since we require a version of ExtUtils::CBuilder
# that support the environment variables, explicitely setting the environment variables
# from default ExtUtils::Cbuilder will ensure cc and cpp settings will become independant
# if we are doing to modify any of them.
# We do that for linker settings as well for coherency although we will NEVER touch them.
# OTHERLDFLAGS will be specific to this makefile.
#
# Take care: with ExtUtils::CBuilder, $ENV{CFLAGS} and $ENV{LDFLAGS} are appended to default perl compile flags, not the others
#
#
my %cbuilder_config = ExtUtils::CBuilder->new()->get_config;
$ENV{CC} = $cbuilder_config{cc} // 'cc';
$ENV{CFLAGS} //= '';
$ENV{CFLAGS} .= ' -DNDEBUG';
$ENV{CXX} = $cbuilder_config{cxx} // $ENV{CC};
$ENV{CXXFLAGS} = $cbuilder_config{cxxflags} // $cbuilder_config{ccflags} // '';
$ENV{LD} = $cbuilder_config{ld} // $ENV{CC};
$ENV{LDFLAGS} //= '';
my @OTHERLDFLAGS = ();
my %CBUILDER_EXTRA_CONFIG = ();

print "==========================================\n";
print "Original compilers and linker settings as per ExtUtils::CBuilder\n";
print "\n";
print "CC           (overwrite) $ENV{CC}\n";
print "CFLAGS       (    fixed) " . ($cbuilder_config{ccflags} // '') . "\n";
print "CFLAGS       (   append) $ENV{CFLAGS}\n";
print "CXX          (overwrite) $ENV{CXX}\n";
print "CXXFLAGS     (overwrite) $ENV{CXXFLAGS}\n";
print "LD           (overwrite) $ENV{LD}\n";
print "LDFLAGS      (    fixed) " . ($cbuilder_config{ldflags} // '') . "\n";
print "LDFLAGS      (   append) $ENV{LDFLAGS}\n";
print "==========================================\n";
print "\n";

my $ac = Config::AutoConf->new();
$ac->check_cc;
#
# We want to align lua integer type with perl ivtype
#
my $ivtype = $Config{ivtype} || '';
if ($ivtype eq 'int') {
    $ac->msg_notice("Use int for lua_Integer");
    $ENV{CFLAGS} .= " -DLUA_INT_TYPE=1";
    $ENV{CXXFLAGS} .= " -DLUA_INT_TYPE=1";
} elsif ($ivtype eq 'long') {
    $ac->msg_notice("Use long for lua_Integer");
    $ENV{CFLAGS} .= " -DLUA_INT_TYPE=2";
    $ENV{CXXFLAGS} .= " -DLUA_INT_TYPE=2";
} elsif ($ivtype eq 'long long') {
    $ac->msg_notice("Use long long for lua_Integer");
    $ENV{CFLAGS} .= " -DLUA_INT_TYPE=3";
    $ENV{CXXFLAGS} .= " -DLUA_INT_TYPE=3";
} else {
    $ac->msg_notice("No exact map found in lua for perl integer type \"$ivtype\": use long long for lua_Integer");
    $ENV{CFLAGS} .= " -DLUA_INT_TYPE=3";
    $ENV{CXXFLAGS} .= " -DLUA_INT_TYPE=3";
}

#
# We want to align lua float type with perl nvtype
#
my $nvtype = $Config{nvtype} || '';
if ($nvtype eq 'float') {
    $ac->msg_notice("Use float for lua_Number");
    $ENV{CFLAGS} .= " -DLUA_FLOAT_TYPE=1";
    $ENV{CXXFLAGS} .= " -DLUA_FLOAT_TYPE=1";
} elsif ($nvtype eq 'double') {
    $ac->msg_notice("Use double for lua_Number");
    $ENV{CFLAGS} .= " -DLUA_FLOAT_TYPE=2";
    $ENV{CXXFLAGS} .= " -DLUA_FLOAT_TYPE=2";
} elsif ($nvtype eq 'long double') {
    $ac->msg_notice("Use long double for lua_Number");
    $ENV{CFLAGS} .= " -DLUA_FLOAT_TYPE=3";
    $ENV{CXXFLAGS} .= " -DLUA_FLOAT_TYPE=3";
} else {
    $ac->msg_notice("No exact map found in lua for perl double type \"$nvtype\": use long double for lua_Number");
    $ENV{CFLAGS} .= " -DLUA_FLOAT_TYPE=3";
    $ENV{CXXFLAGS} .= " -DLUA_FLOAT_TYPE=3";
}
#
# Guess CXX configuration
#
# Sun C compiler is a special case, we know that guess_compiler will always get it wrong
#
my $sunc = 0;
$ac->msg_checking(sprintf "if this is Sun C compiler");
if ($ac->link_if_else("#ifdef __SUNPRO_C\n#else\n#error \"this is not Sun C compiler\"\n#endif\nint main() { return 0; }")) {
    $ac->msg_result('yes');
    my $cc = which($ENV{CC}) || '';
    if (! $cc) {
        #
        # Should never happen since we checked that the compiler works
        #
        $ac->msg_notice("Warning! Sun C compiler working but which() on its location returned false !?");
    } else {
        #
        # $cc should be a full path
        #
        $cc = abs_path($cc);
        my $ccdir = dirname($cc) || File::Spec->curdir();
        #
        # We always give precedence to CC that should be at the same location of the C compiler
        #
        my $cxx = File::Spec->catfile($ccdir, 'CC');
        if (! which($cxx)) {
            #
            # No CC at the same location?
            #
            $ac->msg_notice("Warning! Sun C compiler detected but no CC found at the same location - trying with default search path");
            $cxx = 'CC';
        } else {
            #
            # Could it be that this CC is also the one that is, eventually, in the path?
            #
            my $cxxfromPATH = which('CC') || '';
            if ($cxxfromPATH) {
                $cxxfromPATH = abs_path($cxxfromPATH);
                my $cxxfromWhich = abs_path($cxx);
                if ($cxxfromWhich eq $cxxfromPATH) {
                    $ac->msg_notice("Sun C compiler detected and its CC counterpart is already in the search path");
                    $cxx = 'CC';
                }
            }
        }
        if (which($cxx)) {
            $ac->msg_notice("Forcing CXX to $cxx");
            $ENV{CXX} = $cxx;
            #
            # We got "CC" executable - no need of eventual -x c++ that perl may have add
            #
            if ($ENV{CXXFLAGS} =~ s/\-x\s+c\+\+\s*//) {
                $ac->msg_notice("Removed -x c++ from CXXFLAGS");
            }
        } else {
            $ac->msg_notice("Warning! Sun C compiler detected but no CC found neither in path neither where is the C compiler");
        }
        #
        # In any case, add -lCrun and do not execute guess_compiler - cross fingers if we did not managed to find CXX
        #
        $ac->msg_notice("Adding -lCrun to OTHERLDFLAGS");
        push(@OTHERLDFLAGS, '-lCrun');
        $sunc = 1;
    }
} else {
    $ac->msg_result('no');
}

if ($have_cppguess && ! $sunc) {
    try {
        my ($cxx_guess, $extra_cxxflags_guess, $extra_ldflags_guess) = guess_compiler($ac);
        if (defined($cxx_guess) && (length($cxx_guess) > 0) && which($cxx_guess)) {
            $ac->msg_notice("Setting CXX to $cxx_guess");
            $ENV{CXX} = $cxx_guess;
            if (defined($extra_cxxflags_guess) && (length($extra_cxxflags_guess) > 0)) {
                $ac->msg_notice("Appending $extra_cxxflags_guess to CXXFLAGS");
                $ENV{CXXFLAGS} .= " $extra_cxxflags_guess";
            }
            if (defined($extra_ldflags_guess) && (length($extra_ldflags_guess) > 0)) {
                $ac->msg_notice("Pushing $extra_ldflags_guess to OTHERLDFLAGS");
                push(@OTHERLDFLAGS, $extra_ldflags_guess)
            }
        }
    };
}

if ((! "$ENV{CXX}") || (! which($ENV{CXX}))) {
    $ac->msg_notice("Fallback mode trying to guess from C compiler");
    my $cc_basename = basename($ENV{CC});
    my $cc_dirname = dirname($ENV{CC});
    #
    # Traditionally xxxxcc becomes xxxx++
    #
    if ($cc_basename =~ /cc$/i) {
        my $cxx_basename = $cc_basename;
        $cxx_basename =~ s/cc$/++/;
        my $cxx = File::Spec->catfile($cc_dirname, $cxx_basename);
        if (which($cxx)) {
            $ac->msg_notice("Setting CXX to found $cxx");
            $ENV{CXX} = $cxx;
        }
    }
    #
    # Or xxxxlang becomes lang++
    #
    elsif ($cc_basename =~ /lang$/i) {
        my $cxx_basename = $cc_basename;
        $cxx_basename .= "++";
        my $cxx = File::Spec->catfile($cc_dirname, $cxx_basename);
        if (which($cxx)) {
            $ac->msg_notice("Setting CXX to found $cxx");
            $ENV{CXX} = $cxx;
        }
    }
    #
    # Cross fingers, and use C compiler
    #
    else {
        $ac->msg_notice("Setting CXX to fallback $ENV{CC}");
        $ENV{CXX} = $ENV{CC};
    }
}

# -------------
# CC and CFLAGS
# --------------
#
my $isc99 = 0;
if (($cbuilder_config{cc} // 'cc') ne 'cl') {
    $ac->msg_checking("if C99 is enabled by default:");
    if (try_c("#if !defined(__STDC_VERSION__) || __STDC_VERSION__ < 199901L\n#error \"C99 is not enabled\"\n#endif\nint main(){return 0;}")) {
        $ac->msg_result('yes');
        $isc99 = 1;
    } else {
        $ac->msg_result('no');
        $ac->msg_notice("what CFLAGS is required for C99:");
        $ac->msg_result('');
        foreach my $flag (qw/-std=gnu99 -std=c99 -c99 -AC99 -xc99=all -qlanglvl=extc99/) {
            $ac->msg_checking("if flag $flag works:");
            if (try_c("#if !defined(__STDC_VERSION__) || __STDC_VERSION__ < 199901L\n#error \"C99 is not enabled\"\n#endif\nint main(){return 0;}", { extra_compiler_flags => $flag })) {
                $ac->msg_result('yes');
                $ENV{CFLAGS} .= " $flag";
                $isc99 = 1;
                last;
            } else {
                $ac->msg_result('no');
            }
        }
    }
}

#
# When the compiler is clang, there is a bug with inlining, c.f. for example
# https://sourceforge.net/p/resil/tickets/6/
#
if (is_os_type('Unix', 'darwin') && ! $isc99)
{
  $ac->msg_checking(sprintf "if this is clang compiler");
  if ($ac->link_if_else("#ifndef __clang__\n#error \"this is not clang compiler\"\n#endif\nint main() { return 0; }")) {
      $ac->msg_result('yes');
      #
      # C.f. http://clang.llvm.org/compatibility.html#inline
      #      https://bugzilla.mozilla.org/show_bug.cgi?id=917526
      #
      $ac->msg_notice("Adding -std=gnu89 to CFLAGS for inline semantics");
      $ENV{CFLAGS} .= ' -std=gnu89';
  } else {
      $ac->msg_result('no');
  }
}

if ($^O eq "netbsd" && ! $isc99) {
    #
    # We need long long, that C99 guarantees, else _NETBSD_SOURCE will do it
    #
    $ac->msg_notice("NetBSD platform: Append _NETBSD_SOURCE to CFLAGS to have long long");
    $ENV{CFLAGS} .= ' -D_NETBSD_SOURCE';
}

if(! defined($ENV{MARPAESLIFPERL_OPTIM}) || $ENV{MARPAESLIFPERL_OPTIM}) {
    $ac->msg_checking("optimization flags:");
    $ac->msg_result('');
    if (($cbuilder_config{cc} // 'cc') eq 'cl') {
        foreach my $flag ("/O2") {
            $ac->msg_checking("if flag $flag works:");
            if (try_c("#include <stdlib.h>\nint main() {\n  exit(0);\n}\n", { extra_compiler_flags => $flag })) {
                $ac->msg_result('yes');
                $CBUILDER_EXTRA_CONFIG{optimize} .= " $flag";
                last;
            } else {
                $ac->msg_result('no');
            }
        }
    } else {
        #
        # Some versions of gcc may not yell with bad options unless -Werror is set.
        # Check that flag and set it temporarly.
        #
        my $tmpflag = '-Werror';
        $ac->msg_checking("if flag $tmpflag works:");
        if (try_c("#include <stdlib.h>\nint main() {\n  exit(0);\n}\n", { extra_compiler_flags => $tmpflag })) {
            $ac->msg_result('yes');
        } else {
            $ac->msg_result('no');
            $tmpflag = '';
        }
        #
        # We test AIX case first because it overlaps with general O3
        #
        foreach my $flag ("-O3 -qstrict", # xlc
                          "-O3",          # cl, gcc
                          "-xO3"          # CC
            ) {
            $ac->msg_checking("if flag $flag works:");
            if (try_c("#include <stdlib.h>\nint main() {\n  exit(0);\n}\n", { extra_compiler_flags => "$tmpflag $flag" })) {
                $ac->msg_result('yes');
                $CBUILDER_EXTRA_CONFIG{optimize} .= " $flag";
                last;
            } else {
                $ac->msg_result('no');
            }
        }
    }
}

my $OTHERLDFLAGS = join(' ', @OTHERLDFLAGS);
print "\n";
print "==========================================\n";
print "Tweaked compilers and linker settings\n";
print "\n";
print "CC           (overwrite) $ENV{CC}\n";
print "CFLAGS       (    fixed) " . ($cbuilder_config{ccflags} // '') . "\n";
print "CFLAGS       (   append) $ENV{CFLAGS}\n";
print "CXX          (overwrite) $ENV{CXX}\n";
print "CXXFLAGS     (overwrite) $ENV{CXXFLAGS}\n";
print "LD           (overwrite) $ENV{LD}\n";
print "LDFLAGS      (    fixed) " . ($cbuilder_config{ldflags} // '') . "\n";
print "LDFLAGS      (   append) $ENV{LDFLAGS}\n";
print "OTHERLDFLAGS             $OTHERLDFLAGS\n";
print "==========================================\n";
print "\n";

#
# Re-instanciate a Config::AutoConf object using Config::AutoConf::INI
# --------------------------------------------------------------------
$ac = Config::AutoConf::INI->new(logfile => 'config.log');
$ac->check();
#
# Private extra checks that Config::AutoConf::INI cannot do
#
check_math($ac);
check_ebcdic($ac);
check_inline($ac);
check_forceinline($ac);
check_va_copy($ac);
check_vsnprintf($ac);
check_fileno($ac);
check_localtime_r($ac);
check_write($ac);
check_log2($ac);
check_log2f($ac);
check_char_bit($ac);
check_strtold($ac);
check_strtod($ac);
check_strtof($ac);
if (! check_HUGE_VAL($ac, 'C_HUGE_VAL', 'HUGE_VAL', { extra_compiler_flags => '-DC_HUGE_VAL=HUGE_VAL' })) {
    check_HUGE_VAL($ac, 'C_HUGE_VAL_REPLACEMENT', 1, { extra_compiler_flags => '-DHAVE_HUGE_VAL_REPLACEMENT' });
}
#
# Write config file
#
$ac->write_config_h();

exit(EXIT_SUCCESS);

sub try_c {
    no warnings 'once';
    
    my ($csource, $options) = @_;

    $options //= {};
    my $extra_compiler_flags = $options->{extra_compiler_flags};
    my $link = $options->{link};
    my $run = $options->{run};
    my $cbuilder_extra_config = $options->{cbuilder_extra_config};
    my $output_ref = $options->{output_ref};
    my $silent = $options->{silent} // 1;

    my $stderr_and_stdout_txt = "stderr_and_stdout.txt";
    #
    # We do not want to be polluted in any case, redirect stdout and stderr
    # to the same output using method as per perlfunc open
    #
    open(my $oldout, ">&STDOUT") or die "Can't dup STDOUT: $!";
    open(OLDERR, ">&", \*STDERR) or die "Can't dup STDERR: $!";
    if ($silent) {
        open(STDOUT, '>', $stderr_and_stdout_txt) or die "Can't redirect STDOUT: $!";
        open(STDERR, ">&STDOUT") or die "Can't dup STDOUT: $!";
        select STDERR; $| = 1;  # make unbuffered
        select STDOUT; $| = 1;  # make unbuffered
    }

    $link //= 0;
    $cbuilder_extra_config //= {};
    my $fh = File::Temp->new(UNLINK => 0, SUFFIX => '.c');
    print $fh "$csource\n";
    close($fh);
    my $source = $fh->filename;
    my $rc = 0;
    #
    # Default is compile at least
    #
    try {
        my $cbuilder = ExtUtils::CBuilder->new(config => $cbuilder_extra_config, quiet => 1);
        my $obj = basename($cbuilder->object_file($source));
        $cbuilder->compile(
            source               => $source,
            object_file          => $obj,
            extra_compiler_flags => $extra_compiler_flags
            );
	#
	# Optionally link
	#
        if ($link) {
            my $exe = $cbuilder->link_executable(
                objects              => [ $obj ],
                );
	    #
	    # Optionnally run
	    #
	    if($run) {
                if (! File::Spec->file_name_is_absolute($exe)) {
                    $exe = File::Spec->rel2abs($exe);
                }
                my $output = `$exe`;
                if (WIFEXITED(${^CHILD_ERROR_NATIVE})) {
                    $rc = (WEXITSTATUS(${^CHILD_ERROR_NATIVE}) == EXIT_SUCCESS) ? 1 : 0;
                } else {
                    $rc = 0;
                }
                if ($output_ref) {
                    ${$output_ref} = $output;
                }
	    } else {
		$rc = 1;
	    }
        } else {
	    $rc = 1;
	}
    };
    unlink $fh->filename;

    open(STDOUT, ">&", $oldout) or die "Can't dup \$oldout: $!";
    open(STDERR, ">&OLDERR") or die "Can't dup OLDERR: $!";
    unlink $stderr_and_stdout_txt;

    return $rc;
}

sub try_link {
    my ($csource, $options) = @_;

    $options //= {};

    return try_c($csource, { %$options, link => 1 });
}

sub try_run {
    my ($csource, $options) = @_;

    $options //= {};

    return try_c($csource, { %$options, link => 1, run => 1 });
}

sub try_output {
    my ($csource, $output_ref, $options) = @_;

    $options //= {};

    return try_c($csource, { %$options, link => 1, run => 1, output_ref => $output_ref });
}

sub check_math {
    my ($ac) = @_;

    #
    # log/exp and math lib
    #
    my $lm = $ac->check_lm() // '';
    $ac->msg_checking("for math library:");
    if($lm) {
	$ac->msg_result("$lm");
	$ac->search_libs('log', $lm, { action_on_true => $ac->define_var("HAVE_LOG", 1) });
	$ac->search_libs('exp', $lm, { action_on_true => $ac->define_var("HAVE_EXP", 1) });
	$ENV{LDFLAGS} .= " -l$lm";
    } else {
	$ac->msg_result("not needed");
	$ac->search_libs('log', { action_on_true => $ac->define_var("HAVE_LOG", 1) });
	$ac->search_libs('exp', { action_on_true => $ac->define_var("HAVE_EXP", 1) });
    }
}

sub check_ebcdic {
    my ($ac) = @_;
    #
    # EBCDIC (We could have used $Config{ebcdic} as well
    # --------------------------------------------------
    $ac->msg_checking("EBCDIC");
    my $prologue = <<PROLOGUE;
#ifdef HAVE_STDLIB_H
#include <stdlib.h>
#endif
PROLOGUE
    my $body = <<BODY;
if ('M'==0xd4) {
  exit(0);
} else {
  exit(1);
}
BODY
    my $program = $ac->lang_build_program($prologue, $body);
    if (try_run($program)) {
	$ac->msg_result("yes");
	$ac->define_var("EBCDIC", 1)
    } else {
	$ac->msg_result("no");
    }
}

sub check_inline {
    my ($ac) = @_;

    foreach my $value (qw/inline __inline__ inline__ __inline/) {
	$ac->msg_checking($value);
	my $prologue = <<PROLOGUE;
#ifdef HAVE_STDLIB_H
#include <stdlib.h>
#endif

typedef int foo_t;
static $value foo_t static_foo() {
  return 0;
}
foo_t foo() {
  return 0;
}
PROLOGUE
	my $program = $ac->lang_build_program($prologue);
	if (try_run($program)) {
	    $ac->msg_result("yes");
	    $ac->define_var("C_INLINE", $value);
	    if ($value eq 'inline') {
		$ac->define_var("C_INLINE_IS_INLINE", 1);
	    }
	    last;
	} else {
	    $ac->msg_result("no");
	}
    }
}

sub check_forceinline {
    my ($ac) = @_;

    foreach my $value (qw/forceinline __forceinline__ forceinline__ __forceinline/) {
	$ac->msg_checking($value);
	my $prologue = <<PROLOGUE;
#ifdef HAVE_STDLIB_H
#include <stdlib.h>
#endif

typedef int foo_t;
static $value foo_t static_foo() {
  return 0;
}
foo_t foo() {
  return 0;
}
PROLOGUE
	my $program = $ac->lang_build_program($prologue);
	if (try_run($program)) {
	    $ac->msg_result("yes");
	    $ac->define_var("C_FORCEINLINE", $value);
	    last;
	} else {
	    $ac->msg_result("no");
	}
    }
}

sub check_va_copy {
    my ($ac) = @_;

    foreach my $value (qw/va_copy _va_copy __va_copy/) {
	$ac->msg_checking($value);
	my $prologue = <<PROLOGUE;
#ifdef HAVE_STDLIB_H
#include <stdlib.h>
#endif

#ifdef HAVE_STDARG_H
#include <stdarg.h>
#endif

static void f(int i, ...) {
  va_list args1, args2;

  va_start(args1, i);
  $value(args2, args1);

  if (va_arg(args2, int) != 42 || va_arg(args1, int) != 42) {
    exit(1);
  }

  va_end(args1);
  va_end(args2);
}

PROLOGUE
	my $body = <<BODY;
  f(0, 42);
  exit(0);
BODY
	my $program = $ac->lang_build_program($prologue, $body);
	if (try_run($program)) {
	    $ac->msg_result("yes");
	    $ac->define_var("C_VA_COPY", $value);
	    last;
	} else {
	    $ac->msg_result("no");
	}
    }
}

sub check_vsnprintf {
    my ($ac) = @_;

    foreach my $value (qw/vsnprintf _vsnprintf __vsnprintf/) {
	$ac->msg_checking($value);
	my $prologue = <<PROLOGUE;
#ifdef HAVE_STDIO_H
#include <stdio.h>
#endif
#ifdef HAVE_STDARG_H
#include <stdarg.h>
#endif
#ifdef HAVE_STDLIB_H
#include <stdlib.h>
#endif

static void vsnprintftest(char *string, char *fmt, ...)
{
   va_list ap;

   va_start(ap, fmt);
   $value(string, 10, fmt, ap);
   va_end(ap);
}

PROLOGUE
	my $body = <<BODY;
  char p[100];
  vsnprintftest(p, "%s", "test");
  exit(0);
BODY
	my $program = $ac->lang_build_program($prologue, $body);
	if (try_run($program)) {
	    $ac->msg_result("yes");
	    $ac->define_var("C_VSNPRINTF", $value);
	    last;
	} else {
	    $ac->msg_result("no");
	}
    }
}

sub check_fileno {
    my ($ac) = @_;

    foreach my $value (qw/fileno _fileno __fileno/) {
	$ac->msg_checking($value);
	my $prologue = <<PROLOGUE;
#ifdef HAVE_STDIO_H
#include <stdio.h>
#endif

#ifdef HAVE_STDLIB_H
#include <stdlib.h>
#endif

PROLOGUE
	my $body = <<BODY;
  $value(stdin);
  exit(0);
BODY
	my $program = $ac->lang_build_program($prologue, $body);
	if (try_run($program)) {
	    $ac->msg_result("yes");
	    $ac->define_var("C_FILENO", $value);
	    last;
	} else {
	    $ac->msg_result("no");
	}
    }
}

sub check_localtime_r {
    my ($ac) = @_;

    foreach my $value (qw/localtime_r _localtime_r __localtime_r/) {
	$ac->msg_checking($value);
	my $prologue = <<PROLOGUE;
#ifdef HAVE_STDLIB_H
#include <stdlib.h>
#endif

#ifdef HAVE_TIME_H
#include <time.h>
#endif

PROLOGUE
	my $body = <<BODY;
  time_t time;
  struct tm result;
  $value(&time, &result);
  exit(0);
BODY
	my $program = $ac->lang_build_program($prologue, $body);
	if (try_run($program)) {
	    $ac->msg_result("yes");
	    $ac->define_var("C_LOCALTIME_R", $value);
	    last;
	} else {
	    $ac->msg_result("no");
	}
    }
}

sub check_write {
    my ($ac) = @_;

    foreach my $value (qw/write _write __write/) {
	$ac->msg_checking($value);
	my $prologue = <<PROLOGUE;
#ifdef HAVE_STDIO_H
#include <stdio.h>
#endif

#ifdef HAVE_IO_H
#include <io.h>
#endif

#ifdef HAVE_STDLIB_H
#include <stdlib.h>
#endif

#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif

PROLOGUE
	my $body = <<BODY;
  if ($value(1, "This will be output to standard out\\n", 36) != 36) {
    exit(1);
  }
  exit(0);
BODY
	my $program = $ac->lang_build_program($prologue, $body);
	if (try_run($program)) {
	    $ac->msg_result("yes");
	    $ac->define_var("C_WRITE", $value);
	    last;
	} else {
	    $ac->msg_result("no");
	}
    }
}

sub check_log2 {
    my ($ac) = @_;

    foreach my $value (qw/log2/) {
	$ac->msg_checking($value);
	my $prologue = <<PROLOGUE;
#ifdef HAVE_STDLIB_H
#include <stdlib.h>
#endif

#ifdef HAVE_MATH_H
#include <math.h>
#endif

PROLOGUE
	my $body = <<BODY;
  double x = $value(1.0);
  exit(0);
BODY
	my $program = $ac->lang_build_program($prologue, $body);
	if (try_run($program)) {
	    $ac->msg_result("yes");
	    $ac->define_var("C_LOG2", $value);
	    last;
	} else {
	    $ac->msg_result("no");
	}
    }
}

sub check_log2f {
    my ($ac) = @_;

    foreach my $value (qw/log2f/) {
	$ac->msg_checking($value);
	my $prologue = <<PROLOGUE;
#ifdef HAVE_STDLIB_H
#include <stdlib.h>
#endif

#ifdef HAVE_MATH_H
#include <math.h>
#endif

PROLOGUE
	my $body = <<BODY;
  float x = $value(1.0);
  exit(0);
BODY
	my $program = $ac->lang_build_program($prologue, $body);
	if (try_run($program)) {
	    $ac->msg_result("yes");
	    $ac->define_var("C_LOG2F", $value);
	    last;
	} else {
	    $ac->msg_result("no");
	}
    }
}

sub check_char_bit {
    my ($ac) = @_;

    foreach my $value (qw/CHAR_BIT/) {
	$ac->msg_checking($value);
	my $prologue = <<PROLOGUE;
#ifdef HAVE_STDLIB_H
#include <stdlib.h>
#endif
#ifdef HAVE_STDIO_H
#include <stdio.h>
#endif
#ifdef HAVE_LIMITS_H
#include <limits.h>
#endif

PROLOGUE
	my $body = <<BODY;
  fprintf(stdout, "%d", $value);
  exit(0);
BODY
	my $program = $ac->lang_build_program($prologue, $body);
        my $char_bit = undef;
        if (try_output($program, \$char_bit) && defined($char_bit)) {
	    $ac->msg_result($char_bit);
	    last;
	} else {
            $char_bit = 8;
	    $ac->msg_result("no - Assuming $char_bit");
	}
        #
        # It is impossible to have less than 8
        #
        if ($char_bit < 8) {
            die "CHAR_BIT size is $char_bit < 8";
        }
        $ac->define_var("C_CHAR_BIT", $char_bit);
    }
}

sub check_strtold {
    my ($ac) = @_;

    foreach my $value (qw/strtold _strtold __strtold/) {
	$ac->msg_checking($value);
	my $prologue = <<PROLOGUE;
#ifdef HAVE_STDLIB_H
#include <stdlib.h>
#endif

PROLOGUE
	my $body = <<BODY;
  char *string = "3.14Stop";
  char *stopstring = NULL;

  $value(string, &stopstring);
  exit(0);
BODY
	my $program = $ac->lang_build_program($prologue, $body);
	if (try_run($program)) {
	    $ac->msg_result("yes");
	    $ac->define_var("C_STRTOLD", $value);
	    last;
	} else {
	    $ac->msg_result("no");
	}
    }
}

sub check_strtod {
    my ($ac) = @_;

    foreach my $value (qw/strtod _strtod __strtod/) {
	$ac->msg_checking($value);
	my $prologue = <<PROLOGUE;
#ifdef HAVE_STDLIB_H
#include <stdlib.h>
#endif

PROLOGUE
	my $body = <<BODY;
  char *string = "3.14Stop";
  char *stopstring = NULL;

  $value(string, &stopstring);
  exit(0);
BODY
	my $program = $ac->lang_build_program($prologue, $body);
	if (try_run($program)) {
	    $ac->msg_result("yes");
	    $ac->define_var("C_STRTOD", $value);
	    last;
	} else {
	    $ac->msg_result("no");
	}
    }
}

sub check_strtof {
    my ($ac) = @_;

    foreach my $value (qw/strtof _strtof __strtof/) {
	$ac->msg_checking($value);
	my $prologue = <<PROLOGUE;
#ifdef HAVE_STDLIB_H
#include <stdlib.h>
#endif

PROLOGUE
	my $body = <<BODY;
  char *string = "3.14Stop";
  char *stopstring = NULL;

  $value(string, &stopstring);
  exit(0);
BODY
	my $program = $ac->lang_build_program($prologue, $body);
	if (try_run($program)) {
	    $ac->msg_result("yes");
	    $ac->define_var("C_STRTOF", $value);
	    last;
	} else {
	    $ac->msg_result("no");
	}
    }
}

sub check_HUGE_VAL {
    my ($ac, $what, $value, $options) = @_;

    $ac->msg_checking($what);
    my $rc = 0;
    my $prologue = <<PROLOGUE;
#ifdef HAVE_STDLIB_H
#include <stdlib.h>
#endif

#ifdef HAVE_MATH_H
#include <math.h>
#endif

#ifdef HAVE_HUGE_VAL_REPLACEMENT
#  define C_HUGE_VAL (__builtin_huge_val())
#endif

PROLOGUE
	my $body = <<BODY;
  double x = -C_HUGE_VAL;
  exit(0);
BODY
    my $program = $ac->lang_build_program($prologue, $body);
    if (try_run($program, $options)) {
        $ac->msg_result("yes");
        $ac->define_var($what, $value);
        $rc = 1;
    } else {
        $ac->msg_result("no");
        $rc = 0;
    }

    return $rc;
}
