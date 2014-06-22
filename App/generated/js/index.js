'use strict';
var $, App, Data, Handlebars, em, events, gh;

$ = require('jquery');

Handlebars = require('handlebars');

events = require('events');

em = new events.EventEmitter();

gh = require('./lib/github');

Data = require('./lib/data');

App = (function() {
  function App() {
    this.createEvents();
    gh.getRepos("vikinghug");
  }

  App.prototype.createEvents = function() {
    var self;
    gh.on("UPDATE", (function(_this) {
      return function(data) {
        return _this.updateView(data);
      };
    })(this));
    gh.on("MODULE:DONE", (function(_this) {
      return function(name) {
        return _this.setModuleDone(name);
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
    self = this;
    $("#download-all").on('click', (function(_this) {
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
    $("body").on('click', '.download', (function(_this) {
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
    return $("#message").on('click', '.close', (function(_this) {
      return function(e) {
        return self.removeMessage();
      };
    })(this));
  };

  App.prototype.updateView = function(data) {
    var $el, html, reposSource, template;
    reposSource = $("#repo-template").html();
    template = Handlebars.compile(reposSource);
    html = template(data);
    $el = $("[data-repo-id=" + data.id + "]");
    if ($el.length === 0) {
      $("#repos").append(html);
    } else {
      $el.replaceWith(html);
    }
    return this.sortModules();
  };

  App.prototype.sortModules = function() {
    var $modules, $modulesContainer;
    $modulesContainer = $("#repos");
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

  App.prototype.flashMessage = function(msg) {
    var $el;
    console.log(msg);
    $el = $("#message p");
    $el.html(msg);
    return $("body").addClass('message');
  };

  App.prototype.removeMessage = function() {
    return $("body").removeClass('message');
  };

  return App;

})();

module.exports = window.App = new App();
