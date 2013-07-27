package Spica::Schema::Declare;
use strict;
use warnings;
use Exporter::Lite;
use Spica::Schema;
use Spica::Schema::Client;

our @EXPORT = qw(
    schema
    name
    endpoint
    client
    columns
    row_class
    base_row_class
    inflate
    deflate
);

our $CURRENT_SCHEMA_CACHE;

sub schema (&;$) {
    my ($code, $schme_class) = @_;
    local $CURRENT_SCHEMA_CACHE = $schme_class;
    $code->();
    _current_schema();
}

sub base_row_class ($) {
    my $current = _current_schema();
    $current->{__base_row_class} = $_[0];
}

sub row_namespace ($) {
    my $client_name = shift;
    (my $caller = caller(1)) =~ s/::Schema$//;
    join '::' => $caller, 'Row', Spica::Schema::camelize($client_name);
}

sub _current_schema {
    my $class = __PACKAGE__;
    my $schema_class;

    if ($CURRENT_SCHEMA_CACHE) {
        $schema_class = $CURRENT_SCHEMA_CACHE;
    } else {
        my $i = 1;
        while ( $schema_class = caller($i++) ) {
            last unless $schema_class->isa( $class );
        }
    }

    unless ($schema_class) {
        Carp::confess("PANIC: cannot find a package naem this is not ISA ${class}");
    }

    no warnings 'once';
    if (!$schema_class->isa('Spica::Schema')) {
        no strict 'refs'; ## no critic
        push @{"${schema_class}::ISA"} => 'Spica::Schema';

        my $schema = $schema_class->new();
        $schema_class->set_default_instance( $schema );
    }

    return $schema_class->instance;
}

sub columns (@);
sub name ($);
sub endpoint ($$@);
sub row_class ($);
sub inflate_rule ($@);
sub client (&) {
    my $code = shift;
    my $current = _current_schema();

    my (
        $client_name,
        @client_columns,
        %endpoint,
        @inflate,
        @deflate,
        $row_class,
    );
    no warnings 'redefine';

    my $dest_class = caller();
    no strict 'refs'; ## no critic;
    no warnings 'once';
    local *{"${dest_class}::name"} = sub ($) {
        $client_name = shift;
        $row_class = row_namespace($client_name);
    };
    local *{"${dest_class}::columns"}   = sub (@)    { @client_columns = @_ };
    local *{"${dest_class}::row_class"} = sub (@)    { $row_class = shift };
    local *{"${dest_class}::endpoint"}  = sub ($$@) {
        my ($name, $path, @args) = @_;
        $endpoint{$name} = +{
            path     => $path,
            # XXX: not specifiction.
            requires => ref($args[0]) && ref($args[0]) eq 'ARRAY' ? $args[0] : \@args,
        };
    };
    local *{"${dest_class}::inflate"}   = sub ($&)   {
        my ($rule, $code) = @_;
        $rule = qr/^\Q$rule\E$/ if ref $rule ne 'Regexp';
        push @inflate => ($rule, $code);
    };
    local *{"${dest_class}::deflate"}   = sub ($&)   {
        my ($rule, $code) = @_;
        $rule = qr/^\Q$rule\E$/ if ref $rule ne 'Regexp';
        push @deflate => ($rule, $code);
    };

    $code->();

    my @col_names;
    while (@client_columns) {
        my $col_name = shift @client_columns;
        if (ref $col_name) {
            $col_name = $col_name->{name};
        }
        push @col_names => $col_name;
    }

    $current->add_client( # TODO: あとでclientに変更
        Spica::Schema::Client->new(
            columns   => \@col_names,
            name      => $client_name,
            endpoint  => \%endpoint,
            inflators => \@inflate,
            deflators => \@deflate,
            row_class => $row_class,
            ($current->{__base_row_class} ? (base_row_class => $current->{__base_row_class}) : ()),
        ),
    );
}

1;
