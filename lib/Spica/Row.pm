package Spica::Row;
use strict;
use warnings;

use Carp ();

our $AUTOLOAD;

sub new {
    my ($class, %args) = @_;
    my $self = bless {
        # inflated values
        _get_column_cached => +{},
        # values will be updated
        _dirty_columns => +{},
        _autoload_column_cache => +{},
        %args,
    } => $class;

    $self->{select_columns} ||= [keys %{ $args{row_data} }];
    $self->{category} ||= $args{spica}->schema->get_category($args{category_name});

    return $self;
}

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

sub handle { $_[0]->{spica} }

sub get {
    my ($self, $column) = @_;

    # "Untrusted" means the row is set_column by scalarref
    if ($self->{_untrusted_row_data}{$column}) {
        Carp::carp("${column}'s row data is untrusted. by your update query.");
    }
    my $cache = $self->{_get_column_cached};
    my $data = $cache->{$column};

    unless ($data) {
        $data = $cache->{$column} = $self->{category} ?
            $self->{category}->call_inflate($column => $self->get_column($column)) :
            $self->get_column($column);
    }

    return $data;
}

sub set {
    my ($self, $column, $value) = @_;
    $self->set_column($column => $self->{category}->call_deflate($column, $value));
    delete $self->{_get_column_cached}{$column};
    return $self;
}

sub get_column {
    my ($self, $column) = @_;

    unless ($column) {
        Carp::croak('Please specify $column for first argument.');
    }

    if (exists $self->{row_data}{$column}) {
        if (exists $self->{_dirty_columns}{$column}) {
            return $self->{_dirty_columns}{$column};
        } else {
            return $self->{row_data}{$column};
        }
    } else {
        Carp::croak("Specified column '${column}'");
    }
}

sub get_columns {
    my $self = shift;

    my %data;
    for my $column (@{ $self->{select_columns} }) {
        $data{$column} = $self->get_column($column);
    }
    return \%data;
}

sub set_column {
    my ($self, $column, $value) = @_;

    if (defined $self->{row_data}{$column} && defined $value && $self->{row_data}{$column} eq $value) {
        return $value;
    }

    if (ref $value eq 'SCALAR') {
        $self->{_untrusted_row_data}{$column} = 1;
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
