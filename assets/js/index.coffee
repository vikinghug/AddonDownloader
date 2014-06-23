'use strict'


$            = require('jquery')
Handlebars   = require('handlebars')
fs           = require('fs')
events       = require('events')
em           = new events.EventEmitter()
gh           = require('./lib/github')
Data         = require('./lib/data')

class App

  configBtnEl        : "#config-button"
  fileDialogEl       : "#addons-folder-config"
  configTooltipEl    : "#config-tooltip"
  downloadAllBtnEl   : "#download-all"
  downloadBtnClassEl : ".download"
  messageEl          : "#message"
  reposEl            : "#repos"
  repoTemplateEl     : "#repo-template"
  timer              : false
  secret             : 0

  constructor: ->
    @initView()
    @createEvents()
    gh.getRepos("vikinghug")


  initView: ->
    package_info = JSON.parse(fs.readFileSync('package.json', 'utf8'))
    win = window.gui.Window.get()
    win.title = "#{package_info.name} - v#{package_info.version}"


  checkDevCommand: ->
    @timer  = false
    win = window.gui.Window.get()
    if @secret >= 2
      win.showDevTools()
    @secret = 0


  createEvents: ->
    # module events
    gh.on "MODULE:UPDATE", (data) => @updateView(data)
    gh.on "MODULE:DONE", (name) => @setModuleDone(name)
    gh.on "MODULE:ERROR", (name) => @setModuleError(name)

    # message events
    gh.on "MESSAGE:ADD", (data) => @flashMessage(data)
    gh.on "MESSAGE:CLOSE", => @removeMessage()

    # config events
    gh.on "CONFIG:SET:ADDONSFOLDER", (dest) => @setAddonsFolder(dest)

    self = @
    secretTimer = null

    $("body").on "keyup", (e) ->
      if not self.timer
        self.timer = true
        self.secretTimer = setTimeout(( => self.checkDevCommand() ), 3000)
      # 119 == F8
      self.secret++ if e.ctrlKey && e.keyCode == 119
      if self.secret >= 2
        clearTimeout(self.secretTimer)
        self.checkDevCommand()

    $(@downloadAllBtnEl).on 'click', (e) =>
      try
        gh.downloadRepos()
      catch err
        console.log err


    $("body").on 'click', "a[href]", (e) ->
      e.preventDefault()
      href = e.target.getAttribute("href")
      window.gui.Shell.openExternal(href)
    $("body").on 'click', "#config-button", (e) ->
      e.preventDefault()
      self.setAddonsFolder(gh.addonsFolder)

    $("body").on 'change', @fileDialogEl, (e) ->
      gh.setAddonsFolder(this.value)
      self.setAddonsTooltip(this.value)

    $("body").on 'click', @downloadBtnClassEl, (e) =>
      $el = $(e.target).parents('.module')
      url = $(e.target).data("url")
      url ?= $el.data("repo-url")
      name = $el.data("repo-name")
      gh.downloadRepo(name, url)

    $(@messageEl).on 'click', '.close', (e) =>
      self.removeMessage()

  updateView: (data) ->
    reposSource = $(@repoTemplateEl).html()
    template    = Handlebars.compile(reposSource)
    html        = template(data)
    $el = $("[data-repo-id=#{data.id}]")
    if $el.length == 0
      $(@reposEl).append(html)
    else
      $el.replaceWith(html)

    @sortModules()


  sortModules: ->
    $modulesContainer = $(@reposEl)
    $modules = $modulesContainer.children('.module')

    $modules.sort (a,b) ->
      aStr = a.getAttribute("data-repo-name").toLowerCase()
      bStr = b.getAttribute("data-repo-name").toLowerCase()
      if (aStr > bStr)
        return 1
      else if (bStr > aStr)
        return -1
      else
        return 0

    $modules.detach().appendTo($modulesContainer)

  setModuleDone: (name) -> $("[data-repo-name=#{name}]").addClass("done")
  setModuleError: (name) -> $("[data-repo-name=#{name}]").addClass("error")

  flashMessage: (msg) ->
    console.log msg
    $el = $("#{@messageEl} p")
    $el.html(msg)
    $("body").addClass('message')

  removeMessage: ->
    $("body").removeClass('message')

  setAddonsFolder: (baseDir) ->
    $(@fileDialogEl).attr("nwworkingdir", baseDir)
    $(@fileDialogEl).click()

  setAddonsTooltip: (dest) -> $(@configTooltipEl).html(dest)

module.exports = window.App = new App()
