#
# This file is adapted from Marpa::R2's t/sl_advent.t
#
package MyRecognizerInterface;
use strict;
use diagnostics;

sub new                    { my ($pkg, $string) = @_; bless { string => $string }, $pkg }
sub read                   { 1 }
sub isEof                  { 1 }
sub isCharacterStream      { 1 }
sub encoding               { }
sub data                   { $_[0]->{string} }
sub isWithDisableThreshold { 0 }
sub isWithExhaustion       { 0 }
sub isWithNewline          { 1 }
sub isWithTrack            { 1 }

package MyValueInterface;
use strict;
use diagnostics;

sub new                { my ($pkg) = @_; bless { result => undef }, $pkg }
sub isWithHighRankOnly { 1 }
sub isWithOrderByRank  { 1 }
sub isWithAmbiguous    { 0 }
sub isWithNull         { 0 }
sub maxParses          { 0 }
sub getResult          { $_[0]->{result} }
sub setResult          { $_[0]->{result} = $_[1] }

package main;
use strict;
use warnings FATAL => 'all';
use Test::More;
use Test::More::UTF8;
use Log::Any qw/$log/;
use Log::Any::Adapter 'Stdout';
use Encode qw/decode encode/;
use utf8;
use open ':std', ':encoding(utf8)';

BEGIN { require_ok('MarpaX::ESLIF') };

my $base_dsl = q{
:desc ::= '$TEST'
:start ::= deal
:default ::= action => ::convert[UTF-8]
             symbol-action => ::concat

deal ::= hands
hands ::= hand | hands ';' hand
hand ::= CARD CARD CARD CARD CARD
CARD ~ FACE SUIT
FACE ~ [2-9jqka] | '10'
WS ~ [\s]
:discard ::= WS

:symbol ::= <CARD>  pause => after event => CARD
};

my $eslif = MarpaX::ESLIF->new($log);
isa_ok($eslif, 'MarpaX::ESLIF');

my @tests = ();
push @tests,
    [
    '2♥ 5♥ 7♦ 8♣ 9♠',
    'Parse OK',
    'Hand was 2♥ 5♥ 7♦ 8♣ 9♠',
    ];
push @tests,
    [
    '2♥ a♥ 7♦ 8♣ j♥',
    'Parse OK',
    'Hand was 2♥ a♥ 7♦ 8♣ j♥',
    ];
push @tests,
    [
    'a♥ a♥ 7♦ 8♣ j♥',
    'Parse stopped by application',
    'Duplicate card a♥'
    ];
push @tests,
    [
    'a♥ 7♥ 7♦ 8♣ j♥; 10♥ j♥ q♥ k♥ a♥',
    'Parse stopped by application',
    'Duplicate card j♥'
    ];
push @tests,
    [
    '2♥ 7♥ 2♦ 3♣ 3♦',
    'Parse OK',
    'Hand was 2♥ 7♥ 2♦ 3♣ 3♦',
    ];
push @tests,
    [
    '2♥ 7♥ 2♦ 3♣',
    'Parse reached end of input, but failed',
    'No hands were found'
    ];
push @tests, [
    '2♥ 7♥ 2♦ 3♣ 3♦ 1♦',
    'Parse failed before end',
    undef
    ];
push @tests,
    [
    '2♥ 7♥ 2♦ 3♣',
    'Parse reached end of input, but failed',
    'No hands were found'
    ];
push @tests,
    [
    'a♥ 7♥ 7♦ 8♣ j♥; 10♥ j♣ q♥ k♥',
    'Parse failed after finding hand(s)',
    'Last hand successfully parsed was a♥ 7♥ 7♦ 8♣ j♥'
    ];

my @suit_line = (
    [ 'SUIT ~ [\x{2665}\x{2666}\x{2663}\x{2660}]:u', 'hex' ],
    [ 'SUIT ~ [♥♦♣♠]',                     'char class' ],
    [ q{SUIT ~ '♥' | '♦' | '♣'| '♠'},      'strings' ],
);

