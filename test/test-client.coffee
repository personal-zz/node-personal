
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

describe "Personal Client\t", () ->
    test_srv = close: ->
    beforeEach ->
        #TODO: create test server
        test_srv.close()
    
    it "should initialize correctly"
    it "should fire events"
    it "should refresh an expired token"
    it "should properly format requests"
    it "should use secure password if provided"
    it "should properly upload files"
