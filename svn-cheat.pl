#!/usr/bin/perl
#
# $Id: svn-cheat.pl,v 1.6 2010/05/18 21:40:44 urs Exp $

use Digest::MD5 qw(md5_hex);
use Digest::SHA qw(sha1_hex);

while ($#ARGV >= 1) {
    if ($ARGV[0] eq "-x" && $#ARGV >= 3) {
	($opt, $rev, $path, $file) = (shift, shift, shift, shift);
	$extract{"$rev:$path"} = $file;
    } elsif ($ARGV[0] eq "-r" && $#ARGV >= 3) {
	($opt, $rev, $path, $file) = (shift, shift, shift, shift);
	$replace{"$rev:$path"} = $file;
    } elsif ($ARGV[0] eq "-a" && $#ARGV >= 3) {
	($opt, $rev, $path, $file) = (shift, shift, shift, shift);
	$add{"$rev:$path"} = $file;
    } elsif ($ARGV[0] eq "-d" && $#ARGV >= 2) {
	($opt, $rev, $path) = (shift, shift, shift);
	$delete{"$rev:$path"} = 1;
    } else {
	last;
    }
}

for $k (keys %extract) {
    print "extract: $k $extract{$k}\n";
}

for $k (keys %replace) {
    print "replace: $k $replace{$k}\n";
}

for $k (keys %add) {
    print "add:     $k $add{$k}\n";
}

for $k (keys %delete) {
    print "delete:  $k\n";
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
	undef $b;
	undef $text_md5;
	undef $text_sha1;

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

	$expect_nl = $cont_len > 0 ? 2 : 1;
	while ($_ eq "\n") {
	    $b .= $_;
	    $expect_nl--;
	    $_ = $lines[++$i];
	}
	if ($expect_nl != 0) {
	    print "WARNING: Unexpected number of newlines\n";
	}

	for (keys(%add)) {
	    ($arev, $apath) = split(/:/);
	    if ($arev == $rev && $apath lt $node_path) {
		print_node($apath, $add{$_});
		delete $add{$_};
	    }
	}
	if (!defined($delete{"$rev:$node_path"})) {
	    print OUT $h, $p, $t, $b;
	}
    }

    for (keys(%add)) {
	($arev, $apath) = split(/:/);
	if ($arev == $rev) {
	    print_node($apath, $add{$_});
	    delete $add{$_};
	}
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

    while (length($_) <= $len) {
	$text .= $_;
	$len -= length($_);
	$_ = $lines[++$i];
    }
    if ($len > 0) {
	$text .= substr($_, 0, $len, "");
    }

    return $text;
}

sub print_node {
    my ($path, $file) = @_;
    my ($h, $p, $t, $b);
    my ($text_len, $text_md5);

    open TIN, $file;
    $t = join('', <TIN>);
    close TIN;

    $text_len = length($t);
    $text_md5 = md5_hex($t);

    $h =  "Node-path: $path\n";
    $h .= "Node-kind: file\n";
    $h .= "Node-action: change\n";
    $h .= "Text-content-length: $text_len\n";
    $h .= "Text-content-md5: $text_md5\n";
    $h .= "Content-length: $text_len\n";
    $h .= "\n";

    $p = "";
    $b = "\n\n";

    print OUT $h, $p, $t, $b;
}
