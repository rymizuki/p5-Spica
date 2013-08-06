package Spica;
use strict;
use warnings;
use utf8;
our $VERSION = '0.01';

use Carp ();
use URI;

use Spica::Receiver::Iterator;
use Spica::URIBuilder;
use Spica::Types qw(
    SpecClass
    ParserClass
);

use Mouse;

#
# API's common properties.
# -------------------------------------------------------------------------
has host  => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);
has scheme => (
    is      => 'ro',
    isa     => 'Str',
    default => 'http',
);
has port => (
    is      => 'ro',
    isa     => 'Int',
    default => 80,
);
has base_path => (
    is      => 'ro',
    isa     => 'Str',
    default => '',
);
has default_param => (
    is         => 'ro',
    isa        => 'HashRef',
    default    => sub { +{} },
    auto_deref => 1,
);

#
# Agent's properties
# -------------------------------------------------------------------------
has agent => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    default => "Spica $VERSION",
);

#
# Spica's properties
# -------------------------------------------------------------------------
has suppress_object_creation => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

has spec => (
    is         => 'rw',
    isa        => SpecClass,
    coerce     => 1,
    lazy       => 1,
    default    => sub { "@{[ref $_[0] ? ref $_[0] : $_[0]]}::Spec" },
);

has parser => (
    is         => 'rw',
    isa        => ParserClass,
    coerce     => 1,
    default    => 'Spica::Parser::JSON',
);
has fetcher => (
    is         => 'rw',
    isa        => 'Furl',
    lazy_build => 1,
);

no Mouse;

sub fetch {
    my ($self, $client_name, $endpoint_name, $param, $option) = @_;

    if (ref $endpoint_name && ref $endpoint_name eq 'HASH') {
        $option = $param;
        $param  = $endpoint_name;
        $endpoint_name = 'default';
    }

    my $client = $option->{client} = $self->spec->get_client($client_name)
        or Carp::croak("No such client $client_name");

    my $uri_builder = Spica::URIBuilder->new(
        scheme    => $self->scheme,
        host      => $self->host,
        port      => $self->port,
        path_base => $client->endpoint->{$endpoint_name}{path},
        requires  => $client->endpoint->{$endpoint_name}{requires},
    )->create(+{ $self->default_param => %$param });

    return $self->execute('GET', $uri_builder, $option);
}

sub execute {
    my $self   = shift;
    my $method = shift;

    my ($builder, $option) = sub {
        my $builder;
        if (ref $_[0] && $_[0]->isa('Spica::URIBuilder')) {
            $builder = shift @_;
        } else {
            $builder = Spica::URIBuilder->new(
                scheme    => $self->scheme,
                host      => $self->host,
                port      => $self->port,
                path_base => shift(@_),
            )->create(shift(@_) || +{});
        }

        return ($builder, shift(@_) || +{});
    }->(@_);

    my $client = $option->{client};

    my $response = $self->request($method, $builder);

    if (!$response->is_success) {
        # throw Exception
        Carp::croak("Invalid response. code is '@{[$response->status]}'");
    }

    my $data = $self->parse($response->content);

    if ($client) {
        $client->call_trigger(before_receive => ($self, $data));
        for my $code ($client->get_filter_code('before_receive')) {
            $data = $code->($self, $data);
        }
    }

    my $suppres_object_creation = exists $option->{suppress_object_creation}
        ? $option->{suppress_object_creation}
        : $self->suppress_object_creation
        ;

    if (!$client || $suppres_object_creation) {
        return $data;
    } else {
        my $iterator = $client->receiver->new(
            data                     => $data,
            spica                    => $self,
            row_class                => $self->spec->get_row_class($client->name),
            client                   => $client,
            client_name              => $client->name,
            suppress_object_creation => $suppres_object_creation,
        );

        return wantarray ? $iterator->all : $iterator;
    }
}

sub request {
    my ($self, $method, $builder) = @_;

    if ($method eq 'GET' && keys %{ $builder->param }) {
        # CONTENT is not available, I will gran PATH_QUERY.
        # make PATH_QUERY and delete PARAMS,
        $builder->create_query;
    }

    my $response = $self->fetcher->request(
        method  => $method,
        url     => $builder->uri->as_string,
        content => $builder->param,
        headers => [], # TODO custom any header use.
    );

    return $response;
}

sub parse {
    my ($self, $body) = @_;
    return $self->parser->parse($body);
}

use Furl;
sub _build_fetcher {
    my $self = shift;
    return Furl->new(
        agent => $self->agent,
    );
}

1;
