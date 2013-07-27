package Spica::URIBuilder;
use strict;
use warnings;
use utf8;

use Mouse;

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
    $self->create_uri;

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

sub create_uri {
    my $self = shift;

    $self->uri->path($self->path);
    $self->uri->query_form($self->param);

    $self;
}

sub _build_uri {
    my $lsef = shift;
    return URI->new;
}

1;
