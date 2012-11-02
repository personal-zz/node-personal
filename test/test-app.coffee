PersonalScope = require("../index").Scope
PersonalApp = require("../index").App
crypto = require "crypto"
qs = require "querystring"
http = require "http"
url = require "url"
require "should"

_are_colls_equiv = (arr1, arr2) ->
    to_return = true
    for item in arr1
        to_return = false if not (item in arr2)
    for item in arr2
        to_return = false if not (item in arr1)
    return to_return

describe "PersonalApp", () ->
    app = new PersonalApp
        client_id: "clientid"
        client_secret: "clientsecret"
        sandbox: true

    scope = new PersonalScope
        permissions: ['read']
        resources: ['0135']

    sample_state = crypto.randomBytes(32).toString('hex')
    sample_code = crypto.randomBytes(10).toString('hex')
    sample_redirect_uri = "http://localhost"

    describe "#get_auth_request_url", () ->
        auth_req_obj = app.get_auth_request_url
            redirect_uri: "http://localhost"
            scope: scope
            update: false
            sandbox: true

        url_obj = url.parse auth_req_obj.url, true

        redir_url_obj = url.parse url_obj.query.redirect_uri, true

        it "should set correct client_id", () ->
            url_obj.query.client_id.should.equal "clientid"
        it "should set correct host and path", () ->
            url_obj.host.should.equal "api-sandbox.personal.com"
            url_obj.pathname.should.equal "/oauth/authorize"
        it "should set correct response type", () ->
            url_obj.query.response_type.should.equal "code"
        it "should set correct redirect url", () ->
            redir_url_obj.protocol.should.equal "http:"
            redir_url_obj.host.should.equal "localhost"  
            url.format(redir_url_obj).should.equal auth_req_obj.redirect_uri
        it "should set correct scope", () ->
            url_obj.query.scope.should.equal "read_0135"
        it "should set correct update value", () ->
            url_obj.query.update.should.equal "false"
        it "should set a 32-byte state value", () ->
            redir_url_obj.query.state.length.should.equal 64
            auth_req_obj.state.should.equal redir_url_obj.query.state
    describe "#get_access_token_auth", () ->
        it "should reject empty code", (done) ->
            promise = app.get_access_token_auth
                state: sample_state
                redirect_uri: "http://localhost"
            promise.then (data) ->
                done(new Error "Did not reject empty code")
            , (err) ->
                done()
        it "should reject invalid code", (done) ->
            promise = app.get_access_token_auth
                state: sample_state
                redirect_uri: "http://localhost"
                code: "too short"
            promise.then (data) ->
                done(new Error "Did not reject invalid code")
            , (err) ->
                done()
        it "should reject empty redirect_uri", (done) ->
            promise = app.get_access_token_auth
                code: sample_code
                state: sample_state
            promise.then (data) ->
                done(new Error "Did not reject empty redirect_uri")
            , (err) ->
                done()
        it "should reject via callback argument", (done) ->
            app.get_access_token_auth
                code: sample_code
                state: sample_state
                , (err, data) ->
                    if err? then done() else done(new Error "Rejection not accomplished via callback")
        it "should return the proper access object", (done) ->
            soln = 
                access_token: "sampleaccesstoken"
                refresh_token: "samplerefreshtoken"
            test_app = new PersonalApp
                client_id: "clientid"
                client_secret: "clientsecret"
                test: true
            test_srv = http.createServer (req,res) ->
                body = ""
                if req.method != "POST"
                    test_srv.close()
                    done(new Error "POST not being used")
                req.on "data", (chunk) ->
                    body += chunk if chunk?
                req.on "end", ->
                    post_obj = qs.parse body
                    if !post_obj.grant_type? or post_obj.grant_type != "authorization_code" then done(new Error "Wrong grant type provided")
                    if !post_obj.code? or post_obj.code != sample_code then done(new Error "Wrong code provided")
                    if !post_obj.redirect_uri? or post_obj.redirect_uri != sample_redirect_uri then done(new Error "Wrong redirect URI")
                    if !post_obj.client_id? or post_obj.client_id != "clientid" then done(new Error "Wrong client_id")
                    if !post_obj.client_secret? or post_obj.client_secret != "clientsecret" then done(new Error "Wrong client secret")
                    res.writeHead 200, {'Content-Type': "application/json"}
                    res.end JSON.stringify 
                        access_token: soln.access_token
                        refresh_token: soln.refresh_token
                        expires_in: 3600
            test_srv.listen 7357
            promise = test_app.get_access_token_auth
                code: sample_code
                state: sample_state
                redirect_uri: sample_redirect_uri
            promise.then (data) ->
                if data.access_token == soln.access_token and data.refresh_token == data.refresh_token and data.expiration > Date.now()
                    done()
                else
                    console.err "access object: ", data
                    done(new Error "access object was not correct")
            , (err) ->
                test_srv.close()
                done(err)
