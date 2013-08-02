use Test::More;

use_ok $_ for qw(
    Spica
    Spica::Iterator
    Spica::Parser
    Spica::Parser::JSON
    Spica::Row
    Spica::Spec
    Spica::Spec::Client
    Spica::Spec::Declare
    Spica::URIBuilder
);

done_testing;

