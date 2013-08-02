package Spica::Spec::Client;
use strict;
use warnings;
use utf8;
use feature qw(state);

use Carp ();
use Class::Load ();
use Data::Validator;

use Spica::URIBuilder;
use Spica::Iterator;

use Mouse;

has name => (
    is  => 'rw',
    isa => 'Str'
);
has columns => (
    is  => 'rw',
    isa => 'ArrayRef'
);
has column_settings => (
    is  => 'rw',
    isa => 'ArrayRef',
);
has endpoint  => (
    is      => 'rw',
    isa     => 'HashRef',
);
has deflators => (
    is      => 'ro',
    isa     => 'ArrayRef',
    default => sub { [] }
);
has inflators => (
    is      => 'ro',
    isa     => 'ArrayRef',
    default => sub { [] }
);
has row_class => (
    is  => 'rw',
    isa => 'Str',
);
has receiver => (
    is      => 'rw',
    isa     => 'Str',
);
has base_row_class => (
    is      => 'rw',
    isa     => 'Str',
    default => 'Spica::Row',
);
has trigger => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { +{} },
);

sub BUILD {
    my $self = shift;

    # load row class
    my $row_class = $self->row_class;
    Class::Load::load_optional_class($row_class) or do {
        # make row class automatically
        Class::Load::load_class($self->base_row_class);

        no strict 'refs'; ## no critic
        @{"${row_class}::ISA"} = ($self->base_row_class);
    };

    for my $column (@{ $self->columns }) {
        no strict 'refs'; ## no critic
        unless ($row_class->can($column)) {
            *{"${row_class}::${column}"} = $row_class->generate_column_accessor($column);
        }
    }
    $self->row_class($row_class);

    return $self;
}

no Mouse;

sub add_deflator {
    my ($self, $rule, $code) = @_;
    if (ref $rule ne 'Regexp') {
        $rule = qr/^\Q$rule\E$/;
    }
    unless (ref $code ne 'CODE') {
        Carp::croak('deflate code must be coderef.');
    }
    push @{ $self->{deflators} } => ($rule , $code);
}

sub add_inflator {
    my ($self, $rule, $code) = @_;
    if (ref $rule ne 'Regexp') {
        $rule = qr/^\Q$rule\E$/;
    }
    unless (ref $code ne 'CODE') {
        Carp::croak('inflate code must be coderef.');
    }
    push @{ $self->{inflators} } => ($rule , $code);
}

sub call_deflate {
    my ($self, $col_name, $col_value) = @_;
    my @rules = @{ $self->deflators };
    while(@rules) {
        my $rule = shift @rules;
        my $code = shift @rules;
        if ($col_name =~ /$rule/) {
            return $code->($col_value);
        }
    }
    return $col_value;
}

sub call_inflate {
    my ($self, $col_name, $col_value) = @_;
    my @rules = @{ $self->inflators };
    while (@rules) {
        my $rule = shift @rules;
        my $code = shift @rules;
        if ($col_name =~ /$rule/) {
            return $code->($col_value);
        }
    }
    return $col_value;
}

sub add_trigger {
    state $rule = Data::Validator->new(
        name => 'Str',
        code => 'CodeRef',
    )->with(qw(Method Sequenced));
    my ($self, $args) = $rule->validate(@_);

    my $name = $args->{name};
    my $code = $args->{code};

    push @{ $self->trigger->{$name} } => $code;
}

sub call_trigger {
    state $rule = Data::Validator->new(
        name    => 'Str',
        args    => +{isa => 'HashRef', default => sub { +{} }},
        context => +{isa => 'Spica', optional => 1},
    )->with(qw(Method));
    my ($self, $args) = $rule->validate(@_);

    my $name = $args->{name};
    my $context = exists $args->{context} ? $args->{context} : undef;

    for my $code (@{ $self->trigger->{$name} }) {
        $code->($args->{args}, $context);
    }
}

1;
