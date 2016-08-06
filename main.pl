#!/usr/bin/perl -w 
use strict; 
use warnings; 
use diagnostics; 
use Tkx;
use utf8 ;
use DBI;
use DBD::SQLite;
use Encode;

#SQL=#  opendb "E:\english\english.db"
#SQL=#  select word from Oxford where length(word)>3
my $dbargs = { AutoCommit => 0, PrintError => 1 };
my $dbh = DBI->connect("dbi:SQLite:dbname=english.db", "", "", $dbargs)
  or die $DBI::errstr;
# Global variables
my $RgxStr;
my $WrdStr;
my @SrcResults;
  
# GUI Components Declaration 
 my $mw=Tkx::widget->new("."); 
 my $frame_btns=$mw->new_ttk__frame(); 
 
 my $entry_regxsearch=$mw->new_ttk__entry(-textvariable=>\$RgxStr);
 my $button_search=$mw->new_ttk__button(-text=>"singleSearch",-command=>\&singleSearch);
 my $entry_wordsearch=$mw->new_ttk__entry(-textvariable=>\$WrdStr);
 my $button_wordsearch=$mw->new_ttk__button(-text=>"WordSearch",-command=>\&wordSearch);

#entry_regxSearch={can:mw,txtvar:RgxStr,row:1,col:1,colspan:2};
# button_search={can:mw,txt:singleSearch,row:1,col:2,colspan:2}

my $label_batchrgxinput=$mw->new_ttk__label(-text=>"Batch input Regular expressions");
my $text_batch=$mw->new_tk__text(-height=>6);

my $b_srl_y = $mw-> new_ttk__scrollbar(-orient=>'vertical',-command=>[$text_batch,'yview']);
$text_batch -> configure(-yscrollcommand=>[$b_srl_y,'set']);
my $button_batchSearch=$frame_btns->new_ttk__button(-text=>"BatchSearch&Insert",-command=>\&batchSearchInsert);
my $text_srcResult=$mw->new_tk__text(-height=>40);
my $srl_y = $mw-> new_ttk__scrollbar(-orient=>'vertical',-command=>[$text_srcResult,'yview']);
$text_srcResult -> configure(-yscrollcommand=>[$srl_y,'set']);
$text_srcResult->g_bind("<3>", \&rightClick_getWordMeans);  ## click right mouse button
my $button_store=$frame_btns->new_ttk__button(-text=>"StoreResults",-command=>\&storeResults);

#GUI Grid Setting 
$entry_regxsearch->g_grid(-row =>1, -column => 1,-columnspan=>1,-sticky=>"w"); 
$button_search->g_grid(-row =>1, -column => 2,-columnspan=>1,-sticky=>"w");

$entry_wordsearch->g_grid(-row =>1, -column => 3,-columnspan=>1,-sticky=>"e"); 
$button_wordsearch->g_grid(-row =>1, -column => 4,-columnspan=>1,-sticky=>"e");

$label_batchrgxinput->g_grid(-row =>2, -column => 1,-columnspan=>5);
$text_batch->g_grid(-row =>3, -column =>1,-columnspan=>3,-sticky=>"ewns");
$b_srl_y->g_grid(-row=>3,-sticky=>"ewns");
$frame_btns->g_grid(-row =>3, -column => 4,-columnspan=>1,-sticky => "ewns");
$button_batchSearch->g_grid(-row =>1, -column => 1,-columnspan=>1);
$button_store->g_grid(-row =>2, -column =>1,-columnspan=>1);
$text_srcResult->g_grid(-row =>4, -column =>1,-columnspan=>4,-sticky=>"ewns");
$srl_y->g_grid(-row=>4,-column=>5,-sticky=>"ewns");

Tkx::MainLoop();

