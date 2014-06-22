$            = require('jquery')
path         = require('path')
fs           = require('fs.extra')
exec         = require('exec')
github       = require('octonode')
ghdownload   = require('github-download')
WatchJS      = require("watchjs")
watch        = WatchJS.watch
unwatch      = WatchJS.unwatch
callWatchers = WatchJS.callWatchers
EventEmitter = require('events').EventEmitter
Data         = require('./data')
appData = if process.env.APPDATA? then process.env.APPDATA else path.join(process.env.HOME, ".downloads")

# this is a generic token
client = github.client("b88ebd287229cba593058175b38b059b13af6034")

class Github extends EventEmitter

  blacklist: [
    "AddonDownloader"
    "vikinghug.com"
    "VikingBuddies"
  ]

  addonsFolder    : path.join(appData, "NCSOFT", "WildStar", "addons")
  addonsFolderSet : false

  repos           : []
  queue           : []


  constructor: ->
    self = @
    watch @, ["addonsFolderSet"], (key, command, data) ->
      self.clearQueue() if data
    return

  setRepos: (repos) -> @repos = repos

  setAddonsFolder: (dest) ->
    @addonsFolderSet = true
    return @addonsFolder = dest

  updateAddonsFolder: (dest) -> @emit("CONFIG:SET:ADDONSFOLDER", dest)

  addToQueue: (fn, args...) ->
    @queue.push([fn, args])

  clearQueue: ->
    try
      for fn, i in @queue
        fn[0].apply(this,fn[1])
    catch err
      self.emit("MESSAGE:ADD", err.message)

  downloadRepos: ->
    if not @addonsFolderSet
      @updateAddonsFolder(@addonsFolder)
      @addToQueue(@downloadRepos)
    else
      try
        for repo, i in @repos
          url = repo.git_url
          name = repo.name
          @downloadRepo(name, url)
      catch
        self.emit("MESSAGE:ADD", err.message)

  downloadRepo: (name, url) ->
    if not @addonsFolderSet
      @updateAddonsFolder(@addonsFolder)
      @addToQueue(@downloadRepo, name, url)
    else
      console.log "downloadRepo: ->"
      console.log @addonsFolder, name
      dest = path.join(@addonsFolder, name)

      self = @
      fs.exists dest, (bool) =>
        if bool
          try
            fs.rmrfSync(dest)
          catch err
            self.emit("MESSAGE:ADD", err.message)
            self.emit("MODULE:ERROR", name)
        try
          ghdownload(url, dest)
          .on 'dir', (dir) -> console.log(dir)
          .on 'file', (file) -> console.log(file)
          .on 'zip', (zipUrl) -> console.log(zipUrl)
          .on 'error', (err) -> console.error(err)
          .on 'end', => self.emit("MODULE:DONE", name)
        catch err
          @sendError(err)


  findRepo: (id) ->
    try
      return null if @repos.length == 0

      for repo, i in @repos
        if repo.id == id then return i else return null
    catch err
      @sendError(err)


  getRepos: (owner) ->
    org = client.org(owner)
    org.repos (err, array, headers) =>
      if err
        @emit("MESSAGE:ADD", err.message)
        return
      array = @filterForBlacklist(array)
      try
        for repo, i in array
          try
            @initRepo(repo, i)
          catch err
            @sendError(err)
      catch err
        self.emit("MESSAGE:ADD", err.message)

  sendError: (err) -> self.emit("MESSAGE:ADD", err.message)

  initRepo: (repo, i) ->
    payload =
      id       : repo.id
      owner    : repo.owner.login
      name     : repo.name
      git_url  : repo.git_url
      html_url : repo.html_url
      ssh_url  : repo.ssh_url
      branches : null

    index = @findRepo(repo.id)
    if index
      @repos[index] = payload
    else
      @repos.push(payload)

    @runCommand("branches", payload)
    @runCommand("info", payload)

    self = @
    watch payload, (key, command, data) ->
      switch key
        when "branches"
          try
            for branch, i in data
              branch.html_url = "#{this.html_url}/tree/#{branch.name}"
              branch.download_url = "#{this.git_url}\##{branch.name}"
          catch err
            self.emit("MESSAGE:ADD", err.message)

      self.emit("MODULE:UPDATE", this)
    @emit("MODULE:UPDATE", payload)


  filterForBlacklist: (array) ->
    self = this
    repos = array.filter (repo) ->
      n = 0
      self.blacklist.map (name) => n += (repo.name == name)
      return repo if n == 0


  runCommand: (command, data) ->
    repo = client.repo("#{data.owner}/#{data.name}")
    repo[command] (err, response, headers) =>
      data[command] = response



module.exports = new Github()
