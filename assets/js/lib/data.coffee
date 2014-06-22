
path         = require('path')
fs           = require('fs.extra')
nedb         = require('nedb')
appDir       = path.dirname(require.main.filename)

db           = new nedb({ filename: path.join(appDir, 'data', 'db.json') })


class Data
  db: null

  constructor: ->
    @db = db
    return

  set: (data) ->
    @db.insert(data)

module.exports = window.Data = new Data()