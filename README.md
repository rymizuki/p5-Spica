p5-Spica
===========================================================================

# SYNOPSIS

 my $client = MyClient->new(
     host       => 'example.com',
     secret_key => 'any secret key',
 );

 my $iterator = $client->search('timeline', +{user_id => $user_id});
 
 while (my $row = $iterator->next) {
     say $row->name;
 }

# DESCRIPTION

Spica is the HTTP client for dealing with complex WEB API.
