#!/usr/bin/perl

######################################################################
#############USE AT YOUR OWN RISK#####################################
# the revisions to this code are quick, hasty, and relatively untested
######################################################################

####################################################################
# This is a simple Perl Program that performs the same calculations#
# that the Follower verilog should to for PI control loop.  The    #
# analog data is read from analog.dat in the CWD.  The value of    #
# the coefficients Pterm/Iterm are defined below.                  #
####################################################################
$Pterm = 0x37e0;
$Iterm = 0x380;

#########################################################################
# Two log files are output:  "detailed_calcs.txt" contains detailed     #
# step by step intermediate outputs for each calculation.               #
# "summary_calcs.txt" just contains the final "lft" "rht" calculations. #
#########################################################################
open(DETAILED,">detailed_calcs.txt") || die "ERROR: can't open detailed_calcs.txt for write";
open(SUMMARY,">summary_calcs.txt") || die "ERROR: can't open summary_calcs.txt for write";
print "\nCreating \"detailed_calcs.txt\" and \"summary_calcs.txt\" with results:\n\n";

#################################################################################
## Read analog.dat and pack it into a 2-dim array $a2d[$set_cntr][$chnnl_cntr] ##
#################################################################################
open(INFILE,"analog.dat") || die "ERROR: Can't open analog.dat for read\n";
$set_cntr = 0;
$chnnl_cntr = 0;
while (<INFILE>) {
  if ($_=~/^@/) {
    @words = split(/ /,$_);
	chop($words[1]);
	$a2d[$set_cntr][$chnnl_cntr] = &hex2dec_inv($words[1]);
	$chnnl_cntr++;
	if ($chnnl_cntr>7) {
	  $chnnl_cntr = 0;
	  $set_cntr++;
	}
  }
}

$Intgrl = 0;
$int_dec = 0;
$Fwd = 0;
printf SUMMARY "\/\/calc# right left\n";
for ($calcs=0; $calcs<($set_cntr+1)/6; $calcs++) {
  printf "For calculation %d results are...\n",$calcs+1;
  printf DETAILED "For calculation %d results are...\n",$calcs+1;
  printf SUMMARY "%d ",$calcs+1;
  $base = $calcs*6;
  $accum = 0;
  $accum+=$a2d[$base+0][1];
  $accum-=$a2d[$base+1][0];
  $accum+=2*$a2d[$base+2][4];
  $accum-=2*$a2d[$base+3][2];
  $accum+=4*$a2d[$base+4][3];
  $accum-=4*$a2d[$base+5][7];
  $error = saturate($accum);
  printf "  The Error function for calc %d is %3x\n",$calc+1,$error;
  printf DETAILED "  The Error function for calc %d is %3x\n",$calc+1,$error;
  if ($int_dec==3) {
    $temp = digital_trunc($error/16);
    $Intgrl += $temp;
	$Intgrl = saturate($Intgrl);
    printf "  Integrating...  Intgrl = %3x ...",$Intgrl;
	printf DETAILED "  Integrating...  Intgrl = %3x ...",$Intgrl;
    if ($Fwd<1536) {
	  $Fwd++;
	  printf "Fwd incremented to %3x\n",$Fwd;
	  printf DETAILED "Fwd incremented to %3x\n",$Fwd;
	}
	else {
	  print "Fwd remains saturated";
	  print DETAILED "Fwd remains saturated";
	}
	$int_dec=0;
  }
  else {
    printf "  No integration occurs this cycle\n";
	printf DETAILED "  No integration occurs this cycle\n";
	$int_dec++;
  }
  $Icomp = int($Iterm*$Intgrl/4096);
  $Icomp = mult_sat($Icomp);
  printf "  Icomp = %3x\n",$Icomp;
  printf DETAILED "  Icomp = %3x\n",$Icomp;
  $Pcomp = int($error*$Pterm/4096);
  $Pcomp = mult_sat($Pcomp);
  printf "  Pcomp = %3x\n",$Pcomp;
  printf DETAILED "  Pcomp = %3x\n",$Pcomp;  
  $accum = $Fwd - $Pcomp;
  $rht_reg = saturate($accum - $Icomp);
  printf "  rht_reg = %3x\n",$rht_reg;
  printf DETAILED "  rht_reg = %3x\n",$rht_reg;
  printf SUMMARY "%3x ",$rht_reg;
  $accum = $Fwd + $Pcomp;
  $lft_reg = saturate($accum + $Icomp);
  printf "  lft_reg = %3x\n",$lft_reg;
  printf DETAILED "  lft_reg = %3x\n",$lft_reg;
  printf SUMMARY "%3x\n",$lft_reg;
}
close(SUMMARY);
close(DETAILED);

sub saturate {
  if ($_[0]>2047) {
    print "  Pos Saturation occurred\n";
	print DETAILED "  Pos Saturation occurred\n";
	return(2047); 
  }
  if ($_[0]<-2048) {
    print "  Neg Saturation occurred\n";
	print DETAILED "  Neg Saturation occurred\n";
	return(-2048);
  }
  else { return ($_[0]); }
}

sub mult_sat {
  if ($_[0]>16383) {
    print DETAILED "  Pos Mult Saturation occurred\n";  
    print "  Pos Mult Saturation occurred\n";
	return(16383);
  }
  if ($_[0]<-16384) {
    print DETAILED "  Neg Mult Saturation occurred\n";
    print "  Neg Mult Saturation occurred\n";
	return(-16384);
  }
  else { return ($_[0]); }
}

sub digital_trunc {
  if ($_[0]<0) {
    $temp = -$_[0];
    $temp = int($temp+0.99);
    return(-$temp);
  }
  else { return(int($_[0])); }
}

########################################
## Converts hex number into decimal,   #
## but also performs a 1's complement  #
########################################
sub hex2dec_inv {
  $accum = 0;
  $weight = 1;
  if ($_[0]=~/\n/) {
      chop($_[0]);
  }
  $len = length($_[0]);
  if ($len>3) {
      chop($_[0]);
      $len = length($_[0]);
  }
  for ($y=$len; $y>0; $y--) {
    $accum=$accum+$weight*&hex_val(substr($_[0],$y-1,1));
    $weight*=16;
  }
  return(4095 - $accum);
}

sub hex_val {
  if ($_[0]=~/0/) { return(0); }
  elsif ($_[0]=~/1/) { return(1); }
  elsif ($_[0]=~/2/) { return(2); }
  elsif ($_[0]=~/3/) { return(3); }
  elsif ($_[0]=~/4/) { return(4); }
  elsif ($_[0]=~/5/) { return(5); }
  elsif ($_[0]=~/6/) { return(6); }
  elsif ($_[0]=~/7/) { return(7); }
  elsif ($_[0]=~/8/) { return(8); }
  elsif ($_[0]=~/9/) { return(9); }
  elsif ($_[0]=~/a/i) { return(10); }
  elsif ($_[0]=~/b/i) { return(11); }
  elsif ($_[0]=~/c/i) { return(12); }
  elsif ($_[0]=~/d/i) { return(13); }
  elsif ($_[0]=~/e/i) { return(14); }
  elsif ($_[0]=~/f/i) { return(15); }
  else {return(-1);}
}

close(INFILE);
