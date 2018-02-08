
# multi-file regression template

#add timeunit/timeprecision as needed
#will be echoed into interface file
#timeunit 1ns;
#timeprecision 1ns;
#
timeunit 1ns;
  timeprecision 1ns;
# 
ovc_Name| mtest
ovc_item | mpkt
ovc_var | rand int v1;
ovc_var | rand int v2;
ovc_if | tif
ovc_port | logic [31:0] port1;
ovc_port | logic [15:0] port2;

