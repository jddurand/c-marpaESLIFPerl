#
# This file is adapted from MarpaX::ESLIF::ECMA404
#
package MyRecognizerInterface;
use strict;
use diagnostics;
use Log::Any qw/$log/;

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
sub if_action {
    my ($self) = shift;

    $log->debugf('if_action: %s', \@_);
    $log->debugf('if_action: first 2 character are "%s"', $self->getRecognizer->input(0, 2));

    return 1
}
sub event_action {
    my ($self) = shift;

    $log->debugf('event_action: %s', \@_);
    $log->debugf('event_action: first 2 character are "%s"', $self->getRecognizer->input(0, 2));

    return 1
}
sub regex_action {
    my ($self) = shift;

    $log->debugf('regex_action: %s', \@_);
    $log->debugf('regex_action: first 2 character are "%s"', $self->getRecognizer->input(0, 2));

    return 0
}
sub generator_action {
    my ($self) = shift;

    $log->debugf('generator_action: %s', \@_);
    $log->debugf('generator_action: first 2 character are "%s"', $self->getRecognizer->input(0, 2));

    return '"XXX"'
}
sub setRecognizer          { my ($self, $recognizer) = @_; $log->debugf('setRecognizer: %s', $recognizer); $self->{recognizer} = $recognizer; }
sub getRecognizer          { my ($self) = shift; $self->{recognizer} }

package MyValueInterface;
use strict;
use diagnostics;
use Log::Any qw/$log/;

sub new                { my ($pkg) = @_; bless { result => undef }, $pkg }
sub isWithHighRankOnly { 1 }
sub isWithOrderByRank  { 1 }
sub isWithAmbiguous    { 0 }
sub isWithNull         { 0 }
sub maxParses          { 0 }
sub getResult          { $_[0]->{result} }
sub setResult          { $_[0]->{result} = $_[1] }

sub do_members {
    my $self = shift;

    my $rc = {};
    map { $rc->{$_->[0]} = $_->[1] } @_;

    return $rc;
}

package main;
use strict;
use warnings FATAL => 'all';
use Test::More;
use Test::More::UTF8;
use Log::Any qw/$log/;
use Log::Any::Adapter 'Stdout';

BEGIN { require_ok('MarpaX::ESLIF') };

my $base_dsl = q{
:default ::= action => ::shift event-action => event_action regex-action => regex_action discard-is-fallback => 1
:start       ::= XXXXXX # Replaced on-the-fly by json or object
:discard ::= perl_comment event => perl_comment$
perl_comment ::= /(?:(?:#)(?:[^\\n]*)(?:\\n|\\z))/u
:symbol   ::= LCURLY if-action => if_action pause => after event => LCURLY$

json         ::= object
               | array
               | . => generator_action->(1, 'x')
object       ::= (- LCURLY -) members (- RCURLY -)
               | OBJECT_FROM_INNER_GRAMMAR action => ::concat
members      ::= pair*                       action => do_members separator => ',' hide-separator => 1
pair         ::= string (- /:(?C0)/ -) value      action => ::row
event value$ = completed <value>
event ^value = predicted <value>
value        ::= string
               | object
               | number
               | array
               | 'true'                         action => ::true
               | 'false'                        action => ::false
               | 'null'                         action => ::undef
array        ::= (- /\[(?C1)/ -)          (- /\](?C2)/ -)   action => ::row
               | (- /\[(?C1)/ -) elements (- /\](?C2)/ -)   action => ::row
elements     ::= value+                         action => ::row separator => ',' hide-separator => 1
number         ~ int
               | int frac
               | int exp
               | int frac exp
int            ~ digits
               | '-' digits
digits         ~ [\d]+
frac           ~ '.' digits
exp            ~ e digits
e              ~ 'e'
               | 'e+'
               | 'e-'
               | 'E'
               | 'E+'
               | 'E-'
string       ::= lstring
:symbol ::= lstring pause => after event => lstring$
lstring        ~ quote in_string quote
quote          ~ '"'
in_string      ~ in_string_char*
in_string_char  ~ [^"] | '\\\\' '"'
:discard       ::= whitespace
whitespace     ~ [\s]+
:symbol ::= LCURLY pause => before event => ^LCURLY
LCURLY         ~ '{'
:symbol ::= RCURLY pause => before event => ^RCURLY
RCURLY         ~ '}'
OBJECT_FROM_INNER_GRAMMAR ~ [^\s\S]
};

my @inputs = (
    "{\"test\":\"1\"}",
    "{\"test\":[1,2,3]}",
    "{\"test\":true}",
    "{\"test\":false}",
    "{\"test\":null}",
    "{\"test\":null, \"test2\":\"hello world\"}",
    "{\"test\":\"1.25\"}",
    "{\"test\":\"1.25e4\"}",
    "[]",
    "[
       {
          \"precision\": \"zip\",
          \"Latitude\":  37.7668,
          \"Longitude\": -122.3959,
          \"Address\":   \"\",
          \"City\":      \"SAN FRANCISCO\",
          \"State\":     \"CA\",
          \"Zip\":       \"94107\",
          \"Country\":   \"US\"
       },
       {
          \"precision\": \"zip\",
          \"Latitude\":  37.371991,
          \"Longitude\": -122.026020,
          \"Address\":   \"\",
          \"City\":      \"SUNNYVALE\",
          \"State\":     \"CA\",
          \"Zip\":       \"94085\",
          \"Country\":   \"US\"
       }
     ]",
    "{
       \"Image\": {
         \"Width\":  800,
         \"Height\": 600,
         \"Title\":  \"View from 15th Floor\",
         \"Thumbnail\": {
             \"Url\":    \"http://www.example.com/image/481989943\",
             \"Height\": 125,
             \"Width\":  \"100\"
         },
         \"IDs\": [116, 943, 234, 38793]
       }
     }",
    "{
       \"source\" : \"<a href=\\\"http://janetter.net/\\\" rel=\\\"nofollow\\\">Janetter</a>\",
       \"entities\" : {
           \"user_mentions\" : [ {
                   \"name\" : \"James Governor\",
                   \"screen_name\" : \"moankchips\",
                   \"indices\" : [ 0, 10 ],
                   \"id_str\" : \"61233\",
                   \"id\" : 61233
               } ],
           \"media\" : [ ],
           \"hashtags\" : [ ],
          \"urls\" : [ ]
       },
       \"in_reply_to_status_id_str\" : \"281400879465238529\",
       \"geo\" : {
       },
       \"id_str\" : \"281405942321532929\",
       \"in_reply_to_user_id\" : 61233,
       \"text\" : \"\@monkchips Ouch. Some regrets are harsher than others.\",
       \"id\" : 281405942321532929,
       \"in_reply_to_status_id\" : 281400879465238529,
       \"created_at\" : \"Wed Dec 19 14:29:39 +0000 2012\",
       \"in_reply_to_screen_name\" : \"monkchips\",
       \"in_reply_to_user_id_str\" : \"61233\",
       \"user\" : {
           \"name\" : \"Sarah Bourne\",
           \"screen_name\" : \"sarahebourne\",
           \"protected\" : false,
           \"id_str\" : \"16010789\",
           \"profile_image_url_https\" : \"https://si0.twimg.com/profile_images/638441870/Snapshot-of-sb_normal.jpg\",
           \"id\" : 16010789,
          \"verified\" : false
       }
     } # Last discard is a perl comment"
    );

