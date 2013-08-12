package Spica::Receiver::Row;
use strict;
use warnings;
use utf8;

use Carp ();

use Mouse;

has data => (
    is      => 'ro',
    isa     => 'HashRef',
    default => sub { +{} },
);
has select_columns => (
    is      => 'ro',
    isa     => 'ArrayRef',
    default => sub {
        return [keys %{ shift->data }],
    },
);
has spica => (
    is  => 'ro',
    isa => 'Spica',
);
has client => (
    is      => 'ro',
    isa     => 'Spica::Client',
    lazy    => 1,
    default => sub {
        my $self = shift;
        return $self->spica->spec->get_client($self->client_name);
    },
);
has client_name => (
    is  => 'ro',
    isa => 'Str',
);

sub BUILD {
    my $self = shift;

    # inflated values
    $self->{_get_column_cached} = +{};
    # values will be updated
    $self->{_dirty_columns} = +{};
    $self->{_autoload_column_cache} = +{};

    if (@{ $self->client->column_settings }) {
        $self->{data_origin} = $self->{data};

        for my $column (@{ $self->client->column_settings }) {
            my $name = $column->{name};
            my $from = $column->{from};
            $self->{data}{$name} = $self->{data_origin}{$from};
        }
    }
}

no Mouse;

our $AUTOLOAD;

sub generate_column_accessor {
    my ($x, $column) = @_;

    return sub {
        my $self = shift;

        # setter is alias of set_column (not deflate column) for historical reason
        return $self->set_column($column => @_) if @_;

        # getter is alias of get (inflate column)
        return $self->get($column);
    };
}

sub handle { $_[0]->spica }

sub get {
    my ($self, $column) = @_;

    # "Untrusted" means the row is set_column by scalarref
    if ($self->{_untrusted_data}{$column}) {
        Carp::carp("${column}'s row data is untrusted. by your update query.");
    }
    my $cache = $self->{_get_column_cached};
    my $data = $cache->{$column};

    unless ($data) {
        $data = $cache->{$column} = $self->client ?
            $self->client->call_inflate($column => $self->get_column($column)) :
            $self->get_column($column);
    }

    return $data;
}

sub set {
    my ($self, $column, $value) = @_;
    $self->set_column($column => $self->client->call_deflate($column, $value));
    delete $self->{_get_column_cached}{$column};
    return $self;
}

sub get_column {
    my ($self, $column) = @_;

    unless ($column) {
        Carp::croak('Please specify $column for first argument.');
    }

    if (exists $self->{data}{$column}) {
        if (exists $self->{_dirty_columns}{$column}) {
            return $self->{_dirty_columns}{$column};
        } else {
            return $self->{data}{$column};
        }
    } else {
        Carp::croak("Specified column '${column}'");
    }
}

sub get_columns {
    my $self = shift;

    my %data;
    for my $column (@{ $self->select_columns }) {
        $data{$column} = $self->get_column($column);
    }
    return \%data;
}

sub set_column {
    my ($self, $column, $value) = @_;

    if (defined $self->{data}{$column} && defined $value && $self->{data}{$column} eq $value) {
        return $value;
    }

    if (ref $value eq 'SCALAR') {
        $self->{_untrusted_data}{$column} = 1;
    }

    delete $self->{_get_column_cached}{$column};
    $self->{_dirty_columns}{$column} = $value;

    return $value;
}

sub set_columns {
    my ($self, $args) = @_;

    for my $column (keys %$args) {
        $self->set_column($column => $args->{$column});
    }
}

sub get_dirty_columns {
    my $self = shift;
    return +{
        %{ $self->{_dirty_columns} },
    };
}

# for +columns option by some search methods
sub AUTOLOAD {
    my $self = shift;
    my ($method) = ($AUTOLOAD =~ /([^:']+$)/);
    ($self->{_autoload_column_cache}{$method} ||= $self->generate_column_accessor($method))->($self);
}

### don't autoload this
sub DESTROY { 1 };

1;
