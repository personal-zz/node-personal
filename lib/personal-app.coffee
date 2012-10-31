###
Personal Node.js Library

MIT License
###

q = require "q"
url = require "url"
https = require "https"
crypto = require "crypto"
querystring = require "querystring"

oauth_req_path = "/oauth/authorize"
oauth_access_path = "/oauth/access_token"
oauth_proto = "https" 

code_regex = /^[a-z0-9]{20}$/gi
code_regex.compile code_regex

###
Provides the facilities to use the Personal API outside the request/response paradigm
###
class PersonalApp
    ###
    @param config [Object] configuration options for the app
    @option config [String] client_id <client id> (required)
    @option config [String] client_secret <client secret> (required)
    @option config [Boolean] sandbox use sandbox if true and production if false (default: false)
    ###
    constructor: (config) ->
        @_config = config
        @_config.hostname = "#{if config.sandbox then "api-sandbox" else "api"}.personal.com"
    
    ###
    Get the URL for sending a user to the authorization page

    @param options [Object]
    @option options [String] redirect_uri The callback URL that the user will return to after authorization (required)
    @option options [PersonalScope] scope Object representing the scope for which you are requesting authorization (required)
    @option options [Boolean] update specifies whether the authorization UI dialog is presented when the app already has access to the  resource(default: true)

    returns an object containing
        url: string - a formatted URL string (same formatted output as url.format() - see http://nodejs.org/api/url.html) 
        state: the state parameter in the redirect_uri
    ###
    get_auth_request_url: (options) ->
        #add state param to redirect uri for the securitys
        state_param = crypto.randomBytes(32).toString('hex')
        redir_url_obj = url.parse options.redirect_uri, true
        redir_url_obj.search = undefined
        redir_url_obj.query.state = state_param
        redir_url = url.format redir_url_obj

        #create url object for user redirect
        return_obj = 
            state: state_param
            redirect_uri: redir_url
            url: url.format
                hostname: @_config.hostname
                protocol: oauth_proto
                pathname: oauth_req_path
                query:
                    client_id: @_config.client_id
                    response_type: "code"
                    redirect_uri: redir_url
                    scope: options.scope.to_s()
                    update: (if options.update == false then false else true)

    get_access_token_auth: (args, callback) ->
        ###
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
        ###

        deferred = q.defer()
        
        #check for issues
        rejection = "Authorization code not provided" if !args.code? 
        rejection = "Invalid authorization code" if !code_regex.test(args.code)     
        rejection = "State parameter not provided" if !args.state? 
        rejection = "Invalid state parameter" if args.state?.length != 64
        rejection = "Redirect URI not provided" if !args.redirect_uri?
        if rejection?.length > 0
            if callback? then callback(new Error rejection)
            deferred.reject new Error(rejection)
            return deferred.promise

        #run post
        return_obj = {}
        post_data = querystring.stringify
            grant_type: "authorization_code"
            code: args.code
            client_id: @_options.client_id
            client_secret: @_options.client_secret
            redirect_uri: args.redirect_uri
        https_opts = 
            hostname: @_config.hostname
            path: oauth_access_path
            method: "POST"
            rejectUnauthorized: true
            headers:
                "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8"
                "Content-Length": post_data.length
        req = https.request https_opts, (res) ->
            res.setEncoding "utf8"
            json_res = ""
            res.on "data", (chunk) ->
                json_res += chunk
            res.on "end", (chunk) ->
                json_res += chunk
                res_obj = JSON.parse json_res
                return_obj =
                    access_token: res_obj.access_token
                    refresh_token: res_obj.refresh_token
                    expiration: new Date(Date.now() + expires_in*1000)

        req.on "error", (e) ->
            if callback? then callback(e)
            deferred.reject e
        req.write post_data
        req.end()
        
        #run callback and return promise
        if typeof callback == 'function'
            callback(null, return_obj)
        return deferred.promise

class PersonalClient
    ###
    Client 
    ###

    constructor: (access_options) ->
        ###
        access_options:
            access_token:
            refresh_token:
            expiration: 
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

#Stuff for the connect/express use case
connect_opts = 
    update: true
    sandbox: false

connect_curr_req_url = do ->
    _url = "init_val"
    ret_val = 
        get: -> return _url
        set: (new_url) -> _url = new_url

PersonalConnectOptions = (options) ->
    ###
    #Add all options to the connect/express options for the Personal library
    #
    #options:
    #   client_id:
    #   client_secret:
    #   scope:
    #   update: 
    #   sandbox:
    ###
    connect_opts[key] = val for key,val of options

PersonalHelpers = (app) ->
    app.locals
        auth_req_url: -> return connect_curr_req_url.get()
            
PersonalMiddleware = (req, res, next) ->
    #put logout fn in the request
    req.personal =
        logout: () ->
            req.session?.personal = logged_in: false
    
    #check that we have session and init it
    return next(new Error "session middleware not loaded") if not req.session? 
    req.session.personal = {} if not req.session.personal?
    req.personal.logout() if not req.personal?
    sess = req.session.personal

    #we already have a valid session
    if sess.access_token? and sess.refresh_token? and sess.expiration?
        req.personal.logged_in = true
        req.personal.client = new PersonalClient
            access_token: sess.access_token
            refresh_token: sess.refresh_token
            expiration: sess.expiration
        return next()
    app = new PersonalApp connect_opts

    #we are at the callback url
    if req.query.code? and req.query.state? and req.query.personal?
        if sess.state? and sess.state == req.query.state and sess.redirect_uri?
            #do access token stuff
            promise = app.get_access_token_auth
                code: req.query.code
                state: req.query.state
                redirect_url: sess.redirect_url
            promise.then (access_obj) ->
                sess[key] = val for key,val of access_obj
                sess.client = new PersonalClient access_obj
                next()
            ,(err) ->
                next(err)
            return
    
    #we need to create the url for login and auth
    new_redir_uri = url.parse "#{req.protocol}://#{req.headers.host}#{req.url}", true
    new_redir_uri.search = ""
    new_redir_uri.query.personal = true
    auth_req_obj = app.get_auth_request_url
        scope: connect_opts.scope
        update: connect_opts.update
        sandbox: connect_opts.sandbox
        redirect_uri: url.format new_redir_uri
    connect_curr_req_url.set auth_req_obj.url
    #    console.log connect_curr_req
    sess.state = auth_req_obj.state
    sess.redirect_uri = auth_req_obj.redirect_uri
    next()

#export stuff
exports.Options = PersonalConnectOptions
exports.Helpers = PersonalHelpers
exports.Middleware = PersonalMiddleware
exports.App = PersonalApp
exports.Scope = PersonalScope
