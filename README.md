# juvb12
UVM 1.2 UVC template builder for UVM

How to use juvb12.pl

The README contains the info from "perl juvb12.pl -h"

juvb12.pl generates simple UVM UVC shells using a basic template file.  
Two example templates are provided mtest.tpl and otest.tpl.  There are 
two use models - the first is to generate separate files for the uvc 
components - this is targeted for eventually developing a "real" verification 
component.  The second is using the "-one_file" switch for developing simple 
UVM test cases.  All the uvc code is dumped into a single file.  The types of
ports supported are very limited, but the code generated generally should compile
and run out-of-the-box. A basic run script "jrun" is provided as well as a
"clean" script.  Currently, only Cadence simulators are supported as that is
what I have access to.  Feedback from other users is certainly welcome and can
be accommodated if time is available.  

Have fun,
mcgrath@cadence.com

