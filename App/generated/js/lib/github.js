var EventEmitter, Git, Github, WatchJS, appData, callWatchers, client, cs, db, exec, fs, getKey, ghdownload, git, github, keys, path, request, unwatch, watch, _,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  __slice = [].slice;

db = window.localStorage;

_ = require('underscore');

cs = require('calmsoul');

path = require('path');

fs = require('fs.extra');

exec = require('exec');

request = require('superagent');

github = require('octonode');

ghdownload = require('github-download');

WatchJS = require('watchjs');

Git = require('git-wrapper');

watch = WatchJS.watch;

unwatch = WatchJS.unwatch;

callWatchers = WatchJS.callWatchers;

EventEmitter = require('events').EventEmitter;

require('shelljs/global');

appData = process.env.APPDATA != null ? process.env.APPDATA : path.join(process.env.HOME, '.downloads');

keys = ['894b9db89f78b7142263966c69cabf63cec31a19', '96234b48504bcb43a1d0a9e11cd7e596b45f4e54', '16cd039c3347e9689bf2e7d3eccdcfb627bec2fc', '3fe23a32720c1d08a38dc488c3e5128ea809fdaa'];

getKey = function() {
  return keys[Math.floor(Math.random() * keys.length + 1)];
};

client = github.client(getKey());

git = new Git();

cs.set({
  'info': true
});

