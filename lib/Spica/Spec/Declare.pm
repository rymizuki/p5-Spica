package Spica::Spec::Declare;
use strict;
use warnings;
use Exporter::Lite;

use Spica::Spec;
use Spica::Spec::Client;

our @EXPORT = qw(
    spec 
    name
    endpoint
    client
    columns
    receiver
    row_class
    base_row_class
    inflate
    deflate
    trigger
    filter
);

our $CURRENT_SCHEMA_CACHE;

sub spec (&;$) {
    my ($code, $schme_class) = @_;
    local $CURRENT_SCHEMA_CACHE = $schme_class;
    $code->();
    _current_spec();
}

sub base_row_class ($) {
    my $current = _current_spec();
    $current->{__base_row_class} = $_[0];
}

sub row_namespace ($) {
    my $client_name = shift;
    (my $caller = caller(1)) =~ s/::Spec$//;
    join '::' => $caller, 'Row', Spica::Spec::camelize($client_name);
}

sub _current_spec {
    my $class = __PACKAGE__;
    my $spec_class;

    if ($CURRENT_SCHEMA_CACHE) {
        $spec_class = $CURRENT_SCHEMA_CACHE;
    } else {
        my $i = 1;
        while ( $spec_class = caller($i++) ) {
            last unless $spec_class->isa( $class );
        }
    }

    unless ($spec_class) {
        Carp::confess("PANIC: cannot find a package naem this is not ISA ${class}");
    }

    no warnings 'once';
    if (!$spec_class->isa('Spica::Spec')) {
        no strict 'refs'; ## no critic
        push @{"${spec_class}::ISA"} => 'Spica::Spec';

        my $spec = $spec_class->new();
        $spec_class->set_default_instance( $spec );
    }

    return $spec_class->instance;
}

sub columns (@);
sub name ($);
sub endpoint ($$@);
sub receiver ($);
sub row_class ($);
sub inflate ($&);
sub deflate ($&);
sub trigger ($&);
sub filter ($&);
sub client (&) {
    my $code = shift;
    my $current = _current_spec();

    my (
        $client_name,
        @client_columns,
        %endpoint,
        @inflate,
        @deflate,
        %trigger,
        %filter,
        $row_class,
        $receiver,
    );

    my $dest_class = caller();

    my $_name = sub ($) {
        $client_name = shift;
        $row_class = row_namespace($client_name);
        $receiver = 'Spica::Receiver::Iterator';
    };
    my $_columns = sub (@) { @client_columns = @_ };
    my $_receiver = sub ($) { $receiver = $_[0] };
    my $_row_class = sub ($) { $row_class = $_[0] };
    my $_endpoint = sub ($$@) {
        my ($name, $path, $requires);
        if (@_ == 2) {
            $name = 'default';
            ($path, $requires) = @_;
        } else {
            ($name, $path, $requires) = @_;
        }
        $endpoint{$name} = +{
            path     => $path,
            requires => $requires,
        };
    };
    my $_inflate = sub ($@) {
        my ($rule, $code) = @_;
        $rule = qr/^\Q$rule\E$/ if ref $rule ne 'Regexp';
        push @inflate => ($rule, $code);
    };
    my $_deflate = sub ($@) {
        my ($rule, $code) = @_;
        $rule = qr/^\Q$rule\E$/ if ref $rule ne 'Regexp';
        push @deflate => ($rule, $code);
    };
    my $_trigger = sub ($@) {
        my ($name, $code) = @_;
        push @{ ($trigger{$name} ||= []) } => $code;
    };
    my $_filter = sub ($@) {
        my ($name, $code) = @_;
        push @{ ($filter{$name} ||= []) } => $code;
    };

    no strict 'refs'; ## no critic;
    no warnings 'once';
    no warnings 'redefine';

    local *{"${dest_class}::name"}      = $_name;
    local *{"${dest_class}::columns"}   = $_columns;
    local *{"${dest_class}::receiver"}  = $_receiver;
    local *{"${dest_class}::row_class"} = $_row_class;
    local *{"${dest_class}::endpoint"}  = $_endpoint;
    local *{"${dest_class}::inflate"}   = $_inflate;
    local *{"${dest_class}::deflate"}   = $_deflate;
    local *{"${dest_class}::trigger"}   = $_trigger;
    local *{"${dest_class}::filter"}    = $_filter;

    $code->();

    my (@col_names, @col_settings);
    while (@client_columns) {
        my $col_name = shift @client_columns;
        if (ref $col_name) {
            push @col_settings => $col_name;
            $col_name = $col_name->{name};
        }
        push @col_names => $col_name;
    }

    my $client = Spica::Spec::Client->new(
        columns         => \@col_names,
        column_settings => \@col_settings,
        name            => $client_name,
        endpoint        => \%endpoint,
        inflators       => \@inflate,
        deflators       => \@deflate,
        receiver        => $receiver,
        row_class       => $row_class,
        ($current->{__base_row_class} ? (base_row_class => $current->{__base_row_class}) : ()),
    );

    for my $name (keys %trigger) {
        $client->add_trigger($name => $_) for @{ $trigger{$name} };
    }
    for my $name (keys %filter) {
        $client->add_filter($name => $_) for @{ $filter{$name} };
    }

    $current->add_client($client);
}

1;
