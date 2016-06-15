fs = require 'fs'
path = require 'path'

module.exports = (robot, scripts) ->

  #TODO: make error logging an external script
  robot.error (err, res) ->
    robot.logger.error "#{err}\n#{err.stack}"
    if res?
      res.reply "#{err}\n#{err.stack}"

  scriptsPath = path.resolve(__dirname, 'src')
  fs.exists scriptsPath, (exists) ->
    if exists
      for script in fs.readdirSync(scriptsPath)
        if scripts? and '*' not in scripts
          robot.loadFile(scriptsPath, script) if script in scripts
        else
          robot.loadFile(scriptsPath, script)
