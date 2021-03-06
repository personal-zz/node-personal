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

  describe("Personal Connect/Express Integration\t", function() {
    describe("PersonalOptions\t", function() {
      it("should contain correct default values", function() {
        PersonalOpt.update.should.be["true"];
        return PersonalOpt.sandbox.should.be["false"];
      });
      it("should update existing values", function() {
        PersonalOpt({
          update: false,
          sandbox: true
        });
        PersonalOpt.update.should.be["false"];
        return PersonalOpt.sandbox.should.be["true"];
      });
      return it("should merge new key/values into itself", function() {
        PersonalOpt({
          client_id: 'somesuch',
          client_secret: 'othersuch'
        });
        PersonalOpt.update.should.be["false"];
        PersonalOpt.sandbox.should.be["true"];
        PersonalOpt.client_id.should.equal('somesuch');
        return PersonalOpt.client_secret.should.equal('othersuch');
      });
    });
    describe("PersonalMiddleware\t", function() {
      var req, scope, test_srv, _ref;
      _ref = [null, null], req = _ref[0], scope = _ref[1];
      beforeEach(function() {
        scope = new PersonalScope({
          literal: "read_0135"
        });
        PersonalOpt({
          client_id: "clientid",
          client_secret: "client_secret",
          scope: scope,
          update: false,
          sandbox: true
        });
        return req = {
          session: {},
          query: {},
          headers: {
            host: "localhost"
          },
          protocol: "https",
          url: "/"
        };
      });
      it("should create session.personal if it doesn't exist", function() {
        var next;
        next = function(err) {
          should.not.exist(err);
          return req.session.personal.should.be.ok;
        };
        return PersonalMid(req, {}, next);
      });
      it("should add state and redirect to session", function() {
        var next;
        next = function(err) {
          var redir_url_obj;
          should.not.exist(err);
          req.session.personal.state.should.be.a('string').and.have.length(64);
          redir_url_obj = url.parse(req.session.personal.redirect_uri, true);
          redir_url_obj.protocol.should.equal('https:');
          redir_url_obj.hostname.should.equal('localhost');
          redir_url_obj.query.personal.should.equal('true');
          return redir_url_obj.query.state.should.equal(req.session.personal.state);
        };
        return PersonalMid(req, {}, next);
      });
      it("should create client if it has a valid session", function() {
        var next;
        req.session.personal = {};
        req.session.personal.access_token = "access";
        req.session.personal.refresh_token = "refresh";
        req.session.personal.expiration = new Date();
        next = function(err) {
          should.not.exist(err);
          req.personal.client.should.be.ok;
          req.personal.client._reg_events.should.be.ok;
          req.personal.client.access_options.access_token.should.equal("access");
          req.personal.client.access_options.refresh_token.should.equal("refresh");
          req.personal.client.access_options.expiration.should.equal(req.session.personal.expiration);
          req.personal.logged_in.should.be["true"];
          return req.personal.logout.should.be.a("function");
        };
        return PersonalMid(req, {}, next);
      });
      test_srv = {
        close: function() {}
      };
      after(function() {
        return test_srv.close();
      });
      return it("should get an access code properly", function(done) {
        var call_count, next, res, soln;
        PersonalOpt({
          test: true
        });
        soln = {
          access_token: "at",
          refresh_token: "rt",
          expires_in: 3600
        };
        req.session.personal = {};
        req.session.personal.redirect_uri = "http://localhost";
        req.query.state = req.session.personal.state = crypto.randomBytes(32).toString('hex');
        req.query.personal = true;
        req.query.code = "5w8z42x4e66d6dv8vymp";
        req.query.other_qs_param = true;
        req.path = "/";
        call_count = 0;
        test_srv = http.createServer(function(req_in_srv, res_in_srv) {
          var body;
          if (++call_count >= 2) {
            test_srv.close();
            return done(new Error("access token requested multiple times"));
          }
          body = "";
          try {
            if (req_in_srv.method !== "POST") {
              test_srv.close();
              return done(new Error("Trying to get access token with http verb " + req.method));
            }
            if (req_in_srv.headers["content-type"].split(";")[0] !== "application/x-www-form-urlencoded") {
              test_srv.close();
              return done(new Error("Content type incorrect - " + req.headers["Content-Type"]));
            }
          } catch (err) {
            return done(err);
          }
          req_in_srv.on("data", function(chunk) {
            if (chunk != null) {
              return body += chunk;
            }
          });
          return req_in_srv.on("end", function() {
            var post_obj;
            post_obj = qs.parse(body);
            if (post_obj.grant_type !== "authorization_code") {
              done(new Error("Incorrect grant type - " + post_obj.grant_type));
            }
            if (post_obj.code !== req.query.code) {
              done(new Error("Incorrect code - " + post_obj.code));
            }
            if (post_obj.redirect_uri !== req.session.personal.redirect_uri) {
              done(new Error("Incorrect redirect_uri - " + redirect_uri));
            }
            if (post_obj.client_id !== "clientid") {
              done(new Error("Wrong client ID - " + post_obj.client_id));
            }
            if (post_obj.client_secret !== "client_secret") {
              done(new Error("Wrong client secret - " + post_obj.client_secret));
            }
            res_in_srv.writeHead(200, {
              "Content-Type": "application/json"
            });
            return res_in_srv.end(JSON.stringify(soln));
          });
        });
        test_srv.listen(7357);
        next = function(err) {
          test_srv.close();
          if (err != null) {
            return done(err);
          }
        };
        res = {
          redirect: function(_path) {
            var sess;
            try {
              sess = req.session.personal;
              if (_path !== "/other_qs_param=true") {
                done(new Error("Incorrect redirect path - " + _path));
              }
              if (sess.state != null) {
                done(new Error("req.session.personal.state should be undefined"));
              }
              if (sess.redirect_uri !== "http://localhost") {
                done(new Error("Incorrect redirect_uri - " + sess.redirect_uri));
              }
              if (sess.access_token !== "at") {
                done(new Error("wrong access token - " + sess.access_token));
              }
              if (sess.refresh_token !== "rt") {
                done(new Error("wrong refresh token - " + sess.refresh_token));
              }
              if (req.personal.logged_in !== true) {
                done(new Error("req.personal.logged_in not true"));
              }
              if (req.personal.client.access_options.redirect_uri !== "http://localhost") {
                done(new Error("Incorrect redirect_uri in personal.client - " + sess.redirect_uri));
              }
              if (req.personal.client.access_options.access_token !== "at") {
                done(new Error("wrong access token in personal.client - " + sess.access_token));
              }
              if (req.personal.client.access_options.refresh_token !== "rt") {
                done(new Error("wrong refresh token in personal.client - " + sess.refresh_token));
              }
              return done();
            } catch (err) {
              return done(err);
            }
          }
        };
        return PersonalMid(req, res, next);
      });
    });
    return describe("PersonalHelpers\t", function() {
      var app, helpers, req, scope, _ref;
      _ref = [null, null, null, null], app = _ref[0], helpers = _ref[1], req = _ref[2], scope = _ref[3];
      beforeEach(function() {
        scope = new PersonalScope({
          literal: "read_0135"
        });
        req = {
          session: {},
          query: {},
          headers: {
            host: "localhost"
          },
          protocol: "https",
          url: "/"
        };
        PersonalOpt({
          client_id: "clientid",
          client_secret: "client_secret",
          scope: scope,
          update: false,
          sandbox: true
        });
        app = {
          locals: function(obj) {
            var key, val, _results;
            _results = [];
            for (key in obj) {
              val = obj[key];
              _results.push(app.locals[key] = val);
            }
            return _results;
          }
        };
        return helpers = PersonalHelpers(app);
      });
      it("should create auth_req_url helper", function() {
        var next;
        next = function(err) {
          var auth_url_obj, redir_url_obj;
          if (err != null) {
            return done(err);
          }
          should.not.exist(err);
          auth_url_obj = url.parse(app.locals.auth_req_url(), true);
          redir_url_obj = url.parse(auth_url_obj.query.redirect_uri, true);
          redir_url_obj.protocol.should.equal('https:');
          redir_url_obj.hostname.should.equal('localhost');
          redir_url_obj.query.personal.should.equal('true');
          return redir_url_obj.query.state.should.be.a('string').and.have.length(64);
        };
        return PersonalMid(req, {}, next);
      });
      return it("should use provided callback_uri if present", function() {
        var next;
        PersonalOpt({
          callback_uri: "http://www.host.com"
        });
        next = function(err) {
          var auth_url_obj, redir_url_obj;
          should.not.exist(err);
          auth_url_obj = url.parse(app.locals.auth_req_url(), true);
          redir_url_obj = url.parse(auth_url_obj.query.redirect_uri, true);
          redir_url_obj.protocol.should.equal('http:');
          redir_url_obj.hostname.should.equal('www.host.com');
          redir_url_obj.query.personal.should.equal('true');
          return redir_url_obj.query.state.should.be.a('string').and.have.length(64);
        };
        return PersonalMid(req, {}, next);
      });
    });
  });

}).call(this);
