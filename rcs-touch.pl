#!/usr/bin/perl
#
# $Id: rcs-touch.pl,v 1.2 2011/10/19 21:10:19 urs Exp $
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

$new_date = `date -u $date_fmt $date_opt`;
chop($new_date);

print "$new_date\n";

$re_date = '(\d\d)?\d\d\.\d\d\.\d\d\.\d\d\.\d\d\.\d\d';

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
	if ($lines[$i] =~ /^date\s+($re_date);/) {
	    $old_date = $1;
	    if (!defined($opt_r) || $lines[$i-1] =~ /^$opt_r/) {
		print "$file: $i\n";
		$lines[$i] =~ s/$old_date/$new_date/;
		last;
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
