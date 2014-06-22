var $, Data, EventEmitter, Github, WatchJS, appData, callWatchers, client, exec, fs, ghdownload, github, path, unwatch, watch,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  __slice = [].slice;

$ = require('jquery');

path = require('path');

fs = require('fs.extra');

exec = require('exec');

github = require('octonode');

ghdownload = require('github-download');

WatchJS = require("watchjs");

watch = WatchJS.watch;

unwatch = WatchJS.unwatch;

callWatchers = WatchJS.callWatchers;

EventEmitter = require('events').EventEmitter;

Data = require('./data');

appData = process.env.APPDATA != null ? process.env.APPDATA : path.join(process.env.HOME, ".downloads");

client = github.client("b88ebd287229cba593058175b38b059b13af6034");

Github = (function(_super) {
  __extends(Github, _super);

  Github.prototype.blacklist = ["AddonDownloader", "vikinghug.com", "VikingBuddies"];

  Github.prototype.addonsFolder = path.join(appData, "NCSOFT", "WildStar", "addons");

  Github.prototype.addonsFolderSet = false;

  Github.prototype.repos = [];

  Github.prototype.queue = [];

  function Github() {
    var self;
    self = this;
    watch(this, ["addonsFolderSet"], function(key, command, data) {
      if (data) {
        return self.clearQueue();
      }
    });
    return;
  }

  Github.prototype.setRepos = function(repos) {
    return this.repos = repos;
  };

  Github.prototype.setAddonsFolder = function(dest) {
    this.addonsFolderSet = true;
    return this.addonsFolder = dest;
  };

  Github.prototype.updateAddonsFolder = function(dest) {
    return this.emit("CONFIG:SET:ADDONSFOLDER", dest);
  };

  Github.prototype.addToQueue = function() {
    var args, fn;
    fn = arguments[0], args = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
    return this.queue.push([fn, args]);
  };

  Github.prototype.clearQueue = function() {
    var err, fn, i, _i, _len, _ref, _results;
    try {
      _ref = this.queue;
      _results = [];
      for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
        fn = _ref[i];
        _results.push(fn[0].apply(this, fn[1]));
      }
      return _results;
    } catch (_error) {
      err = _error;
      return self.emit("MESSAGE:ADD", err.message);
    }
  };

  Github.prototype.downloadRepos = function() {
    var i, name, repo, url, _i, _len, _ref, _results;
    if (!this.addonsFolderSet) {
      this.updateAddonsFolder(this.addonsFolder);
      return this.addToQueue(this.downloadRepos);
    } else {
      try {
        _ref = this.repos;
        _results = [];
        for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
          repo = _ref[i];
          url = repo.git_url;
          name = repo.name;
          _results.push(this.downloadRepo(name, url));
        }
        return _results;
      } catch (_error) {
        return self.emit("MESSAGE:ADD", err.message);
      }
    }
  };

  Github.prototype.downloadRepo = function(name, url) {
    var dest, self;
    if (!this.addonsFolderSet) {
      this.updateAddonsFolder(this.addonsFolder);
      return this.addToQueue(this.downloadRepo, name, url);
    } else {
      console.log("downloadRepo: ->");
      console.log(this.addonsFolder, name);
      dest = path.join(this.addonsFolder, name);
      self = this;
      return fs.exists(dest, (function(_this) {
        return function(bool) {
          var err;
          if (bool) {
            try {
              fs.rmrfSync(dest);
            } catch (_error) {
              err = _error;
              self.emit("MESSAGE:ADD", err.message);
              self.emit("MODULE:ERROR", name);
            }
          }
          try {
            return ghdownload(url, dest).on('dir', function(dir) {
              return console.log(dir);
            }).on('file', function(file) {
              return console.log(file);
            }).on('zip', function(zipUrl) {
              return console.log(zipUrl);
            }).on('error', function(err) {
              return console.error(err);
            }).on('end', function() {
              return self.emit("MODULE:DONE", name);
            });
          } catch (_error) {
            err = _error;
            return _this.sendError(err);
          }
        };
      })(this));
    }
  };

  Github.prototype.findRepo = function(id) {
    var err, i, repo, _i, _len, _ref;
    try {
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
    } catch (_error) {
      err = _error;
      return this.sendError(err);
    }
  };

  Github.prototype.getRepos = function(owner) {
    var org;
    org = client.org(owner);
    return org.repos((function(_this) {
      return function(err, array, headers) {
        var i, repo, _i, _len, _results;
        if (err) {
          _this.emit("MESSAGE:ADD", err.message);
          return;
        }
        array = _this.filterForBlacklist(array);
        try {
          _results = [];
          for (i = _i = 0, _len = array.length; _i < _len; i = ++_i) {
            repo = array[i];
            try {
              _results.push(_this.initRepo(repo, i));
            } catch (_error) {
              err = _error;
              _results.push(_this.sendError(err));
            }
          }
          return _results;
        } catch (_error) {
          err = _error;
          return self.emit("MESSAGE:ADD", err.message);
        }
      };
    })(this));
  };

  Github.prototype.sendError = function(err) {
    return self.emit("MESSAGE:ADD", err.message);
  };

  Github.prototype.initRepo = function(repo, i) {
    var index, payload, self;
    payload = {
      id: repo.id,
      owner: repo.owner.login,
      name: repo.name,
      git_url: repo.git_url,
      html_url: repo.html_url,
      ssh_url: repo.ssh_url,
      branches: null
    };
    index = this.findRepo(repo.id);
    if (index) {
      this.repos[index] = payload;
    } else {
      this.repos.push(payload);
    }
    this.runCommand("branches", payload);
    this.runCommand("info", payload);
    self = this;
    watch(payload, function(key, command, data) {
      var branch, err, _i, _len;
      switch (key) {
        case "branches":
          try {
            for (i = _i = 0, _len = data.length; _i < _len; i = ++_i) {
              branch = data[i];
              branch.html_url = "" + this.html_url + "/tree/" + branch.name;
              branch.download_url = "" + this.git_url + "\#" + branch.name;
            }
          } catch (_error) {
            err = _error;
            self.emit("MESSAGE:ADD", err.message);
          }
      }
      return self.emit("MODULE:UPDATE", this);
    });
    return this.emit("MODULE:UPDATE", payload);
  };

  Github.prototype.filterForBlacklist = function(array) {
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

  Github.prototype.runCommand = function(command, data) {
    var repo;
    repo = client.repo("" + data.owner + "/" + data.name);
    return repo[command]((function(_this) {
      return function(err, response, headers) {
        return data[command] = response;
      };
    })(this));
  };

  return Github;

})(EventEmitter);

module.exports = new Github();
