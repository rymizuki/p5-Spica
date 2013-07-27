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
        Spica::Schema::Category
        Spica::Schema::Declare
    );
}

done_testing
