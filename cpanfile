requires 'perl'            => '5.10.0';
requires 'Carp'            => '1.08';
requires 'Class::Load'     => '0.06';
requires 'URI'             => '1.40';
requires 'Mouse'           => '0.93';
requires 'Furl'            => '0.20';
requires 'JSON'            => '2.15';
requires 'Exporter::Lite'  => '0.02';

on 'test' => sub {
    requires 'Test::More' => '0.98';
};
