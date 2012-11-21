
PersonalHelpers = require("../index").Helpers
PersonalMid = require("../index").Middleware
PersonalScope = require("../index").Scope
PersonalOpt = require("../index").Options
PersonalApp = require("../index").App
crypto = require "crypto"
should = require "should"
http = require "http"
url = require "url"
qs = require "querystring"

_are_colls_equiv = (arr1, arr2) ->
    to_return = true
    for item in arr1
        to_return = false if not (item in arr2)
    for item in arr2
        to_return = false if not (item in arr1)
    return to_return

describe "Personal Connect/Express Integration\t", () ->
    describe "PersonalOptions\t", () ->
        it "should contain correct default values", () ->
            PersonalOpt.update.should.be.true
            PersonalOpt.sandbox.should.be.false
        it "should update existing values", () ->
            PersonalOpt 
                update: false
                sandbox: true
            PersonalOpt.update.should.be.false
            PersonalOpt.sandbox.should.be.true
        it "should merge new key/values into itself", () ->
            PersonalOpt 
                client_id: 'somesuch'
                client_secret: 'othersuch'
            PersonalOpt.update.should.be.false
            PersonalOpt.sandbox.should.be.true
            PersonalOpt.client_id.should.equal 'somesuch'
            PersonalOpt.client_secret.should.equal 'othersuch'
    describe "PersonalMiddleware\t", () ->
        [req,scope] = [null,null]
        beforeEach () ->
            scope = new PersonalScope
                literal: "read_0135"
            PersonalOpt
                client_id: "clientid"
                client_secret: "client_secret"
                scope: scope
                update: false
                sandbox: true
            req = 
                session: {}
                query: {}
                headers:
                    host: "localhost"
                protocol: "https"
                url: "/"
        it "should create session.personal if it doesn't exist", () ->
            next = (err) ->
                should.not.exist err
                req.session.personal.should.be.ok
            PersonalMid req, {}, next
        it "should add state and redirect to session", () ->
            next = (err) ->
                should.not.exist err
                req.session.personal.state.should.be.a('string').and.have.length 64
                redir_url_obj = url.parse req.session.personal.redirect_uri, true
                redir_url_obj.protocol.should.equal 'https:'
                redir_url_obj.hostname.should.equal 'localhost'
                redir_url_obj.query.personal.should.equal 'true'
                redir_url_obj.query.state.should.equal req.session.personal.state
            PersonalMid req, {}, next
        it "should create client if it has a valid session", () ->
            req.session.personal = {}
            req.session.personal.access_token = "access"
            req.session.personal.refresh_token = "refresh"
            req.session.personal.expiration = new Date()
            next = (err) ->
                should.not.exist err
                req.personal.client.should.be.ok
                req.personal.client._reg_events.should.be.ok
                req.personal.client.access_options.access_token.should.equal "access"
                req.personal.client.access_options.refresh_token.should.equal "refresh"
                req.personal.client.access_options.expiration.should.equal req.session.personal.expiration
                req.personal.logged_in.should.be.true
                req.personal.logout.should.be.a "function"
            PersonalMid req, {}, next

        test_srv = close: ->
        after ->
            test_srv.close()
        it "should get an access code properly", (done) ->
            PersonalOpt
                test: true
            soln = 
                access_token: "at"
                refresh_token: "rt"
                expires_in: 3600
            req.session.personal = {}
            req.session.personal.redirect_uri = "http://localhost"
            req.query.state = req.session.personal.state = crypto.randomBytes(32).toString('hex')
            req.query.personal = true
            req.query.code = "5w8z42x4e66d6dv8vymp"
            req.query.other_qs_param = true
            req.path = "/"
            call_count = 0
            test_srv = http.createServer (req_in_srv,res_in_srv) ->
                if ++call_count >= 2 
                    test_srv.close()
                    return done new Error("access token requested multiple times")
                body=""
                try
                    if req_in_srv.method != "POST"
                        test_srv.close()
                        return done(new Error "Trying to get access token with http verb #{req.method}")
                    if req_in_srv.headers["content-type"].split(";")[0] != "application/x-www-form-urlencoded"
                        test_srv.close()
                        return done new Error("Content type incorrect - #{req.headers["Content-Type"]}")
                catch err
                    return done(err)
                req_in_srv.on "data", (chunk) ->
                    body += chunk if chunk?
                req_in_srv.on "end", ->
                    post_obj = qs.parse body
                    if post_obj.grant_type != "authorization_code" then done new Error("Incorrect grant type - #{post_obj.grant_type}")
                    if post_obj.code != req.query.code then done new Error("Incorrect code - #{post_obj.code}")
                    if post_obj.redirect_uri != req.session.personal.redirect_uri then done new Error("Incorrect redirect_uri - #{redirect_uri}")
                    if post_obj.client_id != "clientid" then done new Error("Wrong client ID - #{post_obj.client_id}")
                    if post_obj.client_secret != "client_secret" then done new Error("Wrong client secret - #{post_obj.client_secret}")
                    res_in_srv.writeHead 200, {"Content-Type": "application/json"}
                    res_in_srv.end JSON.stringify soln
                    
            test_srv.listen 7357
            next = (err) ->
                test_srv.close()
                done(err) if err?
            res = 
                redirect: (_path) ->
                    try
                        sess = req.session.personal
                        if _path != "/other_qs_param=true" then done new Error("Incorrect redirect path - #{_path}")
                        if sess.state? then done new Error("req.session.personal.state should be undefined")
                        if sess.redirect_uri != "http://localhost" then done new Error("Incorrect redirect_uri - #{sess.redirect_uri}")
                        if sess.access_token != "at" then done new Error("wrong access token - #{sess.access_token}")
                        if sess.refresh_token != "rt" then done new Error("wrong refresh token - #{sess.refresh_token}")
                        if req.personal.logged_in != true then done new Error("req.personal.logged_in not true")
                        if req.personal.client.access_options.redirect_uri != "http://localhost"
                            done new Error("Incorrect redirect_uri in personal.client - #{sess.redirect_uri}")
                        if req.personal.client.access_options.access_token != "at" 
                            done new Error("wrong access token in personal.client - #{sess.access_token}")
                        if req.personal.client.access_options.refresh_token != "rt"
                            done new Error("wrong refresh token in personal.client - #{sess.refresh_token}")
                        done()
                    catch err
                        done err
            PersonalMid req, res, next


    describe "PersonalHelpers\t", () ->
        [app, helpers, req, scope] = [null, null, null, null]
        beforeEach () ->
            scope = new PersonalScope
                literal: "read_0135"
            req = 
                session: {}
                query: {}
                headers:
                    host: "localhost"
                protocol: "https"
                url: "/"
            PersonalOpt
                client_id: "clientid"
                client_secret: "client_secret"
                scope: scope
                update: false
                sandbox: true
            app = 
                locals: (obj) ->
                    app.locals[key] = val for key,val of obj
            helpers = PersonalHelpers(app)
        it "should create auth_req_url helper", ->
            next = (err) ->
                if err? then return done(err)
                should.not.exist err
                auth_url_obj = url.parse app.locals.auth_req_url(), true
                redir_url_obj = url.parse auth_url_obj.query.redirect_uri, true
                redir_url_obj.protocol.should.equal 'https:'
                redir_url_obj.hostname.should.equal 'localhost'
                redir_url_obj.query.personal.should.equal 'true'
                redir_url_obj.query.state.should.be.a('string').and.have.length 64
            PersonalMid req, {}, next
        it "should use provided callback_uri if present", ->
            PersonalOpt callback_uri: "http://www.host.com"
            next = (err) ->
                should.not.exist err
                auth_url_obj = url.parse app.locals.auth_req_url(), true
                redir_url_obj = url.parse auth_url_obj.query.redirect_uri, true
                redir_url_obj.protocol.should.equal 'http:'
                redir_url_obj.hostname.should.equal 'www.host.com'
                redir_url_obj.query.personal.should.equal 'true'
                redir_url_obj.query.state.should.be.a('string').and.have.length 64
            PersonalMid req, {}, next
