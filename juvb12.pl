#!/usr/bin/perl
##

#my $VERNUM="1.10:01/18/12";
#my  $VERNUM="1.20:0l/06/12";
#my  $VERNUM="1.21:04/29/12";
#my  $VERNUM="1.22:09/26/12";
#my  $VERNUM="1.22:10/18/14";
#my  $VERNUM="1.30:10/28/14";
#my  $VERNUM="1.31:2/13/15";
#my  $VERNUM="1.32:2/25/15";
#my  $VERNUM="1.33:3/6/15";
my  $VERNUM="1.34:9/22/17";

print "\njuvb12: version ".$VERNUM." (contact mcgrath\@cadence.com for help or feedback)\n\n";
#print "\njuvb11: version 1.08:09/06/11 (contact mcgrath\@cadence.com for help or feedback)\n\n";
#print "\njuvb: version 1.07:07/22/10 (contact mcgrath\@cadence.com for help or feedback)\n\n";
#print "\njuvb: version 1.06:07/21/10 (contact mcgrath\@cadence.com for help or feedback)\n\n";
#print "\njuvb: version 1.05:05/24/10 (contact mcgrath\@cadence.com for help or feedback)\n\n";
#print "\njuvb: version 1.04:03/27/09 (contact mcgrath\@cadence.com for help or feedback)\n\n";
#
# v1.34 (2/25/15) - update "clean" for Xcelium 
# v1.33 (2/25/15) - reformat files for cleaner look, add support for timescale/timeprecision in template 
# v1.32 (2/25/15) - updated to include uvc files in a pacakge (need to add a timescale switch still) 
# v1.31 (2/13/15) - updated top.sv message to say UVM 1.2 for full template (one file already OK) 
# v1.30 (10/28/14) - updated to support uvm 1.2 changes including deprecated 1.1 features
# v1.22 (08/18/14) 
# v1.21 (04/29/12) - change main_phase() back to run_phase() - not sure which will be recommended
# v1.20 (04/06/12) - fix jrun
# v1.10 (01/18/12) - remove explicit sequencer, add single file version for simple example generation 
# v1.09 (09/15/11) - bug fixes
# v1.08 (09/06/11) - branch for uvm-1.1
# v1.07 (07/22/10) - branch for uvm 
# v1.06 (07/21/10) - convert uvm_report_info() to `uvm_info() 
# v1.05 (05/24/10) - set recording_detail to OVM_FULL and print topology in test 
# v1.04 (03/27/09) - convert `message() to uvm_report_info()
#

#some defaults and counters
$ovc_name="generic_name";
$ovc_if="generic_if";
$ovc_item="generic_item";
$ovc_var_counter=0;
$ovc_port_counter=0;
$ovc_explicit_seqr=0;
$ovc_one_file=0;
$ovc_test_only=0;
$uvm_timeunit="";
$uvm_timeprecision="";
$uvm_version="-uvmhome CDNS-1.2";
$uvm_deprecated="-define UVM_NO_DEPRECATED";
$ovc_run_command="irun";
$ovc_sim_name="Incisive";
$sv_nowarns="-nowarn DSEMEL:DSEM2009";

my $indent1 = "  ";
my $indent2 = $indent1 . $indent1;
my $indent3 = $indent2 . $indent1;
my $separator = "//------------------------------------------------------------------\n";
my $smallsep  = "//------ ";
#process command line
#$template_name="example.tpl";  #default template name
$template_name="";              #error if no template specified (9/14/17)
parse_cmdline();

#process the ovc template
parse_template(); 

#make the directories
mkdir($ovc_name, 0755);
if ($ovc_one_file == 0)
{
  mkdir($ovc_name."/sv", 0755);
  mkdir($ovc_name."/examples", 0755);
}

#create the ovc files
if ($ovc_one_file == 1)
{
  #generate simplified ovc in one sv file
  gen_if_one_file();
  # in -test_only mode - the following components are NOT generated
  if ($ovc_test_only == 0)
  {
    gen_data_item();
    gen_driver_one_file();
    if ($ovc_explicit_seqr == 1) { gen_sequencer_one_file(); }
    gen_agent_one_file();
    gen_seq_lib_one_file();
  }
  gen_test_one_file();
  gen_top_one_file();
  gen_clean_script();
  gen_run_script();
}
else
{
  #generate ovc in multiple sv files
  gen_if();
  gen_data_item();
  gen_driver();
  #only generate monitor when not in "one file" mode
  gen_monitor();
  gen_agent();
  ### conditionally generate sequencer;
  if ($ovc_explicit_seqr == 1) { gen_sequencer(); }
  gen_env();
  gen_seq_lib();
  ### non reusable stuff
  gen_tb();
  gen_test();
  gen_top();
  #generate ovc include .svh file
  gen_ovc_include();
  gen_clean_script();
  gen_run_script();
}

#
# jm(10/29/14) - the parser isn't very precise... be careful specifying the command line arguments 
#

