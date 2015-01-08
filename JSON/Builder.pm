=head1 NAME

JSON::Builder - to build large JSON with temp files when memory limit, and compress optionaly.

=head1 SYNOPSIS

 use JSON::Builder;
 
 my $json = JSON::XS->new()->utf8(1)->ascii(1);
 my ($fh) = tempfile(UNLINK => 1);
 
 my $builder = JSON::Builder->new(json => $json, fh => $fh);
 or
 my $builder = JSON::Builder::Compress->new(json => $json, fh => $fh); # Compress, Base64
  
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
 );
 
 $builder->encode(\%d);
 
 # print for test
 $fh->flush();
 $fh->seek(0,0);
 print <$fh>;

=head1 MOTIVATION

Task: to create JSON while having the memory limitations.
 
If you have only one large value in JSON, or, large values are created one by one, you can use the streaming generator. Otherwise, you should use such a perl structure where large elements are the filehandle with the json fragments. When a perl structure is transformed into json, it bypasses and large elements are excluded from the files. The result json is written into the file.   

=head1 DESCRIPTION

=head2 JSON::Builder

=head3 new

The constructor accepts the following arguments:

=over

=item json

JSON object with the encode and allow_nonref methods support, e.g. JSON::XS.

=item fh

The filehandle of the file where the result should be written into.

=item read_in

LENGTH of L<read> function. Optional.

=back

 my $builder = JSON::Builder->new(json => $json, fh => $fh);

=head3 val

It turns the data to JSON, saves JSON into the variable file created and returns the filehandle of this temporary file:

 my $fv = $builder->val( { a => 'b', c => 'd' } );

=head3 list

Its returns the object JSON::Builder::List

=head3 obj

Its returns the object JSON::Builder::Obj

=head3 encode

Turns the passed data structure into JSON.

 my %d = (
 	one => 1,
 	v   => $fv, # file handler if $builder->val(...)
 	l   => $fl, # file handler of JSON::Builder::List
 	o   => $fo, # file handler of JSON::Builder::Obj
 );

 $builder->encode(\%d)

=head2 JSON::Builder::List

It is aimed to write the JSON elements list into the temporary file.

 my $l = $builder->list();
 $l->add( { 1 => 'a', 2 => 'b' } );
 $l->add( { 1 => 'c', 2 => 'd' } );
 my $fl = $l->end();

=head3 new

Don't use the constructor directly: use the object list method JSON::Builder.

=head3 add

It adds the element:

=head3 end

It returns the filehandle of the file with the JSON list.

=head2 JSON::Builder::Obj

It is for writing the JSON Obj to the temporary file.

 my $o = $builder->obj();
 $o->add( o1 => ['a', 'b'] );
 $o->add( o2 => ['c', 'd'] );
 my $fo = $o->end();

=head3 new

Don't use the constructor directly: use the object obj method JSON::Builder.

=head3 add

Its adds the key-value

=head3 end

It returns the filehandle of the file with the JSON object.

=head2 JSON::Builder::Compress

To ensure that the results file includes the JSON packed, use JSON::Builder::Compress instead of JSON::Builder.
The packing algorithm: deflate �� Compress::Zlib.
The results of that is encoded with the help of encode_base64url �� MIME::Base64.

=head2 Inheritance

If you want to use your own processing algorithm of the JSON portions, you should redeclarate the init, write, write_flush methods for the JSON::Builder object.

=head1 AUTHOR

Nick Kostyria <kni@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by Nick Kostyria

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.2 or,
at your option, any later version of Perl 5 you may have available.

=cut

package JSON::Builder;
use strict;
use warnings;

our $VERSION = '0.03';

use Carp;
use File::Temp qw(tempfile tempdir);

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;

	my $self = { @_ };

	$$self{json}->allow_nonref(1);

	$$self{dir} = tempdir(CLEANUP => 1);

	bless $self, $class;

	$self->init();

	return $self;
}


sub init {
	my $self = shift;
}


sub val {
	my $self = shift;
	my ($val) = @_;
	
	my $json_val = eval { $$self{json}->encode($val) };
	if ($@) {
		carp $@;
		return;
	}

	my ($fh) = tempfile(DIR => $$self{dir}, UNLINK => 1);
	print $fh $json_val;
	$fh->flush;
	$fh->seek(0,0);

	return $fh;
}


sub list {
	my $self = shift;
	JSON::Builder::List->new(%$self);
}


sub obj {
	my $self = shift;
	JSON::Builder::Obj->new(%$self);
}


