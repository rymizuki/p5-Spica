package Spica::Parser::JSON;
use strict;
use warnings;
use parent qw(Spica::Parser);
use JSON;

sub parse {
    my $class = shift;
    return JSON->new->utf8->decode($_[0]);
}

1;
