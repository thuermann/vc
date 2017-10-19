#!/usr/bin/perl
#
# $Id: cvs2quilt.pl,v 1.1 2017/10/19 07:43:46 urs Exp $
#
# Convert CVS repository to a series of quilt patches and log messages file

use Getopt::Std;
use File::Path qw(make_path);
use File::Basename;

if (!getopts("rn:")) {
    die "Usage: $0 [-r] [-n patch-names]\n";
}

$re_time = '(\d\d\d\d-\d\d-\d\d) (\d\d:\d\d:\d\d)';

system("rm -rf Q");
mkdir("Q");

if (defined($opt_n)) {
    @names = `cat $opt_n`;
    chomp(@names);
    unshift(@names, "");
    print "@names\n";
}

# Build the CVS ChangeLog.
$cvs2cl  = 'cvs2cl --stdout -s -S --no-wrap -W0 --no-common-dir';
$cvs2cl .= ' --chrono' if (defined($opt_r));
@changelog = `$cvs2cl`;

for (@changelog) {
    $count++ if (/^[12]/);
}

# Parse the changelog output, build new log file, and build a list of all
# affected files of each revision.
$rev = defined($opt_r) ? 1 : $count;
for ($i = 0; $i <= $#changelog; $i++) {
    # Find header line containing time and replace it by time and name.
    if ($changelog[$i] =~ /^$re_time  /) {
	$name = @names ? $names[$rev] : "r$rev";
	$changelog[$i] = "$1T$2  $name\n";
	$ts[$rev] = "$1 $2";
	$state = 0;
	@files = ();
	next;
    }
    # Delete the empty line following the header line.
    if ($state == 0 && $changelog[$i] eq "\n") {
	undef $changelog[$i];
	$state++;
	next;
    }
    # Build the list of affected files from all following lines until the
    # next emtpy line and replace these lines by all files in one line.
    if ($state == 1) {
	if ($changelog[$i] ne "\n") {
	    $changelog[$i] =~ s/^\s+(\*\s+)?//;
	    $changelog[$i] =~ tr/,:\n//d;
	    push(@files, split(/ /, $changelog[$i]));
	    undef $changelog[$i];
	} else {
	    $changelog[$i] = "\t\t     @files\n";
	    $qfiles[$rev] = "@files";
	    $state++;
	}
	next;
    }
    # Retain all remaining lines of log message until the terminating
    # empty lines which is replaced by a line containing only ".".
    if ($changelog[$i] eq "\n" &&
	($i == $#changelog || $changelog[$i + 1] =~ $re_time)) {
	$changelog[$i] = ".\n";
	defined($opt_r) ? $rev++ : $rev--;
    }
}
open  LOGS, ">Q/logs";
print LOGS @changelog;
close LOGS;

# Write all revisions of all files to directory Q/revs.
mkdir("Q/revs");
for ($rev = 1; $rev <= $count; $rev++) {
    for $file (split(/ /, $qfiles[$rev])) {
	make_path(dirname("Q/$file"), dirname("Q/revs/$file"));
	exc("cvs -q up -kk -p \"-D$ts[$rev]\" $file > Q/revs/$file-$rev");
    }
}

# Build all patches using quilt.
chdir("Q");
mkdir("patches");
for ($rev = 1; $rev <= $count; $rev++) {
    $name = @names ? $names[$rev] : "r$rev";
    exc("quilt new $name");
    exc("quilt add $qfiles[$rev]");
    for $file (split(/ /, $qfiles[$rev])) {
	exc("cp revs/$file-$rev $file");
	if (-z $file) {
	    unlink($file);
	}
    }
    exc("quilt ref -p ab")
}

# Print and execute a command.
sub exc {
    ($cmd) = @_;

    print("+ $cmd\n");
    system("$cmd");
}
