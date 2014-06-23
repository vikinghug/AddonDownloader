'use strict';
var $, App, Data, Handlebars, em, events, fs, gh;

$ = require('jquery');

Handlebars = require('handlebars');

fs = require('fs');

events = require('events');

em = new events.EventEmitter();

gh = require('./lib/github');

Data = require('./lib/data');

App = (function() {
  App.prototype.configBtnEl = "#config-button";

  App.prototype.fileDialogEl = "#addons-folder-config";

  App.prototype.configTooltipEl = "#config-tooltip";

  App.prototype.downloadAllBtnEl = "#download-all";

  App.prototype.downloadBtnClassEl = ".download";

  App.prototype.messageEl = "#message";

  App.prototype.reposEl = "#repos";

  App.prototype.repoTemplateEl = "#repo-template";

  App.prototype.timer = false;

  App.prototype.secret = 0;

  function App() {
    this.initView();
    this.createEvents();
    gh.getRepos("vikinghug");
  }

  App.prototype.initView = function() {
    var package_info, win;
    package_info = JSON.parse(fs.readFileSync('package.json', 'utf8'));
    win = window.gui.Window.get();
    return win.title = "" + package_info.name + " - v" + package_info.version;
  };

  App.prototype.checkDevCommand = function() {
    var win;
    this.timer = false;
    win = window.gui.Window.get();
    if (this.secret >= 2) {
      win.showDevTools();
    }
    return this.secret = 0;
  };

  App.prototype.createEvents = function() {
    var secretTimer, self;
    gh.on("MODULE:UPDATE", (function(_this) {
      return function(data) {
        return _this.updateView(data);
      };
    })(this));
    gh.on("MODULE:DONE", (function(_this) {
      return function(name) {
        return _this.setModuleDone(name);
      };
    })(this));
    gh.on("MODULE:ERROR", (function(_this) {
      return function(name) {
        return _this.setModuleError(name);
      };
    })(this));
    gh.on("MESSAGE:ADD", (function(_this) {
      return function(data) {
        return _this.flashMessage(data);
      };
    })(this));
    gh.on("MESSAGE:CLOSE", (function(_this) {
      return function() {
        return _this.removeMessage();
      };
    })(this));
    gh.on("CONFIG:SET:ADDONSFOLDER", (function(_this) {
      return function(dest) {
        return _this.setAddonsFolder(dest);
      };
    })(this));
    self = this;
    secretTimer = null;
    $("body").on("keyup", function(e) {
      if (!self.timer) {
        self.timer = true;
        self.secretTimer = setTimeout(((function(_this) {
          return function() {
            return self.checkDevCommand();
          };
        })(this)), 3000);
      }
      if (e.ctrlKey && e.keyCode === 119) {
        self.secret++;
      }
      if (self.secret >= 2) {
        clearTimeout(self.secretTimer);
        return self.checkDevCommand();
      }
    });
    $(this.downloadAllBtnEl).on('click', (function(_this) {
      return function(e) {
        var err;
        try {
          return gh.downloadRepos();
        } catch (_error) {
          err = _error;
          return console.log(err);
        }
      };
    })(this));
    $("body").on('click', "a[href]", function(e) {
      var href;
      e.preventDefault();
      href = e.target.getAttribute("href");
      return window.gui.Shell.openExternal(href);
    });
    $("body").on('click', "#config-button", function(e) {
      e.preventDefault();
      return self.setAddonsFolder(gh.addonsFolder);
    });
    $("body").on('change', this.fileDialogEl, function(e) {
      gh.setAddonsFolder(this.value);
      return self.setAddonsTooltip(this.value);
    });
    $("body").on('click', this.downloadBtnClassEl, (function(_this) {
      return function(e) {
        var $el, name, url;
        $el = $(e.target).parents('.module');
        url = $(e.target).data("url");
        if (url == null) {
          url = $el.data("repo-url");
        }
        name = $el.data("repo-name");
        return gh.downloadRepo(name, url);
      };
    })(this));
    return $(this.messageEl).on('click', '.close', (function(_this) {
      return function(e) {
        return self.removeMessage();
      };
    })(this));
  };

  App.prototype.updateView = function(data) {
    var $el, html, reposSource, template;
    reposSource = $(this.repoTemplateEl).html();
    template = Handlebars.compile(reposSource);
    html = template(data);
    $el = $("[data-repo-id=" + data.id + "]");
    if ($el.length === 0) {
      $(this.reposEl).append(html);
    } else {
      $el.replaceWith(html);
    }
    return this.sortModules();
  };

  App.prototype.sortModules = function() {
    var $modules, $modulesContainer;
    $modulesContainer = $(this.reposEl);
    $modules = $modulesContainer.children('.module');
    $modules.sort(function(a, b) {
      var aStr, bStr;
      aStr = a.getAttribute("data-repo-name").toLowerCase();
      bStr = b.getAttribute("data-repo-name").toLowerCase();
      if (aStr > bStr) {
        return 1;
      } else if (bStr > aStr) {
        return -1;
      } else {
        return 0;
      }
    });
    return $modules.detach().appendTo($modulesContainer);
  };

  App.prototype.setModuleDone = function(name) {
    return $("[data-repo-name=" + name + "]").addClass("done");
  };

  App.prototype.setModuleError = function(name) {
    return $("[data-repo-name=" + name + "]").addClass("error");
  };

  App.prototype.flashMessage = function(msg) {
    var $el;
    console.log(msg);
    $el = $("" + this.messageEl + " p");
    $el.html(msg);
    return $("body").addClass('message');
  };

  App.prototype.removeMessage = function() {
    return $("body").removeClass('message');
  };

  App.prototype.setAddonsFolder = function(baseDir) {
    $(this.fileDialogEl).attr("nwworkingdir", baseDir);
    return $(this.fileDialogEl).click();
  };

  App.prototype.setAddonsTooltip = function(dest) {
    return $(this.configTooltipEl).html(dest);
  };

  return App;

})();

module.exports = window.App = new App();
