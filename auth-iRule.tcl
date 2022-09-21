when ACCESS_PER_REQUEST_AGENT_EVENT priority 100 {

    log local0. "ID: [ACCESS::perflow get perflow.irule_agent_id]"
    
    set agent_id [ACCESS::perflow get perflow.irule_agent_id]
	switch -glob -- [string tolower $agent_id] {
  
        "post-header" {
            foreach aHeader [HTTP::header names] {
                log local0. "Post-Header $aHeader: [HTTP::header $aHeader]"
            }            
    
	    }
  
  		"get-bearer" {
            # check to see if the bearer token already has been called
            # and has not yet expired
            # if so, then store the token in the session table
            # if expired, removed token from session
            # therefore, if the session variable exists, then we have a valid token
            # if not, no session variable exists and we need to fire the HTTP Connector
            log local0. "in get-bearer"

            if { [ACCESS::perflow get perflow.custom ] eq "exists" } {
            
                # is it expired
                set now [clock seconds]
                if { $now > [ACCESS::session data get session.sba.token.expiry_time ]} {
                    log local0. "Token has expired, clearing out values"
                    ACCESS::perflow set perflow.scratchpad ""
                    ACCESS::session data set session.sba.token.expiry_time "0"
                    ACCESS::session data set session.sba.token.access_token ""
                    ACCESS::session data set session.sba.token.basic_auth ""
                    ACCESS::session data set session.sba.token.timestamp ""
                }
                else {
                     log local0. "Not expired"
                     log local0. "Token: [ACCESS::session data get session.sba.token.access_token]"
                     # ACCESS::perflow set perflow.scratchpad "exists" 
                }
            } else {
                # test to see if we have a Bearer Token coming to us
                log local0. "Check if Bearer exists [HTTP::header "Authorization"]"
                if { [string tolower [ HTTP::header "Authorization" ] ] starts_with "bearer" } {
                    ACCESS::perflow set perflow.custom "bearer-exists"
                    log local0. "Bearer Exists, bybassing minter"
                } else {
                    log local0. "Session basic_auth for HTTP Connector call"
                    ACCESS::session data set session.sba.token.basic_auth [substr [HTTP::header "Authorization"] 6]
                    ACCESS::perflow set perflow.custom [ACCESS::session data get session.sba.token.basic_auth]
                    log local0. "Basic Auth: [ACCESS::session data get session.sba.token.basic_auth]"
                }
            }
        }

        "store-bearer" {
            # once we make the HTTP Connector call, we need to store the values in the
            # session table
            # data from the HTTP Connector Call is stored in session.sba.connector.return as JSON
            log local0. "In Store-Bearer"
            set access_token ""
            set expiry_time 0 

            # uncomment these when subsession vars are available, v16 and higher
            # regexp -nocase -- {"access_token"\s?:\s?"(.*?)"} [ACCESS::session data get subsession.http_connector.body ] fullmatch access_token
            # regexp -nocase -- {"expiry_time"\s?:\s?"(.*?)"} [ACCESS::session data get subsession.http_connector.body ] fullmatch expiry_time

            #set access_token [string range $access_token 0 [string first "\"" $access_token] ]
            #set expiry_time [string range $expiry_time 0 [string first "\"" $expiry_time]]
            
            # remove when version greater than 15.1
            set access_token [ACCESS::session data get session.sba.token.pre16.access_token]
            set expiry_time [ACCESS::session data get session.sba.token.pre16.expiry_time]

            #log local0. "HTTP Connector Return [ACCESS::session data get session.sba.connector.return]"
            log local0. "Token: $access_token and expiry_time: $expiry_time"

            ACCESS::session data set session.sba.token.timestamp [clock clicks -milliseconds]
            ACCESS::session data set session.sba.token.basic_auth [substr [HTTP::header "Authorization"] 6]
            ACCESS::session data set session.sba.token.access_token $access_token
            ACCESS::session data set session.sba.token.expiry_time $expiry_time
            ACCESS::perflow set perflow.custom "exists"
            HTTP::header replace "Authorization" "Bearer $access_token"
        }
   }
}

when HTTP_REQUEST priority 100 {
    # use this for dumping out all of the headers to the logs, handy for debugging
    #foreach aHeader [HTTP::header names] {
    #    log local0. "Header $aHeader: [HTTP::header $aHeader]"
    #}

    # add in Clientless-Mode Header if we don't have a cookie and this is not a GET request
    if {[string tolower [HTTP::method ] ] ne "GET" } {
        HTTP::header replace "Clientless-Mode" "1"
    }

}

when HTTP_RESPONSE priority 100 {
    # strip out the Auth Header if it exists so we
    # don't expose the JWT token outside of the 
    # application server zone

    if { [HTTP::header exists "Authorization" ] } {
        HTTP::header remove "Authorization"
    }


}