my $eslif = MarpaX::ESLIF->new($log);
isa_ok($eslif, 'MarpaX::ESLIF');

my @GRAMMARARRAY;

$log->info('Creating JSON grammar');
{
    my $dsl = $base_dsl;
    $dsl =~ s/XXXXXX/json/smg;
    push(@GRAMMARARRAY, MarpaX::ESLIF::Grammar->new($eslif, $dsl));
}

$log->info('Creating object grammar');
{
    my $dsl = $base_dsl;
    $dsl =~ s/XXXXXX/object/smg;
    push(@GRAMMARARRAY, MarpaX::ESLIF::Grammar->new($eslif, $dsl));
}

foreach (0..$#inputs) {
    my $recognizerInterface = MyRecognizerInterface->new($inputs[$_]);
    my $marpaESLIFRecognizerJson = MarpaX::ESLIF::Recognizer->new($GRAMMARARRAY[0], $recognizerInterface);
    if (! doparse($marpaESLIFRecognizerJson, $inputs[$_], 0)) {
        BAIL_OUT("Failure when parsing:\n$inputs[$_]\n");
    }
}

my $newFromOrshared = 0;
sub doparse {
    my ($marpaESLIFRecognizer, $inputs, $recursionLevel) = @_;
    my $rc;

    if (defined($inputs)) {
        $log->infof('[%d] Scanning JSON', $recursionLevel);
        $log->info ('-------------');
        $log->infof('%s', $inputs);
        $log->info ('-------------');
    } else {
        $log->infof("[%d] Scanning JSON's object", $recursionLevel);
    }
    my $ok = $marpaESLIFRecognizer->scan(1); # Initial events
    while ($ok && $marpaESLIFRecognizer->isCanContinue()) {
        my $events = $marpaESLIFRecognizer->events();
        my $progress = $marpaESLIFRecognizer->progress(-1, -1);
        $log->debugf('Progress: %s', $progress);
        for (my $k = 0; $k < scalar(@{$events}); $k++) {
            my $event = $events->[$k];
            next unless defined($event);
            $log->debugf('Event %s', $event->{event});
            if ($event->{event} eq 'lstring$') {
                my $pauses = $marpaESLIFRecognizer->nameLastPause('lstring');
                my ($line, $column) = $marpaESLIFRecognizer->location();
                $log->debugf("Got lstring: %s; length=%ld, current position is {line, column} = {%ld, %ld}", $pauses, length($pauses), $line, $column);
            }
            elsif ($event->{event} eq '^LCURLY') {
                my $marpaESLIFRecognizerObject;
                if ((++$newFromOrshared) %2 == 0) {
                    $marpaESLIFRecognizerObject = $marpaESLIFRecognizer->newFrom($GRAMMARARRAY[1]);
                } else {
                    $marpaESLIFRecognizerObject = MarpaX::ESLIF::Recognizer->new($GRAMMARARRAY[1], MyRecognizerInterface->new(undef));
                    $marpaESLIFRecognizerObject->share($marpaESLIFRecognizer);
                }
                # Set exhausted flag since this grammar is very likely to exit when data remains
                $marpaESLIFRecognizerObject->set_exhausted_flag(1);
                # Force read of the LCURLY symbol
                $log->debug("LCURLY symbol read");
                #
                # With alternativeRead
                #
                $marpaESLIFRecognizerObject->alternativeRead('LCURLY', '{', 1); # In UTF-8 '{' is one byte
                my $value = doparse($marpaESLIFRecognizerObject, undef, $recursionLevel + 1);
                # Inject object's value
                $log->debugf("Injecting value from sub grammar: %s", $value);
                $log->debug("OBJECT_FROM_INNER_GRAMMAR symbol read");
                #
                # With deprecated method lexemeRead
                #
                $marpaESLIFRecognizer->lexemeRead('OBJECT_FROM_INNER_GRAMMAR', $value, 0); # Stream moved synchroneously
                $marpaESLIFRecognizerObject->unshare();
            }
            elsif ($event->{event} eq '^RCURLY') {
                # Force read of the RCURLY symbol
                $log->debug("RCURLY symbol read");
                $marpaESLIFRecognizer->alternativeRead('RCURLY', '}', 1); # In UTF-8 '}' is one byte
                goto valuation;
            } elsif ($event->{event} eq '^value' || $event->{event} eq 'value$') {
                # No op
            } else {
                $log->errorf('Unmanaged event %s', $event);
                goto err;
            }
        }
        #
        # Check if there is something else to read
        #

        for (my $offset = -3; $offset < 3; $offset++) {
            my $bytes = $marpaESLIFRecognizer->input($offset);
            $log->debugf("input(%d) returns: %s", $offset, $bytes);
            #
            # When offset is 0, it is also the default value
            #
            if ($offset == 0) {
                my $verif = $marpaESLIFRecognizer->input();
                $log->debugf("input()  returns: %s", $verif);
                if ((! defined($bytes)) && defined($verif)) {
                    BAIL_OUT("input($offset) output is not defined but input() output is defined");
                } elsif (defined($bytes) && (! defined($verif))) {
                    BAIL_OUT("input($offset) output is defined but input() output is not defined");
                } elsif (defined($bytes) && ($bytes ne $verif)) {
                    BAIL_OUT("input($offset) != input()");
                }
            }
            for (my $length = -3; $length < 3; $length++) {
                $bytes = $marpaESLIFRecognizer->input($offset, $length);
                $log->debugf("input(%d, %d) returns: %s", $offset, $length, $bytes);
                #
                # When length is 0, it is also the default value
                #
                if ($length == 0) {
                    my $verif = $marpaESLIFRecognizer->input($offset);
                    $log->debugf("input(%d) returns: %s", $offset, $verif);
                    if ((! defined($bytes)) && defined($verif)) {
                        BAIL_OUT("input($offset, 0) output is not defined but input($offset) output is defined");
                    } elsif (defined($bytes) && (! defined($verif))) {
                        BAIL_OUT("input($offset, 0) output is defined but input($offset) output is not defined");
                    } elsif (defined($bytes) && ($bytes ne $verif)) {
                        BAIL_OUT("input($offset, 0) != input($offset)");
                    }
                }
            }
        }

        my $firstByte = $marpaESLIFRecognizer->input(0, 1);
        my $eof = $marpaESLIFRecognizer->isEof;
        if ((! defined($firstByte)) && $eof) {
            goto valuation;
        }
        #
        # Resume
        #
        $ok = $marpaESLIFRecognizer->resume();
    }

  valuation:
    #
    # Call for valuation
    #
    my $valueInterface = MyValueInterface->new();
    my $eslifValue = MarpaX::ESLIF::Value->new($marpaESLIFRecognizer, $valueInterface);
    while ($eslifValue->value()) {
        if (defined($rc)) {
            $log->fatal("[%d] Ambiguous grammar, first value: %s, other value: %s", $recursionLevel, $rc, $valueInterface->getResult());
            die "Ambiguous grammar";
        }
        $rc = $valueInterface->getResult();
        $log->debugf("[%d] Value: %s", $recursionLevel, $rc);
    }
    goto done;

  err:
    $rc = undef;

  done:
    if (defined($rc)) {
        #
        # Get last discarded data
        #
        my $discardLast = $marpaESLIFRecognizer->discardLast;
        $log->debugf("[%d] Last discarded data: %s", $recursionLevel, $discardLast);
    }
    return $rc;
}

done_testing();


