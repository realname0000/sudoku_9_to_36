#!/usr/bin/perl

use strict;
use warnings;

package board;
use clot;
use cell;

sub new
{
my ($p,$size,$stepdown)=@_;

my $cs=$size**2;  # clot size
my $clotcount=3*$cs;
my @az09;
if ($cs==9) {
    @az09=(1..9);
} elsif ($cs==16) {
    @az09=('A'..'P');
} elsif ($cs==25) {
    @az09=('A'..'Y');
} elsif ($cs==36) {
    @az09=(0..9, 'A'..'Z');
} else {
    die("funny size $size, $cs");
}

my %clot;
for my $z (1 .. $clotcount) {
    if ($z<=$cs) {
        $clot{$z}=clot->new("column ".$z, \@az09, $size);
    } elsif ($z<=(2*$cs)) {
        $clot{$z}=clot->new("row ".($z-$cs), \@az09, $size);
    } else {
        $clot{$z}=clot->new("block ".($z-(2*$cs)), \@az09, $size);
    }
}

my %cell;
for my $y (1..$cs) {
    for my $x (1..$cs) {
        my $block;
        # arithmetic here
        my $y_by_size=int(($y-1)/$size);  # 0 to 2 in standard size
        my $x_by_size=int(($x-1)/$size);  # 0 to 2 in standard size
        $block=1+$x_by_size+($size*$y_by_size);
        die("bad block number $block") if (($block<1) || ($block>$cs));
        #
        my $this=cell->new($cs,  $clot{$x},  $clot{$cs+$y},  $clot{(2*$cs)+$block},  $x,$y, \@az09);
        $cell{$x.",".$y}=$this;
        $clot{$x}->set_clot_list($this);
        $clot{$cs+$y}->set_clot_list($this);
        $clot{(2*$cs)+$block}->set_clot_list($this);
    }
}

my $r={
    size => $size,
    cs => $size**2,
    clot => \%clot,
    cell => \%cell,
       # above here doesn't change after init
    rota => [],
    stepdown => $stepdown, # for undoing guesses
    undo_coords => undef,
    undo_value => undef,
};

my @replace_rota;
if (defined($stepdown)) {
    @replace_rota=@{$stepdown->{rota}};
} else {
    @replace_rota=(1..(3*$cs));
}
$r->{rota}=\@replace_rota;

bless $r,$p;
return $r;
}


sub show_text
{
my ($self)=@_;

my %cell=%{$self->{cell}};
foreach my $y (1..$self->{cs}) {
    foreach my $x (1..$self->{cs}) {
        my $what=$cell{$x.",".$y};
        my ($known, $dig, @maybe)=$what->get_cell();
        if ($known) {
            printf("%s", $dig);
        } else {
            printf(".");
        }
        print " " if (!($x % $self->{size}));;
    }
    print "\n";
    print "\n" if (!($y % $self->{size}));;
}
print "\n";
return;
}


sub infer
{
my ($self)=@_;
my $work=0;
my @newrota=();
foreach my $kclot (@{$self->{rota}}) {
    if ($self->{clot}->{$kclot}->infer($self->{cs})) {
        $work=1;
        unshift(@newrota, $kclot);
    } else {
        push(@newrota, $kclot);
    }
}
$self->{rota}=\@newrota;
return $work;
}

sub finished
{
# return 1 if finished, 0 otherwise
my ($self)=@_;
my $rc=1;
my @newrota=();
foreach my $kclot (@{$self->{rota}}) {
    if ($self->{clot}->{$kclot}->finished()) {
        printf(" finished %s\n", $self->{clot}->{$kclot}->{clot_name});
        # cannot delete because used in check method
    } else {
        # clot not finished implies puzzle not finished
        $rc=0;
        push(@newrota, $kclot);
    }
}
$self->{rota}=\@newrota;
return $rc;
}


sub geometry
{
# return 0 if ok
my ($self)=@_;
foreach my $clot (values %{$self->{clot}}) {
    my $count=$clot->get_clot_list();
    return("bad number of cells ($count) in clot $clot->{clot_name}") if ($self->{cs} != $count);
    printf("CELL LIST: %s ", $clot->{clot_name});
    my @coord=map {"(".$_->getx().",".$_->gety().")" } $clot->get_clot_list();
    foreach my $xy (sort @coord) {
        printf("%s ", $xy);
    }
    print "\n";
}
return 0;
}

sub check
{
# return 0 if ok
my ($self)=@_;
foreach my $clot (values %{$self->{clot}}) {
    my $rc=$clot->check();
    return $rc if ($rc);
}
return 0;
}

sub guess
{
# This populates a new board with known details from the earlier board.
# Then picks a guess and writes this guess in the new board (set_cell) and plans the opposite
# in the old one (notdig).  So if this board is abandoned the other one has learned from it.
my ($self)=@_;

# Start by copying other board to this one.
my $old=$self->{stepdown};
my ($oldcell,$newcell);
die("Can only guess on a copied board - not the original.") if (!$old);
for (my $x=1;$x<=$self->{cs};$x++) {
    for (my $y=1;$y<=$self->{cs};$y++) {
        $oldcell=$old->{cell}->{$x.",".$y};
        $newcell=$self->{cell}->{$x.",".$y};
        $newcell->copy($oldcell);
    }
}

# choose guess
my ($bestprob, $bestcell)=(0,undef);
foreach my $kclot (@{$old->{rota}}) {
    my ($p,$c)=$self->{clot}->{$kclot}->guess();
    ($bestprob, $bestcell)=($p,$c) if ($p>$bestprob);
}
return if (!defined($bestcell));

# mark guess on board
my $x=$bestcell->getx();
my $y=$bestcell->gety();
$newcell=$self->{cell}->{$x.",".$y};
die("SNH This xy is not my cell") if ($bestcell ne $newcell);
my ($known, $value, @maybe)=$newcell->get_cell();
die("SNH cannot guess a cell that's known") if ($known);
die("SNH maybe array expected to exist for cell $x $y") if (!defined($maybe[0]));
my $g=$maybe[int rand scalar @maybe];  # vary the guess over possible values
# save notdig() action in case guess is undone (not now -it pollutes the output)
    $self->{undo_coords}=$x.",".$y;
    $self->{undo_value}=$g;
$newcell->set_cell($g, "guess with probability $bestprob");
#$self->show_text();
return "ok";
}

sub unguess
{
my ($self)=@_;
my $oldboard=$self->{stepdown};
return "EGUESS" if (!defined($oldboard)); # Cannot undo a guess from the start position
my $reason=sprintf("undo bad guess %s", $self->{undo_value});
my $rc=$oldboard->{cell}->{$self->{undo_coords}}->notdig($reason, $self->{undo_value});
return $oldboard;
}

1;
