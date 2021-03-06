// Generated by CoffeeScript 1.4.0
(function() {
  var PersonalApp, PersonalHelpers, PersonalMid, PersonalOpt, PersonalScope, crypto, http, qs, should, url, _are_colls_equiv,
    __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  PersonalHelpers = require("../index").Helpers;

  PersonalMid = require("../index").Middleware;

  PersonalScope = require("../index").Scope;

  PersonalOpt = require("../index").Options;

  PersonalApp = require("../index").App;

  crypto = require("crypto");

  should = require("should");

  http = require("http");

  url = require("url");

  qs = require("querystring");

  _are_colls_equiv = function(arr1, arr2) {
    var item, to_return, _i, _j, _len, _len1;
    to_return = true;
    for (_i = 0, _len = arr1.length; _i < _len; _i++) {
      item = arr1[_i];
      if (!(__indexOf.call(arr2, item) >= 0)) {
        to_return = false;
      }
    }
    for (_j = 0, _len1 = arr2.length; _j < _len1; _j++) {
      item = arr2[_j];
      if (!(__indexOf.call(arr1, item) >= 0)) {
        to_return = false;
      }
    }
    return to_return;
  };

  describe("Personal Client\t", function() {
    var test_srv;
    test_srv = {
      close: function() {}
    };
    beforeEach(function() {
      return test_srv.close();
    });
    it("should initialize correctly");
    it("should fire events");
    it("should refresh an expired token");
    it("should properly format requests");
    it("should use secure password if provided");
    return it("should properly upload files");
  });

}).call(this);
