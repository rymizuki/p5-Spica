use Test::More;
use Test::Requires
    'Test::Fake::HTTPD',
    'HTTP::Request';

use Spica;

my $api = run_http_server {
    my $req = shift;

    return HTTP::Response->new(
        '200',
        'OK',
        ['Content-Type' => 'application/json'],
        '{"result": "success", "message": "hello world.\n"}',
    );
};

{
    package Mock::BasicALLINONE::Schema;
    use Spica::Schema::Declare;

    client {
        name 'mock_basic';
        endpoint '/' => [];
        columns qw(
            result
            message
        );
    };

    1;

}

{
    package Mock::BasicALLINONE::Row::MockBasic;
    use parent 'Spica::Row';

    1;
}

my $spica = Spica->new(
    host => '127.0.0.1',
    port => $api->port,
    schema_class => 'Mock::BasicALLINONE::Schema',
);

my $iter = $spica->fetch('mock_basic', +{});
isa_ok $iter => 'Spica::Iterator';

my $row = $iter->next;
isa_ok $row => 'Mock::BasicALLINONE::Row::MockBasic';
is $row->result => 'success';
is $row->message => "hello world.\n";

done_testing();
