use Test::More;
use Test::Fake::HTTPD;
use HTTP::Response;

my $api = run_http_server {
    my $req = shift;

    if ($req->uri->path eq '/1') {
        return HTTP::Response->new(
            200,
            'OK',
            [],
            '{"id":1, "name":"perl"}',
        );
    } else {
        return HTTP::Response->new(
            200,
            'OK',
            [],
            '[{"id":1, "name":"perl"},{"id":2, "name":"ruby"}]',
        );
    }
};

{
    package Mock::Spec;
    use Spica::Spec::Declare;

    client {
        name 'mock';
        endpoint 'root', '/{id}', ['id'];
        columns qw(
            id
            name
        );
    };
}

use Spica;
use Spica::URIBuilder;

my $spica = Spica->new(host => '127.0.0.1', port => $api->port);

subtest 'array results' => sub {
    my $results = $spica->execute('GET', '/', +{});
    isa_ok $results => 'ARRAY';

    is $results->[0]{id}   => 1;
    is $results->[0]{name} => 'perl';
    is $results->[1]{id}   => 2;
    is $results->[1]{name} => 'ruby';
};
subtest 'hash result' => sub {
    my $result = $spica->execute('GET', '/{id}', +{id => 1});
    isa_ok $result => 'HASH';

    is $result->{id} => 1;
    is $result->{name} => 'perl';
};

done_testing();
