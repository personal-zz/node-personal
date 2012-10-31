PersonalScope = require("../index").Scope
PersonalApp = require("../index").App
PersonalMid = require("../index").Middleware
PersonalOpt = require("../index").Options
PersonalHelpers = require("../index").Helpers
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

describe "Personal Connect/Express Integration", () ->
    scope = new PersonalScope
        literal: "read_0135"
    PersonalOpt
        client_id: "clientid"
        client_secret: "client_secret"
        scope: scope
        update: false
        sandbox: true
    req_temp = 
        session: {}
        query: {}
        headers:
            host: "localhost"
        protocol: "https"
        url: "/"
    describe "PersonalMiddleware", () ->
        it "should create session.personal if it doesn't exist", (done) ->
            req = {}
            req[key] = val for key,val of req_temp
            next = (err) ->
                if err? then return done(err)
                if req.session?.personal? then done() else done(new Error "req.session.personal doesn't exist")
            PersonalMid req, {}, next
        it "should add state and redirect to session", (done) ->
            req = {}
            req[key] = val for key,val of req_temp
            next = (err) ->
                if err? then return done(err)
                if req.session?.personal?.state? then return done() else return done(new Error "session.personal.state doesn't exist")
                if req.session?.personal?.redirect_uri? then done() else done(new Error "session.personal.redirect_uri doesn't exist")
            PersonalMid req, {}, next
        it "should create client if it has a valid session", (done) ->
            req = {}
            req[key] = val for key,val of req_temp
            req.session.personal.access_token = "access"
            req.session.personal.refresh_token = "refresh"
            req.session.personal.expiration = new Date()
            next = (err) ->
                if err? then return done(err)
                if req.personal?.client? then done() else done(new Error "req.personal.client doesn't exist")
            PersonalMid req, {}, next
    describe "PersonalHelpers", () ->
        it "should create auth_req_url helper", (done) ->
            app = 
                locals: (obj) ->
                    app.locals[key] = val for key,val of obj
            helpers = PersonalHelpers(app)

            req = {}
            req[key] = val for key,val of req_temp
            next = (err) ->
                if err? then return done(err)
                if !app.locals?.auth_req_url? then return done(new Error "auth_req_url does not exist")
                #this could be ALOT better
                if app.locals.auth_req_url() != "" then done() else done(new Error "invalid auth_req_url")
            PersonalMid req, {}, next
