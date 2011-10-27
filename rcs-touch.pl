#!/usr/bin/perl
#
# $Id: rcs-touch.pl,v 1.3 2011/10/27 13:39:14 urs Exp $
#
# Change check-in time of RCS and CVS files.

require "getopts.pl";

if (!Getopts("r:d:") || $#ARGV == -1) {
    die "Usage: $0 [-r rev] [-d date] RCS-files...\n";
}

$date_opt = "-d \"$opt_d\"" if (defined($opt_d));

if (`date +%Y $date_opt` < 2000) {
    $date_fmt = "+%y.%m.%d.%H.%M.%S";
} else {
    $date_fmt = "+%Y.%m.%d.%H.%M.%S";
}
$id_fmt = "+%Y/%m/%d\\ %T";

$new_date = `date -u $date_fmt $date_opt`;
$new_id   = `date -u $id_fmt   $date_opt`;
chop($new_date);
chop($new_id);

print "new date: $new_date\n";
print "new Id:   $new_id\n";

$re_rev  = '\d+\.\d+(\.\d+\.\d+)*';
$re_date = '(\d\d)?\d\d(\.\d\d){5}';
$key     = 'Id:';  # Prevent CVS expanding this keyword
$re_id   = qr/\$$key .* ($re_rev) (\d\d\d\d\/\d\d\/\d\d \d\d:\d\d:\d\d).*\$/;

for (@ARGV) {
    rcs_touch($_);
}

sub rcs_touch {
    my ($file) = @_;
    my (@lines);

    if (!open file, $file) {
	print STDERR "$file: $!\n";
	return;
    }
    @lines = <file>;
    close file;
    unshift(@lines, "");

    for $i (1..$#lines) {
	next unless ($lines[$i-1] =~ /^($re_rev)$/);
	next unless (!defined($opt_r) || $lines[$i-1] eq "$opt_r\n");
	if ($lines[$i] =~ s/(^date\s+)($re_date);/$1$new_date;/) {
	    print "$file: $i: $2 -> $new_date\n";
	    $rev = $lines[$i-1];
	    chop($rev);
	    last
	}
    }
    for $i (1..$#lines) {
	if ($lines[$i] =~ /$re_id/) {
	    if ($1 == $rev) {
		$old_id = $3;
		$lines[$i] =~ s/$old_id/$new_id/;
		print "$file: $i: $old_id -> $new_id\n";
	    }
	}
    }

    if (!open file, ">$file") {
	print STDERR "$file: $!\n";
	return;
    }
    print file @lines;
    close file;
}
