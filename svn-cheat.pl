#!/usr/bin/perl
#
# $Id: svn-cheat.pl,v 1.2 2010/05/11 07:46:30 urs Exp $

use Digest::MD5 qw(md5_hex);
use Digest::SHA qw(sha1_hex);

while ($#ARGV >= 3 && ($ARGV[0] eq "-x" || $ARGV[0] eq "-r")) {
    ($opt, $rev, $path, $file) = (shift, shift, shift, shift);
    if ($opt eq "-x") {
	$extract{"$rev:$path"} = $file;
    } else {
	$replace{"$rev:$path"} = $file;
    }
}

for $k (keys %extract) {
    print "extract: $k $extract{$k}\n";
}

for $k (keys %replace) {
    print "replace: $k $replace{$k}\n";
}

open OUT, ">out.dump";

@lines = <>;

$i = 0; $_ = $lines[$i];

while (!/^Revision-number: (\d+)$/) {
    print OUT;
    $_ = $lines[++$i];
}

while (/^Revision-number: (\d+)$/) {
    $rev = $1;
    print "Revision $rev\n";
    rev();
    print "\n";
}

close OUT;


sub rev {
    my ($h, $t, $p);

    $h = header();
    die "wrong length header" if ($cont_len != $prop_len + $text_len);
    print OUT $h;
    printf "skip rev props: %5d\n", $prop_len;
    $p = props($prop_len);
    print OUT $p;
    die "end of rev props" unless ($_ eq "\n");
    print OUT;
    $_ = $lines[++$i];

    while ($i <= $#lines && /^Node-path: (.*)$/) {
	undef $h;
	undef $p;
	undef $t;

	undef $text_md5, $text_sha1;

	$h = header();
	die "wrong length header" if ($cont_len != $prop_len + $text_len);

	if ($prop_len > 0) {
	    printf "skip props:     %5d\n", $prop_len;
	    $p = props($prop_len);
	}

	if ($text_len > 0) {
	    printf "skip text:      %5d\n", $text_len;
	    $t = text($text_len);
	    if (defined($text_md5) && md5_hex($t) ne $text_md5) {
		print "$t";
		die "md5 error";
	    }
	    if (defined($text_sha1) && sha1_hex($t) ne $text_sha1) {
		print "$t";
		die "sha1 error";
	    }
	    if (defined($extract{"$rev:$node_path"})) {
		my $file = $extract{"$rev:$node_path"};
		open TOUT, ">$file";
		print TOUT $t;
		close TOUT;
	    }
	    if (defined($replace{"$rev:$node_path"})) {
		my $file = $replace{"$rev:$node_path"};
		open TIN, $file;
		$t = join('', <TIN>);
		close TIN;
		$text_len  = length($t);
		$text_md5  = md5_hex($t);
		$text_sha1 = sha1_hex($t);
		$cont_len  = $prop_len + $text_len;
		$h =~ s/(Text-content-length): \d+/$1: $text_len/g;
		$h =~ s/(Text-content-md5): .{32}/$1: $text_md5/g;
		$h =~ s/(Text-content-sha1): .{40}/$1: $text_sha1/g;
		$h =~ s/(Content-length): \d+/$1: $cont_len/g;
	    }
	}

	print OUT $h;
	print OUT $p;
	print OUT $t;

	if ($cont_len > 0) {
	    die "end of node" unless ($_ eq "\n");
	    print OUT;
	    $_ = $lines[++$i];
	}

	die "end of node" unless ($_ eq "\n");
	print OUT;
	$_ = $lines[++$i];
    }
}

sub header {
    my ($header);

    $prop_len = 0;
    $text_len = 0;
    $cont_len = 0;

    while ($i < $#lines && $_ ne "\n") {
	$header .= $_;
	chomp;
	print "header line: $_\n";
	if (/^Revision-number: (\d+)$/) {
	    $rev = $1;
	} elsif (/^Prop-content-length: (\d+)$/) {
	    $prop_len  = $1;
	} elsif (/^Text-content-length: (\d+)$/) {
	    $text_len  = $1;
	} elsif (/^Text-content-md5: (.{32})$/) {
	    $text_md5  = $1;
	} elsif (/^Text-content-sha1: (.{40})$/) {
	    $text_sha1  = $1;
	} elsif (/^Content-length: (\d+)$/) {
	    $cont_len  = $1;
	} elsif (/^Node-path: (.*)$/) {
	    $node_path = $1;
	} elsif (/^Node-kind: (file|dir)$/) {
	    $node_kind = $1;
	} elsif (/^Node-action: (add|change|delete)$/) {
	    $node_act  = $1;
	} elsif (/^Node-copyfrom-rev: (\d+)$/) {
	    ;
	} elsif (/^Node-copyfrom-path: (.*)$/) {
	    ;
	} elsif (/^Text-copy-source-md5: (.{32})$/) {
	    ;
	} elsif (/^Text-copy-source-sha1: (.{40})$/) {
	    ;
	} else {
	    print "unknown header line: $_\n";
	}
	$_ = $lines[++$i];
    }
    unless ($_ eq "\n") {
	die "missing end of header";
    }

    $header .= $_;
    $_ = $lines[++$i];
    return $header;
}

sub props {
    my ($len) = @_;
    my ($klen, $vlen, $props, $t);

    return "" if ($len == 0);

    while ($len > 0 && $_ ne "PROPS-END\n") {
	die "prop syntax error" if (!/^K (\d+)$/);
	$klen = length($_) + $1 + 1;
	printf "skip key:       %5d\n", $klen;
	$t = text($klen);
	$props .= $t;
	die "prop syntax error" if (!/^V (\d+)$/);
	$vlen = length($_) + $1 + 1;
	printf "skip val:       %5d\n", $vlen;
	$t = text($vlen);
	$props .= $t;
	$len -= $klen + $vlen;
    }
    unless ($_ eq "PROPS-END\n" && $len == 10) {
	die "prop syntax error";
    }

    $props .= $_;
    $_ = $lines[++$i];

    return $props;
}

sub text {
    my ($len) = @_;
    my ($text);

    while ($len > 0) {
	$text .= $_;
	$len -= length($_);
	$_ = $lines[++$i];
    }
    die "length mismatch" if ($len != 0);

    return $text;
}
