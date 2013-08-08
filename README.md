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

# TODO

此処から先は日本語OK いずれなくなる予定なので。

## TriggerとFilterはコンテキストに在るべき

現在、ClientクラスにTrigger及びFilterを登録しているが、フックポイントはSpica.pm側にあり、
Spicaからspec経由でclientを取得できた場合にフックするようにしている。

そこがどうにももやっとしてるけど、そもそもSpicaに登録できていればスムーズだよね？
Spica=Contextがリクエストやレシーブの機能を受け持っている。フックしたいのはその
API通信から受け取りまでのデータ処理のどこかであるので、その役割を持つクラスにトリガを
するようにすればしっくりくるんじゃない。

## Clientの概念

クライアントさんは、APIのエンドポイントや管理したいプロパティ(いま全部突っ込んでるけど)やアクセサ、
受け取り側のクラスの挙動等を設定している。

基本的にスピカはホストが複数のAPI clientを持つ前提で、clientはrowクラスに1:1で紐づく。
rowクラスは複数のエンドポイントから取得できる(ArrayRefの集合、HashRefの単体として受け取る等の違いはあるかもしれない)という想定で組んでいる。
しかし、それってなんかちがくない？

APIを扱う側としては、Interface毎にクライアントがあったほうが理解しやすい。
でも、パラメータ切り替えたらRowのデータ構造が変わったらどうするの？

clientは「どういうデータ構造」であるか、と「どういうリクエストを投げれば受け取れるのか」と、「どういう受け取り方をするのか」を設定したい。

ただし、ホストの下に複数のクライアントが結びつく(大体同じホストが提供しているAPIは同じような処理で解析できる筈)であろうことと、
すべてを並列にすると管理するの大変になる。ので、その構造は動かしたくない。

いまのところその構造は直感的だと思っているので、その考えを否定しうる要因が上がってきたら再考するかもしれない。ベストだとは思ってない。

## Spica.pmの立ち位置

Spicaは処理の基幹を担っているが、APIによっては、特定ホストの特定クライアントだけどうしても処理の仕方を変えたい、という要求は往々にしてある。悲しいことに既に出会ってる。
本来的には、Spicaが担うべきではなく、Clientの処理の中でリクエスト/レシーブの生成・実行、フックポイントのイベント発火を行うべきだと思う。

Spicaはそのクライアントの集合に対して、同一のインターフェースを提供するアクセサであり、クライアントを集約する枠組みを提供できるといいんじゃないかな。

## Spica::Specの立ち位置

Clientの定義を行う、という点で変更はない。
だが、RowクラスだったりClientの振る舞いに関してはまだ若干もやもやしてる部分がある（何がもやもやしてるのか判然としないが）。

SpicaやClientの在り方が変わるのであれば、必然的にSpecに求められるものも変わるはずなので追々考えてく。

ただ、Clientが根幹を担うということであれば、SpecがClientを定義するのはおかしくて、であれば、SpecはClientの拡張を定義する、というのが正しいのではないだろうか

## まとめ

おおまかな考え方としては、

* SpicaはClientを必ず持つ
* Clientには共通の振舞い方が定義されている
* SpecでClientの振る舞いを拡張できる

というところか。
