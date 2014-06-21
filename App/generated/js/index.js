'use strict';
var $, Handlebars, Repos, WatchJS, callWatchers, client, exec, fs, ghdownload, ghrepo, github, path, unwatch, watch;

$ = require('jquery');

Handlebars = require('handlebars');

WatchJS = require("watchjs");

watch = WatchJS.watch;

unwatch = WatchJS.unwatch;

callWatchers = WatchJS.callWatchers;

github = require('octonode');

ghdownload = require('github-download');

exec = require('exec');

path = require('path');

fs = require('fs.extra');

client = github.client("b88ebd287229cba593058175b38b059b13af6034");

ghrepo = client.repo('vikinghug/VikingActionBarSet');

Repos = (function() {
  Repos.prototype.blacklist = ["vikinghug.com", "VikingBuddies"];

  Repos.prototype.repos = [];

  function Repos() {
    this.createEvents();
    this.getRepos('vikinghug');
  }

  Repos.prototype.createEvents = function() {
    return $("#download-all").on('click', (function(_this) {
      return function(e) {
        return _this.downloadRepos();
      };
    })(this));
  };

  Repos.prototype.downloadRepos = function() {
    var i, name, repo, url, _i, _len, _ref, _results;
    _ref = this.repos;
    _results = [];
    for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
      repo = _ref[i];
      url = repo.git_url;
      name = repo.name;
      _results.push(this.downloadRepo(url, name));
    }
    return _results;
  };

  Repos.prototype.downloadRepo = function(url, name) {
    var downloadPath;
    downloadPath = "./downloads/" + name + "/";
    return fs.exists(downloadPath, (function(_this) {
      return function(bool) {
        if (bool) {
          fs.rmrfSync(downloadPath);
        }
        return ghdownload(url, downloadPath).on('dir', function(dir) {
          return console.log(dir);
        }).on('file', function(file) {
          return console.log(file);
        }).on('zip', function(zipUrl) {
          return console.log(zipUrl);
        }).on('error', function(err) {
          return console.error(err);
        }).on('end', function() {
          return exec('tree', function(err, stdout, sderr) {
            return console.log(stdout);
          });
        });
      };
    })(this));
  };

  Repos.prototype.findRepo = function(id) {
    var i, repo, _i, _len, _ref;
    if (this.repos.length === 0) {
      return null;
    }
    _ref = this.repos;
    for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
      repo = _ref[i];
      if (repo.id === id) {
        return i;
      } else {
        return null;
      }
    }
  };

  Repos.prototype.getRepos = function(owner) {
    var org;
    org = client.org(owner);
    return org.repos((function(_this) {
      return function(err, array, data) {
        var i, payload, repo, self, _i, _len, _results;
        array = _this.filterForBlacklist(array);
        _results = [];
        for (i = _i = 0, _len = array.length; _i < _len; i = ++_i) {
          repo = array[i];
          payload = {
            id: i,
            owner: repo.owner.login,
            name: repo.name,
            git_url: repo.git_url,
            releases: null,
            branches: null
          };
          if (_this.findRepo(i) == null) {
            _this.repos.push(payload);
          } else {
            _this.repos[i] = payload;
          }
          _this.getCommand("releases", payload);
          _this.getCommand("branches", payload);
          _this.getCommand("info", payload);
          _this.updateView(payload);
          self = _this;
          _results.push(watch(payload, function() {
            return self.updateView(this);
          }));
        }
        return _results;
      };
    })(this));
  };

  Repos.prototype.filterForBlacklist = function(array) {
    var repos, self;
    self = this;
    return repos = array.filter(function(repo) {
      var n;
      n = 0;
      self.blacklist.map((function(_this) {
        return function(name) {
          return n += repo.name === name;
        };
      })(this));
      if (n === 0) {
        return repo;
      }
    });
  };

  Repos.prototype.updateView = function(data) {
    var $el, html, reposSource, template;
    reposSource = $("#repo-template").html();
    template = Handlebars.compile(reposSource);
    html = template(data);
    $el = $("[data-repo-id=" + data.id + "]");
    if ($el.length === 0) {
      return $("#repos").append(html);
    } else {
      return $el.replaceWith(html);
    }
  };

  Repos.prototype.getCommand = function(command, data) {
    var repo;
    repo = client.repo("" + data.owner + "/" + data.name);
    return repo[command]((function(_this) {
      return function(err, array, res) {
        return data[command] = array;
      };
    })(this));
  };

  return Repos;

})();

module.exports = window.Repos = new Repos();
