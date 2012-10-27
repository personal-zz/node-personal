PersonalScope = require("../index").PersonalScope
require "should"

_are_colls_equiv = (arr1, arr2) ->
    to_return = true
    for item in arr1
        to_return = false if not (item in arr2)
    for item in arr2
        to_return = false if not (item in arr1)
    return to_return

describe "PersonalScope", () ->
    describe "#constructor", () ->
        it "should create a cartesian product of perms", () ->
            soln = ['read_0000','write_0000','read_9999','write_9999']
            scope = new PersonalScope
                permissions: ['read', 'write']
                resources: ['0000','9999']
            prod_arr = scope.to_a()
            prod_arr.length.should.equal 4
            _are_colls_equiv(soln,prod_arr).should.be.true
        it "should merge literal and cartesian product of perms", () ->
            soln = ['read_0000','write_0000','read_9999','write_9999','read_access','write_contacts','write_messages']
            scope = new PersonalScope
                permissions: ['read', 'write']
                resources: ['0000','9999']
                literal: 'read_access,write_contacts,write_messages'
            prod_arr = scope.to_a()
            prod_arr.length.should.equal 7
            _are_colls_equiv(soln,prod_arr).should.be.true
        it "should reject invalid template IDs", () ->
            scope = new PersonalScope
                permissions: ['read','write','create','grant']
                resources: ['1','12','123','12345','123456','1234567','1`2345678','123456789']
            scope.to_a().length.should.equal 0
    describe "#to_s", () ->
        it "should contain all permissions", () ->
            soln = ['read_0000','write_0000','read_9999','write_9999']
            scope = new PersonalScope
                permissions: ['read', 'write']
                resources: ['0000','9999']
            prod_str = scope.to_s()
            prod_arr = prod_str.split ","
            _are_colls_equiv(soln,prod_arr).should.be.true
