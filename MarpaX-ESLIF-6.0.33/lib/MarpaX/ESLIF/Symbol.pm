use strict;
use warnings FATAL => 'all';

package MarpaX::ESLIF::Symbol;
use parent qw/MarpaX::ESLIF::Base/;
use Carp qw/croak/;

#
# Base required class methods
#
sub _CLONABLE { return 1 }
sub _ALLOCATE {
    return sub {
        my ($class, $eslif, %options) = @_;

        my $type = $options{type} // croak 'type must be defined';

        if (($type eq 'string') or ($type eq 'regex')) {
            my $pattern = $options{pattern} // croak 'pattern must be defined';
            my $encoding = $options{encoding};
            my $modifiers = $options{modifiers};
            my $substitutionPattern = $options{substitutionPattern};
            my $substitutionModifiers = $options{substitutionModifiers};

            return
                ($type eq 'string')
                ?
                MarpaX::ESLIF::Symbol->string_allocate($eslif, $pattern, bytes::length($pattern), $encoding, $modifiers)
                :
                MarpaX::ESLIF::Symbol->regex_allocate($eslif, $pattern, bytes::length($pattern), $encoding, $modifiers, $substitutionPattern, $substitutionModifiers)
        } elsif ($type eq 'meta') {
            my $grammar = $options{grammar} // croak 'grammar must be defined';
            my $symbol = $options{symbol} // croak 'symbol must be defined';

            return MarpaX::ESLIF::Symbol->meta_allocate($eslif, $grammar, $symbol)
        } else {
            croak "Type must be 'string', 'regex' or 'meta'"
        }
    }
}
sub _DISPOSE  { return \&MarpaX::ESLIF::Symbol::dispose }
sub _EQ {
    return sub {
        my ($class, $args_ref, $eslif, %options) = @_;

        my $type = $options{type} // croak 'type must be defined';

        if (($type eq 'string') or ($type eq 'regex')) {

            my $pattern = $options{pattern} // croak 'pattern must be defined';
            my $encoding = $options{encoding};
            my $modifiers = $options{modifiers};
            my $substitutionPattern = $options{substitutionPattern};
            my $substitutionModifiers = $options{substitutionModifiers};

            my $definedEncoding = defined($encoding); # It is legal to create a symbol with no encoding
            my $definedModifiers = defined($modifiers); # It is legal to create a symbol with no modifier
            my $definedSubstitutionPattern = defined($substitutionPattern); # It is legal to create a symbol with no substitution pattern
            my $definedSubstitutionModifiers = defined($substitutionModifiers); # It is legal to create a symbol with no substitution modifier

            my ($args_eslif, %args_options) = @{$args_ref};
            my $_definedEncoding = defined($args_options{encoding});
            my $_definedModifiers = defined($args_options{modifiers});
            my $_definedSubstitutionPattern = defined($args_options{substitutionPattern});
            my $_definedSubstitutionModifiers = defined($args_options{substitutionModifiers});
            return $_ if
                $eslif == $args_eslif
                &&
                $type eq $args_options{type}
                &&
                $pattern eq $args_options{pattern}
                &&
                ((! $definedEncoding && ! $_definedEncoding) || ($definedEncoding && $_definedEncoding && ($encoding eq $args_options{encoding})))
                &&
                ((! $definedModifiers && ! $_definedModifiers) || ($definedModifiers && $_definedModifiers && ($modifiers eq $args_options{modifiers})))
                &&
                ((! $definedSubstitutionPattern && ! $_definedSubstitutionPattern) || ($definedSubstitutionPattern && $_definedSubstitutionPattern && ($substitutionPattern eq $args_options{substitutionPattern})))
                &&
                ((! $definedSubstitutionModifiers && ! $_definedSubstitutionModifiers) || ($definedSubstitutionModifiers && $_definedSubstitutionModifiers && ($substitutionModifiers eq $args_options{substitutionModifiers})))

        } elsif ($type eq 'meta') {
            my $grammar = $options{grammar} // croak 'grammar must be defined';
            my $symbol = $options{symbol} // croak 'symbol must be defined';

            my ($args_eslif, %args_options) = @{$args_ref};

            return $_ if
                $eslif == $args_eslif
                &&
                $type eq $args_options{type}
                &&
                $grammar == $args_options{grammar}
                &&
                $symbol eq $args_options{symbol}
        } else {
            croak "Type must be 'string', 'regex' or 'meta'"
        }
    }
}

# ABSTRACT: MarpaX::ESLIF's symbol

our $AUTHORITY = 'cpan:JDDPAUSE'; # AUTHORITY

our $VERSION = '6.0.33'; # TRIAL VERSION


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

MarpaX::ESLIF::Symbol - MarpaX::ESLIF's symbol

=head1 VERSION

version 6.0.33

