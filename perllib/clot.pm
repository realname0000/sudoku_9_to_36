#!/usr/bin/perl

# using "clot" for a colection of cells
# 9 cells in standard sized game (row/colum/block)
use strict;
use warnings; 
package clot;

sub new
{
# This data is board geometry and does not change during the game.
my ($p,$name,$az09ref,$size)=@_;
my $r={
    cells => [],   # which cells are in this clot
    clot_name => $name,
    az09ref => $az09ref,
    size => $size,
};
bless $r,$p;
return $r;
}

sub notdig
{
# exclude a certain value from (unsolved) cells in the clot
my ($self,$reason,$dig)=@_;
die("needed digit in clot->notdig()") if (!defined($dig));
foreach my $c (@{$self->{cells}}) {
    $c->notdig($reason,$dig);
}
return;
}

sub finished
{
# return 1 if finished
my ($self)=@_;
foreach my $c (@{$self->{cells}}) {
    my ($k,@junk)=$c->get_cell();
    return 0 if (!$k);
}
return 1;
}

sub check
{
# return 0 if ok
my ($self)=@_;
my %dd=();
foreach my $c (@{$self->{cells}}) {
    my ($k,$v,@m)=$c->get_cell();
    $dd{$v}++ if ($k);
}
foreach my $k (sort keys %dd) {
   return "ERROR  $dd{$k} of $k in ".$self->{clot_name} if ($dd{$k}>1);
}
return 0;
}

sub set_clot_list
{
my ($self,@cid)=@_;
push (@{$self->{cells}}, @cid);
return;
}

sub get_clot_list
{
my ($self)=@_;
return @{$self->{cells}};
}

sub guess
{
my ($self,$parm)=@_;
#
my @c=@{$self->{cells}};
my ($prob,$cellchoice)=(0,undef);
#
foreach my $c (@c) {
    my ($known,$value,@maybe)=$c->get_cell();
    if ($known) {
        next;
    } 
    # @maybe is number to guess from
    if (scalar @maybe>1) {
        my $p=1/(scalar @maybe);
        ($prob,$cellchoice)=($p,$c) if ($p>$prob);
    }
}
# 
return ($prob,$cellchoice);
}

#############

sub infer
{
my ($self,$cs)=@_;
my $cells_remaining=0;
my %poss_count;
my $work=0;
#
my @c=@{$self->{cells}};
my $from={map {$_=>[]} @{$self->{az09ref}}};
#
foreach my $c (@c) {
    my ($known,$value,@maybe)=$c->get_cell();
    next if ($known);
    foreach my $m (@maybe) {
        $poss_count{$m}++;
        push(@{$from->{$m}}, $c);  # list of cells allowing m as content
    }
    $cells_remaining++;
}
# 
foreach my $m (keys %poss_count) {
#
# single possibility
#
    if (1==$poss_count{$m}) {
      my $c=$from->{$m}->[0];
      $c->set_cell($m, "Only place for char ".$m." in ".$self->{clot_name});
      $work=1;
    }
    return 1 if ($work);
#
# multiple cells in one clot transferring info to other clots they are in
#
    if (($poss_count{$m}>1) && ($poss_count{$m} <= $self->{size})) {
      my @spread=@{$from->{$m}};
          # Cut this digit from the remainder of relevant clots.
          my $fc=shift @spread; # first cell
          my ($target_column, $target_row, $target_block)=($fc->{incolumn}, $fc->{inrow}, $fc->{inblock});
          foreach my $c (@spread) {
              $target_column=0 if ($target_column != $c->{incolumn});
              $target_row=0 if ($target_row != $c->{inrow});
              $target_block=0 if ($target_block != $c->{inblock});
          }
          my %foreigncells=();
          foreach my $changeclot ($target_column, $target_row, $target_block) {
              next if ((!$changeclot) or ($changeclot==$self));
              foreach my $changecell ($changeclot->get_clot_list()) {
                  $foreigncells{$changecell}=$changecell;
              }
          }
          foreach my $changecell ($fc, @spread) {
              delete $foreigncells{$changecell};
          }
          # keys have been stringified but values have not
          foreach my $c (values %foreigncells) {
              my $reason=sprintf("guided by %s", $self->{clot_name});
              my $rc=$c->notdig($reason,$m);
              $work |= 1 if ("ok_1" eq $rc);
          }
   }
   return 1 if ($work);
}
#
# multiple cells in one clot improving the same clot
#
my %pc2m=(map {$_=>[]}  2..$self->{size});
foreach my $m (@{$self->{az09ref}}) {
   push(@{$pc2m{$poss_count{$m}}}, $m) if ($poss_count{$m}); # which chars have what poss_counts, keyed by count 
}
my @sofar;
foreach my $p (sort {$pc2m{$a} <=> $pc2m{$b}} keys %pc2m) {
    next if (0==@{$pc2m{$p}});
    push @sofar, @{$pc2m{$p}};
    #printf("PossCount %s in %s has these chars: %s\n", $p, $self->{clot_name}, join('',@{$pc2m{$p}}) );
    if ((scalar @sofar) >= $p) {
        # then exclude any other values from these $p cells
        $work |=1 if ($self->cycle($from, $p,[], [@sofar]));
    }
}

return $work;
}


sub cycle
{
# pick any $p elements of @sofar st combined from == $p
my ($self,$from,$p,$chosen,$dredge)=@_;
## $from   # @{$from->{$v}} is a list of cells
## $p      # number of chars to choose

my $work=0;
my %tf; # totalfrom
my @chosen=@{$chosen};
if (@chosen>1) {
    foreach my $v (@chosen) {
        foreach my $f (@{$from->{$v}}) {
            $tf{$f}=$f;
        }
    }
    return 0 if (scalar keys %tf > $p);
}

if ($p == @chosen) {
    # test the from values
    my $reason=sprintf("cycle of %d in  %s", $p, $self->{clot_name});
    my $ndr=0;
    my %todelete=(map {$_=>0}  @{$self->{az09ref}});
    foreach my $v (@chosen) {
        delete $todelete{$v};
    }
    foreach my $c (values %tf) {
        $ndr=1 if ($c->notdig($reason, keys %todelete) eq "ok_1");
    }
    return $ndr;
}
my @dredge=@{$dredge};
return 0 if (!@dredge);
my $car=shift @dredge;

# we both take it and don't take it.
return 1 if ($self->cycle($from, $p,[@chosen,$car], [@dredge]));
return 1 if ($self->cycle($from, $p,[@chosen], [@dredge]));
return 0;
}

1;
