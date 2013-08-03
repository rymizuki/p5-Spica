use Test::More;

use_ok $_ for qw(
    Spica
    Spica::Parser
    Spica::Parser::JSON
    Spica::Receiver::Iterator
    Spica::Receiver::Row
    Spica::Spec
    Spica::Spec::Client
    Spica::Spec::Declare
    Spica::URIBuilder
);

done_testing;

