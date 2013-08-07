p5-Spica
===========================================================================

This library is a development stage.

# SYNOPSIS

```
package MyClient::Spec;
use strict;
use warnings;
use Spica::Spec::Declare;

client {
    name 'users';
    endpoint '/users' => [];
    columns (
        'id',
        'name',
    );
};

client {
    name 'profile';
    endpoint '/profile/{id}', [qw(id)];
    columns (
        'id',
        'name',
        'message',
        'created_at',
    );
    receiver 'MyClient::Receiver::Row::Profile';
}

1;

package main;
use strict;
use warnings;
use Spica;


my $client = Spica->new(
    host => 'example.com',
    spec => 'MyClient::Spec',
);

my $users = $client->fetch('users', +{limit => 10});
# GET http://example.com/users?limit=10

while (my $user = $users->next) {
  say $user->name;
}


my $profile = $client->fetch('profile', +{id => 10});
# GET http://example.com/profile/10

say $profile->name;

```

# DESCRIPTION

Spica is the HTTP client for dealing with complex WEB API.
