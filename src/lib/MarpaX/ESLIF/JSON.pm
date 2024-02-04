use strict;
use warnings FATAL => 'all';

package MarpaX::ESLIF::JSON;
use MarpaX::ESLIF::JSON::Encoder;
use MarpaX::ESLIF::JSON::Decoder;

# ABSTRACT: ESLIF's JSON interface

# AUTHORITY

# VERSION

=head1 DESCRIPTION

This is JSON's strict and relax encoder/decoder writen directly in L<MarpaX::ESLIF> library.

There are two JSON modes:

=over

=item Strict

Encoder and decoder are strict, as per L<ECMA-404 The JSON Data Interchange Standard|https://www.json.org>.

=item Relax

This is strict grammar extended with:

=over

=item Unlimited commas

=item Trailing separator

=item Perl style comment

=item C++ style comment

=item Infinity

=item NaN

=item Unicode's control characters (range C<[\x00-\x1F]>).

=item Number with non significant zeroes on the left.

=item Number with a leading C<+> sign.

=back

=back

=cut

=head1 METHODS

=head2 MarpaX::ESLIF::JSON->new($eslif[, $strict])

   my $eslifJSON = MarpaX::ESLIF::JSON->new($eslif);

Just a convenient wrapper over L<MarpaX::ESLIF::JSON::Encoder> and L<MarpaX::ESLIF::JSON::Decoder>. Parameters are:

=over

=item C<$eslif>

MarpaX::ESLIF object instance. Required.

=item C<$strict>

A true value means strict JSON, else relax JSON. Default is a true value.

=back

=cut

sub new {
    my $class = shift;

    return bless { encoder => MarpaX::ESLIF::JSON::Encoder->new(@_), decoder => MarpaX::ESLIF::JSON::Decoder->new(@_) }, $class
}

=head2 $eslifJSON->encode($value)

   my $string = $eslifJSON->encode($value);


=cut

sub encode {
    my ($self, $value) = @_;

    return $self->{encoder}->encode($value)
}

=head2 $eslifJSON->decode($string, %options)

   my $value = $eslifJSON->decode($string);

Please refer to L<MarpaX::ESLIF::JSON::Decoder> for the options.

=cut

sub decode {
    my ($self, $string, %options) = @_;

    return $self->{decoder}->decode($string, %options)
}

=head1 NOTES

=over

=item Floating point special values

C<+/-Infinity> and C<+/-NaN> are always mapped to L<Math::BigInt>'s C<binf()>, C<binf('-')>, C<bnan()>, C<bnan('-')>, respectively.

=item other numbers

They are always mapped to L<Math::BigFloat>.

=back

=cut

1;
