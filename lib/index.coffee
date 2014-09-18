jsonfile = require('jsonfile')
commander = require('commander')
chalk = require('chalk')
fs = require('fs')
path = require('path')
_ = require('lodash')

runCommand = (cmd) ->
  return () ->
    # make these variables available outside of initialize scope
    dataDir = currentSchemeFile = currentScheme = schemeFile = commands = undefined

    initialize = () ->
      dataDir = process.env.QDHOME ? path.join(process.env.HOME, ".quick-dir")
      fs.mkdirSync(dataDir) unless fs.existsSync(dataDir)
      currentSchemeFile = path.join(dataDir, "currentScheme")
      currentScheme = null
      if fs.existsSync(currentSchemeFile)
        currentScheme = fs.readFileSync(currentSchemeFile, 'utf8')
        schemeFile = path.join(dataDir, "#{currentScheme}.scheme")
      else
        commands.changeScheme "default"

    #prompt.message = "(crypto-pass)"
    #cacheFile = (commander.config ? commander.config : path.join(getUserHome(), ".crypto-pass"));

    #if (fs.existsSync(cacheFile)) {
    #  cache = jsonfile.readFileSync(cacheFile);
    #}

    # load config
    #config = cache._config;

    commands =
      printCurrentScheme: () ->
        console.log currentScheme
        return 0

      initalizeSchemeFile: () ->
        init =
          slots: {}
        fs.writeFileSync(schemeFile, JSON.stringify(init), "utf8")

      changeScheme: (name) ->
        return 1 if name is currentScheme
        return commands.printCurrentScheme() unless name?
        fs.writeFileSync(currentSchemeFile, name, "utf8")
        currentScheme = name
        schemeFile = path.join(dataDir, "#{currentScheme}.scheme")
        commands.initalizeSchemeFile() unless fs.existsSync(schemeFile)
        return 0

      listSlots: () ->
        return 1 unless fs.existsSync schemeFile
        scheme = JSON.parse(fs.readFileSync(schemeFile), "utf8")
        console.log currentScheme
        console.log "------------------------------"
        for idx, slot of scheme.slots
          console.log "#{idx}\t#{slot}"
        return 0

      getSlot: (idx) ->
        return 1 unless fs.existsSync schemeFile
        idx = parseInt(idx)
        return 1 unless _.isNumber(idx) and not _.isNaN(idx)
        scheme = JSON.parse(fs.readFileSync(schemeFile), "utf8")
        _path = scheme.slots[idx]
        return 1 unless _.isString(_path)
        console.log _path
        return 0

      saveSlot: (idx, _path) ->
        #console.log "foo1: #{idx} #{_path} #{schemeFile}"
        return 1 unless fs.existsSync schemeFile
        idx = parseInt(idx)
        #console.log "foo1.b: #{idx}"
        return 1 unless _.isNumber(idx) and not _.isNaN(idx)
        #console.log "foo1.c: #{schemeFile}"
        scheme = JSON.parse(fs.readFileSync(schemeFile), "utf8")
        _path = process.cwd() unless _.isString(_path)
        return 1 unless fs.existsSync _path
        #console.log "foo2: #{idx} #{_path} #{JSON.stringify(scheme)}"
        scheme.slots[idx] = _path
        #console.log "foo3: #{JSON.stringify(scheme)}"
        fs.writeFileSync(schemeFile, JSON.stringify(scheme), "utf8")
        #console.log "foo4"
        return 0

      clearSlots: () ->
        return 1 unless fs.existsSync schemeFile
        scheme = JSON.parse(fs.readFileSync(schemeFile), "utf8")
        scheme.slots = {}
        fs.writeFileSync(schemeFile, JSON.stringify(scheme), "utf8")
        return 0

      compactSlots: () ->
        return 1 unless fs.existsSync schemeFile
        scheme = JSON.parse(fs.readFileSync(schemeFile), "utf8")
        slotsArray = []
        for idx, slot of scheme.slots
          slotsArray.push
            idx: parseInt(idx)
            slot: slot
        slotsArray = _.sortBy(slotsArray, 'idx')
        scheme.slots = {}
        for obj, idx in slotsArray
          scheme.slots[idx] = obj.slot
        fs.writeFileSync(schemeFile, JSON.stringify(scheme), "utf8")
        return 0

    initialize()
    #util = require 'util'
    #console.log "#{arguments} : #{util.inspect(arguments)}"
    commands[cmd].apply(this, arguments);

commander
  .version(require("../package.json").version)

commander
  .command('scheme [name]')
  .description('changes schemes (list current scheme is no name is given)')
  .action(runCommand("changeScheme"));

commander
  .command("listSlots")
  .action(runCommand("listSlots"));

commander
  .command("getSlot <idx>")
  .action(runCommand("getSlot"));

commander
  .command("saveSlot <idx> [path]")
  .action(runCommand("saveSlot"));

commander
  .command("clearSlots")
  .action(runCommand("clearSlots"));

commander
  .command("compactSlots")
  .action(runCommand("compactSlots"));

commander
  .command('*')
  .description('output usage information')
  .action(commander.help)

commander.parse(process.argv);