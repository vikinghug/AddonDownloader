var EventEmitter, Github, WatchJS, appData, callWatchers, client, db, exec, fs, getKey, ghdownload, github, keys, path, request, unwatch, watch, _,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  __slice = [].slice;

db = window.localStorage;

_ = require('underscore');

path = require('path');

fs = require('fs.extra');

exec = require('exec');

request = require('superagent');

github = require('octonode');

ghdownload = require('github-download');

WatchJS = require("watchjs");

watch = WatchJS.watch;

unwatch = WatchJS.unwatch;

callWatchers = WatchJS.callWatchers;

EventEmitter = require('events').EventEmitter;

appData = process.env.APPDATA != null ? process.env.APPDATA : path.join(process.env.HOME, ".downloads");

keys = ["894b9db89f78b7142263966c69cabf63cec31a19", "96234b48504bcb43a1d0a9e11cd7e596b45f4e54", "16cd039c3347e9689bf2e7d3eccdcfb627bec2fc", "3fe23a32720c1d08a38dc488c3e5128ea809fdaa"];

getKey = function() {
  return keys[Math.floor(Math.random() * keys.length + 1)];
};

client = github.client(getKey());

Github = (function(_super) {
  __extends(Github, _super);

  Github.prototype.blacklist = ["AddonDownloader", "vikinghug.com", "VikingActionBarSet", "VikingDocs", "VikingQuestTrackerSet", "VikingMedic"];

  Github.prototype.whitelist = ["VikingActionBarFrame", "VikingActionBarShortcut", "VikingBuddies", "VikingClassResources", "VikingContextMenuPlayer", "VikingGroupFrame", "VikingHealthShieldBar", "Vikinghug", "VikingInventory", "VikingLibrary", "VikingMiniMap", "VikingNameplates", "VikingSettings", "VikingSprintMeter", "VikingTooltips", "VikingTradeskills", "VikingUnitFrames", "VikingXPBar"];

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

  Github.prototype.init = function() {
    if (db.addonsFolderSet === "false") {
      console.log("NOPE");
      return this.updateAddonsFolder(path.join(appData, "NCSOFT", "WildStar", "addons"));
    }
  };

  Github.prototype.setRepos = function(repos) {
    return db.repos = repos;
  };

  Github.prototype.setAddonsFolder = function(dest) {
    db.addonsFolderSet = true;
    return db.addonsFolder = dest;
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
      return this.emit("MESSAGE:ADD", err.message);
    }
  };

  Github.prototype.downloadRepos = function() {
    var err, i, id, name, repo, _i, _len, _ref, _results;
    if (!db.addonsFolderSet) {
      this.updateAddonsFolder(db.addonsFolder);
      return this.addToQueue(this.downloadRepos);
    } else {
      try {
        _ref = JSON.parse(db.repos);
        _results = [];
        for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
          repo = _ref[i];
          id = repo.id;
          name = repo.name;
          _results.push(this.downloadRepo(name, id));
        }
        return _results;
      } catch (_error) {
        err = _error;
        return this.emit("MESSAGE:ADD", err.message);
      }
    }
  };

  Github.prototype.downloadRepo = function(name, id) {
    var currentBranch, dest, repo, self, url;
    repo = this.findRepo(id);
    console.log(repo);
    currentBranch = repo.current_branch;
    url = _.findWhere(repo.branches, {
      name: currentBranch
    }).download_url;
    if (!db.addonsFolderSet) {
      this.updateAddonsFolder(db.addonsFolder);
      return this.addToQueue(this.downloadRepo, name, url);
    } else {
      console.log("downloadRepo: ->");
      console.log(db.addonsFolder, name);
      dest = path.join(db.addonsFolder, name);
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
    var index, repos;
    repos = JSON.parse(db.getItem("repos"));
    index = this.findRepoIndex(id);
    return repos[index];
  };

  Github.prototype.findRepoIndex = function(id) {
    var err, i, repo, repos, _i, _len;
    console.log("findRepoIndex", id);
    try {
      repos = JSON.parse(db.getItem("repos"));
      if (repos.length === 0) {
        return null;
      }
      for (i = _i = 0, _len = repos.length; _i < _len; i = ++_i) {
        repo = repos[i];
        if (repo.id === id) {
          return i;
        }
      }
      return null;
    } catch (_error) {
      err = _error;
      return this.sendError(err);
    }
  };

  Github.prototype.resetBranches = function(branch) {
    var key, repos, value, _results;
    repos = JSON.parse(db.getItem("repos"));
    _results = [];
    for (key in repos) {
      value = repos[key];
      _results.push(this.setBranch(value.id, branch));
    }
    return _results;
  };

  Github.prototype.setBranch = function(id, branch) {
    var err, index, repos;
    console.log("setBranch");
    try {
      repos = JSON.parse(db.getItem("repos"));
      index = this.findRepoIndex(id);
      console.log("index: ", index);
      if (branch == null) {
        branch = "master";
      }
      repos[index].current_branch = branch;
      return this.updateRepo(repos[index], index);
    } catch (_error) {
      err = _error;
      return this.sendError(err);
    }
  };

  Github.prototype.addRepo = function(repo, branch) {
    var err, repos;
    console.log("addRepo");
    try {
      repos = JSON.parse(db.getItem("repos"));
      this.setBranch(repo.id, branch);
      repos.push(repo);
      db.repos = JSON.stringify(repos);
      return repo;
    } catch (_error) {
      err = _error;
      return this.sendError(err);
    }
  };

  Github.prototype.updateRepo = function(repo, index) {
    var err, repos, _base;
    console.log("updateRepo");
    try {
      repos = JSON.parse(db.getItem("repos"));
      _.extend(repos[index], repo);
      if ((_base = repos[index]).current_branch == null) {
        _base.current_branch = "master";
      }
      console.log("### current_branch: ", repos[index].current_branch);
      repos[index].branches = this.updateBranches(repos[index].branches, repos[index].current_branch);
      db.repos = JSON.stringify(repos);
      return repos[index];
    } catch (_error) {
      err = _error;
      return this.sendError(err);
    }
  };

  Github.prototype.updateBranches = function(branches, currentBranch) {
    var key, value;
    for (key in branches) {
      value = branches[key];
      value.current = value.name === currentBranch ? true : false;
    }
    return branches;
  };

  Github.prototype.getRepos = function(owner) {
    var self;
    if (db.repos === void 0) {
      db.setItem("repos", JSON.stringify([]));
    }
    self = this;
    return request.get('http://api.vikinghug.com/repos').end((function(_this) {
      return function(res) {
        var i, index, repo, _i, _len, _ref, _results;
        _ref = res.body;
        _results = [];
        for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
          repo = _ref[i];
          index = self.findRepoIndex(repo.id);
          if (index !== null && index !== void 0) {
            repo = self.updateRepo(repo, index);
          } else {
            repo = self.addRepo(repo);
          }
          _results.push(self.emit("MODULE:UPDATE", repo));
        }
        return _results;
      };
    })(this));
  };

  Github.prototype.sendError = function(err) {
    return this.emit("MESSAGE:ADD", err.message);
  };

  Github.prototype.filterForWhitelist = function(array) {
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
      if (n > 0) {
        return repo;
      }
    });
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

  return Github;

})(EventEmitter);

module.exports = new Github();
