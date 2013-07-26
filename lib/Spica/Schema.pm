package Spica::Schema;
use strict;
use warnings;
use Spica::Row;

use Mouse;

has category => (
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

sub add_category {
    my ($self, $category) = @_;
    return $self->{category}{$category->name} = $category;
}

sub get_category {
    my ($self, $name) = @_;
    return unless $name;
    return $self->{category}{$name};
}

sub get_row_class {
    my ($self, $category_name) = @_;

    my $category = $self->{category}{$category_name};
    return $category->{row_class} if $category;
    return 'Spica::Row';
}

sub camelize {
    my $s = shift;
    return join '' => map { ucfirst $_ } split(/(?<=[A-Za-z])_(?=[A-Za-z])|\b/, $s);
}

1;