### functions definition
##
# search aginst DB which match to the regular expression input, get results into text editor
#
sub singleSearch{
    my $srchResult = "";
    my $rgxParameter=addRgxFixes($RgxStr);
    $RgxStr= $rgxParameter;  ## to show modified parameter
    # search if it ever been searched
    #SQL=#  select relatesWords from Relates where searchStr like ?
    my $sth_qe = $dbh->prepare(q{select relatesWords from Relates where searchStr like ?});
    # print "Debug:select relatesWords from Relates where searchStr like '$rgxParameter' \n";
    $sth_qe->execute($rgxParameter);
    my @row_qe = $sth_qe->fetchrow_array;
    # print "Debug: @row_qe \n";
    if (scalar(@row_qe) != 0) {  # if the search record already exists in DB , use the contents of DB to display
        my $v_relatesWords = $row_qe[0];
        my @tmp = split ",", $v_relatesWords;
        @SrcResults = ();
        foreach my $w (@tmp) {
            #SQL=#  select means from Oxford where word=$w
            my $sth_wrd = $dbh->prepare(q{select means from Oxford where word=?});
            $sth_wrd->execute($w);
            my @row_men = $sth_wrd->fetchrow_array;
            my $v_means = decode("utf8", $row_men[0]);
            $srchResult = $srchResult . $w . "   :" . $v_means . "\n";
            # print "Debug: $srchResult \n";
            $sth_wrd->finish;
        }
        $text_srcResult->delete("1.0","end");
        $text_srcResult->insert("1.0",$srchResult);
        $sth_qe->finish;
    }
    else {    # check all words in Oxford dictionary , pick all words which match regular search word out, show in editor
        @SrcResults = ();
        # input code here
        my $sth_1 = $dbh->prepare(q{select word,means from Oxford where length(word)>3});
        $sth_1->execute;
        my @row_1;
        while (@row_1 = $sth_1->fetchrow_array) {   	
            my $v_word = $row_1[0];
            my $v_means = decode("utf8", $row_1[1]);
            if ($v_word =~ m/$rgxParameter/g) {
                push @SrcResults, $v_word;
                $srchResult = $srchResult . $v_word . "   :" . $v_means . "\n";
                # print "Debug: $srchResult \n";
            }
        }
        $sth_1->finish;
        $text_srcResult->delete("1.0","end");
        $text_srcResult->insert("1.0",$srchResult);
        $text_srcResult->insert("1.0","No Results Found !") if($srchResult eq "") ;
    }
}

##
# add prefix and subfix of reuglar expression to input string, remove enter and new line characters
# 
sub addRgxFixes{
	my $para=shift;
	$para=~s/[\r\n]+//g;   ## remove enter and line end character 
    $para="\^".$para if($para !~/^\^/g);  ## add RGX begin character, if input not added
    $para=$para."\$" if($para !~/\$$/g);  ## add RGX end  character, if input not added
    return $para;
} 

##
# search word , get all other words belong to its class
#
sub wordSearch{
	my $wrd=$WrdStr;
	print "input= $wrd \n";
	#"?%" ,"%,?,%" ,"%,?"
	my $para1="$wrd\%";
	my $para2="\%,$wrd,\%";
	my $para3="\%,$wrd";
	my @results;
	# print "Debug: $para1 \n $para2 \n $para3 \n";
	#SQL=#  select relatesWords from relates where relates.relatesWords like ?  or relates.relatesWords like ?   or relates.relatesWords like ?
    my $sth_1=$dbh->prepare(q{select relatesWords from Relates where relatesWords like ?  or relatesWords like ?   or relatesWords like ?});
    $sth_1->execute($para1,$para2,$para3);
    my @row_1;
    while(@row_1=$sth_1->fetchrow_array){
    	my $v_relatesWords=$row_1[0];
    	$v_relatesWords=~s/,/\n/g;
    	push @results,$v_relatesWords."\n";
    }    
    $sth_1->finish;
    $text_srcResult->delete("1.0","end");
    $text_srcResult->insert("1.0",join("\r\n",@results));
    print "result=". join("\r\n",@results);
    $text_srcResult->insert("1.0","No Results Found !") if(scalar @results ==0) ;
    
}

