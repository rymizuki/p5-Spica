package Spica;
use strict;
use warnings;
use utf8;
our $VERSION = '0.01';

use Spica::Iterator;

use Carp ();
use Class::Load ();
use URI;

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

has schema_class => (
    is      => 'ro',
    isa     => 'Str',
    default => sub { "@{[ ref $_[0] ? ref $_[0] : $_[0] ]}::Schema" },
);
has parser_class => (
    is      => 'ro',
    isa     => 'Str',
    default => 'Spica::Parser::JSON',
);

has schema => (
    is         => 'rw',
    isa        => 'Spica::Schema',
    lazy_build => 1,
);
has parser => (
    is         => 'rw',
    isa        => 'Object',
    lazy_build => 1,
);
has fetcher => (
    is         => 'rw',
    isa        => 'Furl::HTTP',
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

    my $client = $self->schema->get_client($client_name)
        or Carp::croak("No such client $client_name");
    my $suppres_object_creation = exists $option->{suppress_object_creation}
        ? delete $option->{suppress_object_creation}
        : $self->suppress_object_creation;

    my $uri_builder = $client->get_uri_builder($endpoint_name)->create($param);

    my $content = $self->request('GET', $uri_builder, $option);

    my $iterator = Spica::Iterator->new(
        data                     => $content,
        spica                    => $self,
        row_class                => $self->schema->get_row_class($client_name),
        client                   => $self->schema->get_client($client_name),
        client_naem              => $client_name,
        suppress_object_creation => $suppres_object_creation,
    );

    return wantarray ? $iterator->all : $iterator;
}

sub save {
    my ($self, $client_name, $endpoint_name, $param, $option) = @_;

    if (ref $endpoint_name && ref $endpoint_name eq 'HASH') {
        $option = $param;
        $param  = $endpoint_name;
        $endpoint_name = 'default';
    }

    my $client = $self->schema->get_client($client_name)
        or Carp::croak("No such client $client_name");
    my $suppres_object_creation = exists $option->{suppress_object_creation}
        ? delete $option->{suppress_object_creation}
        : $self->suppress_object_creation;

    my $uri_builder = $client->get_uri_builder($endpoint_name)->create($param);

    my $content = $self->request('POST', $uri_builder, $option);

    if ($suppres_object_creation) {
        return $content;
    } else {
        return $self->schema->get_row_class($client_name)->new(
            row_data       => $content,
            spica          => $self,
            client         => $client,
            client_naem    => $client_name,
            select_columns => $self->{select_columns},
        );
    }
}

sub request {
    my ($self, $method, $path, $param, $option) = @_;

    # XXX: umm...
    my $uri_builder;
    if (ref $path && ref $path eq 'Spica::URIBuilder') {
        $uri_builder = $path;
        # XXX $self->request('GET', $builder, \%options);
        $option = $param;
    } else {
        $uri_builder = Spica::URIBuilder->new(
            path  => $path,
            param => $param,
        );
    }

    my %content;
    if ($method eq 'GET') {
        %content = ();
        $uri_builder->create_query;
    } elsif ($method eq 'POST') {
        %content = %{ $uri_builder->param };
    }

    my ($minor_version, $code, $msg, $headers, $body) = $self->fetcher->request(
        method     => $method,
        scheme     => $self->scheme,
        host       => $self->host,
        ($self->scheme eq 'https' ? () : (port => $self->port)),
        path_query => $uri_builder->uri->path_query,
        content    => \%content,
    );

    if ($code != 200) {
        # throw Exception
        Carp::croak("Invalid response. code is '$code'");
    }

    return $self->parse($body);
}

sub parse {
    my ($self, $body) = @_;
    return $self->parser->parse($body);
}

sub make_path {
    my $self = shift;
    return join '/' => $self->base_path, @_;
}

sub uri_for {
    my ($self, $path, $param) = @_;

    $param ||= +{};
    $param = +{ $self->default_param => %$param };

    my $uri = URI->new($path);
    $uri->query_form(+{ $uri->query_form => %$param });

    return $uri;
}

sub _build_schema {
    my $self = shift;
    my $schema_class = $self->{schema_class};
    Class::Load::load_class( $schema_class );
    my $schema = $schema_class->instance;

    if (!$schema) {
        Carp::croak("schema object was not passed, and could not get schema instance from ${schema_class}");
    }

    $schema->namespace(ref $self ? ref $self : $self);
    return $schema;
}

sub _build_parser {
    my $self = shift;
    my $parser_class = $self->parser_class;
    Class::Load::load_class( $parser_class );

    return $parser_class->new;
}

use Furl::HTTP;
sub _build_fetcher {
    my $self = shift;
    return Furl::HTTP->new(
        agent => $self->agent,
    );
}

1;