Github = (function(_super) {
  __extends(Github, _super);

  Github.prototype.blacklist = ['AddonDownloader', 'vikinghug.com', 'VikingActionBarSet', 'VikingDocs', 'VikingQuestTrackerSet', 'VikingMedic'];

  Github.prototype.whitelist = ['VikingActionBarFrame', 'VikingActionBarShortcut', 'VikingBuddies', 'VikingClassResources', 'VikingContextMenuPlayer', 'VikingGroupFrame', 'VikingHealthShieldBar', 'Vikinghug', 'VikingInventory', 'VikingLibrary', 'VikingMiniMap', 'VikingNameplates', 'VikingSettings', 'VikingSprintMeter', 'VikingTooltips', 'VikingTradeskills', 'VikingUnitFrames', 'VikingXPBar'];

  Github.prototype.queue = [];

  function Github() {
    var self;
    self = this;
    watch(this, ['addonsFolderSet'], function(key, command, data) {
      if (data) {
        return self.clearQueue();
      }
    });
    return;
  }

  Github.prototype.init = function() {
    if (db.addonsFolderSet === 'false') {
      cs.debug('NOPE');
      return this.updateAddonsFolder(path.join(appData, 'NCSOFT', 'WildStar', 'addons'));
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
    return this.emit('CONFIG:SET:ADDONSFOLDER', dest);
  };

  Github.prototype.addToQueue = function() {
    var args, fn;
    fn = arguments[0], args = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
    return this.queue.push([fn, args]);
  };

  Github.prototype.clearQueue = function() {
    var err, fn;
    if (this.queue.length > 0) {
      try {
        fn = this.queue.shift();
        fn[1].push(this.clearQueue);
        return fn[0].apply(this, fn[1]);
      } catch (_error) {
        err = _error;
        return this.emit('MESSAGE:ADD', err.message);
      }
    } else {
      return this.emit('MESSAGE:ADD', "ALL DONE!");
    }
  };

  Github.prototype.done = function() {
    return this.clearQueue();
  };

  Github.prototype.downloadRepos = function() {
    var err, i, id, name, repo, self, _i, _len, _ref;
    self = this;
    if (!db.addonsFolderSet) {
      this.updateAddonsFolder(db.addonsFolder);
      return this.addToQueue(this.downloadRepos);
    } else {
      try {
        _ref = JSON.parse(db.repos);
        for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
          repo = _ref[i];
          id = repo.id;
          name = repo.name;
          self.emit("MODULE:RESET", name);
          this.addToQueue(this.downloadRepo, name, id, this.done);
        }
        return this.clearQueue();
      } catch (_error) {
        err = _error;
        return this.emit('MESSAGE:ADD', err.message);
      }
    }
  };

  Github.prototype.downloadRepo = function(name, id, callback) {
    var currentBranch, dest, repo, self, url;
    self = this;
    self.emit("MODULE:RESET", name);
    repo = this.findRepo(id);
    currentBranch = repo.current_branch;
    url = _.findWhere(repo.branches, {
      name: currentBranch
    }).download_url;
    if (!db.addonsFolderSet) {
      this.updateAddonsFolder(db.addonsFolder);
      return this.addToQueue(this.downloadRepo, name, url);
    } else {
      cs.debug('downloadRepo: ->');
      cs.debug(db.addonsFolder, name);
      dest = path.join(db.addonsFolder, name);
      return fs.exists(dest, (function(_this) {
        return function(bool) {
          var err;
          if (bool) {
            try {
              fs.rmrfSync(dest);
            } catch (_error) {
              err = _error;
              self.emit('MESSAGE:ADD', err.message);
              self.emit('MODULE:ERROR', name);
            }
          }
          try {
            if (which('git')) {
              console.log("# GIT EXISTS, CLONING REPO");
              url = url.substring(0, url.indexOf('#'));
              dest = "\"" + dest + "\"";
              return git.exec('clone', {
                b: currentBranch
              }, [url, dest], function(err) {
                if (err) {
                  self.sendError(err);
                }
                self.emit("MODULE:DONE", name);
                if (callback != null) {
                  return callback.apply(self);
                }
              });
            } else {
              console.log("# GIT DOES NOT EXIST, DOWNLOADING REPO");
              return ghdownload(url, dest).on('dir', function(dir) {
                return cs.debug(dir);
              }).on('file', function(file) {
                return cs.debug(file);
              }).on('zip', function(zipUrl) {
                return cs.debug(zipUrl);
              }).on('error', function(err) {
                return console.error(err);
              }).on('end', function() {
                self.emit("MODULE:DONE", name);
                if (callback != null) {
                  return callback.apply(self);
                }
              });
            }
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
    repos = JSON.parse(db.getItem('repos'));
    index = this.findRepoIndex(id);
    return repos[index];
  };

  Github.prototype.findRepoIndex = function(id) {
    var err, i, repo, repos, _i, _len;
    cs.debug('findRepoIndex', id);
    try {
      repos = JSON.parse(db.getItem('repos'));
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
    repos = JSON.parse(db.getItem('repos'));
    _results = [];
    for (key in repos) {
      value = repos[key];
      _results.push(this.setBranch(value.id, branch));
    }
    return _results;
  };

  Github.prototype.setBranch = function(id, branch) {
    var err, index, repos;
    cs.debug('setBranch');
    try {
      repos = JSON.parse(db.getItem('repos'));
      index = this.findRepoIndex(id);
      cs.debug('index: ', index);
      branch = branch != null ? branch : 'master';
      repos[index].current_branch = branch;
      return this.updateRepo(repos[index], index);
    } catch (_error) {
      err = _error;
      return this.sendError(err);
    }
  };

  Github.prototype.addRepo = function(repo, branch) {
    var err, repos;
    cs.debug('addRepo');
    try {
      repos = JSON.parse(db.getItem('repos'));
      repos.push(repo);
      db.repos = JSON.stringify(repos);
      return repo;
    } catch (_error) {
      err = _error;
      return this.sendError(err);
    }
  };

  Github.prototype.updateRepo = function(repo, index) {
    var err, repos, _ref;
    cs.debug('updateRepo');
    try {
      repos = JSON.parse(db.getItem('repos'));
      repo = _.extend(repos[index], repo);
      repos[index].current_branch = (_ref = repos[index].current_branch) != null ? _ref : 'master';
      repos[index].branches = this.updateBranches(repos[index].branches, repos[index].current_branch);
      cs.debug(repos[index]);
      cs.debug(repos[index].branches);
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
      db.setItem('repos', JSON.stringify([]));
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
            repo = self.setBranch(repo.id);
          }
          _results.push(self.emit('MODULE:UPDATE', repo));
        }
        return _results;
      };
    })(this));
  };

  Github.prototype.sendError = function(err) {
    return this.emit('MESSAGE:ADD', err.message);
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
