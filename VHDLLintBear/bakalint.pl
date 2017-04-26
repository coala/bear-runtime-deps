#!/usr/bin/perl
##############################################################################
#
# Copyright (c) 2005-2008 Salvador E. Tropea <salvador en inti gov ar>
# Copyright (c) 2005-2008 Instituto Nacional de Tecnología Industrial
#
##############################################################################
#
# Target:           Any
# Language:         Perl
# Interpreter used: v5.6.1/v5.8.4
# Text editor:      SETEdit 0.5.5
#
##############################################################################
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
# 02111-1307, USA
#
##############################################################################
#
# Description: A very stupid (baka) lint tool for VHDL.
#
##############################################################################
#
# TODO
#
# Mejorarlo ;-)
#
use Getopt::Long;

$Version='0.4.0';
@reserved=(
'abs','access','after','alias','all','and','architecture','array','assert',
'attribute','begin','block','body','buffer','bus','case','component',
'configuration','constant','disconnect','downto','else','elsif','end',
'entity','exit','file','for','function','generate','generic','group',
'guarded','if','impure','in','inertial','inout','is','label','library',
'linkage','literal','loop','map','mod','nand','new','next','nor','not',
'null','of','on','open','or','others','out','package','port','postponed',
'procedure','process','pure','range','record','register','reject','rem',
'report','return','rol','ror','select','severity','shared','signal','sla',
'sll','sra','srl','subtype','then','to','transport','type','unaffected',
'units','until','use','variable','wait','when','while','with','xnor','xor',
# Not reserved, just very important
'std','IEEE','textio','standard','std_logic_1164','numeric_std',
'numeric_bit','boolean','bit','character','severity_level','natural',
'integer','real','time',
'delay_length','natural','positive','string','bit_vector','file_open_kind',
'file_open_status','file',
'line','text','side','width',
'std_logic','std_logic_vector','std_ulogic','std_ulogic_vector','x01','x01z',
'ux01','ux01z',
'unsigned','signed',
'read_mode','write_mode','append_mode','open_ok','status_error','name_error',
'mode_error','note','warning','error','failure','fs','ps','ns','us','ms',
'sec','min','hr',
'false','true','nul','soh','stx','etx','eot','enq','ack','bel','bs','ht',
'lf','vt','ff','cr','so',
'si','dle','dc1','dc2','dc3','dc4','nak','syn','etb','can','em','sub','esc',
'fsp','gsp','rsp','usp',
'del','c128','c129','c130','c131','c132','c133','c134','c135','c136','c137',
'c138','c139',
'c140','c141','c142','c143','c144','c145','c146','c147','c148','c149','c150',
'c151','c152',
'c153','c154','c155','c156','c157','c158','c159',
'now',
'input','output','read','readline','write','writeline',
'falling_edge','rising_edge','to_bit','to_bitvector','to_stdulogic',
'to_stdlogicvector','to_stdulogicvector','to_x01','to_x01z','to_ux01',
'to_ux01z','is_x',
'shift_left','shift_right','rotate_left','rotate_right','resize',
'to_integer','to_unsigned','to_signed','std_match','to_01,',
'base','left','right','high','low','ascending','image','value','pos','val',
'succ',
'pred','leftof','rightof','range','reverse_range','length','delayed','stable',
'quiet','transaction','event','active','last_event','last_active','last_value',
'driving','driving_value','simple_name','instance_name',
'foreign');
@wishbone=
(
 'rst_i','rst_o','clk_i','clk_o','adr_i','adr_o','dat_i','dat_o','we_i',
 'we_o','stb_i','stb_o','ack_o','ack_i','sel_i','sel_o','cyc_i','cyc_o',
 'tgd_i','tgd_o','err_i','err_o','rty_i','rty_o','lock_i','lock_i','tga_i',
 'tga_o','tgc_i','tgc_o'
);

$line=1;
$warnings=0;
$errors=0;
$indent=0;
$mxSig=15;

print "BakaLint v$Version Copyright (c) 2005-2008 Salvador E. Tropea/INTI\n";

