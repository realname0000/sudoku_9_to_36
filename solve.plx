#!/usr/bin/perl -w

use strict;
use Carp;
use FindBin;

use lib "$FindBin::Bin/perllib";
use board;
use clot;
use cell;

###############################################################
package main;

my $calc_all=0;
if ($ARGV[0] eq "-a") {
    $calc_all=1;
    shift;
}
# use ARGV and <>
my @row_as_text;
while (<>) {
    chomp();
    push(@row_as_text,$_);
}

my $size;
if (length $row_as_text[0] == 9) {
    $size=3;
} elsif (length $row_as_text[0] == 16) {
    $size=4;
} elsif (length $row_as_text[0] == 25) {
    $size=5;
} elsif (length $row_as_text[0] == 36) {
    $size=6;
} else {
    die("Input is not the size of a recognised board");
}

my $sol=0;                # count solutions
my $guess_depth=0;        # how many used
my $guesses_allowed=1000000;

my $board=board->new($size);

my $y=1;
foreach my $rat (@row_as_text) {
    my @rr=split(//, $rat);
    my $x=1;
    foreach my $dig (@rr) { 
        die("Undefined digit while reading input") if (!defined($dig));
        $board->{cell}->{$x.",".$y} -> set_cell($dig, "input provided") if ($dig =~ /^[0-9a-zA-Z]$/);
        $x++;
    }
    $y++;
}

my $rc;
$rc=$board->check();    # check content
die($rc) if ($rc);
$board->show_text();

my $check; # is board valid?
PUZZLE: while (1) {
    my $work=$board->infer();
    while ($board->check()) {
        print "UNDO after infer\n";
        $board=$board->unguess();
        die("Exhausted after $sol solutions\n") if ("EGUESS" eq $board);
    }

    print " - - - - - - - - - - -\n";
    if ($board->finished()) {
        $check=$board->check();
        die($check) if ($check);
        $board->show_text();
        printf("Solution number %d\n", ++$sol);
            if (!$guess_depth) {
                print "no guesses - unique solution";
                exit 0;
            }
            die("only one solution wanted\n") if (!$calc_all);
        $board=$board->unguess();  # look for more solutions
        die("Exhausted after $sol solutions\n") if ("EGUESS" eq $board);
        next;
    }

    if (!$work) {
        die("too many guesses") if ($guess_depth++ > $guesses_allowed);
      # $board->show_text();
        $board=board->new($size,$board);
        $board->guess();
        while ($board->check()) {
            print "UNDO after guess\n";
            $guesses_allowed++;
            $board=$board->unguess();
            die("Exhausted after $sol solutions\n") if ("EGUESS" eq $board);
        }
    }
}
