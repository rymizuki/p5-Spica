p5-Spica
===========================================================================

This library is a development stage.

# SYNOPSIS

```
package MyClient::Schema;
use Spica::Schema::Declare;

client {
    name 'profile';
    endpoint '/profile', [qw(id)];
    columns (
        'id',
        'name',
        'message',
        'created_at',
    );
}

1;

 my $client = MyClient->new(
     host         => 'example.com',
     schema_class => 'MyClient::Schema',
 );

 my $profile = $client->fetch('profile', +{id => $user_id});

 say $profile->name;
 
 ```

# DESCRIPTION

Spica is the HTTP client for dealing with complex WEB API.
