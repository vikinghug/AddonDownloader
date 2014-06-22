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
addonsFolder = process.env.LOCALAPPDATA

# this is a generic token
client = github.client("b88ebd287229cba593058175b38b059b13af6034")

class Github extends EventEmitter

  blacklist: [
    "vikinghug.com"
    "VikingBuddies"
  ]

  repos: []

  constructor: -> return

  setRepos: (repos) ->
    @repos = repos

  downloadRepos: ->
    for repo, i in @repos
      url = repo.git_url
      name = repo.name
      @downloadRepo(name, url)

  downloadRepo: (name, url) ->
    dest = "./downloads/#{name}"
    self = @
    fs.exists dest, (bool) =>
      if bool then fs.rmrfSync dest

      ghdownload(url, dest)
      .on 'dir', (dir) -> console.log(dir)
      .on 'file', (file) -> console.log(file)
      .on 'zip', (zipUrl) -> console.log(zipUrl)
      .on 'error', (err) -> console.error(err)
      .on 'end', =>
        try
          addonDir = path.join(__dirname, "App", "downloads", name)
          fs.move addonDir, addonsFolder
        catch err
          self.emit("MESSAGE:ADD", err.message)


  findRepo: (id) ->
    return null if @repos.length == 0

    for repo, i in @repos
      if repo.id == id then return i else return null

  getRepos: (owner) ->
    org = client.org(owner)
    org.repos (err, array, headers) =>
      if err
        console.log err
        return
      array = @filterForBlacklist(array)

      for repo, i in array
        @initRepo(repo, i)

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


    # @runCommand("releases", payload)
    @runCommand("branches", payload)
    @runCommand("info", payload)

    self = @
    watch payload, (key, command, data) ->
      switch key
        when "branches"
          for branch, i in data
            branch.html_url = "#{this.html_url}/tree/#{branch.name}"
            branch.download_url = "#{this.git_url}\##{branch.name}"
      Data.set(payload)
      self.emit("UPDATE", this)
    @emit("UPDATE", payload)
    Data.set(@repos)

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