db = window.localStorage

_            = require('underscore')
$            = require('jquery')
cs           = require('calmsoul')
Handlebars   = require('handlebars')
fs           = require('fs')
events       = require('events')
em           = new events.EventEmitter()
gh           = require('./lib/github')

cs.set(info: false)

class App

  configBtnEl        : "#config-button"
  fileDialogEl       : "#addons-folder-config"
  configTooltipEl    : "#config-tooltip"
  downloadAllBtnEl   : "#download-all"
  downloadBtnClassEl : ".download"
  setBranchClassEl   : ".set-branch"
  messageEl          : "#message"
  reposEl            : "#repos"
  repoTemplateEl     : "#repo-template"
  timer              : false
  secret             : 0

  constructor: ->
    gh.init()
    gh.getRepos("vikinghug")
    @initView()
    @createEvents()


  initView: ->
    package_info = JSON.parse(fs.readFileSync('package.json', 'utf8'))
    win = window.gui.Window.get()
    win.title = "#{package_info.name} - v#{package_info.version}"
    @setAddonsTooltip(db.addonsFolder) if db.addonsFolder?


  checkDevCommand: ->
    @timer  = false
    win = window.gui.Window.get()
    if @secret >= 2
      win.showDevTools()
    @secret = 0


  createEvents: ->
    # module events
    gh.on "MODULE:RESET", (name) => @setModuleReady(name)
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
      KEY_ESCAPE = 27
      KEY_F8     = 119
      return self.removeMessage() if e.keyCode == KEY_ESCAPE
      if not self.timer
        self.timer = true
        self.secretTimer = setTimeout(( => self.checkDevCommand() ), 3000)
      # 119 == F8
      self.secret++ if e.ctrlKey && e.keyCode == KEY_F8
      if self.secret >= 2
        clearTimeout(self.secretTimer)
        self.checkDevCommand()

    $("body").on 'click', @downloadAllBtnEl, (e) =>
      try
        gh.downloadRepos()
      catch err
        self.flashMessage(err.message)


    $("body").on 'click', '#reset-all', (e) =>
      try
        gh.resetBranches("master")
        $.each $('.module'), (i, el) =>
          self.updateBranchMenu($(el), "master")
      catch err
        self.flashMessage(err.message)



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
      id   = $el.data("repo-id")
      name = $el.data("repo-name")
      gh.downloadRepo(name, id)

    $("body").on 'click', @setBranchClassEl, (e) =>
      $el    = $(e.target).parents('.module')
      url    = $(e.target).data("url") or $el.data("repo-url")
      id     = $el.data("repo-id")
      name   = $el.data("repo-name")
      branch = $(e.target).text()
      gh.setBranch(id, branch)
      @updateBranchMenu($el, branch)

    $("body").on 'mouseenter', '.branches', (e) =>
      viewportHeight = $(window).height()
      mousePosition  = e.clientY

      $el     = $(e.currentTarget)
      $menuEl = $el.find('.menu')
      if mousePosition > viewportHeight / 2
        $menuEl.css
          "top": -$menuEl.height()
        $menuEl.removeClass("top")
        $menuEl.addClass("bottom")
      else
        $menuEl.css
          "top": 50
        $menuEl.removeClass("bottom")
        $menuEl.addClass("top")

    $(@messageEl).on 'click', '.close', (e) =>
      @removeMessage()


  updateBranchMenu: ($module, branch) ->
    $module.find('button.dropdown').text(branch)
    $.each $module.find('.menu .set-branch'), (i, el) ->
      if $(el).text() == branch
        $(el).addClass('checked')
      else
        $(el).removeClass('checked')



  updateView: (data) ->
    cs.debug "updateView", data
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

  setModuleReady: (name) -> $("[data-repo-name=#{name}]").removeClass("done")
  setModuleDone: (name) -> $("[data-repo-name=#{name}]").addClass("done")
  setModuleError: (name) -> $("[data-repo-name=#{name}]").addClass("error")

  flashMessage: (msg) ->
    cs.debug msg
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
