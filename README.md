p5-Spica
===========================================================================

This library is a development stage.

# DESCRIPTION

Spica is the HTTP client for dealing with complex WEB API.

# SYNOPSIS

```
# minimal case
{
    my $spica = Spica->new(host => 'example.ry-m.com');
    my $results = $spica->fetch('/users', +{});
    
    while(my $result = $results->next) {
        say $result->name;
    }
}

# custom spec
{
    package Example::Spec;
    use Spica::Spec::Declare;

    client {
        name 'users';
        endpoint 'default' => '/users', [];
        filter 'before_receive' => sub {
            my ($spica, $data) = @_;
            return $data->{rows};
        };
    };

    client {
        name 'profile';
        endpoint 'update' => +{
            method   => 'POST'
            path     => '/profile/{user_id}',
            requires => [qw(user_id)],
        }; 
        endpoint 'single' => '/profile/{user_id}', [];
        receiver 'Example::Receiver::Row::Profile';
    }

    package Example::Receiver::Row::Profile;
    use parent qw(Spica::Receiver::Row);

    sub is_perler {
        my $self = shift;
        return $self->name eq 'perl' ? 1 : 0;
    }

    package main;
    use Spice;

    my $spica = Spica->new(
        host => 'example.ry-m.com',
        spec => 'Example::Spec',        
    );

    my $users = $spica->fetch('users', +{});

    while (my $user = $users->next) {
        my $profile = $spica->fetch('profile', 'single', +{user_id => $user->id});

        if ($profile->name ne 'perl') {
            # FIXME: 更新メソッドをfetchと名付けるのは少し気持ちが悪い
            #        Spicaを継承してアクセサ生やしてくださいよってスタンスでもいいとは思いつつ。
            $profile = $spica->fetch('profile', 'update', +{
                user_id => $user->id,
                name    => 'perl',
            });
        }

        say $profile->name; # perl
        say $profile->is_perler ? 'Yes!!!' : 'No...'; # Yes!!!
    }
}
```
