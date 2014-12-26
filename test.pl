$| = 1;
use v5.10;
use strict;
use warnings;


use JSON::XS;
use File::Temp qw(tempfile);

use Compress::Zlib;
use MIME::Base64 qw(decode_base64url);

use Test::More tests => 3;

BEGIN { use_ok( 'JSON::Builder' ) }

my $json = JSON::XS->new()->utf8(1)->ascii(1);


sub foo {
	my ($fh, $builder) = @_;

	my $fv = $builder->val( { a => 'b', c => 'd' } );

	my $l = $builder->list();
	$l->add( { 1 => 'a', 2 => 'b' } );
	$l->add( { 1 => 'c', 2 => 'd' } );
	my $fl = $l->end();

	my $o = $builder->obj();
	$o->add( o1 => ['a', 'b'] );
	$o->add( o2 => ['c', 'd'] );
	my $fo = $o->end();

	my %d = (
		one => 1,
		v   => $fv,
		l   => $fl,
		o   => $fo,
		zl  => $builder->list()->end(),
		zo  => $builder->obj()->end(),
	);

	$builder->encode(\%d);

	$fh->flush();
	$fh->seek(0,0);
	join "", <$fh>;
}


my $j = {
	one => 1,
	v => { a => 'b', c => 'd' },
	l => [
		{ 1 => 'a', 2 => 'b' },
		{ 1 => 'c', 2 => 'd' },
	],
	o => {
		o1 => ['a', 'b'],
		o2 => ['c', 'd'],
	},
	zl => [],
	zo => {},
};


{
	my ($fh) = tempfile(UNLINK => 1);

	my $builder = JSON::Builder->new(
		json    => $json,
		fh      => $fh,
		read_in => 1000*57
	);

	my $r = foo($fh, $builder);
	is_deeply($json->decode($r), $j, "Simple");
}
{
	my ($fh) = tempfile(UNLINK => 1);

	my $builder = JSON::Builder::Compress->new(
		json    => $json,
		fh      => $fh,
		read_in => 1000*57
	);

	my $r = foo($fh, $builder);
	my $rj = uncompress(decode_base64url($r));
	is_deeply($json->decode($rj), $j, "Compress, Base64");
}
