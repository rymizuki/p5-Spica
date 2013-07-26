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

has host  => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);
has scheme => (
    is => 'ro',
    isa => 'Str',
    default => 'http',
);
has port => (
    is => 'ro',
    isa => 'Str',
    default => 80,
);
has token => (
    is       => 'ro',
    isa      => 'Str',
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
has cache_period => (
    is      => 'ro',
    isa     => 'Int',
    default => 0,
);
has agent => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => sub { "Spica $VERSION" },
);
has base_path => (
    is      => 'ro',
    isa     => 'Str',
    default => '',
);
has suppress_object_creation => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

has default_param => (
    is         => 'ro',
    isa        => 'HashRef',
    auto_deref => 1,
    lazy_build => 1,
);

has schema => (
    is         => 'ro',
    isa        => 'Spica::Schema',
    lazy_build => 1,
);
has parser => (
    is         => 'ro',
    lazy_build => 1,
);
has client => (
    is         => 'ro',
    isa        => 'Furl::HTTP',
    lazy_build => 1,
);

no Mouse;

sub single {
    my ($self, @args) = @_;

    my (@path, $param, $option);
    while (@args) {
        if (ref $args[0] && ref $args[0] eq 'HASH') {
            $param  = shift @args;
            $option = shift @args;
        } else {
            push @path => shift @args;
        }
    }
    my $category_name = $path[0];

    my $category = $self->schema->get_category($category_name)
        or Carp::croak("No such category $category_name");
    my $suppres_object_creation = exists $option->{suppress_object_creation}
        ? delete $option->{suppress_object_creation}
        : $self->suppress_object_creation;

    my $path = exists $option->{path} ? $option->{path} : $self->make_path(@path);
    my $content = $self->fetch_raw($path, $param, $option);

    if ($suppres_object_creation) {
        return $content;
    } else {
        return $self->schema->get_row_class($category_name)->new(
            row_data       => $content,
            spica          => $self,
            category       => $category,
            category_name  => $category_name,
        );
    }
}

sub search {
    my ($self, @args) = @_;

    my (@path, $param, $option);
    while (@args) {
        if (ref $args[0] && ref $args[0] eq 'HASH') {
            $param  = shift @args;
            $option = shift @args;
        } else {
            push @path => shift @args;
        }
    }

    my $category_name = $path[0];
    my $category = $self->schema->get_category($category_name)
        or Carp::croak("No such category $category_name");
    my $suppres_object_creation = exists $option->{suppress_object_creation}
        ? delete $option->{suppress_object_creation}
        : $self->suppress_object_creation;

    my $path = exists $option->{path} ? $option->{path} : $self->make_path(@path);
    my $content = $self->fetch_raw($path, $param, $option);

    my $iterator = Spica::Iterator->new(
        data                     => $content,
        spica                    => $self,
        row_class                => $self->schema->get_row_class($category_name),
        category                 => $self->schema->get_category($category_name),
        category_naem            => $category_name,
        suppress_object_creation => $suppres_object_creation,
    );

    return wantarray ? $iterator->all : $iterator;
}

sub fetch_raw {
    my ($self, $path, $param, $option) = @_;

    my ($minor_version, $code, $msg, $headers, $body) = $self->client->request(
        method     => 'GET',
        scheme     => $self->scheme,
        host       => $self->host,
        port       => $self->port,
        path_query => $self->uri_for($path, $param),
    );

    if ($code != 200) {
        # throw Exception
        warn $body;
        Carp::croak("Invalid response. code is '$code'");
    }

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
    my $parser_class = $self->{parser_class};
    Class::Load::load_class( $parser_class );

    return $parser_class;
}

use Furl::HTTP;
sub _build_client {
    my $self = shift;
    return Furl::HTTP->new(
        agent => $self->agent,
    );
}

sub _build_default_param {
    my $self = shift;

    return +{
        token => $self->token,
    };
}

1;
