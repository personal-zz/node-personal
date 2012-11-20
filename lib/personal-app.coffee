###

#Personal Node.js Library

MIT License
###

#TODO: Treat secure pw and shared secret as separate entities

q = require "q"
url = require "url"
mime = require "mime"
http = require "http" #for unit tests ONLY
https = require "https"
crypto = require "crypto"
querystring = require "querystring"

#TODO: convert the following to _<uppercase> format
_api_path_prefix = "/api/v1"
_oauth_req_path = "/oauth/authorize"
_oauth_access_path = "/oauth/access_token"
_oauth_proto = "https" 
_test_proto = "http"
_test_hostname = "127.0.0.1"
_test_port = 7357

_BACKOFF_DELAY = 2000 #2s

_code_regex = /^[a-z0-9]{20}$/gi
_code_regex.compile _code_regex

_QPS_REGEX = /developer over qps/igm
_QPS_REGEX.compile _QPS_REGEX

#Helper fns
_http_req = (opts, proto_obj, data, res_enc, callback) ->
    deferred = q.defer()

    _handle_err = (err) ->
        if callback? then callback err
        deferred.reject err

    req = proto_obj.request opts, (res) ->
        if res_enc? then res.setEncoding res_enc
        json_res = ""
        res.on "data", (chunk) ->
            json_res += chunk
        res.on "end", () ->
            if @statusCode == 403 and _QPS_REGEX.test(json_res)
                return setTimeout _http_req, _BACKOFF_DELAY, opts, proto_obj, res_enc, callback
            if @statusCode != 200
                return _handle_err new Error("status #{@statusCode}\t#{json_res}")
            try
                return_obj = JSON.parse json_res
                callback null, return_obj if callback? and typeof callback == 'function'
                deferred.resolve return_obj
            catch e
                _handle_err e

    req.on "error", (e) ->
        _handle_err e
    req.write(data) if data?
    req.end()
    
    return deferred.promise

