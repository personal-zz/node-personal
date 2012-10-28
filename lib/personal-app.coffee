###
# Personal Node.js Library
#
# MIT License
###

crypto = require "crypto"

class PersonalApp
    ###
    PersonalApp is the central class to the library.  Instantiate it to access the Personal API.
    ###
    
    constructor: (@config) ->
        ###
        config:
            client_id: string - <client id> (required)
            client_secret: string - <client secret> (required)
        ###
        @_state = {}
        @_access = {}
    
    get_auth_request_url: (options) ->
        ###
        Get the URL for sending a user to the authorization page

        options:
            redirect_uri: string - The callback URL that the user will return to after authorization (required)
            scope: PersonalScope - Object representing the scope for which you are requesting authorization (required)
            update: boolean - specifies if the selection UI dialog should be presented even if the 3rd party already has access to the requested resource(default: true)
            sandbox: boolean - uses sandbox if true, production otherwise (default: false)

        returns a url object, call url.format(<return value>) to get formatted URL string (see http://nodejs.org/api/url.html) 
        ###

        #add state param to redirect uri for the securitys
        state_param = crypto.randomBytes(32).toString('hex')
        redir_url_obj = url.parse options.redirect_uri, true
        redir_url_obj.search = undefined
        redir_url_obj.query.state = state_param
        @_state[state_param] = url.format(redir_url_obj)
        
        #create url object for user redirect
        if options.sandbox
            urlObj = url.parse("https://api-sandbox.personal.com/oauth/authorize", true)
        else
            urlObj = url.parse("https://api.personal.com/oauth/authorize", true)
        urlObj.search = undefined
        urlObj.query =
            client_id: @config.client_id
            response_type: "code"
            redirect_uri: @_state[state_param]
            scope: options.scope.to_s()
            update: (update == false ? false : true)
        return urlObj

    get_access_token_auth: (code, state, callback) ->
        ###
        Get the access token for Personal API access using authorization code flow

        code: string - code returned in querystring of callback url (required)
        state: string - state parameter return from query string of callback url (required)
        callback: function - function(access_token){console.log(access_token);} (required)
        ###

        #run post
        #place returned infos into @_access
        #run callback(access_token)


    get_client: (access_code) ->
        ###

        ###

class PersonalClient
    ###
    Client 
    ###

class PersonalScope
    ###
    Define the scope you need for authorization code OAuth flow
    ###
    
    #"static" vars
    _all_perms = ['read','write','create','grant']
    _re_temp_id = /^[0-9]{4}$/
    _re_temp_id.compile(_re_temp_id)

    _is_valid_template_id = (temp_id_str) ->
        return _re_temp_id.test temp_id_str

    _is_valid_permission_rule = (perm, resource) ->
        if _is_valid_template_id(resource) and (perm in _all_perms)
            return true
        switch resource
            when 'contacts', 'messages'
                return true if perm in ['read','write']
            when 'access'
                return true if perm == 'read'
            else return false
    
    constructor: (args) ->
        ###
        For literal scope (e.g., "read_0135,write_0136"), provide args.literal
        For cartesian product scope (e.g.,, (read,write)x(0135,0136)), provide args.permission and args.resources

        args:
            permissions: array of strings for permissions. Subset of ['read', 'write', 'create', 'grant'] (optional)
            resources: array of strings for resources to request, e.g. ['contacts','message','access','<4 digit template id>']
            literal: Either string in proper scope format (e.g., "read_0135,write_0135") or array of objects (e.g., [{read: '0135'},{write: '0136'}])"
        ###
        @_scope = {}
        for perm in _all_perms
            @_scope[perm] = []

        @add_perms_cprod args
        @add_perms_simple args.literal

    add_permission_str: (permission_string) ->
        ###
        Adds one rule to permission scope by string

        permission_string: String representation of rule (e.g., "read_0135")

        returns true upon success, false otherwise
        ###
        [name,resource] = permission_string.split "_"
        return @add_permission name, resource

    add_permission: (name, resource) ->
        ###
        Adds one rule to permission scope by name and resource

        rule: Either string representation of rule (e.g., "read_0135") or object representation (e.g., {read: '0135'})

        returns true upon success, false otherwise
        ###
        if _is_valid_permission_rule name, resource
            @_scope[name].push resource
            return true
        return false


    add_perms_simple: (rules) ->
        ###
        For literal scope (e.g., "read_0135,write_0136"), provide args.literal
        
        returns true if all permissions were successfully added, false if any permissions were invalid
        
        rules: Either string in proper scope format (e.g., "read_0135,write_0135") or array of objects (e.g., [{read: '0135'},{write: '0136'}])"
        ###
        to_return = true
        if Array.isArray rules
            for rule in rules
                for perm,res of rule
                    if not @add_permission perm, res
                        to_return = false
        
        else if typeof rules == "string"
            for rule in rules.split ","
                if not @add_permission_str rule
                    to_return = false
        else
            to_return = false
        return to_return

    add_perms_cprod: (args) ->
        ###
        Add cartesian product scope (e.g.,, (read,write)x(0135,0136))
        args:
            permissions: array of strings for permissions. Subset of ['read', 'write', 'create', 'grant']
            resources: array of strings for resources to request, e.g. ['contacts','message','access','<4 digit template id>']
        
        returns true if all permissions were successfully added, false if any permissions were invalid
        
        Example:
            pscope.add_perms_cprod({permissions: ['read','write'], resources: ['0135','contacts']})
            pscope.to_s() //"read_0135,read_contacts,write_0135,write_contacts"
        ###
        to_return = true

        if args.permissions? and Array.isArray(args.permissions) and args.resources? and Array.isArray(args.permissions)
            for perm in args.permissions
                for res in args.resources
                    if _is_valid_permission_rule perm, res
                        @_scope[perm].push res
                    else
                        to_return = false
        return to_return

    to_a: () ->
        ###
        Returnss the permissions as an array of strings.  Each string is suitable for use in the OAuth flow
        ###
        to_return = []
        for perm, temps of @_scope
            for temp in temps
                to_return.push "#{perm}_#{temp}"
        return to_return

    asArray: () ->
        ###
        Returnss the permissions as an array of strings.  Each string is suitable for use in the OAuth flow
        ###
        return @to_a()

    to_s: () ->
        ###
        Returnss the permissions as a string in the format required for the Personal OAuth flow
        ###
        return @to_a().join()

    toString: () ->
        ###
        Returnss the permissions as a string in the format required for the Personal OAuth flow
        ###
        return @to_s()

exports.PersonalApp = PersonalApp
exports.PersonalScope = PersonalScope
