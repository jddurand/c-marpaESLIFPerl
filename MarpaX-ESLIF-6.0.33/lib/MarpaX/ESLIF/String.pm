use strict;
use warnings FATAL => 'all';

#
# Based on BSON::String v1.10.2
#
package MarpaX::ESLIF::String;
use Carp qw/croak/;

# ABSTRACT: ESLIF String is any string value with encoding attribute

our $AUTHORITY = 'cpan:JDDPAUSE'; # AUTHORITY

our $VERSION = '6.0.33'; # TRIAL VERSION


sub new {
    my ($class, $value, $encoding) = @_;

    croak 'Undefined value' unless defined($value);
    croak 'Undefined encoding' unless defined($encoding);

    $value = "$value"; # Make sure it is a PV
    $encoding = "$encoding"; # Make sure it is a PV

    #
    # We TRUST the encoding. If user lies, behaviour will be undetermined.
    #
    my $lcEncoding = lc($encoding);
    if ($lcEncoding eq 'utf8' || $lcEncoding eq 'utf-8') {
        utf8::upgrade($value)
    }

    return bless {value => $value, encoding => $encoding}, $class
}

sub encoding {
    # my ($self) = @_;
    return $_[0]->{encoding} # For performance
}

sub value {
    # my ($self) = @_;
    return $_[0]->{value} # For performance
}

use overload (
    # Unary
    q{bool} => sub { !! $_[0]->{value} },
    q{""} => sub { $_[0]->{value} },
    q{0+} => sub { 0+ $_[0]->{value} },
    q{~}  => sub { ~( $_[0]->{value} ) },
    # Binary
    ( map { $_ => eval "sub { return \$_[0]->{value} $_ \$_[1] }" } qw( + * ) ), ## no critic
    (
        map {
            $_ => eval ## no critic
              "sub { return \$_[2] ? \$_[1] $_ \$_[0]->{value} : \$_[0]->{value} $_ \$_[1] }"
        } qw( - / % ** << >> x <=> cmp & | ^ )
    ),
    (
        map { $_ => eval "sub { return $_(\$_[0]->{value}) }" } ## no critic
          qw( cos sin exp log sqrt int )
    ),
    q{atan2} => sub {
        return $_[2] ? atan2( $_[1], $_[0]->{value} ) : atan2( $_[0]->{value}, $_[1] );
    },

    # Special
    fallback => 1
);


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

MarpaX::ESLIF::String - ESLIF String is any string value with encoding attribute

=head1 VERSION

version 6.0.33

=head1 DESCRIPTION

MarpaX::ESLIF::String is a string type wrapper that associates an encoding information to the string value. Without this wrapper, only valid perl string having the utf8 flag will be able to transport encoding information to MarpaX::ESLIF.

=head1 METHODS

=head2 MarpaX::ESLIF::String->new($string, $encoding)

  my $string = 'value';
  my $encoding = 'UTF-8';
  my $s = MarpaX::ESLIF::String->new($string, $encoding)

C<$string> parameter defaults to the empty string, and C<$encoding> parameter may be undef. In the later case, MarpaX::ESLIF will know you want to say this is a string, and will B<guess> the encoding.

C<$s> overloads by default as if it was C<$string>.

=head2 $s->value

Returns the string value.

=head2 $s->encoding

Returns the associated encoding.

=head1 SEE ALSO

L<MarpaX::ESLIF>

=head1 AUTHOR

Jean-Damien Durand <jeandamiendurand@free.fr>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2017 by Jean-Damien Durand.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