##
# store results in text editor into DB
#
sub storeResults {
    my $result =encode("utf8",$text_srcResult->get("1.0", "end"));
    my @list;
    open my $filelike, "<", \$result or die $!;
    while (<$filelike>) {
        chomp;
        if (~/([a-z]+)\s+\:/g) {
            push @list, $1;
        }
    }
    pop @list;  ## remove the last word, becuase Tkx::Text will automatically add an end character 
    print "@list\n";

    #SQL=#  select searchStr,relatesWords,rel_num from Relates
    my $sth_searchStr =
      $dbh->prepare(q{select searchStr,relatesWords,rel_num from Relates where searchStr=?});
    $sth_searchStr->execute($RgxStr);
    my @row_1 = $sth_searchStr->fetchrow_array;
    if (scalar @row_1 > 0) {
    	# GUI Components Declaration 
    	my $response;
    	#    	Messagebox_save={can:mw,type:yesno,var:response,msg: The records already exist.Do you want to recover it ?}; 
    	$response= Tkx::tk___messageBox(-type =>"yesno", -message => " The records already exist.Do you want to recover it ?",-icon =>"question", -title => "null");
        
        if ($response eq "no") {  # yes  or no
            $sth_searchStr->finish;
            return;
        }
        else {
            #SQL=#  update Relates set relatesWords =?where searchStr=?
            my $upth_1 = $dbh->prepare(qq{update Relates set relatesWords =?,rel_num=? where searchStr=?})
              or die $dbh->errstr;
            $upth_1->execute(decode("utf8",join(",",@list)),scalar @list,$RgxStr);
            $dbh->commit;
            $upth_1->finish;
        }
    }
    else {

        #SQL=#  insert into Relates ( searchStr,relatesWords,rel_num) values(?,?,?);
        my $isth_1 =
          $dbh->prepare(qq{insert into Relates (searchStr,relatesWords,rel_num) values(?,?,?);})
          or die $dbh->errstr;
        $isth_1->execute($RgxStr, join(",", @list), scalar @list);
        $dbh->commit;
        $isth_1->finish;
    }
}
##
# batch search regulation express strings and get all search results insert into db
#
sub batchSearchInsert{
	my $batch_input=$text_batch->get("0.1","end");
	open BatchInput,"<", \$batch_input;  # open string variable input like open a file handle
	while(<BatchInput>){	
		$_=~s/[\"\']//g;  #remove  " or '		
		my $para=addRgxFixes($_);
		print "Input parameter=".$para."\n";
		if((index($para, "[")!=-1) && (index($para,"]") !=-1)){ # if contains [x..y], it means it require auto increase characters input as parameters
			if($para =~m/^(.*?)\[(.*?)\](.*?)$/g) {   # get strings match x..y
				my @res= split(/\.\./,$2);	
					for($res[0]..$res[1]){
						my $tmp_para=$1.$_.$3;
						print "Debug: get parameter: $tmp_para \n";
						searchOutRexStr($tmp_para) if(!isRecordExist($tmp_para));
					}
			}
		}else{
			searchOutRexStr($para) if(!isRecordExist($para));	
		}
		
	}
}
##
# check if the search record of the regular string already exists, return true if exists in DB   
#
sub isRecordExist{
	my $v_rgx=shift;
	my $sth_qe = $dbh->prepare(q{select relatesWords from Relates where searchStr like ?});
	
    # print "Debug:select relatesWords from Relates where searchStr like '$RgxStr' \n";
    $sth_qe->execute($v_rgx);
    my @row_qe = $sth_qe->fetchrow_array;
    # print "Debug: @row_qe \n";
    if (scalar(@row_qe) != 0) {return 1;}
    return 0;
}
##
# get regx string and search out result , return a string of search result
# this is only used for batch Search
#
sub searchOutRexStr{
	my $v_rgx=shift;
	    my @SrcResults = ();
        # input code here
        my $sth_1 = $dbh->prepare(q{select word,means from Oxford where length(word)>3});
        $sth_1->execute;
        my @row_1;
        while (@row_1 = $sth_1->fetchrow_array) {   	
            my $v_word = $row_1[0];
            my $v_means = decode("utf8", $row_1[1]); 
            if ($v_word =~ m/$v_rgx/g) {
                push @SrcResults, $v_word;
                # print "Debug: $v_word \n";
            }
        }
 	   #SQL=#  insert into Relates ( searchStr,relatesWords,rel_num) values(?,?,?);
 	   if(scalar @SrcResults !=0){
 	   	  my $isth_1 =
          $dbh->prepare(qq{insert into Relates (searchStr,relatesWords,rel_num) values(?,?,?);})
          or die $dbh->errstr;
        $isth_1->execute($v_rgx, join(",", @SrcResults), scalar @SrcResults);
        $dbh->commit;
        $isth_1->finish;
 	   }

}

##
# click mouse right button, when selected a word, it open a browser to search out word means page in bing dictionary
#  
sub rightClick_getWordMeans{
	my $range=$text_srcResult->tag_range("sel");  ## get range of selected words, "sel" is predefined tk variable
	my @r_set=split(" ",$range);   
	my $tmp=$text_srcResult->get("$r_set[0]","$r_set[1]");  ## change range to string which perl can recogonized
	print "range = $range ,selected = $tmp \n";
	`firefox -private -url //http://cn.bing.com/dict/?q=$tmp&go=submit&qs=bs`;
}
# GUI Components Declaration 
# A Frame Defined 
#frame_btns={can:mw,row:2,col:3,colspan:1}
#container1={type:MainWindow,name:mw}
#label_batchRgxInput={can:mw,txt:Batch input Regular expressions,row:2,col:1,colspan:1}
#text_batch={can:mw,height:7,width:10,mode:esnw,row:2,col:2,colspan:1}
#button_Go={can:frame_btns,txt:Go,row:1,col:3,colspan:1}
#text_srcResult={can:mw,height:40,width:20,mode:esnw,row:3,col:1,colspan:3}
#button_Store={can:frame_btns,txt:StoreResult,row:2,col:4,colspan:1}

