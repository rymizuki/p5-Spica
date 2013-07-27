use strict;
use Test::More;

BEGIN {
    use_ok($_) for qw(
        Spica
        Spica::Iterator
        Spica::Parser
        Spica::Parser::JSON
        Spica::Row
        Spica::Schema
        Spica::Schema::Client
        Spica::Schema::Declare
        Spica::URIBuilder
    );
}

done_testing
