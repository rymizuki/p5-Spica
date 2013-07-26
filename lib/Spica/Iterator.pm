package Spica::Iterator;
use strict;
use warnings;
use 5.10.0;

use Mouse;

has spica => (is => 'ro');
has row_class => (is => 'ro');
has category => (is => 'ro');
has category_name => (is => 'ro');
has suppress_object_creation => (
    is => 'rw',
    isa => 'Bool',
    default => 0,
);
has data => (
    is => 'ro',
    isa => 'ArrayRef',
    required => 1,
);
has pager => (
    is => 'ro',
    isa => 'HashRef|Undef'
);

has position => (is => 'ro', isa => 'Int', required => 0, default => 0);

around BUILDARGS => sub {
    my $origin = shift;
    my $class  = shift;
    my %args = @_;

    if (!$args{data}) {
        $args{data} = [];
    } elsif (ref $args{data} eq 'HASH') {
        $args{data} = [$args{data}];
    }

    return $class->$origin(%args);
};

no Mouse;

sub next {
    my $self = shift;

    my $row = $self->{data}[$self->{position}++];

    unless ($row) {
        $self->{position} = 0;
        return;
    }

    if ($self->{suppress_object_creation}) {
        return $row;
    } else {
        return $self->{row_class}->new(
            row_data       => $row,
            spica          => $self->spica,
            category       => $self->category,
            category_name  => $self->category_name,
            select_columns => $self->{select_columns},
        );
    }
}

sub all {
    my $self = shift;

    my $results = [];

    if ($self->{data}) {
        $results = $self->{data};

        if (!$self->{suppress_object_creation}) {
            $results = [
                map {
                    $self->{row_class}->new(
                        row_data       => $_,
                        spica          => $self->spica,
                        category       => $self->category,
                        category_name  => $self->category_name,
                        select_columns => $self->{select_columns},
                    )
                } @$results
            ];
        }
    }

    return wantarray ? @$results : $results;
}

1;
