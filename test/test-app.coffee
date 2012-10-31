PersonalScope = require("../index").Scope
PersonalApp = require("../index").App
url = require "url"
crypto = require "crypto"
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
        it "should reject empty state", (done) ->
            promise = app.get_access_token_auth
                code: sample_code
                redirect_uri: "http://localhost"
            promise.then (data) ->
                done(new Error "Did not reject empty state")
            , (err) ->
                done()
        it "should reject invalid state", (done) ->
            promise = app.get_access_token_auth
                state: "too short"
                redirect_uri: "http://localhost"
                code: sample_code
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
