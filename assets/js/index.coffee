'use strict'


$            = require('jquery')
Handlebars   = require('handlebars')
events       = require('events')
em           = new events.EventEmitter()
gh           = require('./lib/github')
Data         = require('./lib/data')

class App

  constructor: ->
    @createEvents()
    gh.getRepos("vikinghug")

  createEvents: ->
    gh.on "UPDATE", (data) => @updateView(data)
    gh.on "MESSAGE:ADD", (data) => @flashMessage(data)
    gh.on "MESSAGE:CLOSE", => @removeMessage()

    self = @
    $("#download-all").on 'click', (e) =>
      try
        gh.downloadRepos()
      catch err
        console.log err

    $("body").on 'click', '.download', (e) =>
      $el = $(e.target).parents('.module')
      url = $(e.target).data("url")
      url ?= $el.data("repo-url")
      name = $el.data("repo-name")
      gh.downloadRepo(name, url)

    $("#message").on 'click', '.close', (e) =>
      self.removeMessage()

  updateView: (data) ->
    reposSource = $("#repo-template").html()
    template    = Handlebars.compile(reposSource)
    html        = template(data)
    $el = $("[data-repo-id=#{data.id}]")
    if $el.length == 0
      $("#repos").append(html)
    else
      $el.replaceWith(html)

  flashMessage: (msg) ->
    console.log msg
    $el = $("#message p")
    $el.html(msg)
    $("body").addClass('message')

  removeMessage: ->
    $("body").removeClass('message')


module.exports = window.App = new App()