### perl juvb.pl template=example.tpl
sub parse_cmdline()
  {
    #print "num args is ".$#ARGV."\n";
    if ($#ARGV == -1) { usage(); }  ### no arguments, print help and exit
    foreach $argnum (0 .. $#ARGV) 
      {
        #print "$ARGV[$argnum]\n";
        #check for template name
        #-template - template file name information
        #
        if ($ARGV[$argnum] =~ m/\s*-template|-tem|-tpl\Z/i)
          {
            #@fields = split /=/,$ARGV[$argnum];
            #$template_name=$fields[1];
            $template_name=$ARGV[$argnum+1];;
            ###print "-template: $ARGV[$argnum] : ", $template_name, "\n";
          }
        #
        #-help - print help message
        #
        if ($ARGV[$argnum] =~ m/\s*(-help|-h)/i)
          {
            usage();
          }
        #
        #-use_seqr : use explicit sequencer vs. parameterized uvm_sequencer
        if ($ARGV[$argnum] =~ m/\s*(-use_seqr|-use_s)/i)
          {
            $ovc_explicit_seqr=1;
            print "argument : -use_seqr specified\n";
          }
        #
        #-one_file - generate simplified template in one file for generating test cases
        #
        if ($ARGV[$argnum] =~ m/\s*(-one_file|-one)/i)
          {
            $ovc_one_file=1;
            print "argument : -one_file specified\n";
          }
        #
        #-uvmhome CDNS-1.2 | CDNS-1.1d or | $UVMHOME env var
        #
        if ($ARGV[$argnum] =~ m/\s*(-uvmh)/i)
          {
            $uvm_version="-uvmhome ".$ARGV[++$argnum];
            print "argument : $uvm_version specified\n";
          }
        #
        # -uvm - generate the default -uvm switch for irun
        #
        if ($ARGV[$argnum] =~ /(?i)\s*(-uvm)\Z/)
          {
            print "argument : -uvm specified\n";
            $uvm_version="-uvm";
            $uvm_deprecated="";
          }
        #
        #Only generate a test class in -one_file mode (no -one_file needed)
        #  this is for making simple uvm test cases
        #   
        if ($ARGV[$argnum] =~ /(?i)-test\Z|-test[_only]|-tes/)
          {
            ###print "to_arg is ",$ARGV[$argnum],"\n";
            print "argument : -test_only\n";
            $ovc_test_only=1;
            $ovc_one_file=1;
          }
        #
        #Incisive use model (default) or Xcelium use model
        #   
        if ($ARGV[$argnum] =~ /(?i)-x\Z|-xrun/)
          {
            ###print "to_arg is ",$ARGV[$argnum],"\n";
            print "argument : -xrun (Xcelium) specified\n";
            $ovc_run_command="xrun";
            $ovc_sim_name="Xcelium";
          }

      }
  }

sub usage()
  {
    print "USAGE: perl juvb.pl -help (print this message)\n";
    print "\n";
    print "NOTE : default version of uvm is CDNS-1.2 if [-uvm | -uvmhome] NOT specified\n";
    print "\n";
    print "       perl juvb.pl [-template | -tem | -tpl ] template_name [ args ]\n";
    print "       template file args\n";
    print "         ovc_name -> name of ovc (i.e. ahb_master)\n";
    print "         ovc_item -> name of sequence item (i.e mstr_pkt)\n";
    print "         ovc_var  -> list of sequence_item variables\n";
    print "                      see example templates for more info\n";
    print "                      support is limited, but gives a good starting point for the sequence_item field macro\n"; 
    print "         ovc_if   -> name ofinterface (i.e. mstr_if)\n";
    print "         ovc_port -> list of ports in interface\n";
    print "\n";
    print "         [ args ] \n";
    print "         -use_seqr  : use explicit sequencer vs. parameterized uvm_sequencer \n";
    print "         -one_file  : generate simplified uvc in one file - for examples and debug \n";
    print "         -test_only : simplified version of -one_file with only a test class \n"; 
    print "         -uvmhome   : CDNS-1.2 (default) | CDNS-1.1d | \\\$UVMHOME (user must set env var) \n"; 
    print "         -uvm       : use default version of UVM supplied with Incisive or Xcelium \n"; 
    print "         -xrun      : use Xcelium run command [xrun] (default Incisive run command [irun]) \n"; 
    print "\n";
    print "add \"timeunit\" and \"timeprecision\" to template file if needed in package file (if \*W,TSNSPK warning emitted) \n";
    print "\n";
    exit;
  } # end sub usage()

sub parse_template()
  {
    open(TH, $template_name) || die("ERROR: no template specified using [-template|-tem|-tpl] or : ".$template_name." not found\n");
    print "Parsing template : $template_name ...\n\n";
    for (;;) 
      {
        undef $!;
        unless (defined( $line = <TH> )) 
          {
            die $! if $!;
            last; # reached EOF
          }
        #next if ($line =~ m/^#/); #comment line starts with "#"
        next if ($line =~ m/\s*#/); #comment line starts with "#"
        next if ($line =~ m/^\s\s*$/); #blank line 
  
        #check for ovc_if
        if ($line =~ m/\s*ovc_if/i)
          {
            #print "OVC_IF: $line";
            @fields = split /\|/, $line;
            s/ ^\s+ | \s+$ //gx for @fields; #crunch out any white space
            $ovc_if=$fields[1];
          }

        #check for ovc_name
        if ($line =~ m/\s*ovc_name/i)
          {
            #print "OVC_NAME: $line";
            @fields = split /\|/, $line;
            s/ ^\s+ | \s+$ //gx for @fields; #crunch out any white space
            $ovc_name=$fields[1];
          }

        #check for ovc_item
        if ($line =~ m/\s*ovc_item/i)
          {
            #print "OVC_ITEM: $line";
            @fields = split /\|/, $line;
            s/ ^\s+ | \s+$ //gx for @fields; #crunch out any white space
            $ovc_item=$fields[1];
            #print "field0=", $fields[0], "\n"; 
            #print "field1=", $fields[1], "\n"; 
            #print "\n";
          }

        #check for ovc_var
        if ($line =~ m/\s*ovc_var/i)
          {
            #print "\n";
            print "OVC_VAR: $line";
            @fields = split /\|/, $line;
            s/ ^\s+ | \s+$ //gx for @fields; #crunch out any white space
            $ovc_var=$fields[1];
            @ovc_var_array[$ovc_var_counter++]=$ovc_var;
          }

        #check for ovc_port
        if ($line =~ m/\s*ovc_port/i)
          {
            #print "\n";
            print "OVC_PORT: $line";
            @fields = split /\|/, $line;
            s/ ^\s+ | \s+$ //gx for @fields; #crunch out any white space
            $ovc_port=$fields[1];
            @ovc_port_array[$ovc_port_counter++]=$ovc_port;
          }

        #check for timeunit
        if ($line =~ m/\s*timeunit/)
          {
            #print "\n";
            $uvm_timeunit=$line;
            $uvm_timeunit =~ s/^\s+//; #crunch out any white space
            print "timeunit specified : $uvm_timeunit";
          }

        #check for timeprecision
        if ($line =~ m/\s*timeprecision/)
          {
            #print "\n";
            $uvm_timeprecision=$line;
            $uvm_timeprecision =~ s/^\s+//; #crunch out any white space
            print "timeprecision specified : $uvm_timeprecision";
          }



        #print $line;
      }

  } #end parse_template

sub gen_if()
  {
    open(FH, ">".$ovc_name."/sv/".$ovc_name."_if.sv") || die("can't open interface: $ovc_name");

    print FH $separator;
    print FH "// Interface\n";
    print FH "interface ".$ovc_if."(input logic clock, input logic reset); \n";
    ### iterate through port list (for now)
    foreach $port_decl (@ovc_port_array) 
      {
        print FH $indent1 . $port_decl,"\n";   
      }
    print FH "endinterface : ".$ovc_if."\n";
    print FH "\n";
    close(FH);
  } #end gen_if

sub gen_if_one_file()
  {
    open(FH, ">".$ovc_name."/top.sv") || die("can't open file: top.sv");
    print FH "//SystemVerilog UVM-1.2 UVC template generated by juvb.pl : version ".$VERNUM."\n";
    print FH "//contact mcgrath\@cadence.com for help or feedback\n";
    print FH "\n";
    print FH "interface ".$ovc_if."(input logic clock, input logic reset); \n";
    ### iterate through port list (for now)
    foreach $port_decl (@ovc_port_array)
      {
        print FH $port_decl,"\n";
      }
    print FH "endinterface : ".$ovc_if."\n";
    print FH "\n";
    print FH "module top();\n";
    print FH "import uvm_pkg::*;\n";
    print FH "`include \"uvm_macros.svh\"\n";
    print FH "\n";
    close(FH);
  } #end gen_if_one_file()


sub gen_data_item()
  {
    if ($ovc_one_file == 1)
    {
      open(FH, ">>".$ovc_name."/top.sv") || die("can't open file: top.sv");
    }
    else
    {
      open(FH, ">".$ovc_name."/sv/".$ovc_item.".sv") || die("can't open data_item: $ovc_item");
    }
    print FH $smallsep . "uvm_sequence_item Class\n";
    print FH "class $ovc_item extends uvm_sequence_item; \n";
    print FH $indent1 . "//------------------------------------------------------------------\n";
    print FH $indent1 . "// Fields\n";
    foreach $var_decl (@ovc_var_array) 
      {
        print FH $indent1 . $var_decl,"\n";   
      }
    print FH "\n";
    print FH $indent1 . "//------------------------------------------------------------------\n";
    print FH $indent1 . "// UVM Registration Macro\n";
    print FH $indent1 . "`uvm_object_utils_begin(".$ovc_item.")\n";
    foreach $var_decl (@ovc_var_array) 
      {
        $field_type="  `uvm_field_int(";
        #print "var_decl=",$var_decl,"\n";
        @fields = split /\s+/, $var_decl;
        ### print FH "DEBUG_SPLIT F0=".$fields[0]." F1=".$fields[1]." F2=".$fields[2]." F3=".$fields[3]." F4=".$fields[4]."\n";
        #check which field to print
        # rand bit [7:0] payload []; fields are 0 thru 4
        $pf = 0; #default field to print (bit parity, want to print field 1 here)
        if ($fields[$pf] =~ m/rand/)
          {
            #starts with "rand"
            $pf=2;
          }
        else
          {
            #doesn't start with "rand"
            $pf=1;
          }
        if ($fields[$pf] =~ m/^\[/)
          {
            #is a vector (i.e. bit [7:0]
            $pf=$pf+1;
          }
        if ($fields[$pf+1] =~ m/^\[/)
          {
            #is an array (i.e payload []
            $field_type="  `uvm_field_array_int(";
          }
        s/;/ / for $fields[$pf];
        print FH $indent2 . $field_type; 
        print FH $fields[$pf],", UVM_ALL_ON)\n";
        ### print FH "DEBUG pf=".$pf." F0=".$fields[0]." F1=".$fields[1]." F2=".$fields[2]." F3=".$fields[3]." F4=".$fields[4]."\n";
      }
    print FH $indent1 . "`uvm_object_utils_end\n";
    print FH "\n";
    print FH $indent1 . $separator;
    print FH $indent1 . "// Methods\n";
    print FH $indent1 . "//extern virtual function <ret type> func_name(...)\n";
    print FH "\n";
    print FH $indent1 . $separator;
    print FH $indent1 . "// Private properties (variables)\n";
    print FH $indent1 . "//protected ...\n";
    print FH "\n";
    print FH $indent1 . $separator;
    print FH $indent1 . "// Constructor\n";
    print FH $indent1 . "function new(string name=\"".$ovc_item."\");\n";
    print FH $indent2 . "super.new(name);\n";
    print FH $indent1 . "endfunction : new\n";
    print FH "endclass : $ovc_item \n";
    print FH "\n";
    print FH $separator;
    print FH "// class " . $ovc_item . " Method Implementation(s)\n";
    print FH "\n";
    print FH "//------------------------------------------------------------------------------\n";
    print FH "//function <ret type> " . $ovc_item . "::func_name(...)\n";
    print FH "\n";
    close(FH);
  } #end gen_data_item


sub gen_driver()
  {

    open(FH, ">".$ovc_name."/sv/".$ovc_name."_driver.sv") || die("can't open driver: $ovc_name");
    print FH $smallsep . "uvm_driver Class\n";
    print FH "class " . $ovc_name . "_driver extends uvm_driver#(" . $ovc_item . ");\n";
    print FH $indent1 . "//------------------------------------------------------------------\n";
    print FH $indent1 . "// Fields\n";
    print FH $indent1 . "virtual interface ". $ovc_if . " vif;\n";
    print FH "\n";
    print FH $indent1 . "//------------------------------------------------------------------\n";
    print FH $indent1 . "// UVM registration macro\n";
    print FH $indent1 . "`uvm_component_utils_begin(".$ovc_name."_driver)\n";
    print FH $indent2 . "`uvm_field_object(req, UVM_ALL_ON)\n";
    print FH $indent1 . "`uvm_component_utils_end\n";
    print FH "\n";
    print FH $indent1 . "//------------------------------------------------------------------\n";
    print FH $indent1 . "// UVM Phases\n";
    print FH $indent1 . "extern virtual function void build_phase(uvm_phase phase);\n";
    print FH $indent1 . "extern virtual function void connect_phase(uvm_phase phase);\n";
    print FH $indent1 . "extern virtual task run_phase(uvm_phase phase);\n";
    print FH $indent1 . "extern virtual function void phase_started(uvm_phase phase);\n";
    print FH $indent1 . "extern virtual function void report_phase(uvm_phase phase);\n";
    print FH "\n";
    print FH $indent1 . "//------------------------------------------------------------------\n";
    print FH $indent1 . "// Methods\n";
    print FH $indent1 . "extern virtual task get_and_drive();\n";
    print FH $indent1 . "extern virtual task send_to_dut(input ".$ovc_item."  item);\n";
    print FH "\n";
    print FH $indent1 . "//------------------------------------------------------------------\n";
    print FH $indent1 . "// Private properties(variables)\n";
    print FH $indent1 . "protected string    tID;\n";
    print FH $indent1 . "protected uvm_phase curr_phase;\n";
    print FH "\n";
    print FH $indent1 . "//------------------------------------------------------------------\n";
    print FH $indent1 . "// Constructor\n";
    print FH $indent1 . "function new(string name, uvm_component parent);\n";
    print FH $indent2 . "super.new(name,parent);\n";
    print FH $indent1 . "endfunction : new\n";
    print FH "endclass : " . $ovc_name . "_driver\n";
    print FH "\n";
    print FH $separator;
    print FH "// class " . $ovc_name . "_driver Phase and Method Implementation(s)\n";
    print FH "\n";
    print FH "//------------------------------------------------------------------------------\n";
    print FH "function void " . $ovc_name . "_driver::build_phase(uvm_phase phase);\n";
    print FH $indent1 . "super.build_phase(phase);\n";
    print FH $indent1 . "tID=get_type_name();\n";
    print FH $indent1 . "tID=tID.toupper();\n";
    print FH "endfunction : build_phase\n";
    print FH "\n";
    print FH "//------------------------------------------------------------------------------\n";
    print FH "function void " . $ovc_name . "_driver::connect_phase(uvm_phase phase);\n";
    print FH $indent1 . "super.connect_phase(phase);\n";
    print FH $indent1 . "if(!uvm_config_db#(virtual ".$ovc_if.")::get(this,\"\",\"vif\",vif))\n";
    print FH $indent2 . "`uvm_fatal(\"NOVIF\", {\"virtual interface must be set for: \", get_full_name(),\".vif\"});\n";
    print FH "endfunction : connect_phase\n";
    print FH "\n";
    print FH "//------------------------------------------------------------------------------\n";
    print FH "task " . $ovc_name . "_driver::run_phase(uvm_phase phase);\n";
    print FH "  `uvm_info(tID,\"RUNNING:\",UVM_MEDIUM)\n";
    print FH "  get_and_drive();\n";
    print FH "endtask : run_phase\n";
    print FH "\n";
    print FH "//------------------------------------------------------------------------------\n";
    print FH "function void " . $ovc_name . "_driver::phase_started(uvm_phase phase);\n";
    print FH $indent1 . "// get phase to see if any phase specific actions are needed\n";
    print FH $indent1 . "curr_phase = phase;\n";
    print FH "endfunction : phase_started\n";
    print FH "\n";
    print FH "//------------------------------------------------------------------------------\n";
    print FH "task " . $ovc_name . "_driver::get_and_drive();\n";
    print FH $indent1 . "forever begin\n";
    print FH $indent2 . "seq_item_port.get_next_item(req);\n";
    print FH $indent2 . "send_to_dut(req);\n";
    print FH $indent2 . "seq_item_port.item_done();\n";
    print FH $indent1 . "end\n";
    print FH "endtask : get_and_drive\n";
    print FH "\n";
    print FH "//------------------------------------------------------------------------------\n";
    print FH "task " . $ovc_name . "_driver::send_to_dut(input ".$ovc_item."  item);\n";
    #
    # NOTE: if any `message() macros used, `uvm_info() message tag won't print
    #       `uvm_info(TAG, MESSAGE, VERBOSITY)
    #
    print FH $indent1 . "`uvm_info(tID,\$sformatf(\"[subphase is %0s] item sent is: \\n%0s\",curr_phase.get_name(),item.sprint()),UVM_HIGH)\n";
    print FH $indent1 . "// Send data to DUT (BFM - fill in your BFM code here)\n";
    print FH $indent1 . "#10;\n";
    #### dummy place holder to test vif
    print FH $indent1 . "//vif.port1=item.v1;\n";
    print FH $indent1 . "//vif.port2=item.v2;\n";
    print FH $indent1 . "#10;\n";
    print FH "endtask : send_to_dut\n";
    print FH "\n";
    print FH "//------------------------------------------------------------------------------\n";
    print FH "function void " . $ovc_name . "_driver::report_phase(uvm_phase phase);\n";
    print FH $indent1 . "// fill in any reporting code if needed\n";
    print FH "endfunction : report_phase\n";
    print FH "\n";
    print FH "\n";
    close(FH);
  } ### end gen_driver()

sub gen_driver_one_file()
  {
    open(FH, ">>".$ovc_name."/top.sv") || die("can't open file: top.sv");
    print FH $smallsep . "uvm_driver Class\n";
    print FH "class ".$ovc_name."_driver extends uvm_driver #(".$ovc_item.");\n";
    print FH "virtual interface ".$ovc_if." vif;\n";
    print FH "`uvm_component_utils_begin(".$ovc_name."_driver)\n";
    print FH "  `uvm_field_object(req, UVM_ALL_ON)\n";
    print FH "`uvm_component_utils_end\n";
    print FH "function new(string name, uvm_component parent);\n";
    print FH "  super.new(name,parent);\n";
    print FH "endfunction : new\n";
    print FH "virtual function void build_phase(uvm_phase phase);\n";
    print FH "  super.build_phase(phase);\n";
    print FH "  if(!uvm_config_db#(virtual ".$ovc_if.")::get(this,\"\",\"vif\",vif))\n";
    print FH "    `uvm_fatal(\"NOVIF\", {\"virtual interface must be set for: \", get_full_name(),\".vif\"});\n";
    print FH "endfunction : build_phase\n"; 
    print FH "task run_phase(uvm_phase phase);\n";
    print FH "  `uvm_info(get_type_name(),\"RUNNING:\",UVM_MEDIUM)\n";
    print FH "  forever\n";
    print FH "    begin\n";
    print FH "      seq_item_port.get_next_item(req);\n";
    print FH "      //Send data to DUT (BFM - fill in your BFM code here)\n";
    print FH "      `uvm_info(get_type_name(),\$sformatf(\"[subphase is %0s] item sent is: \\n%0s\",phase.get_name(),req.sprint()),UVM_HIGH)\n";
    print FH "      #10 ;\n";
    print FH "      seq_item_port.item_done();\n";
    print FH "    end\n";
    print FH "endtask : run_phase\n";
    print FH "endclass : ".$ovc_name."_driver \n";
    print FH "\n";
    close(FH);
  } ### end gen_driver_one_file()

sub gen_monitor()
  {
    ### variables in sequence_item class
    foreach $var_decl (@ovc_var_array) 
      {
        print FH "  `uvm_field_int(";
        #print "var_decl=",$var_decl,"\n";
        @fields = split /\s/, $var_decl;
        s/;/ / for $fields[2];                ### print space here, not ","
        print FH $fields[2],"UVM_ALL_ON)\n";
      }
    
    open(FH, ">".$ovc_name."/sv/".$ovc_name."_monitor.sv") || die("can't open monitor: $ovc_name");
    print FH $smallsep . "uvm_monitor Class\n";
    print FH "class ".$ovc_name."_monitor extends uvm_monitor;\n";
    print FH $indent1 . "//------------------------------------------------------------------\n";
    print FH $indent1 . "// Fields\n";
    print FH $indent1 . "string tID;\n";
    print FH $indent1 . "virtual interface ".$ovc_if." vif;\n";
    print FH $indent1 . $ovc_item." trans;\n";
    print FH $indent1 . "event e_trans_collected; //event to signal transaction collected\n";
    print FH $indent1 . "//TLM port for scoreboard communication (implement scoreboard write method if needed)\n";
    print FH $indent1 . "uvm_analysis_port #(".$ovc_item.") sb_post;\n"; 
    print FH "\n";
    print FH $indent1 . "// UVM registration macro\n";
    print FH $indent1 . "`uvm_component_utils_begin(".$ovc_name."_monitor)\n";
    print FH $indent1 . "  `uvm_field_object(trans, UVM_ALL_ON)\n";
    print FH $indent1 . "`uvm_component_utils_end\n";
    print FH "\n";
    print FH $indent1 . $separator;
    print FH $indent1 . "// UVM Phases\n";
    print FH $indent1 . "extern virtual function void build_phase(uvm_phase phase);\n";
    print FH $indent1 . "extern virtual task run_phase(uvm_phase phase);\n";
    print FH "\n";
    print FH $indent1 . "// Methods\n";
    print FH $indent1 . "extern virtual task collect_data();\n";
    print FH "\n";
    print FH $indent1 . "//------------------------------------------------------------------\n";
    print FH $indent1 . "// Example covergroup\n";
    print FH $indent1 . "covergroup cov_trans @ e_trans_collected;\n";
    print FH $indent1 . "option.per_instance=1;\n";
    print FH $indent1 . "option.name={get_full_name(),\".cov_trans\"};\n";
    #print "DEBUG " . $fields[1] . " " . $fields[2] . " " . $fields[3] . " " . $fields[4] . "\n";
    # check for range ([N:M]) vs. variable name 
    if ($fields[2] =~ m/\[/)
      {
        #remove ";" if found
        $fields[3] =~ s/\;//g;
        print FH $indent2 . "cg1: coverpoint trans.".$fields[3]."\n";
      }
    else
      {
        $fields[2] =~ s/\;//g;
        print FH $indent2 . "cg1: coverpoint trans.".$fields[2]."\n";
      }
    print FH $indent2 . "{ bins MIN[]     = {0};\n";
    print FH $indent3 . "bins MAX[]     = {63};\n";
    print FH $indent2 . "}\n";
    print FH $indent1 . "endgroup\n";
    print FH "\n";
    print FH $indent1 . $separator;
    print FH $indent1 . "// Constructor\n";
    print FH $indent1 . "function new(string name, uvm_component parent);\n";
    print FH $indent2 . "super.new(name,parent);\n";
    print FH $indent2 . "tID=get_type_name();\n";
    print FH $indent2 . "tID=tID.toupper();\n";
    print FH $indent2 . "cov_trans = new();\n";
    print FH $indent2 . "trans = new();\n";
    print FH $indent2 . "sb_post = new(\"sb_post\", this);\n";
    print FH $indent1 . "endfunction : new\n";
    print FH "\n";
    print FH "endclass : ".$ovc_name."_monitor \n";
    print FH "\n";
    print FH "// class " . $ovc_name."_monitor" . " Phase and Method Implementation(s)\n";
    print FH $separator;
    print FH "function void " . $ovc_name."_monitor::build_phase(uvm_phase phase);\n";
    print FH "  super.build_phase(phase);\n";
    print FH "  if(!uvm_config_db#(virtual ".$ovc_if.")::get(this,\"\",\"vif\",vif))\n";
    print FH "    `uvm_fatal(\"NOVIF\", {\"virtual interface must be set for: \", get_full_name(),\".vif\"});\n";
    print FH "endfunction : build_phase\n"; 
    print FH "\n";
    print FH $separator;
    print FH "task " . $ovc_name."_monitor::run_phase(uvm_phase phase);\n";
    print FH "  `uvm_info(tID,\"RUNNING:\",UVM_MEDIUM)\n";
    print FH "  collect_data();\n";
    print FH "endtask : run_phase\n";
    print FH "\n";
    print FH "task " . $ovc_name."_monitor::collect_data();\n";
    print FH "  forever\n";
    print FH "    begin\n";
    print FH "      //put code to collect bus transactions here\n";
    print FH "      #10 ;\n";
    print FH "      ->e_trans_collected; //signal transaction collection complete\n";
    print FH "      //post good transactions to scoreboard if enabled\n";
    print FH "      if (sb_post.size()>0)\n";
    print FH "        sb_post.write(trans);\n";
    print FH "    end;\n";
    print FH "endtask : collect_data\n";
    close(FH);
  }

sub gen_sequencer()
  {
    open(FH, ">".$ovc_name."/sv/".$ovc_name."_sequencer.sv") || die("can't open sequencer: $ovc_name");
    print FH "class ".$ovc_name."_sequencer extends uvm_sequencer #(".$ovc_item.");\n";
    print FH "\n";
    print FH $indent1 .$separator;
    print FH $indent1 . "// UVM registration macro\n";
    print FH $indent1 . "`uvm_component_utils(".$ovc_name."_sequencer)\n";
    print FH "\n";
    print FH $indent1 . $separator;
    print FH $indent1 . "// Constructor\n";
    print FH $indent1 . "function new(string name, uvm_component parent);\n";
    print FH $indent2 . "super.new(name,parent);\n";
    print FH $indent1 . "endfunction : new\n";
    print FH "endclass : ".$ovc_name."_sequencer \n";
    close(FH);
  }

sub gen_sequencer_one_file()
  {
    open(FH, ">>".$ovc_name."/top.sv") || die("can't open agent: $ovc_name");
    print FH $smallsep . "uvm_sequencer Class\n";
    print FH "class ".$ovc_name."_sequencer extends uvm_sequencer #(".$ovc_item.");\n";
    print FH "  `uvm_component_utils(".$ovc_name."_sequencer)\n";
    print FH "function new(string name, uvm_component parent);\n";
    print FH "  super.new(name,parent);\n";
    print FH "endfunction : new\n";
    print FH "endclass : ".$ovc_name."_sequencer \n";
    print FH "\n";
    close(FH);
  }


sub gen_agent()
  {
    open(FH, ">".$ovc_name."/sv/".$ovc_name."_agent.sv") || die("can't open agent: $ovc_name");
    print FH $smallsep . "uvm_agent Class\n";
    print FH "class ".$ovc_name."_agent extends uvm_agent;\n";
    #(08/18/14) print FH "uvm_active_passive_enum is_active;\n";
    #
    print FH $indent1 . $separator;
    print FH $indent1 . "// Fields\n";  
    if ($ovc_explicit_seqr==1)
      {
        print FH $indent1 . $ovc_name."_sequencer sequencer;\n";
      }
    else
      {
        print FH $indent1 . "uvm_sequencer #(".$ovc_item.") sequencer;\n";
      }
    #
    print FH $indent1 . $ovc_name."_driver driver;\n";
    print FH $indent1 . $ovc_name."_monitor monitor;\n";
    print FH "\n";
    print FH $indent1 . $separator;
    print FH $indent1 . "// UVM registration macro\n";
    print FH $indent1 . "`uvm_component_utils_begin(".$ovc_name."_agent)\n";
    print FH $indent2 . "`uvm_field_enum(uvm_active_passive_enum, is_active, UVM_ALL_ON)\n";
    print FH $indent1 . "`uvm_component_utils_end\n";
    print FH "\n";
    print FH $indent1 . $separator;
    print FH $indent1 . "// UVM Phases\n";
    print FH $indent1 . "extern function void build_phase(uvm_phase phase);\n";
    print FH $indent1 . "extern function void connect_phase(uvm_phase phase);\n";
    print FH "\n";
    print FH $indent1 . $separator;
    print FH $indent1 . "// Methods\n";
    print FH "\n";
    print FH $indent1 . $separator;
    print FH $indent1 . "// Private properties(variables)\n";
    print FH $indent1 . "//protected ...\n";
    print FH "\n";
    print FH $indent1 . $separator;
    print FH $indent1 . "// Constructor\n";
    print FH $indent1 . "function new(string name, uvm_component parent);\n";
    print FH $indent2 . "super.new(name,parent);\n";
    print FH $indent1 . "endfunction : new\n";
    print FH "endclass : ".$ovc_name."_agent \n";
    print FH "\n";
    print FH $separator;
    print FH "//class " . $ovc_name . "_agent Phase and Method Implementation(s)\n";
    print FH "\n";
    print FH $separator;
    print FH "function void " . $ovc_name . "_agent::build_phase(uvm_phase phase);\n";
    print FH $indent1 . "super.build_phase(phase);\n";
    print FH $indent1 . "monitor=".$ovc_name."_monitor::type_id::create(\"monitor\",this);\n";
    print FH $indent1 . "if (is_active == UVM_ACTIVE)\n";
    print FH $indent2 . "begin\n";
    print FH $indent3 . "driver=".$ovc_name."_driver::type_id::create(\"driver\",this);\n";
    #
    if ($ovc_explicit_seqr==1)
      {
         print FH $indent3 . "sequencer=".$ovc_name."_sequencer::type_id::create(\"sequencer\",this);\n";
      }
    else
      {
         print FH $indent3 . "sequencer=uvm_sequencer#(".$ovc_item.")::type_id::create(\"sequencer\",this);\n";
      }
    #
    print FH $indent2 . "end\n";
    print FH "endfunction : build_phase\n";
    print FH "\n";
    print FH $separator;
    print FH "function void " . $ovc_name . "_agent::connect_phase(uvm_phase phase);\n";
    print FH $indent1 . "if (is_active == UVM_ACTIVE)\n";
    print FH $indent2 . "begin\n";
    print FH $indent3 . "driver.seq_item_port.connect(sequencer.seq_item_export);\n";
    print FH $indent2 . "end\n";
    print FH "endfunction : connect_phase\n"; 
    print FH "\n";
    close(FH); ### end gen_agent()
  }

sub gen_agent_one_file()
  {
    open(FH, ">>".$ovc_name."/top.sv") || die("can't open agent: $ovc_name");
    print FH $smallsep . "uvm_agent Class\n";
    print FH "class ".$ovc_name."_agent extends uvm_agent;\n";
    #(08/18/14) print FH "uvm_active_passive_enum is_active;\n";
    ### USE_SEQ print FH $ovc_name."_sequencer sequencer;\n";
    #print FH "uvm_sequencer #(".$ovc_item.") sequencer;\n";
    #
    if ($ovc_explicit_seqr==1)
      {
        print FH $ovc_name."_sequencer sequencer;\n";
      }
    else
      {
        print FH "uvm_sequencer #(".$ovc_item.") sequencer;\n";
      }
    #
    print FH $ovc_name."_driver driver;\n";
    print FH "`uvm_component_utils_begin(".$ovc_name."_agent)\n";
    print FH "  `uvm_field_enum(uvm_active_passive_enum, is_active, UVM_ALL_ON)\n";
    print FH "`uvm_component_utils_end\n";
    print FH "function new(string name, uvm_component parent);\n";
    print FH "   super.new(name,parent);\n";
    print FH "endfunction : new\n";
    print FH "virtual function void build_phase(uvm_phase phase);\n";
    print FH "  super.build_phase(phase);\n";
    print FH "  if (is_active == UVM_ACTIVE)\n";
    print FH "    begin\n";
    print FH "      driver=".$ovc_name."_driver::type_id::create(\"driver\",this);\n";
    ### USE_SEQ print FH "      sequencer=".$ovc_name."_sequencer::type_id::create(\"sequencer\",this);\n";
    #print FH "      sequencer=uvm_sequencer#(".$ovc_item.")::type_id::create(\"sequencer\",this);\n";
    #
    if ($ovc_explicit_seqr==1)
      {
         print FH "      sequencer=".$ovc_name."_sequencer::type_id::create(\"sequencer\",this);\n";
      }
    else
      {
        print FH "      sequencer=uvm_sequencer#(".$ovc_item.")::type_id::create(\"sequencer\",this);\n";
      }
    #
    print FH "    end\n";
    print FH "endfunction : build_phase\n";
    print FH "virtual function void connect_phase(uvm_phase phase);\n";
    print FH "  if (is_active == UVM_ACTIVE)\n";
    print FH "    begin\n";
    print FH "      driver.seq_item_port.connect(sequencer.seq_item_export);\n";
    print FH "    end\n";
    print FH "endfunction : connect_phase\n"; 
    print FH "endclass : ".$ovc_name."_agent \n";
    print FH "\n";
    close(FH);
  } ### end gen_agent_one_file()

sub gen_env()
  {
    open(FH, ">".$ovc_name."/sv/".$ovc_name."_env.sv") || die("can't open env: $ovc_name");
    print FH $smallsep . "uvm_agent Class\n";
    print FH "class ".$ovc_name."_env extends uvm_env;\n";
    print FH $indent1 . $separator;
    print FH $indent1 . "// Fields\n";  
    print FH $indent1 . $ovc_name."_agent agent0;\n";
    print FH "\n";
    print FH $indent1 . $separator;
    print FH $indent1 . "// UVM registration macro\n";
    print FH $indent1 . "`uvm_component_utils(".$ovc_name."_env)\n";
    print FH "\n";
    print FH $indent1 . $separator;
    print FH $indent1 . "// UVM Phases\n";
    print FH $indent1 . "extern virtual function void build_phase(uvm_phase phase);\n";
    print FH "\n";
    print FH $indent1 . $separator;
    print FH $indent1 . "// Methods\n";
    print FH "\n";
    print FH $indent1 . $separator;
    print FH $indent1 . "// Constructor\n";
    print FH $indent1 . "function new(string name, uvm_component parent);\n";
    print FH $indent2 . "super.new(name,parent);\n";
    print FH $indent1 . "endfunction : new\n";
    print FH "endclass : ".$ovc_name."_env \n";
    print FH "\n";
    print FH $separator;
    print FH "// Methods\n";
    print FH "function void " . $ovc_name . "_env::build_phase(uvm_phase phase);\n";
    print FH $indent1 . "super.build_phase(phase);\n";
    print FH $indent1 . "agent0=".$ovc_name."_agent::type_id::create(\"agent0\",this);\n";
    print FH "endfunction : build_phase\n";
    print FH "\n";

    close(FH); ### end gen_env()
  }

sub gen_seq_lib()
  {
    open(FH, ">".$ovc_name."/sv/".$ovc_name."_seq_lib.sv") || die("can't open seq_lib: $ovc_name");
    #jm - start base_sequence
    print FH $smallsep . "uvm_sequence Classes\n";
    print FH $smallsep . "base sequence : define common sequence methods and properties(variables)\n";
    print FH $smallsep . "this sequence is not intended to be directly called - no body method\n";
    #print FH $separator;
    print FH "class ".$ovc_name."_base_seq extends uvm_sequence #($ovc_item);\n";
    print FH "string tID;\n";
    print FH "`uvm_object_utils(".$ovc_name."_base_seq)\n";
    print FH "//declare a p_sequencer pointer to sequencer (optional if needed)\n";
    ### USE_SEQ print FH "`uvm_declare_p_sequencer(".$ovc_name."_sequencer)\n";
    print FH "`uvm_declare_p_sequencer(uvm_sequencer#(".$ovc_item."))\n";
    print FH "\n";
    print FH "function new(string name = \"".$ovc_name."_base_seq\");\n";
    print FH "   super.new(name);\n";
    print FH "   tID=get_type_name();\n";
    print FH "   tID=tID.toupper();\n";
    print FH "endfunction : new\n";
    print FH "\n";
    print FH "task pre_body();\n";
    print FH "`ifndef UVM_VERSION_1_1\n";
    print FH "  uvm_phase starting_phase = get_starting_phase();\n";
    print FH "`endif\n";
    print FH "  if(starting_phase != null) starting_phase.raise_objection(this,get_type_name());\n";
    print FH "endtask :  pre_body\n";
    print FH "\n";
    print FH "task post_body();\n";
    print FH "`ifndef UVM_VERSION_1_1\n";
    print FH "  uvm_phase starting_phase = get_starting_phase();\n";
    print FH "`endif\n";
    print FH "  if(starting_phase != null) starting_phase.drop_objection(this,get_type_name());\n";
    print FH "endtask :  post_body\n";
    print FH "endclass : ".$ovc_name."_base_seq\n";
    #jm - end base_sequence
    print FH "\n";
    #print FH $separator;
    print FH $smallsep . "basic sequence example (calls an item)\n";
    print FH "class ".$ovc_name."_seq1 extends ".$ovc_name."_base_seq;\n";
    print FH "//\"req\" built-in uvm_sequence class member for sequence_item\n";
    print FH "rand int delay1;\n";
    print FH "constraint d1 {delay1 inside {[55:125]};}\n";
    print FH "\n";
    print FH "`uvm_object_utils_begin(".$ovc_name."_seq1)\n";
    print FH "   `uvm_field_int(delay1,UVM_ALL_ON + UVM_DEC)\n";
    print FH "`uvm_object_utils_end\n";
    print FH "\n";
    print FH "function new(string name = \"".$ovc_name."_seq1\");\n";
    print FH "   super.new(name);\n";
    print FH "endfunction : new\n";
    print FH "\n";
    print FH "task body();\n";
    print FH "  `uvm_info(tID,\"sequence RUNNING\",UVM_MEDIUM)\n";
    print FH "  `uvm_info(tID,\$sformatf(\"delay1=%0d\",delay1),UVM_HIGH)\n";
    print FH "  #delay1  //dummy delay to illustrate a sequence rand variable\n";
    print FH "  `uvm_do(req) //this line sends the transaction\n"; 
    print FH "  #delay1\n";
    print FH "  `uvm_info(tID,\"sequence COMPLETE\",UVM_MEDIUM)\n";
    print FH "endtask : body\n";
    print FH "endclass : ".$ovc_name."_seq1 \n";
    print FH "\n";
    #generate a sequence which calls a sub-sequence
    #print FH $separator;
    print FH $smallsep . "nested sequence example \n";
    print FH "class ".$ovc_name."_seq2 extends ".$ovc_name."_base_seq;\n";
    print FH "//\"req\" built-in uvm_sequence class member for sequence_item\n";
    print FH "rand int sd1;\n";
    print FH "rand int scnt;\n";
    print FH "constraint d1 {sd1 inside {[15:25]};}\n";
    print FH "constraint s1 {scnt inside {[4:10]};}\n";
    print FH "\n";
    print FH "`uvm_object_utils_begin(".$ovc_name."_seq2)\n";
    print FH "   `uvm_field_int(sd1,UVM_ALL_ON + UVM_DEC)\n";
    print FH "   `uvm_field_int(scnt,UVM_ALL_ON + UVM_DEC)\n";
    print FH "`uvm_object_utils_end\n";
    print FH "\n";
    print FH "function new(string name = \"".$ovc_name."_seq2\");\n";
    print FH "   super.new(name);\n";
    print FH "endfunction : new\n";
    print FH "\n";
    print FH "".$ovc_name."_seq1 es1;\n";
    print FH "task body();\n";
    print FH "  `uvm_info(tID,\"sequence RUNNING\",UVM_MEDIUM)\n";
    print FH "  `uvm_info(tID,\$sformatf(\"sd1=%0d\", sd1),UVM_HIGH);\n";
    print FH "  for (int i=1; i<scnt; i++)\n";
    print FH "    begin\n";
    print FH "      #sd1  //dummy delay to illustrate a sequence rand variable\n";
    print FH "      `uvm_do(es1) //send sub-sequence\n";
    print FH "    end\n";
    print FH "  `uvm_info(tID,\"sequence COMPLETE\",UVM_MEDIUM)\n";
    print FH "endtask : body\n";
    print FH "endclass : ".$ovc_name."_seq2 \n";
    print FH "\n";
    print FH $smallsep . "additional sequences can be included here\n";
    print FH "\n";
    close(FH);
  } ### end gen_seq_lib()

sub gen_seq_lib_one_file()
  {
    open(FH, ">>".$ovc_name."/top.sv") || die("can't open seq_lib: $ovc_name");
    #jm - basic sequence for one_file 
    print FH $smallsep . "uvm_sequence Classes\n";
    print FH "//basic sequence (calls an item)\n";
    print FH "class ".$ovc_name."_seq extends uvm_sequence #($ovc_item);\n";
    print FH "rand int delay1;\n";
    print FH "constraint d1 {delay1 inside {[55:125]};}\n";
    print FH "`uvm_object_utils_begin(".$ovc_name."_seq)\n";
    print FH "   `uvm_field_int(delay1,UVM_ALL_ON + UVM_DEC)\n";
    print FH "`uvm_object_utils_end\n";
    print FH "function new(string name = \"".$ovc_name."_seq\");\n";
    print FH "   super.new(name);\n";
    print FH "endfunction : new\n";
    print FH "\n";
    print FH "task body();\n";
    print FH "`ifndef UVM_VERSION_1_1\n";
    print FH "  uvm_phase starting_phase = get_starting_phase();\n";
    print FH "`endif\n";
    print FH "  if(starting_phase != null) starting_phase.raise_objection(this,get_type_name());\n";
    print FH "  `uvm_info(get_type_name(),\"sequence RUNNING\",UVM_MEDIUM)\n";
    print FH "  `uvm_info(get_type_name(),\$sformatf(\"delay1=%0d\",delay1),UVM_HIGH)\n";
    print FH "  #delay1  //dummy delay to illustrate a sequence rand variable\n";
    print FH "  `uvm_do(req) //this line sends the transaction\n"; 
    print FH "  if(starting_phase != null) starting_phase.drop_objection(this,get_type_name());\n";
    print FH "  `uvm_info(get_type_name(),\"sequence COMPLETE\",UVM_MEDIUM)\n";
    print FH "endtask : body\n";
    print FH "endclass : ".$ovc_name."_seq\n";
    #jm - end base_sequence
    print FH "\n";
    close(FH);
  } ### end gen_seq_lib_one_file()

sub gen_ovc_include()
  {
    ### file list for files in sv directory (.svh file)
    open(FH, ">".$ovc_name."/sv/".$ovc_name."_inc.svh") || die("can't open include file: $ovc_name");
    print FH "\n";
    print FH "include file created if needed\n";
    print FH "`include \"".$ovc_item.".sv\"\n";
    if ($ovc_explicit_seqr == 1) {print FH "`include \"".$ovc_name."_sequencer.sv\"\n";}
    print FH "`include \"".$ovc_name."_monitor.sv\"\n";
    print FH "`include \"".$ovc_name."_driver.sv\"\n";
    print FH "`include \"".$ovc_name."_agent.sv\"\n";
    print FH "`include \"".$ovc_name."_env.sv\"\n";
    print FH "`include \"".$ovc_name."_seq_lib.sv\"\n";
    #print FH "../sv/".$ovc_item.".sv\n";
    #print FH "../sv/".$ovc_name."_sequencer.sv\n";
    #print FH "../sv/".$ovc_name."_monitor.sv\n";
    #print FH "../sv/".$ovc_name."_driver.sv\n";
    print FH "\n";
    close(FH);

    ### generate a package to contain the uvc
    open(FH, ">".$ovc_name."/sv/".$ovc_name."_pkg.sv") || die("can't open package file: $ovc_name");
    print FH "\n";
    print FH "package ".$ovc_name."_pkg;\n";
    print FH $uvm_timeunit;
    print FH $uvm_timeprecision;
    print FH "import uvm_pkg::*;\n";
    print FH "`include \"uvm_macros.svh\"\n";
    print FH "`include \"".$ovc_item.".sv\"\n";
    if ($ovc_explicit_seqr == 1) {print FH "`include \"".$ovc_name."_sequencer.sv\"\n";}
    print FH "`include \"".$ovc_name."_monitor.sv\"\n";
    print FH "`include \"".$ovc_name."_driver.sv\"\n";
    print FH "`include \"".$ovc_name."_agent.sv\"\n";
    print FH "`include \"".$ovc_name."_env.sv\"\n";
    print FH "`include \"".$ovc_name."_seq_lib.sv\"\n";
    print FH "endpackage : ".$ovc_name."_pkg\n";
    close(FH);

    gen_run_script();
    gen_clean_script();
  } ### end gen_ovc_include()

sub gen_run_script()
  {
    ### run script (jrun)
    if ($ovc_one_file == 1)
    {
      open(FH, ">".$ovc_name."/jrun") || die("can't open file: jrun");
    }
    else
    {
      open(FH, ">".$ovc_name."/examples/jrun") || die("can't open file: jrun");
    }
    print FH "\n";
    print FH "## use +UVM_OBJECTION_TRACE to trace objections\n";
    print FH "## use +UVM_CONFIG_DB_TRACE to trace config db access\n";
    print FH "## use +UVM_RESOURCE_DB_TRACE to trace resource db access\n";
    print FH "## use +UVM_PHASE_TRACE to trace phasing\n";
    print FH "##   see UVM Reference Manual for *TRACE* details\n";
    print FH "set -x";
    print FH "\n";
    ###print FH "irun -uvm -incdir ../sv -incdir \$UVM_HOME/src \$UVM_HOME/src/uvm.svh -f ../sv/".$ovc_name."_inc.svh\n";
    print FH "#\n";
    print FH "#if using Accellera UVM - point UVMHOME to that install and use -uvmhome \$UVMHOME instead of -uvm\n";
    print FH "#\n";
    print FH "# NOTE: $ovc_run_command is the run command for Cadence $ovc_sim_name Simulator\n";
    print FH "#   If using a non-Cadence simulator, replace the $ovc_run_command command line with the appropriate vendor specific command line\n";
    print FH "#     add \"-uvmnocdnsextra\" to use UVM not supplied with the Cadence release\n"; 
    print FH "#\n";
    print FH "# use the \$1 argument for your favorite command line option like -gui : i.e. jrun -gui\n";
    print FH "# $ovc_sim_name debug: -linedebug   -> enables line debug\n";
    print FH "# $ovc_sim_name debug: -access +rwc -> r=read / w=write/ c=connectivity access\n";
    print FH "# $ovc_sim_name debug: -g | -gui    -> enable graphical debugger\n";
    print FH "#\n";
    if ($ovc_one_file == 1)
    {
      print FH "$ovc_run_command $uvm_version $uvm_deprecated $sv_nowarns top.sv +UVM_VERBOSITY=UVM_HIGH -access +rwc \$1\n";
      print FH "\n";
      chmod(0755, $ovc_name."/jrun");
    }
    else
    {
      # -sem2009
      #print FH "#irun -uvm -incdir ../sv ../sv/".$ovc_name."_if.sv top.sv +UVM_TESTNAME=test2 +UVM_VERBOSITY=UVM_HIGH \n";
      print FH "$ovc_run_command $uvm_version $uvm_deprecated $sv_nowarns -incdir ../sv ../sv/".$ovc_name."_if.sv ../sv/".$ovc_name."_pkg.sv top.sv +UVM_TESTNAME=test2 +UVM_VERBOSITY=UVM_HIGH -access +rwc \$1\n";
      print FH "\n";
      chmod(0755, $ovc_name."/examples/jrun");
    }
    close(FH);
  }

sub gen_clean_script()
  { 
    ### clean script (clean) 
    if ($ovc_one_file == 1)
    {
      open(FH, ">".$ovc_name."/clean") || die("can't open file: clean");
      chmod(0755, $ovc_name."/clean");
    }
    else
    {
      open(FH, ">".$ovc_name."/examples/clean") || die("can't open file: clean");
      chmod(0755, $ovc_name."/examples/clean");
    }
    print FH "\n";
    print FH "set -x";
    print FH "\n";
    print FH "rm -rf INCA_libs\n";
    print FH "rm -rf xcelium.d\n";
    print FH "rm -rf waves.shm\n";
    print FH "rm -rf ncsim.shm\n";
    print FH "rm -rf .simvision\n";
    print FH "rm -f *.log\n";
    print FH "rm -f *.history\n";
    print FH "rm -f *.key\n";
    print FH "rm -f log.dat\n";
    print FH "\n";
    close(FH);
  } ### end gen_clean_script()

sub gen_tb()
  {
    open(FH, ">".$ovc_name."/examples/$ovc_name\_demo_tb.sv") || die("can't open tb: tb.sv");
    print FH "class ",$ovc_name,"_demo_tb extends uvm_env;\n";
    print FH $indent1 . $separator;
    print FH $indent1 . "// Fields\n";
    print FH $indent1 . $ovc_name."_env $ovc_name"."0;\n";
    print FH "\n";
    print FH $indent1 . $separator;
    print FH $indent1 . "// UVM registration macro\n";
    print FH $indent1 . "`uvm_component_utils(",$ovc_name."_demo_tb)\n";
    print FH "\n";
    print FH $indent1 . $separator;
    print FH $indent1 . "// UVM phases\n";
    print FH $indent1 .  "extern virtual function void build_phase(uvm_phase phase);\n";
    print FH "\n";
    print FH $indent1 . $separator;
    print FH $indent1 . "// Methods\n";
    print FH "\n";
    print FH $indent1 . "// Private properties(variables)\n";
    print FH "\n";
    print FH $indent1 . $separator;
    print FH $indent1 . "// Constructor\n";
    print FH $indent1 . "function new(string name, uvm_component parent);\n";
    print FH $indent2 . "super.new(name,parent);\n";
    print FH $indent1 . "endfunction : new\n";
    print FH "endclass : $ovc_name"."_demo_tb \n";
    print FH "\n";
    print FH $indent1 . $separator;
    print FH $indent1 . "// class " . $ovc_name . "_demo_tb Phase and Method Implementation(s)\n";
    print FH "\n";
    print FH $indent1 . $separator;
    print FH "function void " . $ovc_name . "_demo_tb::build_phase(uvm_phase phase);\n";
    print FH "  super.build_phase(phase);\n";
    print FH "  $ovc_name"."0=".$ovc_name."_env::type_id::create(\"$ovc_name"."0\",this);\n";
    print FH "endfunction : build_phase\n";
    print FH "\n";
    close(FH);
  }

sub gen_test_one_file()
  {
    open(FH, ">>".$ovc_name."/top.sv") || die("can't open top.sv");
    print FH $smallsep . "uvm_test Class\n";
    print FH "class onetest extends uvm_test;\n";
    if ($ovc_test_only==0)
      {
        print FH $ovc_name."_agent agnt0;\n";
      }
    print FH "`uvm_component_utils(onetest)\n";
    print FH "\n";
    print FH "function new(string name, uvm_component parent);\n";
    print FH "   super.new(name,parent);\n";
    print FH "endfunction : new\n";
    print FH "\n";
    print FH "virtual function void build_phase(uvm_phase phase);\n";
    print FH "  super.build_phase(phase);\n";
    if ($ovc_test_only==0)
      {
    ###print FH "  uvm_config_db#(int)::set(this,\"".$ovc_name.".agnt0\",\"is_active\",UVM_ACTIVE);\n"; 
    print FH "  uvm_config_db#(int)::set(this,\"agnt0\",\"is_active\",UVM_ACTIVE);\n"; 
    print FH "  uvm_config_db#(int)::set(this,\"*\",\"recording_detail\",UVM_FULL);\n";
    ### print FH "  uvm_config_db#(uvm_object_wrapper)::set(this, \"agnt0.sequencer.main_phase\",\"default_sequence\",".$ovc_name."_seq::type_id::get());\n";
    print FH "  uvm_config_db#(uvm_object_wrapper)::set(this, \"agnt0.sequencer.run_phase\",\"default_sequence\",".$ovc_name."_seq::type_id::get());\n";
    print FH "  agnt0=$ovc_name\_agent::type_id::create(\"agnt0\",this);\n";
     }
    print FH "endfunction : build_phase\n";
    print FH "virtual function void start_of_simulation_phase(uvm_phase phase);\n";
    print FH "  uvm_top.print_topology();\n";
    print FH "endfunction : start_of_simulation_phase\n";
    print FH "endclass : onetest \n";
    print FH "\n";
    close(FH);
  } ### end gen_test_one_file()

sub gen_test()
  {
    open(FH, ">".$ovc_name."/examples/testlib.sv") || die("can't open test: testlib.sv");
    #jm - start base_test
    print FH "//class base_test : define common test methods and properties(variables)\n";
    print FH "//this test is not intended to be directly called \n";
    print FH $separator;
    print FH "class base_test extends uvm_test;\n";
    print FH $indent1 . $separator;
    print FH $indent1 . "// Fields\n";
    print FH $indent1 . $ovc_name."_demo_tb tb0;\n";
    print FH "\n";
    print FH $indent1 . $separator;
    print FH $indent1 . "// UVM registration macro\n";
    print FH $indent1 . "`uvm_component_utils(base_test)\n";
    print FH "\n";
    print FH $indent1 . $separator;
    print FH $indent1 . "// UVM phases\n";
    print FH $indent1 . "extern virtual function void build_phase(uvm_phase phase);\n";
    print FH $indent1 . "extern virtual function void start_of_simulation_phase(uvm_phase phase);\n";
    print FH $indent1 . "//extern virtual function void end_of_elaboration_phase(uvm_phase phase);\n";
    print FH "\n";
    print FH $indent1 . $separator;
    print FH $indent1 . "// Methods\n";
    print FH "\n";
    print FH $indent1 . $separator;
    print FH $indent1 . "// Private properties(variables)\n";
    print FH "\n";
    print FH $indent1 . $separator;
    print FH $indent1 . "// Constructor\n";
    print FH $indent1 . "function new(string name, uvm_component parent);\n";
    print FH $indent2 . "super.new(name,parent);\n";
    print FH $indent1 . "endfunction : new\n";
    print FH "endclass : base_test \n";
    print FH "\n";
    print FH "// class base_test Phase and Method Implementation(s)\n";
    print FH $separator;
    print FH "function void base_test::build_phase(uvm_phase phase);\n";
    print FH $indent1 . "super.build_phase(phase);\n";
    print FH $indent1 . "uvm_config_db#(int)::set(this,\"*\",\"recording_detail\",UVM_FULL);\n";
    print FH $indent1 . "tb0=$ovc_name\_demo_tb::type_id::create(\"tb0\",this);\n";
    print FH "endfunction : build_phase\n";
    print FH "\n";
    print FH $separator;
    print FH "// -- uncomment code to illustrate how to enable logging UVM_INFO messages to a file;\n";
    print FH "//function void base_test::end_of_elaboration_phase(uvm_phase phase);\n";
    print FH "//  UVM_FILE fh;\n";
    print FH "//  fh=\$fopen(\"log.dat\");\n";
    print FH "//  uvm_top.set_report_severity_file_hier(UVM_INFO,fh);\n";
    print FH "//  uvm_top.set_report_severity_action_hier(UVM_INFO, UVM_LOG);\n";
    print FH "//endfunction : end_of_elaboration_phase\n";
    print FH "\n";
    print FH $separator;
    print FH "function void base_test::start_of_simulation_phase(uvm_phase phase);\n";
    print FH "  uvm_top.print_topology();\n";
    print FH "endfunction : start_of_simulation_phase\n";
    print FH "\n\n";
    #jm - end base_test

    print FH $separator;
    print FH "//class test1 : define common test methods and properties(variables)\n";
    print FH "class test1 extends base_test;\n";
    print FH $indent1 . $separator;
    print FH $indent1 . "// Fields\n";
    print FH "\n";
    print FH $indent1 . $separator;
    print FH $indent1 . "// UVM registration macro\n";
    print FH $indent1 . "`uvm_component_utils(test1)\n";
    print FH "\n";
    print FH $indent1 . $separator;
    print FH $indent1 . "// UVM Phases\n";
    print FH $indent1 . "extern virtual function void build_phase(uvm_phase phase);\n";
    print FH "\n";
    print FH $indent1 . $separator;
    print FH $indent1 . "// Methods\n";
    print FH "\n";
    print FH $indent1 . $separator;
    print FH $indent1 . "// Private properties(variables)\n";
    print FH "\n";
    print FH $indent1 . $separator;
    print FH $indent1 . "// Constructor\n";
    print FH $indent1 . "function new(string name, uvm_component parent);\n";
    print FH $indent2 . "super.new(name,parent);\n";
    print FH $indent1 . "endfunction : new\n";
    print FH "endclass : test1 \n";
    print FH "\n";
    print FH $separator;
    print FH "// class test1 Phase and Method Implementation(s)\n";
    print FH "\n";
    print FH $separator;
    print FH "function void test1::build_phase(uvm_phase phase);\n";
    print FH "  //configure sequence for \"run_phase\" - will run in run_phase\n";
    ### print FH "  uvm_config_db#(uvm_object_wrapper)::set(this, \"tb0.".$ovc_name."0.agent0.sequencer.reset_phase\",\"default_sequence\",".$ovc_name."_reset_seq::type_id::get());\n";
    ### print FH "  uvm_config_db#(uvm_object_wrapper)::set(this, \"tb0.".$ovc_name."0.agent0.sequencer.main_phase\",\"default_sequence\",".$ovc_name."_seq1::type_id::get());\n";
    print FH "  uvm_config_db#(uvm_object_wrapper)::set(this, \"tb0.".$ovc_name."0.agent0.sequencer.run_phase\",\"default_sequence\",".$ovc_name."_seq1::type_id::get());\n";
    print FH "  uvm_config_db#(int)::set(this,\"tb0.".$ovc_name."0.agent0\",\"is_active\",UVM_ACTIVE);\n"; 
    print FH "  //NEED to set configurations before calling super.build_phase() which creates the verification hierarchy \"tb0\"\n";
    print FH "  super.build_phase(phase);\n";
    print FH "endfunction : build_phase\n";
    print FH "\n";

    #jm - start test2
    print FH $separator;
    print FH "//class test2 : define common test methods and properties(variables)\n";
    print FH "class test2 extends base_test;\n";
    print FH $indent1 . $separator;
    print FH $indent1 . "// Fields\n";
    print FH "\n";
    print FH $indent1 . $separator;
    print FH $indent1 . "// UVM registration macro\n";
    print FH $indent1 . "`uvm_component_utils(test2)\n";
    print FH "\n";
    print FH $indent1 . $separator;
    print FH $indent1 . "// UVM Phases\n";
    print FH $indent1 . "extern virtual function void build_phase(uvm_phase phase);\n";
    print FH "\n";
    print FH $indent1 . $separator;
    print FH $indent1 . "// Methods\n";
    print FH "\n";
    print FH $indent1 . $separator;
    print FH $indent1 . "// Private properties(variables)\n";
    print FH "\n";
    print FH $indent1 . $separator;
    print FH $indent1 . "// Constructor \n";
    print FH $indent1 . "function new(string name, uvm_component parent);\n";
    print FH $indent2 . "super.new(name,parent);\n";
    print FH $indent1 . "endfunction : new\n";
    print FH "endclass : test2 \n";
    print FH "\n";
    print FH $separator;
    print FH "// class test2 Phase and Method Implementation(s)\n";
    print FH "\n";
    print FH $separator;
    print FH "function void test2::build_phase(uvm_phase phase);\n";
    print FH "  //configure sequence for \"run_phase\" will run run_phase\"\n";
    ### print FH "  uvm_config_db#(uvm_object_wrapper)::set(this, \"tb0.".$ovc_name."0.agent0.sequencer.reset_phase\",\"default_sequence\",".$ovc_name."_reset_seq::type_id::get());\n";
    ### print FH "  uvm_config_db#(uvm_object_wrapper)::set(this, \"tb0.".$ovc_name."0.agent0.sequencer.main_phase\",\"default_sequence\",".$ovc_name."_seq2::type_id::get());\n";
    print FH "  uvm_config_db#(uvm_object_wrapper)::set(this, \"tb0.".$ovc_name."0.agent0.sequencer.run_phase\",\"default_sequence\",".$ovc_name."_seq2::type_id::get());\n";
    print FH "  uvm_config_db#(int)::set(this,\"tb0.".$ovc_name."0.agent0\",\"is_active\",UVM_ACTIVE);\n"; 
    print FH "  //NEED to set configurations before calling super.build_phase() which creates the verification hierarchy \"tb0\"\n";
    print FH "  super.build_phase(phase);\n";
    print FH "endfunction : build_phase\n";
    #jm - end test2
    close(FH);
  } ### end gen_test()


sub gen_top()
  {
    ### generate top.sv
    open(FH, ">".$ovc_name."/examples/top.sv") || die("can't open file: top.sv");
    print FH "//SystemVerilog UVM-1.2 UVC template generated by juvb.pl : version ".$VERNUM."\n";
    print FH "//contact mcgrath\@cadence.com for help or feedback\n";
    print FH "\n";
    print FH "module top();\n";
    print FH "import uvm_pkg::*;\n";
    print FH "`include \"uvm_macros.svh\"\n";
    ### pkg print FH "`include \"".$ovc_name."_inc.svh\"\n";
    print FH "import ".$ovc_name."_pkg::*;\n";
    print FH "`include \"".$ovc_name."_demo_tb.sv\"\n";
    print FH "`include \"testlib.sv\"\n";
    print FH "logic clock;\n";
    print FH "logic reset;\n";
    print FH $ovc_if." if0(clock, reset); //instantiate ovc interface\n";
    print FH "\n";
    print FH "initial\n";
    print FH "  begin\n";
    print FH "    uvm_config_db#(virtual ".$ovc_if.")::set(null,\"uvm_test_top.tb0.".$ovc_name."0.agent0.*\", \"vif\",if0);\n";
    print FH "    run_test();\n";
    print FH "  end\n"; 
    print FH "\n";
    print FH "always #10 clock = ~clock;\n";
    print FH "initial\n";
    print FH "  begin\n";
    print FH "    clock=0;\n";
    print FH "    reset=1; //active high reset for this example\n";
    print FH "    #75 reset=0;\n";
    print FH "  end\n";
    print FH "//instantiate and connect dut to interface(s) here\n";
    print FH "endmodule\n";
    close(FH);
  } ### end gen_top()

sub gen_top_one_file()
  {
    ### generate top.sv
    open(FH, ">>".$ovc_name."/top.sv") || die("can't open file: top.sv");
    print FH $smallsep . "begin RTL\n";
    print FH "logic clock;\n";
    print FH "logic reset;\n";
    print FH $ovc_if." if0(clock, reset); //instantiate ovc interface\n";
    print FH "\n";
    print FH "initial\n";
    print FH "  begin\n";
    print FH "    uvm_config_db#(virtual ".$ovc_if.")::set(null,\"uvm_test_top.agnt0.*\", \"vif\",if0);\n";
    print FH "    run_test(\"onetest\");\n";
    print FH "  end\n"; 
    print FH "\n";
    print FH "always #10 clock = ~clock;\n";
    print FH "initial\n";
    print FH "  begin\n";
    print FH "    clock=0;\n";
    print FH "    reset=1; //active high reset for this example\n";
    print FH "    #75 reset=0;\n";
    print FH "  end\n";
    print FH "//instantiate and connect dut to interface(s) here\n";
    print FH "endmodule\n";
    close(FH);
  }