for my $test_data (@tests) {
    my ($input, $expected_result, $expected_value) = @{$test_data};
    $log->infof('Testing input: %s, expected result: %s, expected value: %s', $input, $expected_result, $expected_value);

    my ($actual_result, $actual_value);

    utf8::encode(my $byte_input = $input);

    for my $suit_line_data (@suit_line) {
        my ($suit_line, $suit_line_type) = @{$suit_line_data};
        $log->infof('Testing suite line: %s, type: %s', $suit_line, $suit_line_type);
      PROCESSING: {
          # Note: in production, you would compute the three grammar variants
          # ahead of time.
          my $full_dsl = $base_dsl . $suit_line;
          $full_dsl =~ s/\$TEST/$input/;
          my $grammar = MarpaX::ESLIF::Grammar->new($eslif, $full_dsl);
          my $description = $grammar->currentDescription;
          my $descriptionByLevel0 = $grammar->descriptionByLevel(0);
          my $descriptionByLevel1 = $grammar->descriptionByLevel(1);
          ok(utf8::is_utf8($description), "Description '$description' have the utf8 flag");
          ok(utf8::is_utf8($descriptionByLevel0), "descriptionByLevel(0) '$descriptionByLevel0' have the utf8 flag");
          ok(utf8::is_utf8($descriptionByLevel1), "descriptionByLevel(1) '$descriptionByLevel1' have the utf8 flag");
          my $recognizerInterface = MyRecognizerInterface->new($input);
          my $re = MarpaX::ESLIF::Recognizer->new($grammar, $recognizerInterface);
          my %played = ();
          my $pos;
          my $ok = $re->scan();
          while ($ok && $re->isCanContinue()) {

            # In our example there is a single event: no need to ask what it is
            my $CARD = $re->nameLastPause('CARD');
            ok(utf8::is_utf8($CARD), "Card '$CARD' have the utf8 flag");
            if ( ++$played{$CARD} > 1 ) {
                $actual_result = 'Parse stopped by application';
                $actual_value  = "Duplicate card " . $CARD;
                last PROCESSING;
            }
            $ok = $re->resume();
          }
          if ( not $ok ) {
              $actual_result = "Parse failed before end";
              $actual_value  = $@;
              last PROCESSING;
          }

          my $valueInterface = MyValueInterface->new();
          my $status = eval { MarpaX::ESLIF::Value->new($re, $valueInterface)->value() };
          if (! defined($status)) {
              $log->errorf("MarpaX::ESLIF::Value->new error, %s", $@);
          }
          my $last_hand;
          my ($handoffset, $handlength) = eval { $re->lastCompletedLocation('hand') };
          if (! defined($handoffset) && ! defined($handlength)) {
              $log->errorf("MarpaX::ESLIF::Recognizer->lastCompletedLocation error, %s", $@);
          }
          if ( $handlength ) {
              $last_hand = decode('UTF-8', my $tmp = substr($byte_input, $handoffset, $handlength), Encode::FB_CROAK);
          }
          if ($status) {
              my $value = $valueInterface->getResult();
	      # UTF-8 outputs are true strings. In case of any other encoding, you have to explicitly stringify, i.e.: utf8::is_utf8("$value")
              ok(utf8::is_utf8($value), "Value '$value' have the utf8 flag");
              $actual_result = 'Parse OK';
              $actual_value  = "Hand was $last_hand";
              last PROCESSING;
          }
          if ( defined $last_hand ) {
              $actual_result = 'Parse failed after finding hand(s)';
              $actual_value =  "Last hand successfully parsed was $last_hand";
              last PROCESSING;
          }
          $actual_result = 'Parse reached end of input, but failed';
          $actual_value  = 'No hands were found';
        }

        is( $actual_result, $expected_result, "Result of $input using $suit_line_type should be: $expected_result" );
        is( $actual_value, $expected_value, "Value of $input using $suit_line_type should be: $expected_value" ) if $expected_value;
    }
}

done_testing();


