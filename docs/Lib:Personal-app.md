# personal-app.coffee

#### Classes
  
* [PersonalApp](#PersonalApp)
  
* [PersonalClient](#PersonalClient)
  
* [PersonalScope](#PersonalScope)
  


#### Functions
  
* [PersonalConnectOptions](#PersonalConnectOptions)
  
* [PersonalHelpers](#PersonalHelpers)
  
* [PersonalMiddleware](#PersonalMiddleware)
  



  Personal Node.js Library

MIT License




## Classes
  
### <a name="PersonalApp">[PersonalApp](PersonalApp)</a>
    
    
    
    
#### Instance Methods          
      
##### <a name="constructor">constructor(config)</a>

      
##### <a name="get_auth_request_url">get\_auth\_request\_url(options)</a>

      
##### <a name="get_access_token_auth">get\_access\_token\_auth(args, callback)</a>
Get the access token for Personal API access using authorization code flow
args:
            * code: string - code returned in querystring of callback url (required)
            * state: string - state parameter return from query string of callback url (required)
            * redirect_uri: redirect_uri from authorization request (required)
        callback: function - function(err, return_obj){console.log(return_obj.access_token);} (optional - may use returned promise instead)
        
        returns a promise whose resolution value is an object with the following properties
            * access_token: string - currently valid access token
            * refresh_token: string - token that may be used to refresh access token
            * expiration: date - time at which access token needs to be refreshed
        
      
    
    
  
### <a name="PersonalClient">[PersonalClient](PersonalClient)</a>
    
    
    
    
#### Instance Methods          
      
##### <a name="constructor">constructor(access_options)</a>
access_options:
    access_token:
    refresh_token:
    expiration: 

      
    
    
  
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

returns true if all permissions were successfully added, false if any permissions were invalid

rules: Either string in proper scope format (e.g., "read_0135,write_0135") or array of objects (e.g., [{read: '0135'},{write: '0136'}])"

      
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
Returnss the permissions as an array of strings.  Each string is suitable for use in the OAuth flow

      
##### <a name="to_s">to\_s()</a>
Returnss the permissions as a string in the format required for the Personal OAuth flow

      
##### <a name="toString">toString()</a>
Returnss the permissions as a string in the format required for the Personal OAuth flow

      
    
    
  



## Functions
  
### <a name="PersonalConnectOptions">PersonalConnectOptions(options)</a>
#Add all options to the connect/express options for the Personal library
#
#options:
#   client_id:
#   client_secret:
#   scope:
#   update: 
#   sandbox:

  
### <a name="PersonalHelpers">PersonalHelpers(app)</a>

  
### <a name="PersonalMiddleware">PersonalMiddleware(req, res, next)</a>

  

