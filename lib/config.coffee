fs = require("fs")
path = require("path")
chalk = require("chalk")
util = require("./util")

{saveJsonFile, loadJsonFile, ensureDirExists, emitter} = util
dataDir = config = configFile = undefined

saveConfg = () ->
  saveJsonFile(config, configFile)
  emitter.emit "config:saved", config

initConfigObj = () ->
  return {
    colors: true
  }

loadConfig = () ->
  dataDir = process.env.QDHOME ? path.join(process.env.HOME, ".quick-dir")
  ensureDirExists dataDir
  configFile = path.join(dataDir, "config.json")
  config = loadJsonFile(configFile, initConfigObj)
  config.colors = true unless config.colors?
  chalk.enabled = config.colors
  emitter.emit "config:loaded", config, dataDir

getConfig = () ->
  return config

getDataDir = () ->
  return dataDir

module.exports = {
  saveConfg: saveConfg
  loadConfig: loadConfig
  getConfig: getConfig
  getDataDir: getDataDir
}

# to prevent circular require dependencies
emitter.emit "config:initialized"
