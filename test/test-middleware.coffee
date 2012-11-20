
PersonalHelpers = require("../index").Helpers
PersonalMid = require("../index").Middleware
PersonalScope = require("../index").Scope
PersonalOpt = require("../index").Options
PersonalApp = require("../index").App
crypto = require "crypto"
should = require "should"
url = require "url"

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
            PersonalOpt
                client_id: "clientid"
                client_secret: "client_secret"
                scope: scope
                update: false
                sandbox: true
            scope = new PersonalScope
                literal: "read_0135"
            req = 
                session: {}
                query: {}
                headers:
                    host: "localhost"
                protocol: "https"
                url: "/"
        it "should create session.personal if it doesn't exist", (done) ->
            next = (err) ->
                if err? then return done(err)
                if req.session?.personal? then done() else done(new Error "req.session.personal doesn't exist")
            PersonalMid req, {}, next
        it "should add state and redirect to session", (done) ->
            next = (err) ->
                if err? then return done(err)
                if req.session?.personal?.state? then return done() else return done(new Error "session.personal.state doesn't exist")
                if req.session?.personal?.redirect_uri? then done() else done(new Error "session.personal.redirect_uri doesn't exist")
            PersonalMid req, {}, next
        it "should create client if it has a valid session", (done) ->
            req.session.personal.access_token = "access"
            req.session.personal.refresh_token = "refresh"
            req.session.personal.expiration = new Date()
            next = (err) ->
                if err? then return done(err)
                if req.personal?.client? then done() else done(new Error "req.personal.client doesn't exist")
            PersonalMid req, {}, next
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
        it "should create auth_req_url helper", () ->
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
        it "should use provided callback_uri if present", () ->
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
