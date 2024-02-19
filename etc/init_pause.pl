#!env perl
use strict;
use diagnostics;
use File::HomeDir;
use File::Spec;
use POSIX qw/EXIT_SUCCESS/;

my ($user, $heyhey) = @ARGV;

my $pause = File::Spec->catfile(File::HomeDir->my_home, '.pause');
print "Initializing $pause\n";
open(my $fd, '>', $pause) || die "Cannot open $pause, $!";
print $fd "$user\n$heyhey\n";
close($fd) || warn "Cannot close $pause, $!";

exit(EXIT_SUCCESS);