=head1 SYNOPSIS

  use MarpaX::ESLIF;

  my $eslif = MarpaX::ESLIF->new();

  my $stringSymbol = MarpaX::ESLIF::Symbol->new($eslif, type => 'string', pattern => '"String Pattern"');
  #
  # In ESLIF, a regex is anchored by default
  #
  my $regexSymbol = MarpaX::ESLIF::Symbol->new($eslif, type => 'regex', pattern => 'Regex.*Pattern', modifiers => 'A');
  my $metaSymbol = MarpaX::ESLIF::Symbol->new($eslif, type => 'meta',
                                                      grammar => MarpaX::ESLIF::Grammar->new(
                                                                   $eslif,
                                                                   "<something> ::= <SOMETHING>\n<SOMETHING> ~ 'that'"),
                                                      symbol => 'SOMETHING');
  #
  # For regex, a substitution pattern is supported
  #
  my $substitutionSymbol = MarpaX::ESLIF::Symbol->new($eslif, type => 'regex', pattern => 'Regex(.*)Pattern', modifiers => 'A', substitutionPattern => '$1', substitutionModifiers => 'g');

  if (defined(my $match = $stringSymbol->try('String Pattern here'))) {
      print "==> String match: $match\n";
  }

  if (defined(my $match = $regexSymbol->try('Should match Regex etc Pattern in there'))) {
      print "==> Regex match: $match\n";
  }

  if (defined(my $match = $metaSymbol->try('something'))) {
      print "==> Meta match: $match\n";
  }

  if (defined(my $match = $substitutionSymbol->try('Should match Regex etc Pattern in there'))) {
      print "==> Meta match: $match\n";
  }

External symbols can be of type C<string>, C<regex> or C<meta>. They can be used agains a L<MarpaX::ESLIF::Recognizer> or any external input.

A string pattern I<must> follow ESLIF)s BNF, i.e. start and ends with:

=over

=item C<'> (single quote) character

=item C<"> (double quote) character

=item C<“> (LEFT DOUBLE QUOTATION MARK) and C<”> characters (RIGHT DOUBLE QUOTATION MARK), respectively

=back

A meta symbol I<must> be a lexeme in the given external grammar.

=head1 DESCRIPTION

MarpaX::ESLIF::Symbol allows to create external symbols on demand

=head1 METHODS

=head2 MarpaX::ESLIF::Symbol->new($eslif, %options)

Returns a symbol instance, noted C<$symbol> later. C<%options> is a hash that contains:

=over

=item C<type>

Value must be "string", "regex" or "meta". Required.

=item C<pattern>

Value is the pattern content. Required for "string" and "regex" types.

=item C<encoding>

Value is the pattern encoding. Optional for "string" and "regex" types.

=item C<modifiers>

Value is a string containing modifiers. Optional for "string" and "regex" types.

It must follow the specification of the I<Terminals> section of L<MarpaX::ESLIF::BNF>:

  ----------------------------------------------------------------
  Modifiers   Explanation
  ----------------------------------------------------------------
  e           Unset back-references in the pattern will match to empty strings
  i           Case-insensitive
  j           \u, \U and \x and unset back-references will act as JavaScript standard
  m           Multi-line regex
  n           Enable Unicode properties and extend meaning of meta-characters
  s           A dot meta-character in the pattern matches all characters, including newlines
  x           Enable comments. This has some limitation due marpaESLIF semantics
  D           A dollar meta-character matches only at the end of the subject string
  J           Allow duplicate names for sub-patterns
  U           Inverts the "greediness" of the quantifiers
  a           Meta-characters will be limited to their ASCII equivalent
  u           Forces support of large codepoints
  b           Could mean "forced binary" mode
  c           Could mean "forced unicode character" mode
  A           Remove the systematic anchoring
  ----------------------------------------------------------------

Note that a string pattern accepts only the C<i> and C<c> modifiers.

=item C<substitutionPattern>

Value is the substitution content, writen as if this was an ESLIF string. Optional and supported only for "regex" type. If set, it is assumed that it is in the same encoding as C<pattern>.

=item C<substitutionModifiers>

Value is a string containing substitution modifiers. Optional and supported only for "regex" type.

It must follow the substitution specification of the I<Terminals> section of L<MarpaX::ESLIF::BNF>:

  ----------------------------------------------------------------
  Modifiers         PCRE2 flag unset   PCR2 flag set
  ----------------------------------------------------------------
  x                                    PCRE2_SUBSTITUTE_EXTENDED
  g                                    PCRE2_SUBSTITUTE_GLOBAL
  l                                    PCRE2_SUBSTITUTE_LITERAL
  !                                    PCRE2_SUBSTITUTE_UNKNOWN_UNSET
  f                                    PCRE2_SUBSTITUTE_UNSET_EMPTY
  ----------------------------------------------------------------

=item C<grammar>

Value is an external grammar. Required for "meta" type.

=item C<symbol>

Value is a lexeme in the external grammar. Required for "meta" type.

=back

=head2 $symbol->try($eslif, $scalar)

Try to match the external symbol C<$symbol> on C<$scalar>, that can be anything. Return C<undef> if failure, the matched string if success.

=head1 SEE ALSO

L<MarpaX::ESLIF>, L<MarpaX::ESLIF::Recognizer>

=head1 AUTHOR

Jean-Damien Durand <jeandamiendurand@free.fr>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2017 by Jean-Damien Durand.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
