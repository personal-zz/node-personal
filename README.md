#node-personal [![Build Status](https://secure.travis-ci.org/mike-spainhower/node-personal.png?branch=master)](https://travis-ci.org/mike-spainhower/node-personal)

##Overview

__NodeJS library for Personal Web API__

[Personal Developer Site](http://developer.personal.com)

###Install

stub

###Use

stub

###Contribute

stub

##API Docs

# personal-app.coffee

#### Classes
  
* [PersonalApp](#PersonalApp)
  
* [PersonalClient](#PersonalClient)
  
* [PersonalScope](#PersonalScope)
  


#### Functions
  
* [\_http\_req](#_http_req)
  
* [PersonalConnectOptions](#PersonalConnectOptions)
  
* [PersonalHelpers](#PersonalHelpers)
  
* [PersonalMiddleware](#PersonalMiddleware)
  



  #Personal Node.js Library

MIT License




## Classes
  
### <a name="PersonalApp">[PersonalApp](PersonalApp)</a>
    
    
    
    
#### Instance Methods          
      
##### <a name="constructor">constructor(config)</a>
PersonalApp constructor

    config:
        client_id: string - <client id> (required)
        client_secret: string - <client secret> (required)
        sandbox: boolean - use sandbox if true and production if false (default: false)

      
##### <a name="get_auth_request_url">get\_auth\_request\_url(options)</a>
Get the URL for sending a user to the authorization page

    options:
        redirect_uri: string - The callback URL that the user will return to after authorization (required)
        scope: PersonalScope - Object representing the scope for which you are requesting authorization (required)
        update: boolean - specifies if the selection UI dialog should be presented even if the 3rd party already has access to the requested resource(default: true)

    returns an object containing
        url: string - a formatted URL string (same formatted output as url.format() - see http://nodejs.org/api/url.html) 
        state: the state parameter in the redirect_uri

      
##### <a name="get_access_token_auth">get\_access\_token\_auth(args, callback)</a>
Get the access token for Personal API access using authorization code flow

    args:
        code: string - code returned in querystring of callback url (or refresh_token if refreshing) (required if is_refresh=false)
        redirect_uri: redirect_uri from authorization request (required if is_refresh=false)
        is_refresh: boolean - whether this is a token refresh (optional - default: false)
        refresh_token: string - refresh token (required if is_refresh=true)
        access_token: string - access token (required if is_refresh=true)

    callback: function - function(err, return_obj){console.log(return_obj.access_token);} (optional - may use returned promise instead)

    returns a promise whose resolution value is an object with the following properties
        access_token: string - currently valid access token
        refresh_token: string - token that may be used to refresh access token
        expiration: date - time at which access token needs to be refreshed

      
    
    
  
### <a name="PersonalClient">[PersonalClient](PersonalClient)</a>
    
    
    
    
#### Instance Methods          
      
##### <a name="constructor">constructor(@access_options)</a>
PersonalClient constructor

    access_options:
        client_id: string
        client_secret: string
        client_password: string - if you have changed your client password, provide it (optional)
        access_token: string - access token from oauth
        refresh_token: string - refresh token from oauth
        expiration: date - time at which access token expires
        sandbox: boolean - Whether to use api-sandbox (default: false)

      
##### <a name="bind">bind(event_name, callback)</a>
Register a callback to run when certain events happen

    event_name: string - Name of events
    callback: string - function(data){}

Valid events and data:
    "refresh_token": Called when token is refreshed.  Data is:
        access_token: access token
        refresh_token: refresh_token
        expiration: Date of expiration

      
##### <a name="refresh">refresh(callback)</a>
Performs a refresh on the access token.  Generally PersonalClient will take care of this for you, but this is provided in case manual refresh is desired
    
    callback: function - form of function(error){}, called when refresh is complete.  error is undefined on success (optional)

    returns a promise object

      
##### <a name="request">request(options, callback)</a>
send request to the Personal API

    options: 
        path: string - everything after "/api/v1" in the path (required)
        method: string - "GET" "PUT" "POST" or "DELETE" (required)
        data: object - javascript object to send (optional)
    callback: function(err, data){} (optional)

    return a promise containing the parsed object returned from the server

      
##### <a name="upload_file">upload\_file(gem_id, filename, buf)</a>

      
    
    
  
### <a name="PersonalScope">[PersonalScope](PersonalScope)</a>
    
    Define the scope you need for authorization code OAuth flow


    
    
#### Instance Methods          
      
##### <a name="constructor">constructor(args)</a>
For literal scope (e.g., "read_0135,write_0136"), provide args.literal

For cartesian product scope (e.g.,, (read,write)x(0135,0136)), provide args.permission and args.resources

    args:
        permissions: array of strings for permissions. Subset of ['read', 'write', 'create', 'grant'] (optional)
        resources: array of strings for resources to request, e.g. ['contacts','message','access','<4 digit template id>']
        literal: Either string in proper scope format (e.g., "read_0135,write_0135") or array of objects (e.g., [{read: '0135'},{write: '0136'}])"

      
##### <a name="add_permission_str">add\_permission\_str(permission_string)</a>
Adds one rule to permission scope by string

    permission_string: String representation of rule (e.g., "read_0135")

    returns true upon success, false otherwise

      
##### <a name="add_permission">add\_permission(name, resource)</a>
Adds one rule to permission scope by name and resource

    rule: Either string representation of rule (e.g., "read_0135") or object representation (e.g., {read: '0135'})

    returns true upon success, false otherwise

      
##### <a name="add_perms_simple">add\_perms\_simple(rules)</a>
For literal scope (e.g., "read_0135,write_0136"), provide args.literal

    rules: Either string in proper scope format (e.g., "read_0135,write_0135") or array of objects (e.g., [{read: '0135'},{write: '0136'}])"

    returns true if all permissions were successfully added, false if any permissions were invalid

      
##### <a name="add_perms_cprod">add\_perms\_cprod(args)</a>
Add cartesian product scope (e.g.,, (read,write)x(0135,0136))

    args:
        permissions: array of strings for permissions. Subset of ['read', 'write', 'create', 'grant']
        resources: array of strings for resources to request, e.g. ['contacts','message','access','<4 digit template id>']

    returns true if all permissions were successfully added, false if any permissions were invalid

Example:
     
    pscope.add_perms_cprod({permissions: ['read','write'], resources: ['0135','contacts']})
    pscope.to_s() //"read_0135,read_contacts,write_0135,write_contacts"

      
##### <a name="to_a">to\_a()</a>
Returnss the permissions as an array of strings.  Each string is suitable for use in the OAuth flow

      
##### <a name="asArray">asArray()</a>
Returns the permissions as an array of strings.  Each string is suitable for use in the OAuth flow

      
##### <a name="to_s">to\_s()</a>
Returns the permissions as a string in the format required for the Personal OAuth flow

      
##### <a name="toString">toString()</a>
Returns the permissions as a string in the format required for the Personal OAuth flow

      
    
    
  



## Functions
  
### <a name="_http_req">\_http\_req(opts, proto_obj, data, res_enc, callback)</a>

  
### <a name="PersonalConnectOptions">PersonalConnectOptions(options)</a>
Add all options to the connect/express options for the Personal library

    options:
       client_id: (required)
       client_secret: (required)
       scope: (required)
       update: boolean - (optional - default: true)
       sandbox: boolean - true to use sandbox, false otherwise (optional - default: false)
       callback_uri: string - override dynamic callback uri with something static (optional - default: dynamically created)

    returns its full options object

  
### <a name="PersonalHelpers">PersonalHelpers(app)</a>
Provides helpers for Express views

To use:

    express = require("express");
    personal = require("personal");
    app = express();
    personal.Helpers(app);

Helpers:

    auth_req_url() - provides the authorization request URL for starting the OAuth flow

  
### <a name="PersonalMiddleware">PersonalMiddleware(req, res, next)</a>
Connect middleware for using the Personal API

To use (connect):
    
    example

To use (express):
    
    express = require("express");
    personal = require("node-personal");
    personal.Options({<see PersonalConnectOptions>});
    app = express()
    app.configure(function(){
        //various configuration
        express.use(express.session(<config>));
        express.use(personal.Middleware);
    })

req.session.personal.req_url will now have the appropriate URL for sending users to the authorization page

Once users return from the authorization page, req.personal.client will be a working PersonalClient

  


#Change Log

## Version 0.1.6 - November 20, 2012

- Added ability to use a changed Secure Password ([@mike][]) 
- Fixed large bug in Personal login management ([@mike][])
- Ficed large bug in PersonalConnectOptions ([@mike][])
- Fixed a variety of smaller bugs ([@mike][])
- Added fuller suite of test cases ([@mike][])

## Version 0.1.0 - October 31, 2012

- Initial release to celebrate Halloween. ([@mike][])

[@mike]: https://github.com/mike-spainhower

#License

## MIT License

Copyright (c) 2012 Personal

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.
