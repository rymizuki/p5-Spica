package Spica::Schema;
use strict;
use warnings;
use Spica::Row;

use Mouse;

# XXX: $self->clientで呼び出すとSchema::Declare::client呼び出してしまう
has client => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { +{} },
);

has namespace => (
    is      => 'rw',
    isa     => 'Str',
    default => '',
);

no Mouse;

sub set_default_instance {
    my ($class, $instance) = @_;
    no strict 'refs'; ## no critic
    no warnings 'once';
    return ${"${class}::DEFAULT_INSTANCE"} = $instance;
}

sub instance {
    my $class = shift;
    no strict 'refs'; ## no critic
    no warnings 'once';
    return ${"${class}::DEFAULT_INSTANCE"};
}

sub add_client {
    my ($self, $client) = @_;
    return $self->{client}{$client->name} = $client;
}

sub get_client {
    my ($self, $name) = @_;
    return unless $name;
    return $self->{client}{$name};
}

sub get_row_class {
    my ($self, $client_name) = @_;

    my $client = $self->{client}{$client_name};
    return $client->{row_class} if $client;
    return 'Spica::Row';
}

sub camelize {
    my $s = shift;
    return join '' => map { ucfirst $_ } split(/(?<=[A-Za-z])_(?=[A-Za-z])|\b/, $s);
}

1;