sub encode {
	my $self = shift;
	my ($d) = @_;

	my $json = $$self{json};
	my $fh   = $$self{fh};

	$self->kv($d);
	$self->write_flush();

	$fh->flush;
	$fh->seek(0,0);
}


sub kv {
	my $self = shift;
	my ($d) = @_;

	if (ref $d eq "ARRAY") {
		$self->write("[");
		my $i = @$d;
		foreach (@$d) {
		   	$self->kv($_);
			$self->write(",") if --$i;
		}
		$self->write("]");
	} elsif (ref $d eq "HASH") {
		my $json = $$self{json};
		$self->write("{");
		my $i = keys %$d;
		foreach (keys %$d) {
			$self->write($json->encode($_), ':');
			$self->kv($$d{$_});
			$self->write(",") if --$i;
		}
		$self->write("}");
	} elsif (ref $d eq "GLOB") {
       while (read($d, my $buf, $$self{read_in} || 57000)) {
			$self->write($buf);
	   }
	} elsif (not ref $d) {
		my $json = $$self{json};
		$self->write($json->encode($d));
	}
}


sub write {
	my $self = shift;
	print { $$self{fh} } @_;
}

sub write_flush {
	my $self = shift;
}


package JSON::Builder::List;
use strict;
use warnings;

use File::Temp qw(tempfile);

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;

	my $self = { @_, first => 1 };

	$$self{fh} = tempfile(DIR => $$self{dir}, UNLINK => 1);

	bless $self, $class;
	return $self;
}


sub add {
	my $self = shift;
	my ($val) = @_;

	my $json_val = eval { $$self{json}->encode($val) };
	if ($@) {
		carp $@;
		return;
	}

	if ($$self{first}) {
		$$self{first} = 0;
		print { $$self{fh} } "[", $json_val;
	} else {
		print { $$self{fh} } ",", $json_val;
	}
}


sub end {
	my $self = shift;
	my $fh = $$self{fh};

	if ($$self{first}) {
		$$self{first} = 0;
		print $fh "[";
	}
	print $fh "]";

	$fh->flush;
	$fh->seek(0,0);
	return $fh;
}



package JSON::Builder::Obj;
use strict;
use warnings;

use File::Temp qw(tempfile);

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;

	my $self = { @_, first => 1 };

	$$self{fh} = tempfile(DIR => $$self{dir}, UNLINK => 1);

	bless $self, $class;
	return $self;
}


sub add {
	my $self = shift;
	my ($key, $val) = @_;

	my $json_key = eval { $$self{json}->encode($key) };
	if ($@) {
		carp $@;
		return;
	}

	my $json_val = eval { $$self{json}->encode($val) };
	if ($@) {
		carp $@;
		return;
	}

	if ($$self{first}) {
		$$self{first} = 0;
		print { $$self{fh} } "{", $json_key, ":", $json_val;
	} else {
		print { $$self{fh} } ",", $json_key, ":", $json_val;
	}
}


sub end {
	my $self = shift;
	my $fh = $$self{fh};

	if ($$self{first}) {
		$$self{first} = 0;
		print $fh "{";
	}
	print $fh "}";

	$fh->flush;
	$fh->seek(0,0);
	return $fh;
}



package JSON::Builder::Compress; # Compress, Base64
use strict;
use warnings;
use base qw(JSON::Builder);

use Compress::Zlib;
use MIME::Base64 qw(encode_base64url);

sub init {
	my $self = shift;
	$$self{x} = deflateInit();
	$$self{write_buf} = "";
}


sub write {
	my $self = shift;

	my $buf = join "", @_;

	my ($output, $status) = $$self{x}->deflate($buf);
	$status == Z_OK or die "deflation failed\n";

	if ($output) {
	 	my $write_buf = join "", $$self{write_buf}, $output;
		my $l = int(length($write_buf)/ 57) * 57;
		if ($l) {
			my $buf_head = substr $write_buf, 0, $l;
			$$self{write_buf} = substr $write_buf, $l;
			print { $$self{fh} } encode_base64url($buf_head, "");
		} else {
			$$self{write_buf} = $write_buf;
		}
	}
};


sub write_flush {
	my $self = shift;

	my ($output, $status) = $$self{x}->flush();
    $status == Z_OK or die "deflation failed\n";

	if ($output) {
		$$self{write_buf} .= $output;
	}

	print { $$self{fh} } encode_base64url($$self{write_buf}, "");

	$$self{write_buf} = "";
}


1;
