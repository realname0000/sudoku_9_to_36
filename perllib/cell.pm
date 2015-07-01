#!/usr/bin/perl

use strict;
use warnings;

package cell;
use Carp;

sub new
{
my ($p,$cs,$incolumn, $inrow, $inblock, $x, $y, $az09ref)=@_;

my $r={
    known => 0,
    value => 0,
      # below here doesn't change after init
    incolumn => $incolumn,
    inrow => $inrow,
    inblock => $inblock,
    x => $x,
    y => $y,
    az09ref => $az09ref,
};

die("No incolumn value") if (!defined ($r->{incolumn}));
die("No inrow value") if (!defined ($r->{inrow}));
die("No inblock value") if (!defined ($r->{inblock}));
die("No X value") if (!defined ($r->{x}));
die("No Y value") if (!defined ($r->{y}));

$r->{maybe} = {map {$_=>0} @{$az09ref}};

bless $r,$p;
return $r;
}

sub copy
{
my ($self,$from)=@_;
foreach my $k ("known","value") {
    $self->{$k} = $from->{$k};
}
my %replace_maybe;
foreach my $m (keys %{$from->{"maybe"}}) {
    $replace_maybe{$m}=0;
}
$self->{maybe}=\%replace_maybe;
return;
}

sub set_cell
{
my ($self,$value,$reason)=@_;
carp("needed value parameter") if (!defined($value));
die("bad cell input $value") if ($value !~ /^[0-9a-zA-Z]$/); # XXXXX
$value=uc $value;
return("ERROR cannot set cell twice") if ($self->{known} && ($self->{value} ne $value));
printf("cell %d %d becomes %s: %s\n", $self->{x}, $self->{y}, $value, $reason) if (defined($reason));
$self->{known}=1;
$self->{value}=$value;
$self->{maybe}={}; # always empty if cell is known
#this cell wants to update clots of cells
$self->{inrow}->notdig('',$value);
$self->{incolumn}->notdig('',$value);
$self->{inblock}->notdig('',$value);
return;
}


sub setm
{
my ($self)=@_;
carp("cannot set maybe values in a known cell") if ($self->{known});
$self->{maybe}={map {uc $_ => 0} @_};
return;
}

sub get_cell
{
my ($self)=@_;
die("black hole for $self  X=$self->{x}  Y=$self->{y}") if (!$self->{known} && (0==keys %{$self->{maybe}}));
return ($self->{known}, $self->{value}, sort keys %{$self->{maybe}});
}

sub getx
{
my ($self)=@_;
return $self->{x};
}

sub gety
{
my ($self)=@_;
return $self->{y};
}

sub notdig
{
my ($self,$reason)=@_;
return "ok_0" if ($self->{known});
my $rc="ok_0";
foreach my $dig (@_) {
    next unless (defined($self->{maybe}->{$dig}));
    printf("cell %d %d excludes %s: %s\n", $self->{x}, $self->{y}, $dig, $reason) if ($reason);
    delete $self->{maybe}->{$dig};
    $rc="ok_1";
}
if (1 == keys %{$self->{maybe}}) {
    $self->set_cell(keys %{$self->{maybe}}, "others eliminated");
    return "ok_1";
}
return $rc;
}

1;
