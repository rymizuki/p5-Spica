use Test::More;
use Spica::Schema::Declare;

subtest 'edge case' => sub {
    my $klass = 'Spica::Test::Declare002Schema';
    my $schema = schema {
        client {
            name 'foo';
        };
    } $klass;

    ok $schema;
    isa_ok $schema => $klass;

    ok ! $schema->get_client('bar'), "non exists client should return undef";
    ok ! $schema->get_client(), "no name given should return undef";
};

done_testing;
