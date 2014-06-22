var Data, appDir, db, fs, nedb, path;

path = require('path');

fs = require('fs.extra');

nedb = require('nedb');

appDir = path.dirname(require.main.filename);

db = new nedb({
  filename: path.join(appDir, 'data', 'db.json')
});

Data = (function() {
  Data.prototype.db = null;

  function Data() {
    this.db = db;
    return;
  }

  Data.prototype.set = function(data) {
    return this.db.insert(data);
  };

  return Data;

})();

module.exports = window.Data = new Data();
