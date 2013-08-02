package Spica::URIBuilder;
use strict;
use warnings;
use utf8;

use Mouse;

has scheme => (
    is  => 'ro',
    isa => 'Str',
);

has host => (
    is  => 'ro',
    isa => 'Str',
);

has port => (
    is  => 'ro',
    isa => 'Int',
);

has path_base => (
    is  => 'rw',
    isa => 'Str',
);

has path => (
    is  => 'ro',
    isa => 'Str',
);

has requires => (
    is => 'rw',
    isa => 'ArrayRef[Str]',
    default => sub { [] },
);

has param => (
    is => 'ro',
    isa => 'HashRef',
    default => sub { +{} },
);

has uri => (
    is         => 'ro',
    isa        => 'URI',
    lazy_build => 1,
);

no Mouse;

sub is_invalid_param {
    my ($self, $param) = @_;
    $param ||= +{};
    return grep { !exists $param->{$_} || !defined $param->{$_} } @{ $self->{requires} };
}

sub create {
    my ($self, $param) = @_;

    if (my @invalid_params = $self->is_invalid_param($param)) {
        Carp::croak(sprintf("Invalid paramters. %s is required.", join(',' => @invalid_params)));
    }

    $self->create_path($param);
    $self->uri->path($self->path);
    $self->uri->port($self->port)
        if $self->port && $self->scheme ne 'https';

    return $self;
}

sub create_path {
    my ($self, $param) = @_;

    my $path_base = $self->path_base;

    if ($path_base =~ /\{(?:[0-9a-zA-Z_]+)\}/) {
        for my $column (keys %$param) {
            my $pattern = qr!\{$column\}!;
            next unless $path_base =~ $pattern;

            # TODO: クエリパラメータには不要なはずなのでdel
            my $value = delete $param->{$column};
            $path_base =~ s/$pattern/$value/;
        }
    }

    $self->{path}  = $path_base;
    $self->{param} = $param;

    return $self;
}


sub create_query {
    my $self = shift;

    $self->uri->query_form($self->param);
    $self;
}

sub _build_uri {
    my $self = shift;
    if ($self->scheme && $self->host) {
        return URI->new(sprintf '%s://%s', $self->scheme, $self->host);
    } else {
        return URI->new;
    }
}

1;