ParseCommandLine();
$mxCnt=$mxSig-2;
$fileBase=$file;
$fileBase=~s/\..*//;
open(FIL,"<$file") || die "Can't open $file file\n";
open(OUT,">$outFile") || die "Can't create $outFile file\n";
do
  {
   GetLine();
   if ($isEof)
     {
      print "End of $file\n";
      PrintWarning("unbalanced constructions") if scalar(@indentSt);
      ReportErrors(1);
     }
   $incIndent=0;
   $tempIncIndent=0;
   $isFuncProc=0;

   #########################################
   # Enforce lower case on reserved words  #
   #########################################
   CheckReserved();

   ###############################
   # Apply the replacements list #
   ###############################
   ApplyAllReplacements();

   $found=0;
   $label=0;
   ########
   # port #
   ########
   if ($t=~/[^\w\d_]port[^\w\d_]/)
     {
      $insidePort=1;
      $found++;
      $oP=$cP=0;
      $curLabel='';
      if ($t=~/[^\w\d_]port[^\w\d_]+map[^\w\d_]/)
        {
         $incIndent=6;
         $tempIncIndent=3;
        }
      else
        {
         $incIndent=3;
        }
     }
   ###########
   # generic #
   ###########
   if ($t=~/[^\w\d_]generic[^\w\d_]/)
     {
      $insideGeneric=1;
      $found++;
      $oP=$cP=0;
      $curLabel='';
      if ($t=~/[^\w\d_]generic[^\w\d_]+map[^\w\d_]/)
        {
         $incIndent=6;
         $tempIncIndent=3;
        }
      else
        {
         $incIndent=3;
        }
     }

   #########################################
   # Extract variables, signals and labels #
   #########################################
   if ($t=~/variable\s+([^:]+)\s*:\s*([^;]+);/)
     {
      $a=$1;
      $a=~s/\s//g;
      @v=split /,/,$a;
      foreach $a (@v)
         {
          if ($a ne lc($a))
            {
             PrintNCError("use lower case for variables [$a]");
             AddReplacement($a,lc($a));
            }
         }
      $curLabel='';
      $found++;
     }
   elsif ($t=~/[^\w\d_]signal[^\w\d_]/ and
          $t!~/[^\w\d_]attribute[^\w\d_]/)
     {
      my $tmp1=0;
      $tmp1=1 if $t=~/(.*)signal\s+([^:]+)\s*:\s*([^\:]+)\:\=/;
      PrintError("`signal ... : ...;` must fit in one line")
         unless $t=~/(.*)signal\s+([^:]+)\s*:\s*([^;]+);/ or
                $tmp1 or $insideFuncProcDec;
      $pre=$1;
      $a=$2;
      $b=$3;
      $a=~s/^\s+//;
      $a=~s/\s+$//;
      $c=$a;
      $notHere=$insideFuncProcDec || ($pre=~/procedure|function/i) || $tmp1;
      if (length($c)>$mxSig)
        {
         PrintError("too much signals on this line, split it") if $c=~/,/;
         PrintError("signal name/s must be less than $mxSig characters");
        }
      $a=~s/\s//g;
      @v=split /,/,$a;

      unless ($notHere)
        {
         #print "signal [$c] [$b]\n";
         $a=$t;
         $t=$pre."signal $c".MakeSps($mxSig-length($c))." : $b;";
         $t.="\n" if $a=~/\n/;
         $t.='>';
        }

      foreach $a (@v)
         {
          if ($a ne lc($a))
            {
             PrintNCError("use lower case for signals [$a]");
             AddReplacement($a,lc($a));
            }
         }
      $curLabel='';
      $found++;
     }
   elsif ($t=~/(.*)constant\s+([^:=]+)\s*:\s*(.*)>$/s)
     {
      $pre=$1; $a=$2; $b=$3;
      $notHere=$insideFuncProcDec || $pre=~/procedure|function/;
      PrintError("`constant ... : ... :=` must fit in one line ($insideFuncProcDec $isFuncProc)")
        unless $b=~/:=/ or $notHere;
      if ($b!~/;/)
        {
         $insideConst=1;
         $incIndent=3;
        }
      $a=~s/^\s+//;
      $a=~s/\s+$//;
      $c=$a;
      if (length($c)>$mxSig)
        {
         PrintError("too much constants on this line, split it") if $c=~/,/;
         PrintError("constant name/s must be less than $mxCnt characters");
        }
      $a=~s/\s//g;
      @v=split /,/,$a;

      $t="<constant $c".MakeSps($mxCnt-length($c))." : $b>" unless ($notHere);

      foreach $a (@v)
         {
          if ($a ne uc($a))
            {
             PrintNCError("use upper case for constants [$a]");
             AddReplacement($a,uc($a));
            }
         }
      $curLabel='';
      $found++;
     }
   elsif ($insidePort and
          $t=~/[^\w\d_]+([^:\(]+)\s*:\s*(in|out|inout|buffer)\s+/)
     {
      $found++;
      $a=$ports=$1;
      $kind=$2;
      PrintError("don't use buffer, use an auxiliar signal instead")
        if $kind eq 'buffer';
      PrintError("use only one port on each line") if $ports=~/,/;
      $a=~s/^\s+//;
      $a=~s/\s+$//;
      $b=length($a);
      PrintError("the maximum port name length is $mxSig") if $b>$mxSig;
      $ports=~s/\s//g;
      if ($ports ne lc($ports))
        {
         PrintNCError("use lower case for ports [$ports]");
         $newP=lc($ports);
         AddReplacement($ports,$newP);
         $ports=$newP;
        }
      if ($kind eq 'in' and $ports!~/_i$/)
        {
         PrintNCError("rename `$ports` to `$ports"."_i`");
         $newP=$ports.'_i';
         AddReplacement($ports,$newP);
         $ports=$newP;
        }
      elsif ($kind eq 'out' and $ports!~/_o$/)
        {
         PrintNCError("rename `$ports` to `$ports"."_o`");
         $newP=$ports.'_o';
         AddReplacement($ports,$newP);
         $ports=$newP;
        }
      elsif ($kind eq 'inout' and $ports!~/_io$/)
        {
         PrintNCError("rename `$ports` to `$ports"."_io`");
         $newP=$ports.'_io';
         AddReplacement($ports,$newP);
         $ports=$newP;
        }
      if ($forWishbone)
        {
         foreach $a (@wishbone)
            {
             if ($a eq $ports)
               {
                PrintNCError("rename wishbone `$ports` to `wb_$ports`");
                $newP='wb_'.$ports;
                AddReplacement($ports,$newP);
                $ports=$newP;
                last;
               }
            }
        }
      $t=~/[^\w\d_]+([^:\(]+)\s*:\s*(in|out|inout|buffer)\s+/;
      $a=$ports=$1;
      $kind=$2;
      $a=~s/^\s+//;
      $a=~s/\s+$//;
      $b=length($a);
      PrintError("the maximum port name length is $mxSig") if $b>$mxSig;
      $c=MakeSps($mxSig-$b);
      $t=~s/$ports\s*:\s*$kind/$a$c : $kind/i;
      #print "Ports [$a] $kind [$c]\n";
     }
   elsif ($insideGeneric and
          $t=~/[^\w\d_]+([^:\(]+)\s*:/)
     {
      $a=$generics=$1;
      PrintError("use only one generic on each line") if $generics=~/,/;
      $a=~s/^\s+//;
      $a=~s/\s+$//;
      $b=length($a);
      PrintError("the maximum generic name length is $mxSig") if $b>$mxSig;
      $generics=~s/\s//g;
      if ($generics ne uc($generics))
        {
         PrintNCError("use upper case for generics [$generics]");
         AddReplacement($generics,uc($generics));
        }
      $found++;

      $t=~/[^\w\d_]+([^:\(]+)\s*:/;
      $a=$generics=$1;
      $a=~s/^\s+//;
      $a=~s/\s+$//;
      $b=length($a);
      PrintError("the maximum generic name length is $mxSig") if $b>$mxSig;
      $c=MakeSps($mxSig-$b);
      $t=~s/$generics\s*:/$a$c :/i;
      #print "Generics [$1] $2\n";
     }
   elsif ($t=~/[^\w\d_\(]+([\d\w_]+)\s*:[\s\>]/)
     {
      $curLabel=$1;
      $found++;
      $label=1;
     }
   if ($insidePort or $insideGeneric)
     {
      for (; $t=~/\(/g; $oP++) {}
      for (; $t=~/\)/g; $cP++) {}
      if ($cP==$oP)
        {
         if ($t=~/[^\w\d_](generic|port)[^\w\d_]+map[^\w\d_]/)
           {
            $incIndent=$tempIncIndent=0;
           }
         else
           {
            $incIndent=-(pop @indentSt);
            $insidePort=$insideGeneric=0;
            print OUT "Poping $incIndent end of port or generic\n"
               if $DebugIncStack;
           }
        }
     }

   ###############
   # with/select #
   ###############
   if ($t=~/[^\w\d_]with[^\w\d_]/)
     {
      if ($t=~/[^\w\d_]with[^\w\d_]+(.*)\s+select\s+([\w\d_]+)\s*<=/)
        {
         $curLabel='';
         $found++;
         if (t!~/;/)
           {
            $incIndent=5;
            $insideWith++;
           }
        }
      else
        {
         PrintError("`with ... select ... <=` must fit in one line");
        }
     }

   ###############################################
   # Are we opening something that needs an end? #
   ###############################################
   # architecture #
   ################
   if ($t=~/[^\w\d_]architecture[^\w\d_]/)
     {
      if ($t=~/[^\w\d_]architecture[^\w\d_]+([\w\d_]+)\s+of\s+([\w\d_]+)\s+is/)
        {
         push @nestedT,'architecture';
         push @nestedC,"of entity $2";
         $curLabel='';
         SolveMixed('architectures',$1);
         $found++;
         $incIndent=3;
         $lookForBegin++;
        }
      else
        {
         PrintError("`architecture ... of ... is` must fit in one line")
           unless $t=~/end[^\w\d_]+architecture[^\w\d_]/;
        }
     }
   #############
   # component #
   #############
   if ($t=~/[^\w\d_]+component\s+/)
     {
      if ($t=~/[^\w\d_]+component\s+([\w\d_]+)\s+is/)
        {
         push @nestedT,'component';
         push @nestedC,'';
         SolveMixed('components',$1);
         $curLabel='';
         $incIndent=3;
         $found++;
        }
      else
        {
         PrintError("`component ... is` must fit in one line")
           unless $t=~/end[^\w\d_]+component[^\w\d_]/;
        }
     }
   ##########
   # entity #
   ##########
   if ($t=~/[^\w\d_]+entity\s+/)
     {
      if ($t=~/[^\w\d_]+entity\s+([\w\d_]+)\s+is/)
        {
         push @nestedT,'entity';
         push @nestedC,'';
         $curLabel='';
         SolveMixed('entities',$1);
         $found++;
         $incIndent=3;
        }
      else
        {
         PrintError("`entity ... is` must fit in one line")
           unless $t=~/end[^\w\d_]+entity[^\w\d_]/ or
                  $t=~/use[^\w\d_]+entity[^\w\d_]/;
        }
     }
   #########
   # block #
   #########
   if ($t=~/[^\w\d_]block[^\w\d_]/ and
       $t!~/end[^\w\d_]+block[^\w\d_]/)
     {
      push @nestedT,'block';
      $curLabel=SolveWithoutLabel('block') unless $curLabel;
      push @nestedN,$curLabel;
      push @nestedC,'';
      $curLabel='';
      $found++;
      $incIndent=3;
      $lookForBegin++;
     }
   ###########
   # process #
   ###########
   if ($t=~/[^\w\d_]process[^\w\d_]/ and
       $t!~/end[^\w\d_]+process[^\w\d_]/)
     {
      push @nestedT,'process';
      $curLabel=SolveWithoutLabel('process') unless $curLabel;
      push @nestedN,$curLabel;
      push @nestedC,'';
      $curLabel='';
      $found++;
      $incIndent=3;
      $lookForBegin++;
     }
   ####################
   # if then|generate #
   ####################
   if ($t=~/[^\w\d_]if[^\w\d_]/ and
       $t!~/end[^\w\d_]+if[^\w\d_]/)
     {
      unless ($t=~/[^\w\d_](then|generate)[^\w\d_]/)
        {
         $oldLine=$line;
         do
           {
            PutLine();
            $tempIncIndent=4;
            GetLine();
            PrintError("unexpected end of file, looking for `then|generate` from line $oldLine")
              if $isEof;
            $line++;
            CheckReserved();
            ApplyAllReplacements();
           }
         while ($t!~/[^\w\d_](then|generate)[^\w\d_]/);
        }
      if ($1 eq 'generate')
        {
         push @nestedT,'generate';
         $curLabel=SolveWithoutLabel('generate') unless $curLabel;
         push @nestedN,$curLabel;
        }
      else
        {
         push @nestedT,'if';
         push @nestedN,'';
         $insideIf++;
        }
      push @nestedC,'';
      $curLabel='';
      $found++;
      $incIndent=3;
     }
   #####################
   # for loop|generate #
   #####################
   if ($t=~/[^\w\d_]for[^\w\d_]/)
     {
      if ($t=~/[^\w\d_]for[^\w\d_](.*)[^\w\d_](loop|generate)[^\w\d_]/)
        {
         if ($2 eq 'generate')
           {
            push @nestedT,'generate';
            $curLabel=SolveWithoutLabel('generate') unless $curLabel;
           }
         else
           {
            push @nestedT,'loop';
           }
         push @nestedN,$curLabel;
         push @nestedC,'';
         $curLabel='';
         $found++;
         $incIndent=4;
        }
      elsif ($t!~/[^\w\d_]wait\s+for[^\w\d_]/ and
             $t!~/for\s+[\w\d_]+\s*:/) # for xxx: use ...
        {
         PrintError("`for ... loop|generate` must fit in one line");
        }
     }
   ##############
   # while loop #
   ##############
   if ($t=~/[^\w\d_]while[^\w\d_]/)
     {
      if ($t=~/[^\w\d_]while[^\w\d_](.*)[^\w\d_]loop[^\w\d_]/)
        {
         push @nestedT,'loop';
         push @nestedN,$curLabel;
         push @nestedC,'';
         $curLabel='';
         $found++;
         $incIndent=3;
        }
      else
        {
         PrintError("`while ... loop` must fit in one line");
        }
     }
   ########
   # case #
   ########
   if ($t=~/[^\w\d_]case[^\w\d_]/ and
       $t!~/end[^\w\d_]+case[^\w\d_]/)
     {
      if ($t=~/[^\w\d_]case[^\w\d_](.*)[^\w\d_]is[^\w\d_]/)
        {
         push @nestedT,'case';
         push @nestedN,'';
         push @nestedC,'';
         $curLabel='';
         $found++;
         $incIndent=5+5;
         $insideCase++;
        }
      else
        {
         PrintError("`case ... is` must fit in one line");
        }
     }
   ########
   # when #
   ########
   if ($insideCase and $t=~/^[^\w\d_]\s*when[^\w\d_]/)
     {
      $curLabel='';
      $found++;
      $tempIncIndent=-5;
     }
   ############
   # function #
   ############
   if ($t=~/[^\w\d_]function[^\w\d_]/ and
       $t!~/end[^\w\d_]+function[^\w\d_]/)
     {
      if ($t=~/[^\w\d_](function[^\w\d_]([\w\d_]+)[^\w\d_]*\()/ or
          # function "op" ( => function <n> (
          $t=~/[^\w\d_](function\s*(\<\d+\>)\s*\()/)
        {
         $a=$1;
         $n=$2;
         if ($n=~/\<(\d+)\>/)
           {
            $n=@fStrs[$1];
            $a=~s/\<$1\>/@fStrs[$1]/;
           }
         push @nestedT,'function';
         push @nestedN,$n;
         push @nestedC,'';
         $curLabel='';
         $found++;
         $incIndent=length($a);
         $isFuncProc=1;
         $insideFuncProcDec=1;
         $oP=$cP=0;
         $lookForBegin++;
         if ($label)
           {# We usually confuse arguments with labels
            $found--;
            $label=1;
           }
        }
      else
        {
         PrintError("`function name(` must fit in one line");
        }
     }
   #############
   # procedure #
   #############
   if ($t=~/[^\w\d_]procedure[^\w\d_]/ and
       $t!~/end[^\w\d_]+procedure[^\w\d_]/)
     {
      if ($t=~/[^\w\d_](procedure[^\w\d_]([\w\d_]+)[^\w\d_]*\()/)
        {
         push @nestedT,'procedure';
         push @nestedN,$2;
         push @nestedC,'';
         $curLabel='';
         $found++;
         $isFuncProc=1;
         $insideFuncProcDec=1;
         $incIndent=length($1);
         $lookForBegin++;
         $label=0;
        }
      else
        {
         PrintError("`procedure name(` must fit in one line");
        }
     }
   ########
   # type #
   ########
   if ($t=~/[^\w\d_]type[^\w\d_]/ and
       $t!~/[^\w\d_]is\s+record[^\w\d_]/) # type xxxx is record ...
     {
      if ($t=~/[^\w\d_]type[^\w\d_]+([\w\d_]+)[^\w\d_]+is[^\w\d_]/)
        {
         if ($1 ne lc($1))
           {
            PrintNCError("use lower case for types [$1]");
            AddReplacement($1,lc($1));
           }
         $curLabel='';
         $found++;
        }
      else
        {
         PrintError("`type ... is` must fit in one line")
            unless $t=~/[^\w\d_]attribute(.*)[^\w\d_]type[^\w\d_]is/;
        }
     }
   ###########
   # subtype #
   ###########
   if ($t=~/[^\w\d_]subtype[^\w\d_]/)
     {
      if ($t=~/[^\w\d_]subtype[^\w\d_]+([\w\d_]+)[^\w\d_]+is[^\w\d_]/)
        {
         if ($1 ne lc($1))
           {
            PrintNCError("use lower case for subtypes [$1]");
            AddReplacement($1,lc($1));
           }
         $curLabel='';
         $found++;
        }
      else
        {
         PrintError("`subtype ... is` must fit in one line");
        }
     }
   ##########
   # record #
   ##########
   if ($t=~/[^\w\d_]record[^\w\d_]/ and
       $t!~/end[^\w\d_]+record[^\w\d_]/)
     {
      push @nestedT,'record';
      push @nestedN,'';
      push @nestedC,'';
      $curLabel='';
      $found++;
      $incIndent=3;
     }
   ###########
   # package #
   ###########
   if ($t=~/[^\w\d_]package[^\w\d_]/)
     {
      if ($t=~/[^\w\d_]+(package)\s+([\w\d_]+)\s+is/ or
          $t=~/[^\w\d_]+(package\s+body)\s+([\w\d_]+)\s+is/)
        {
         push @nestedT,$1;
         push @nestedC,'';
         $curLabel='';
         SolveMixed('packages',$2);
         $found++;
         $incIndent=3;
         $lookForBegin++;
        }
      else
        {
         PrintError("`package ... is` must fit in one line")
           unless $t=~/end[^\w\d_]+package[^\w\d_]/;
        }
     }

   if ($insideFuncProcDec)
     {
      for (; $t=~/\(/g; $oP++) {}
      for (; $t=~/\)/g; $cP++) {}
      if ($cP==$oP)
        {
         $insideFuncProcDec=0;
         $insideConst=0;
         if ($t=~/\)\s*;/ or
             $t=~/\)\s*return\s+[^;]+;/)
           {# prototype
            $lookForBegin--;
            pop @nestedT;
            pop @nestedN;
            pop @nestedC;
            if ($t=~/[^\w\d_]((function|procedure)[^\w\d_]([\w\d_]+)[^\w\d_]*\()/)
              {
               $incIndent=0;
              }
            else
              {
               $incIndent=-(pop @indentSt);
               print OUT "Poping $incIndent end of f/p proto\n"
                  if $DebugIncStack;
              }
           }
         elsif ($t=~/\)\s+is/ or
                $t=~/\)\s*return\s+[^;]+is/)
           {# declaration
            if ($t=~/[^\w\d_]((function|procedure)[^\w\d_]([\w\d_]+)[^\w\d_]*\()/)
              {
               $incIndent=3;
              }
            else
              {
               $incIndent=3-(pop @indentSt);
               print OUT "Poping $incIndent end of f/p proto(dec)\n"
                  if $DebugIncStack;
               push @indentSt,3;
               print OUT "Pushing 3 instead\n" if $DebugIncStack;
              }
           }
         else
           {
            PrintError("end of prototype or `is` should be here");
           }
        }
     }
   if ($insideWith && $t=~/;/)
     {
      $insideWith=0;
      $incIndent=-(pop @indentSt);
      print OUT "Poping $incIndent end of width\n" if $DebugIncStack;
     }
   if ($insideConst && $t=~/;/)
     {
      $insideConst=0;
      $incIndent=-(pop @indentSt);
      print OUT "Poping $incIndent end of constant\n" if $DebugIncStack;
     }

   #########
   # begin #
   #########
   if ($lookForBegin && $t=~/[^\w\d_]begin[^\w\d_]/)
     {
      $lookForBegin--;
      $tempIncIndent=-3;
      $found++;
     }
   ##############
   # else/elsif #
   ##############
   if ($insideIf && $t=~/[^\w\d_](elsif|else)[^\w\d_]/)
     {
      $tempIncIndent=-3;
      $found++;
     }

   ###############################################################
   # Sanity check about more than one structure in the same line #
   ###############################################################
   if ($found==2 and $label==1)
     {
      $cIndent=MakeIndentStr();
      $t=~s/([^\w\d_\(]+[\d\w_]+)\s*:\s*/$1:\n$cIndent/;
      PrintWarning("label and sentence in the same line");
     }
   elsif ($found==2 and $isFuncProc)
     {
      # Arguments are constants and signals
     }
   elsif ($found>=2)
     {
      PrintError("more than one sentence in the same line");
     }

   ############################
   # Are we ending something? #
   ############################
   if ($t=~/[^\w\d_]end[^\w\d_\>\<]+([\>\<\w\d_]+)[^\w\d_]*;/)
     {
      CheckPosEnd();
      $n=$1;
      $n=@fStrs[$1] if $n=~/\<(\d+)\>/;
      CheckEnd($n);
     }
   elsif ($t=~/[^\w\d_]end[^\w\d_]+([\w\d_]+)[^\w\d_\>\<]+([\>\<\w\d_]+)[^\w\d_]*;/)
     {
      CheckPosEnd();
      $n1=$1;
      $n=$2;
      $n=@fStrs[$1] if $n=~/\<(\d+)\>/;
      CheckEnd("$n1 $n");
     }
   elsif ($t=~/[^\w\d_]end[^\w\d_]+([\w\d_]+)[^\w\d_]+([\w\d_]+)[^\w\d_]+([\w\d_]+)[^\w\d_]*;/)
     {
      CheckPosEnd();
      CheckEnd("$1 $2 $3");
     }
   elsif ($t=~/[^\w\d_]end[^\w\d_]*;/)
     {
      CheckPosEnd();
      $etype=pop @nestedT;
      $ename=pop @nestedN;
      $ecomment=pop @nestedC;
      $esug=$etype;
      $esug.=' '.$ename if $ename;
      PrintWarning("incomplete end [$esug]");
      $esug.=';';
      $esug.=' -- '.$ecomment if $ecomment;
      $t=~s/end(.*);/end $esug/;
     }
   elsif ($t=~/[^\w\d_]end[^\w\d_]/)
     {
      PrintError("`end ...;` must fit in one line");
     }

   #########################################################
   # Output the fixed line containing the original comment #
   #########################################################
   PutLine();
   $line++;
  }
while (1);


sub CheckEnd
{
 my ($end)=@_;
 my ($etype, $ename, $ecomment, $esug);

 $etype=pop @nestedT;
 $ename=pop @nestedN;
 $ecomment=pop @nestedC;
 $esug=$etype;
 $esug.=' '.$ename if $ename;

 if ($end ne $esug)
   {
    PrintWarning("end missmatch [$end vs $esug]");
    $esug.=';';
    $esug.=' -- '.$ecomment if $ecomment;
    $t=~s/end(.*);/end $esug/;
   }
}

sub CheckPosEnd
{
 my ($etype);

 PrintError("`end` must be in a separated line") if $found;
 PrintError("don't know the starting point of that end")
   unless scalar(@nestedT);
 $insidePort=$insideGeneric=0;
 $tempIncIndent=-(pop @indentSt);
 print OUT "Poping $tempIncIndent `end`\n" if $DebugIncStack;
 $incIndent=$tempIncIndent;

 $etype=pop @nestedT;
 $insideIf--   if $insideIf   and ($etype eq 'if');
 $insideCase-- if $insideCase and ($etype eq 'case');
 push @nestedT,$etype;
}

sub PrintError
{
 PrintNCError(@_);
 ReportErrors(0);
}

sub ReportErrors
{
 my ($end,$keepOut)=@_;
 my ($erLev,$hcheck);

 $keepOut=0;
 if ($errors+$warnings==0)
   {
    print "Perfect! well ... at least for me ;-)\n";
    unless ($noHeader)
      {
       print "Now checking the header ...\n";
       $hcheck="check_vhdl_head.pl --input=$file --output=$headFile";
       $hcheck.=" --no-xilinx" if $noXilinx;
       $hcheck.=" --replace"   if $overHead;
       $warnings++ if system($hcheck);
      }
   }
 else
   {
    print "Found ";
    if ($errors)
      {
       print "$errors error";
       print 's' if $errors>1;
       print ' and ' if $warnings;
      }
    if ($warnings)
      {
       print "$warnings warning";
       print 's' if $warnings>1;
      }
    print ".\n";
    if ($end)
      {
       print "I suggest the changes found in `$outFile` output file.\nThe corrected file is most probably ";
       print "wrong" if $errors;
       print "right" unless $errors;
       print ".\n";
       $keepOut=1;
      }
    unlink $depends if $depends;
   }
 close(FIL);
 close(OUT);
 unlink $outFile unless ($keepOut or $keepOutput);
 if (scalar(@replFrom))
   {
    open(REP,">$repFile") || die "Can't create $repFile file\n";
    for ($i=0; $i<scalar(@replFrom); $i++)
       {
        $from=@replFrom[$i];
        $to=@replTo[$i];
        print REP "$from $to\n";
       }
    close(REP);
   }
 else
   {
    unlink $repFile;
   }
 $erLev=0;
 $erLev+=1 if $warnings;
 $erLev+=2 if $errors;
 exit $erLev;
}

sub PrintNCError
{
 my ($msg)=@_;

 print "$file:$line:error - $msg.\n";
 $errors++;
}

sub PrintWarning
{
 my ($msg)=@_;

 $warnings++;
 print "$file:$line:warning - $msg.\n";
}

sub PrintInfo
{
 my ($msg)=@_;

 print "$file:$line:information - $msg.\n";
}

sub GetLine
{
 my ($rNum,$rRep);

 $t=<FIL>;
 $isEof=1 unless $t;
 PrintError("tabs aren't allowed, please expand them first") if $t=~/\t/;
 # Extract the strings
 # TODO: same for %...%
 @fStrs=();
 $rNum=0;
 while ($t=~/(\"[^\"]*\")/g)
   {
    push @fStrs,$1;
    $rRep="<$rNum>";
    $t=~s/\"[^\"]*\"/$rRep/;
    $rNum++;
   }
 # Extract the comment
 $comment='';
 if ($t=~/(\s*\-\-(.*)\n?)/)
   {
    $comment=$1;
    $t=~s/(\s*\-\-(.*)\n?)//;
   }
 # Add some delimiters so we don't have "special cases" at the end/beggining
 # of each line.
 $t="<$t>";
 #print "\n\n$t\n\n" if $line==329;
}

sub PutLine
{
 my ($rNum,$rRep,$rToV);

 # Remove the delimiters
 $t=substr($t,1,length($t)-2);
 # Restore the comment
 $t.=$comment;
 # Insert the strings
 for ($rNum=0; $rNum<scalar(@fStrs); $rNum++)
    {
     $rRep="<$rNum>";
     $rToV=@fStrs[$rNum];
     #print "$rRep -> $rToV\n" if $line==329;
     $t=~s/$rRep/$rToV/;
    }
 unless ($noIndent)
   {# Unindent the line
    $t=~s/^ +//;
   }
 # Compute the indent string
 $indent+=$tempIncIndent;
 $cIndent=MakeIndentStr();
 # Indent
 $t=$cIndent.$t unless $t=~/^\s*$/;
 # Write to output
 print OUT scalar(@indentSt).$t."$incIndent $tempIncIndent\n"
    if $DebugIncStack;
 print OUT $t unless $DebugIncStack;
 $indent-=$tempIncIndent;
 print OUT "Pushing $incIndent in PutLine (positive)\n"
    if $incIndent>0 and $DebugIncStack;
 push @indentSt,$incIndent if $incIndent>0;
 $indent+=$incIndent;
}

sub AddReplacement
{
 my ($from,$to)=@_;
 my $add;

 $add=1;
 for ($i=0; $i<scalar(@replFrom); $i++)
    {
     if (@replFrom[$i] eq $from)
       {
        if (@replTo[$i] eq $to)
          {
           $add=0;
           last;
          }
        PrintError("trying to add already existing replacement rule ($from -> $to | @replFrom[$i] -> @replTo[$i])");
       }
    }
 if ($add)
   {
    push @replFrom,$from;
    push @replTo,$to;
   }
 ApplyReplacement($from,$to);
}

sub ApplyReplacement
{
 my ($from,$to)=@_;
 if (length($from)==length($to))
   {
    $t=~s/([^\w\d_])$from([^\w\d_])/$1$to$2/g;
   }
 elsif (length($from)>length($to))
   {
    while (length($from)>length($to))
      {
       $to.=' ';
      }
    $t=~s/([^\w\d_])$from([^\w\d_])/$1$to$2/g;
   }
 else
   {
    $difL=length($to)-length($from);
    $t=~s/([^\w\d_])($from\s{0,$difL})([^\w\d_])/$1$to$3/g;
   }
}

sub ParseCommandLine
{
 my $f;

 GetOptions("input=s"      => \$file,
            "output=s"     => \$outFile,
            "head-out=s"   => \$headFile,
            "depends=s"    => \$depends,
            "replace=s"    => \$repFile,
            "no-header"    => \$noHeader,
            "no-indent"    => \$noIndent,
            "no-warn-case" => \$noCase,
            "no-xilinx"    => \$noXilinx,
            "wishbone"     => \$forWishbone,
            "keep-output"  => \$keepOutput,
            "over-head"    => \$overHead,
            "max-sig-len=i"=> \$mxSig,
            "stack-debug"  => \$DebugIncStack,
            "help|?"       => \$help) or ShowHelp();
 ShowHelp() if $help;
 unless ($file)
   {
    print "You must specify a file name\n";
    ShowHelp();
   }
 $f=$file;
 $f=~s/\.vhdl?$//;
 $outFile="$f.lint.vhdl" unless $outFile;
 $headFile="$f.head.vhdl" unless $headFile;
 LoadRepFile() if $repFile;
 $repFile="$file.lint.txt" unless $repFile;
}

sub ShowHelp
{
 print "Usage: bakalint.pl --input=file.vhdl [options]\n";
 print "\nAvailable options:\n";
 print "--output=file        Set the name of the suggested output.\n";
 print "--head-out=file      Set the name of the suggested output for header stuff.\n";
 print "--replace=file       Set the name of the replace file.\n";
 print "--no-header          Disable header checking.\n";
 print "--no-indent          Disables the indentation fixes.\n";
 print "--no-warn-case       Disables case warnings in reserved words.\n";
 print "--no-xilinx          Disables Xilinx synthesis tools header check.\n";
 print "--wishbone           Apply Wishbone replacements.\n";
 print "--keep-output        Don't delete output files.\n";
 print "--over-head          Overwrite the original code during header check.\n";
 print "--max-sig-len=n      Limit signal names to n chars [15]\n";
 print "--depends=file       The file to remove if the process fails.\n";
 print "--stack-debug        Enable the dump of data to debug the stack.\n";
 print "--help               Prints this text.\n\n";
 exit 1;
}

sub LoadRepFile
{
 if (open(REP,"<$repFile"))
   {
    while ($a=<REP>)
      {
       if ($a=~/([\w\d_]+) ([\w\d_]+)\n/)
         {
          push @replFrom,$1;
          push @replTo,$2;
         }
      }
    close(REP);
   }
}

sub SolveWithoutLabel
{
 my ($kind)=@_;
 my ($res);

 PrintWarning("$kind without label");
 $res=$kind.'_'.$fileBase.'_'.$line;
 $cIndent=MakeIndentStr();
 print OUT "$cIndent$res:\n";
 return $res;
}

sub MakeIndentStr
{
 my ($ret,$i);

 return '' if $noIndent;
 #$ret=sprintf "%3d:",$indent;
 #return $ret;
 for ($i=0; $i<$indent; $i++)
    {
     $ret.=' ';
    }
 return $ret;
}

sub MakeSps
{
 my ($l)=@_;
 my ($ret,$i);

 for ($i=0; $i<$l; $i++)
    {
     $ret.=' ';
    }
 return $ret;
}

sub CheckReserved
{
 my ($a);

 foreach $a (@reserved)
    {
     $found=0;
     while ($t=~/[^\w\d_]($a)[^\w\d_]/gi)
       {
        if ($a ne $1)
          {
           PrintWarning("wrong case [$1]") unless $noCase;
           $warnings++ if $noCase;
           $found=1;
          }
       }
     $t=~s/([^\w\d_])($a)([^\w\d_])/$1$a$3/gi if $found;
    }
}

sub ApplyAllReplacements
{
 my ($i);

 for ($i=0; $i<scalar(@replFrom); $i++)
    {
     ApplyReplacement(@replFrom[$i],@replTo[$i]);
    }
}

sub SolveMixed
{
 my ($kind,$val)=@_;

 if  ($val eq lc($val))
   {
    PrintNCError("use mixed case for $kind [$val]");
    $newP=uc(substr($val,0,1)).substr($val,1);
    PrintInfo("choosing $newP as replacement");
    AddReplacement($val,$newP);
   }
 else
   {
    $newP=$val;
   }
 push @nestedN,$newP;
}
