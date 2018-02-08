#! /bin/csh  -f

#set echo

# Incisive ("") or Xcelium("-x")
#set simver=""
set simver=-x

rm -f all.log
echo "------------- Running juvb12.pl regression -------------"

#
# test "perl juvb12.pl -help"
#
echo "--------------------------------------------------------------" > all.log
echo "### command : perl juvb12.pl" -h >> all.log
echo "### command : perl juvb12.pl" -h
perl juvb12.pl -h >> all.log
echo "--------------------------------------------------------------" >> all.log
echo ""  >> all.log


set TESTLIST = "mtest"
set TESTLIST = "$TESTLIST  otest"
#echo $TESTLIST

#
# no options
#
foreach TEST ( $TESTLIST )
  echo "$TEST  -------------------------------------------------" >> all.log
  echo "### command : perl juvb12.pl -tem $TEST.tpl "
  echo "### command : perl juvb12.pl -tem $TEST.tpl " >> all.log
  perl juvb12.pl -tem $TEST.tpl $simver >>& all.log
  cd $TEST/examples
  echo "-------- jrun --------" >>& all.log
  ./jrun >>& ../../all.log
  cd -
  echo "cleaning..." >> all.log
  ./clean >>& all.log
  echo "--------------------------------------------------------------" >> all.log
  echo ""  >> all.log
end

#
# -use_s option
#
foreach TEST ( $TESTLIST )
  echo "$TEST -use_s -------------------------------------------------" >> all.log
  echo "### command : perl juvb12.pl -tem $TEST.tpl -use_s" 
  echo "### command : perl juvb12.pl -tem $TEST.tpl -use_s" >> all.log
  perl juvb12.pl -tem $TEST.tpl -use_s $simver >>& all.log
  cd $TEST/examples
  echo "-------- jrun --------" >>& all.log
  ./jrun >>& ../../all.log
  cd -
  echo "cleaning..." >> all.log
  ./clean >>& all.log
  echo "--------------------------------------------------------------" >> all.log
  echo ""  >> all.log
end

#
# -one option
#
foreach TEST ( $TESTLIST )
  echo "$TEST -one -------------------------------------------------" >> all.log
  echo "### command : perl juvb12.pl -tem $TEST.tpl -one" 
  echo "### command : perl juvb12.pl -tem $TEST.tpl -one" >> all.log
  perl juvb12.pl -tem $TEST.tpl -one $simver >>& all.log
  cd $TEST
  echo "-------- jrun --------" >>& all.log
  ./jrun >>& ../../all.log
  cd -
  echo "cleaning..." >> all.log
  ./clean >>& all.log
  echo "--------------------------------------------------------------" >> all.log
  echo ""  >> all.log
end

#
# -use_s -one options
#
foreach TEST ( $TESTLIST )
  echo "$TEST -use_s -one -------------------------------------------------" >> all.log
  echo "### command : perl juvb12.pl -tem $TEST.tpl -use_s -one " 
  echo "### command : perl juvb12.pl -tem $TEST.tpl -use_s -one " >> all.log
  perl juvb12.pl -tem $TEST.tpl -use_s -one $simver >>& all.log
  cd $TEST
  echo "-------- jrun --------" >>& all.log
  ./jrun >>& ../../all.log
  cd -
  echo "cleaning..." >> all.log
  ./clean >>& all.log
  echo "--------------------------------------------------------------" >> all.log
  echo ""  >> all.log
end

#
# results 
#
echo "results ------------------------------------------------------" 
grep \*E all.log
grep \*W all.log
grep UVM_WARNING all.log
grep UVM_ERROR all.log
grep UVM_FATAL all.log
echo "results ------------------------------------------------------" 

echo "------------- Done running juvb12.pl regression -------------"



