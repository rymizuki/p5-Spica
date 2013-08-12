package Spica;
use strict;
use warnings;
use utf8;
our $VERSION = '0.01';

use Spica::Client;
use Spica::Receiver::Iterator;
use Spica::Types qw(
    SpecClass
    ParserClass
);
use Spica::URIMaker;

use Furl;

use Mouse;

# -------------------------------------------------------------------------
# fetcher's args
# -------------------------------------------------------------------------
has host => (
    is  => 'ro',
    isa => 'Str',
);
has scheme => (
    is      => 'ro',
    isa     => 'Str',
    default => 'http',
);
has port => (
    is  => 'ro',
    isa => 'Int|Undef',
);
has agent => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    default => "Spica $VERSION",
);
has default_param => (
    is         => 'ro',
    isa        => 'HashRef',
    auto_deref => 1,
    default    => sub { +{} },
);
has default_headers => (
    is      => 'ro',
    isa     => 'ArrayRef',
    default => sub { [] },
);

# -------------------------------------------------------------------------
# spica behavior's args
# -------------------------------------------------------------------------
has no_throw_http_exception => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);
has is_suppress_object_creation => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);
has spec => (
    is        => 'ro',
    isa       => SpecClass,
    coerce    => 1,
    predicate => 'has_spec',
);
has parser => (
    is      => 'rw',
    isa     => ParserClass,
    coerce  => 1,
    lazy    => 1,
    default => 'Spica::Parser::JSON',
);

# -------------------------------------------------------------------------
# auto build args
# -------------------------------------------------------------------------
has uri_builder => (
    is         => 'ro',
    isa        => 'Spica::URIMaker',
    lazy_build => 1,
);
has fetcher => (
    is         => 'rw',
    isa        => 'Furl',
    lazy_build => 1,
);

no Mouse;

# $spica->fetch($url, $param);
# $spica->fetch($client_name, $param);
# $spica->fetch($client_name, $endpoint_name, $param);
sub fetch {
    my $self        = shift;

    # get client
    my $client_name = shift;
    my $client = $self->get_client($client_name);

    # parseing args
    my ($endpoint_name, $param) = (ref $_[0] && ref $_[0] eq 'HASH' ? ('default', @_) : @_);

    # get endpoint
    my $endpoint = $client->get_endpoint($endpoint_name)
        or Carp::croak("No such enpoint ${endpoint_name}.");
    my $method = $endpoint->{method};

    # init uri builder
    my $builder = $self->uri_builder->new_uri->create(
        path_base => $endpoint->{path},
        requires  => $endpoint->{requires}, 
        param     => +{ $self->default_param => %$param },
    );
    if ($method eq 'GET' || $method eq 'HEAD' || $method eq 'DELETE') {
        # `content` is not available, I will grant `path_query`.
        # make `path_query` and delete `content` params.
        $builder->create_query;
    }

    # execute request
    my $response = $self->_execute_request($client, $method, $builder);

    # execute parseing
    my $data = $self->_execute_parsing($client, $response);

    # execute receive
    return $self->_execute_receive($client, $data);
}

sub get_client {
    my ($self, $client_name) = @_;

    if ($self->has_spec) {
        return $self->spec->get_client($client_name)
            or Carp::croak("No such client ${client_name}.");
    } else {
        # XXX: Create client and endpoint.
        return Spica::Client->new(
            name     => 'default',
            endpoint => +{
                'default' => +{
                    method   => 'GET',
                    path     => $client_name,
                    requires => [],
                },
            },
        );
    }
}

sub _execute_request {
    my ($self, $client, $method, $builder) = @_;

    {
        # hookpoint:
        #   name: `before_request`
        #   args: ($client isa 'Spica::Client', $builder isa `Spica::URIMaker`)
        $client->call_trigger('before_request' => ($self, $builder));
        $builder = $client->call_filter('before_request' => ($self, $builder));
    }

    my $response = $self->fetcher->request(
        method  => $method,
        url     => $builder->as_string,
        content => $builder->content || $builder->param,
        headers => $self->default_headers, # TODO: custom any header use.
    );

    {
        # hookpoint:
        #   name: `after_request`
        #   args: ($client isa 'Spica::Client', $response isa `Furl::Response`)
        $client->call_trigger('after_request' => ($self, $response));
        $response = $client->call_filter('after_request' => ($self, $response));
    }

    if (!$response->is_success && !$self->no_throw_http_exception) {
        # throw Exception
        Carp::croak("Invalid response. code is '@{[$response->status]}'");
    }

    return $response;
}

sub _execute_parsing {
    my ($self, $client, $response) = @_;
    return $self->parser->parse($response->content);
}

sub _execute_receive {
    my ($self, $client, $data) = @_;

    if ($self->is_suppress_object_creation) {
        return $data;
    } else {
        {
            # hookpoint:
            #   name: `before_receive`.
            #   args: ($client isa 'Spica::Client', $data isa 'ArrayRef|HashRef')
            $client->call_trigger('before_receive' => ($self, $data));
            $data = $client->call_filter('before_receive' => ($self, $data));
        }

        my $iterator = $client->receiver->new(
            data                     => $data,
            spica                    => $self,
            row_class                => $client->row_class,
            client                   => $client,
            client_name              => $client->name,
            suppress_object_creation => $self->is_suppress_object_creation,
        );

        return wantarray ? $iterator->all : $iterator;
    }
}

# -------------------------------------------------------------------------
# builders
# -------------------------------------------------------------------------
sub _build_uri_builder {
    my $self = shift;
    return Spica::URIMaker->new(
        scheme => $self->scheme,
        host   => $self->host,
        ($self->port && $self->scheme ne 'https' ? (port => $self->port) : ()),
    );
}

sub _build_fetcher {
    my $self = shift;
    return Furl->new(
        agent => $self->agent,
    );
}

1;
