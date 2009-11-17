#!/usr/bin/perl
#
# $Id: cvs-co-all.pl,v 1.1 2009/11/17 22:47:03 urs Exp $

$root = $ENV{CVSROOT};
$rep  = shift;

@files = split(' ', `cd $root; find $rep -name \\*,v | sort`);
for $f (@files) {
    print "$f\n";
    $f =~ s/,v$//;
    $f =~ s/\/Attic//;
    @log = `cvs rlog $f`;

    $f =~ s/^$rep\///;

    system("mkdir -p \$(dirname revs/$f)");
    system("mkdir -p \$(dirname revs-kk/$f)");
    system("mkdir -p \$(dirname revs-ko/$f)");
    system("mkdir -p \$(dirname logs/$f)");
    system("mkdir -p \$(dirname desc/$f)");
    system("mkdir -p \$(dirname tags/$f)");
    system("mkdir -p \$(dirname ts/$f)");

    for (@log) {
	if (/^symbolic names:/) {
	    $tags = 1;
	} elsif ($tags) {
	    if (/^\t(.*): (.*)$/) {
		($tag, $rev) = ($1, $2);
		open OUT, ">tmp-tag" || die;
		print OUT "$tag\n";
		close OUT;
		system("touch tags/$f-$rev");
		system("cat tags/$f-$rev >>tmp-tag");
		system("mv tmp-tag tags/$f-$rev");
	    } else {
		$tags = 0;
	    }
	}
	if (/^revision (\d+\.\d+)/) {
	    $rev = $1;
	} elsif (/^date: (\d\d\d\d[-\/]\d\d[-\/]\d\d \d\d:\d\d:\d\d)/) {
	    $date = $1;
	    $date =~ s/[-\/: ]/./g;
	    $date =~ s/^19// if ($date =~ /^19\d\d/);
	    if (/state: dead;/) {
		system("touch revs/$f-$rev");
		system("touch revs-kk/$f-$rev");
		system("touch revs-ko/$f-$rev");
	    } else {
		system("rm -rf $rep");
		system("cvs co -r $rev $rep/$f");
		system("mv $rep/$f revs/$f-$rev");
		system("rm -rf $rep");
		system("cvs co -kk -r $rev $rep/$f");
		system("mv $rep/$f revs-kk/$f-$rev");
		system("rm -rf $rep");
		system("cvs co -ko -r $rev $rep/$f");
		system("mv $rep/$f revs-ko/$f-$rev");
		system("rm -rf $rep");
	    }
	    open OUT, ">ts/$f-$rev" || die;
	    print OUT "$date\n";
	    close OUT;
	    open OUT, ">logs/$f-$rev" || die;
	    $copy = 1;
	} elsif (/^description:/) {
	    open OUT, ">desc/$f-desc" || die;
	    $copy = 1;
	} elsif (/^------------/ || /^==========/) {
	    close OUT;
	    $copy = 0;
	} elsif ($copy) {
	    print OUT $_;
	}
    }
}
