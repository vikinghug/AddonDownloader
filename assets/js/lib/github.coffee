db           = window.localStorage

_            = require('underscore')
cs           = require('calmsoul')
path         = require('path')
fs           = require('fs.extra')
exec         = require('exec')
request      = require('superagent')
github       = require('octonode')
ghdownload   = require('github-download')
WatchJS      = require('watchjs')
Git          = require('git-wrapper')
watch        = WatchJS.watch
unwatch      = WatchJS.unwatch
callWatchers = WatchJS.callWatchers
EventEmitter = require('events').EventEmitter
require('shelljs/global')

appData = if process.env.APPDATA? then process.env.APPDATA else path.join(process.env.HOME, '.downloads')

keys = [
  '894b9db89f78b7142263966c69cabf63cec31a19'
  '96234b48504bcb43a1d0a9e11cd7e596b45f4e54'
  '16cd039c3347e9689bf2e7d3eccdcfb627bec2fc'
  '3fe23a32720c1d08a38dc488c3e5128ea809fdaa']
getKey = -> return keys[Math.floor(Math.random() * keys.length + 1)]

client = github.client(getKey())
git    = new Git()

cs.set
  'info': true

class Github extends EventEmitter

  blacklist: [
    'AddonDownloader'
    'vikinghug.com'
    'VikingActionBarSet'
    'VikingDocs'
    'VikingQuestTrackerSet'
    'VikingMedic'
  ]

  whitelist: [
    'VikingActionBarFrame'
    'VikingActionBarShortcut'
    'VikingBuddies'
    'VikingClassResources'
    'VikingContextMenuPlayer'
    'VikingGroupFrame'
    'VikingHealthShieldBar'
    'Vikinghug'
    'VikingInventory'
    'VikingLibrary'
    'VikingMiniMap'
    'VikingNameplates'
    'VikingSettings'
    'VikingSprintMeter'
    'VikingTooltips'
    'VikingTradeskills'
    'VikingUnitFrames'
    'VikingXPBar'
  ]

  queue           : []

  constructor: ->
    self = @
    watch @, ['addonsFolderSet'], (key, command, data) ->
      self.clearQueue() if data
    return

  init: ->
    if db.addonsFolderSet == 'false'
      cs.debug 'NOPE'
      @updateAddonsFolder path.join(appData, 'NCSOFT', 'WildStar', 'addons')

  setRepos: (repos) -> db.repos = repos

  setAddonsFolder: (dest) ->
    db.addonsFolderSet = true
    return db.addonsFolder = dest

  updateAddonsFolder: (dest) -> @emit('CONFIG:SET:ADDONSFOLDER', dest)

  addToQueue: (fn, args...) ->
    @queue.push([fn, args])

  clearQueue: ->
    try
      for fn, i in @queue
        fn[0].apply(this,fn[1])
    catch err
      @emit('MESSAGE:ADD', err.message)

  downloadRepos: ->
    if not db.addonsFolderSet
      @updateAddonsFolder(db.addonsFolder)
      @addToQueue(@downloadRepos)
    else
      try
        for repo, i in JSON.parse( db.repos )
          id = repo.id
          name = repo.name
          @downloadRepo(name, id)
      catch err
        @emit('MESSAGE:ADD', err.message)

  downloadRepo: (name, id) ->
    repo          = @findRepo(id)
    cs.debug repo
    currentBranch = repo.current_branch
    url           = _.findWhere(repo.branches, {name: currentBranch}).download_url
    if not db.addonsFolderSet
      @updateAddonsFolder(db.addonsFolder)
      @addToQueue(@downloadRepo, name, url)
    else
      cs.debug 'downloadRepo: ->'
      cs.debug db.addonsFolder, name
      dest = path.join(db.addonsFolder, name)

      self = @
      fs.exists dest, (bool) =>
        if bool
          try
            fs.rmrfSync(dest)
          catch err
            self.emit('MESSAGE:ADD', err.message)
            self.emit('MODULE:ERROR', name)
        try
          if (which('git'))
            cs.info "# GIT EXISTS, CLONING REPO"
            urlsplit = url.split('#')
            url = urlsplit[0]
            branch = urlsplit[1]

            git.exec 'clone', {b: branch}, [url, dest], (err) =>
              self.sendError(err) if err
              self.emit("MODULE:DONE", name)
          else
            cs.info "# GIT DOES NOT EXIST, DOWNLOADING REPO"
            ghdownload(url, dest)
              .on 'dir', (dir) -> cs.debug(dir)
              .on 'file', (file) -> cs.debug(file)
              .on 'zip', (zipUrl) -> cs.debug(zipUrl)
              .on 'error', (err) -> console.error(err)
              .on 'end', => self.emit("MODULE:DONE", name)

        catch err
          @sendError(err)


  findRepo: (id) ->
    repos = JSON.parse( db.getItem('repos') )
    index = @findRepoIndex(id)
    return repos[index]


  findRepoIndex: (id) ->
    cs.debug 'findRepoIndex', id
    try
      repos = JSON.parse( db.getItem('repos') )
      return null if repos.length == 0
      for repo, i in repos
        return i if repo.id == id
      return null
    catch err
      @sendError(err)

  resetBranches: (branch) ->
    repos = JSON.parse(db.getItem('repos'))
    for key, value of repos
      @setBranch(value.id, branch)

  setBranch: (id, branch) ->
    cs.debug 'setBranch'
    try
      repos = JSON.parse( db.getItem('repos') )
      index = @findRepoIndex(id)
      cs.debug 'index: ', index
      branch = branch ? 'master'
      repos[index].current_branch = branch
      return @updateRepo(repos[index], index)
    catch err
      @sendError(err)

  addRepo: (repo, branch) ->
    cs.debug 'addRepo'
    try
      repos = JSON.parse(db.getItem('repos'))
      repos.push(repo)
      db.repos = JSON.stringify(repos)
      return repo
    catch err
      @sendError(err)

  updateRepo: (repo, index) ->
    cs.debug 'updateRepo'
    try
      repos = JSON.parse( db.getItem('repos') )
      repo = _.extend(repos[index], repo)
      repos[index].current_branch = repos[index].current_branch ? 'master'
      repos[index].branches = @updateBranches(repos[index].branches, repos[index].current_branch)
      cs.debug repos[index]
      cs.debug repos[index].branches
      db.repos = JSON.stringify(repos)
      return repos[index]
    catch err
      @sendError(err)

  updateBranches: (branches, currentBranch) ->
    for key, value of branches
      value.current = if value.name == currentBranch then true else false
    return branches

    # cs.debug branches

  getRepos: (owner) ->
    db.setItem('repos', JSON.stringify([])) if db.repos == undefined
    self = this
    request
    .get('http://api.vikinghug.com/repos')
    .end (res) =>
      for repo, i in res.body
        index = self.findRepoIndex(repo.id)
        if index != null and index != undefined
          repo = self.updateRepo(repo, index)
        else
          repo = self.addRepo(repo)
          repo = self.setBranch(repo.id)

        self.emit('MODULE:UPDATE', repo)

  sendError: (err) -> @emit('MESSAGE:ADD', err.message)


  filterForWhitelist: (array) ->
    self = this
    repos = array.filter (repo) ->
      n = 0
      self.blacklist.map (name) => n += (repo.name == name)
      return repo if n > 0

  filterForBlacklist: (array) ->
    self = this
    repos = array.filter (repo) ->
      n = 0
      self.blacklist.map (name) => n += (repo.name == name)
      return repo if n == 0




module.exports = new Github()
