package Spica::Spec::Declare;
use strict;
use warnings;
use Exporter::Lite;

use Spica::Spec;
use Spica::Client;

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

sub _generate_filter_init_builder {
    my (@attributes) = @_;

    return sub {
        my ($spica, $builder) = @_;
        my %param =  map { $_->{origin} => $builder->param->{$_->{name}} }
                    grep { exists $builder->param->{$_->{name}} }
                    @attributes;
        $builder->param(\%param);
        return $builder;
    };
}

sub _generate_filter_init_row_class {
    my (@attributes) = @_;

    return sub {
        my ($spica, $data) = @_;
        my %data = map  { $_->{name} => $data->{$_->{origin}} }
                   grep { $_->{row_accessor} }
                   @attributes;
        return \%data;
    };
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
        my $name = shift;
        my ($method, $path_base, $requires) = @_;
        if (@_ == 1) {
            $method    = $_[0]{method};
            $path_base = $_[0]{path};
            $requires  = $_[0]{requires};
        } else {
            $method = 'GET';
            ($path_base, $requires) = @_;
        }
        if (!$method or !$path_base or !$requires) {
            Carp::croak('Invalid args endpoint.');
        }
        $endpoint{$name} = +{
            method   => $method,
            path     => $path_base,
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

    my (@accessor_names, @attributes);
    while (@client_columns) {
        my $column_name = shift @client_columns;
        my $option = ref $client_columns[0] ? shift @client_columns : +{
            # default generating accessor
            row_accessor => 1,
        };

        push @accessor_names => $column_name if $option->{row_accessor};
        push @attributes => +{
            name         => $column_name,
            origin       => ($option->{from} || $column_name),
            row_accessor => $option->{row_accessor},
        };
    }

    push @{ $filter{init_builder}   } => _generate_filter_init_builder   @attributes;
    push @{ $filter{init_row_class} } => _generate_filter_init_row_class @attributes;

    my $client = Spica::Client->new(
        columns   => \@accessor_names,
        name      => $client_name,
        endpoint  => \%endpoint,
        inflators => \@inflate,
        deflators => \@deflate,
        receiver  => $receiver,
        row_class => $row_class,
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