#Stuff for the standalone use case (used by express/connect functionality)
class PersonalApp
    ###
    PersonalApp is intended for a stand-alone (non-web server) app.  Instantiate it to access the Personal API.
    
    ###
    
    constructor: (config) ->
        ###
        PersonalApp constructor
        
            config:
                client_id: string - <client id> (required)
                client_secret: string - <client secret> (required)
                sandbox: boolean - use sandbox if true and production if false (default: false)
        ###
        @_config = config
        @_config.hostname = "#{if config.sandbox then "api-sandbox" else "api"}.personal.com"
        #if config.test == true then _test_proto and _test_hostname will be used

    get_auth_request_url: (options) ->
        ###
        Get the URL for sending a user to the authorization page

            options:
                redirect_uri: string - The callback URL that the user will return to after authorization (required)
                scope: PersonalScope - Object representing the scope for which you are requesting authorization (required)
                update: boolean - specifies if the selection UI dialog should be presented even if the 3rd party already has access to the requested resource(default: true)

            returns an object containing
                url: string - a formatted URL string (same formatted output as url.format() - see http://nodejs.org/api/url.html) 
                state: the state parameter in the redirect_uri
        ###

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
                protocol: _oauth_proto
                pathname: _oauth_req_path
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
        ###

        deferred = q.defer()
        
        #check for issues
        rejection = "Authorization code not provided" if (!args.code?) and !args.is_refresh
        rejection = "Invalid authorization code" if (!_code_regex.test(args.code)) and !args.is_refresh
        rejection = "Redirect URI not provided" if (!args.redirect_uri?) and !args.is_refresh
        rejection = "Refresh token not provided" if (!args.refresh_token?) and args.is_refresh == true
        rejection = "Access token not provided" if (!args.access_token?) and args.is_refresh == true
        if rejection?.length > 0
            if callback? then callback(new Error rejection)
            deferred.reject new Error(rejection)
            return deferred.promise

        #run post
        return_obj = {}
        #set settings whether this is refresh or not
        post_obj = 
            grant_type: if args.is_refresh == true then "refresh_token" else "authorization_code"
            client_id: @_config.client_id
            client_secret: @_config.client_secret
        https_opts = 
            hostname: if @_config.test then _test_hostname else @_config.hostname
            port: _test_port if @_config.test
            path: _oauth_access_path
            method: "POST"
            rejectUnauthorized: true
            headers:
                "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8"
        #account for difference between refresh and normal
        if args.is_refresh == true
            post_obj.refresh_token = args.refresh_token
            https_opts.headers["Authorization"] = "Bearer #{args.access_token}" 
        else 
            post_obj.code = args.code
            post_obj.redirect_uri = args.redirect_uri
        post_data = querystring.stringify post_obj
        https_opts.headers["Content-Length"] = post_data.length
        proto_obj = if @_config.test then http else https
        
        #run callback and return promise
        _http_req(https_opts, proto_obj, post_data, "utf8").then (res_obj) ->
            deferred.resolve 
                access_token: res_obj.access_token
                refresh_token: res_obj.refresh_token
                expiration: new Date(Date.now() + res_obj.expires_in*1000)
        .fail (err) -> deferred.reject err
        return deferred.promise

class PersonalClient
    ###
    Client for making calls to personal api 

    ###

    constructor: (@access_options) ->
        ###
        PersonalClient constructor

            access_options:
                client_id: string
                client_secret: string
                access_token: string - access token from oauth
                refresh_token: string - refresh token from oauth
                expiration: date - time at which access token expires
                sandbox: boolean - Whether to use api-sandbox (default: false)
        ###
        @access_options.hostname = "#{if @access_options.sandbox == true then 'api-sandbox' else 'api' }.personal.com"
        @access_options.expiration = new Date(@access_options.expiration)
        @_reg_events = 
            refresh_token: []

    bind: (event_name, callback) ->
        ###
        Register a callback to run when certain events happen

            event_name: string - Name of events
            callback: string - function(data){}

        Valid events and data:
            "refresh_token": Called when token is refreshed.  Data is:
                access_token: access token
                refresh_token: refresh_token
                expiration: Date of expiration
        ###
        if @_reg_events[event_name]? and typeof callback == 'function' then @_reg_events[event_name].push callback
        return true

    _fire_event: (event_name, data) ->
        if @_reg_events[event_name]?
            callback(data) for callback in @_reg_events[event_name]

    refresh: (callback) ->
        ###
        Performs a refresh on the access token.  Generally PersonalClient will take care of this for you, but this is provided in case manual refresh is desired
            
            callback: function - form of function(error){}, called when refresh is complete.  error is undefined on success (optional)

            returns a promise object
        ###
        deferred = q.defer()
        #perform refresh POST
        app = new PersonalApp @access_options
        app.get_access_token_auth
            refresh_token: @access_options.refresh_token
            access_token: @access_options.access_token
            is_refresh: true
        .then (data) =>
            try
                for own key,val of data
                    @access_options[key] = val 
                @access_options.expiration = new Date(@access_options.expiration)
                @_fire_event "refresh_token", @access_options
                deferred.resolve data
            catch e
                deferred.reject e
        ,(err) ->
            deferred.reject err
        return deferred.promise

    request: (options, callback) ->
        ###
        send request to the Personal API

            options: 
                path: string - everything after "/api/v1" in the path (required)
                method: string - "GET" "PUT" "POST" or "DELETE" (required)
                data: object - javascript object to send (optional)
            callback: function(err, data){} (optional)

            return a promise containing the parsed object returned from the server
        ###
        deferred = q.defer()
        do_request = (options) =>
            https_opts = 
                hostname: if @access_options.test then _test_hostname else @access_options.hostname
                port: _test_port if @access_options.test
                path: "#{_api_path_prefix}/#{options.path}?client_id=#{@access_options.client_id}"
                method: options.method
                headers:
                    "Content-Type": "application/json"
                    "Authorization": "Bearer #{@access_options.access_token}"
                    "Secure-Password": @access_options.client_secret
            proto_obj = if @access_options.test then http else https
            _http_req(https_opts, proto_obj, JSON.stringify(options.data)).then (res_obj) ->
                deferred.resolve res_obj
            .fail (err) -> deferred.reject err

        if @access_options.expiration < Date.now()
            @refresh().then ()-> 
                do_request(options)
            , (err) -> deferred.reject(err)
        else
            do_request options
        return deferred.promise

    upload_file: (gem_id, filename, buf) ->
        deferred = q.defer()
        do_request = () =>
            try
                https_opts = 
                    hostname: if @access_options.test then _test_hostname else @access_options.hostname
                    port: _test_port if @access_options.test
                    path: "/file?client_id=#{@access_options.client_id}&files[]=#{encodeURIComponent filename}&gem_id=#{encodeURIComponent gem_id}"
                    method: "POST"
                    headers:
                        "Content-Type": mime.lookup filename
                        "Content-Length": buf.toString('hex').length/2
                        "Authorization": "Bearer #{@access_options.access_token}"
                        "Secure-Password": @access_options.client_secret
                proto_obj = if @access_options.test then http else https
                _http_req(https_opts, proto_obj, buf).then (res_obj) ->
                    deferred.resolve res_obj
                .fail (err) -> deferred.reject err
            catch err
                deferred.reject err
    
        if @access_options.expiration < Date.now()
            @refresh().then ()-> 
                do_request()
            , (err) -> deferred.reject(err)
        else
            do_request()
        return deferred.promise


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
        
            rules: Either string in proper scope format (e.g., "read_0135,write_0135") or array of objects (e.g., [{read: '0135'},{write: '0136'}])"
        
            returns true if all permissions were successfully added, false if any permissions were invalid
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
        Returns the permissions as an array of strings.  Each string is suitable for use in the OAuth flow
        ###
        return @to_a()

    to_s: () ->
        ###
        Returns the permissions as a string in the format required for the Personal OAuth flow
        ###
        return @to_a().join()

    toString: () ->
        ###
        Returns the permissions as a string in the format required for the Personal OAuth flow
        ###
        return @to_s()

#Stuff for the connect/express use case
connect_opts = do ->
    _opts =
        update: true
        sandbox: false
    ret_val =
        get: (key) -> if key? then return _opts[key] else return _opts
        set: (key,val) -> 
            _opts[key] = val
            return _opts

connect_curr_req_url = do ->
    _url = "init_val"
    ret_val = 
        get: -> return _url
        set: (new_url) -> _url = new_url

PersonalConnectOptions = (options) ->
    ###
    Add all options to the connect/express options for the Personal library
    
        options:
           client_id: (required)
           client_secret: (required)
           scope: (required)
           update: boolean - (optional - default: true)
           sandbox: boolean - true to use sandbox, false otherwise (optional - default: false)
           callback_uri: string - override dynamic callback uri with something static (optional - default: dynamically created)
    ###
    PersonalConnectOptions[key] = val for key,val of options
    #connect_opts.set(key,val) for key,val of options

PersonalConnectOptions 
    update: true
    sandbox: false

PersonalHelpers = (app) ->
    ###
    Provides helpers for Express views

    To use:

        express = require("express");
        personal = require("personal");
        app = express();
        personal.Helpers(app);

    Helpers:

        auth_req_url() - provides the authorization request URL for starting the OAuth flow
    ###
    app.locals
        auth_req_url: -> return connect_curr_req_url.get()
            
PersonalMiddleware = (req, res, next) ->
    ###
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
    ###
    #put logout fn in the request
    req.personal =
        logout: () ->
            req.session?.personal = logged_in: false
    
    #check that we have session and init it
    return next(new Error "session middleware not loaded") if not req.session? 
    req.session.personal = {} if not req.session.personal?
    #req.personal.logout() if not req.personal? #<-- HUH?!
    sess = req.session.personal

    #we already have a valid session
    if sess.access_token? and sess.refresh_token? and sess.expiration?
        req.personal.logged_in = true
        req.personal.client = new PersonalClient
            client_id: connect_opts.get "client_id"
            client_secret: connect_opts.get "client_secret"
            access_token: sess.access_token
            refresh_token: sess.refresh_token
            expiration: sess.expiration
            redirect_uri: sess.redirect_uri
            sandbox: connect_opts.get "sandbox"
        return next()
    app = new PersonalApp connect_opts.get()

    #we are at the callback url
    if req.query.code? and req.query.state? and req.query.personal?
        if sess.state? and sess.state == req.query.state and sess.redirect_uri?
            #do access token stuff
            promise = app.get_access_token_auth
                code: req.query.code
                state: req.query.state
                redirect_uri: sess.redirect_uri
            promise.then (access_obj) ->
                for own key,val of access_obj
                    sess[key] = val 
                req.personal.client = new PersonalClient
                    client_id: connect_opts.get "client_id"
                    client_secret: connect_opts.get "client_secret"
                    access_token: sess.access_token
                    refresh_token: sess.refresh_token
                    expiration: sess.expiration
                    redirect_uri: sess.redirect_uri
                    sandbox: connect_opts.get "sandbox"
                req.personal.logged_in = true
                next()
            ,(err) ->
                next(err)
            promise.fin () ->
                sess.state = null
                #TODO: remove code, state, and personal from query (redirect)

            return
   
    #we need to create the url for login and auth
    if (not sess.state?) or (not sess.redirect_uri?)
        if connect_opts.get("callback_uri")?
            new_redir_uri = url.parse connect_opts.get("callback_uri"), true
        else
            new_redir_uri = url.parse "#{req.protocol}://#{req.headers.host}#{req.url}", true
        new_redir_uri.search = ""
        delete new_redir_uri.query.code
        new_redir_uri.query.personal = true
        auth_req_obj = app.get_auth_request_url
            scope: connect_opts.get "scope"
            update: connect_opts.get "update"
            sandbox: connect_opts.get "sandbox"
            redirect_uri: url.format new_redir_uri
        connect_curr_req_url.set auth_req_obj.url
        sess.req_url = auth_req_obj.url
        sess.state = auth_req_obj.state
        sess.redirect_uri = auth_req_obj.redirect_uri
    else
        connect_curr_req_url.set sess.req_url
    next()

#export stuff
exports.Client = PersonalClient
exports.Options = PersonalConnectOptions
exports.Helpers = PersonalHelpers
exports.Middleware = PersonalMiddleware
exports.App = PersonalApp
exports.Scope = PersonalScope
