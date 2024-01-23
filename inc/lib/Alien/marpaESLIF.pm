#
# Note: Copy/pasted from Alien::OpenCV
#
package Alien::marpaESLIF;

use strict;
use warnings;
use base qw( Alien::Base );
use 5.008004;

1;

=head1 NAME

Alien::marpaESLIF - Find or build marpaESLIF computer vision library

=head1 SYNOPSIS

From L<ExtUtils::MakeMaker>:

 use ExtUtils::MakeMaker;
 use Alien::Base::Wrapper ();

 WriteMakefile(
   Alien::Base::Wrapper->new('Alien::marpaESLIF')->mm_args2(
     NAME => 'FOO::XS',
     ...
   ),
 );

From L<Module::Build>:

 use Module::Build;
 use Alien::Base::Wrapper qw( Alien::marpaESLIF !export );
 use Alien::marpaESLIF;

 my $build = Module::Build->new(
   ...
   configure_requires => {
     'Alien::Base::Wrapper' => '0',
     'Alien::marpaESLIF' => '0',
     ...
   },
   Alien::Base::Wrapper->mb_args,
   ...
 );

 $build->create_build_script;

From L<Inline::C> / L<Inline::CPP> script:

 use Inline 0.56 with => 'Alien::marpaESLIF';

From L<Dist::Zilla>

 [@Filter]
 -bundle = @Basic
 -remove = MakeMaker

 [Prereqs / ConfigureRequires]
 Alien::marpaESLIF = 0

 [MakeMaker::Awesome]
 header = use Alien::Base::Wrapper qw( Alien::marpaESLIF !export );
 WriteMakefile_arg = Alien::Base::Wrapper->mm_args

From L<FFI::Platypus>:

 use FFI::Platypus;
 use Alien::marpaESLIF;

 my $ffi = FFI::Platypus->new(
   lib => [ Alien::marpaESLIF->dynamic_libs ],
 );

=head1 DESCRIPTION

This distribution provides marpaESLIF so that it can be used by other
Perl distributions that are on CPAN.  It does this by first trying to
detect an existing install of marpaESLIF on your system.  If found it
will use that.  If it cannot be found, the source code will be downloaded
from the internet and it will be installed in a private share location
for the use of other modules.

=head1 SEE ALSO

=over 4

=item L<c-marpaESLIF|https://github.com/jddurand/c-marpaESLIF.git>

The marpaESLIF home page.

=item L<Alien>

Documentation on the Alien concept itself.

=item L<Alien::Base>

The base class for this Alien.

=item L<Alien::Build::Manual::AlienUser>

Detailed manual for users of Alien classes.

=back

=cut
