jsonfile = require('jsonfile')
commander = require('commander')
chalk = require('chalk')
fs = require('fs')
path = require('path')
_ = require('lodash')

fatalError = (msg) ->
  console.error chalk.red(msg) if msg?
  process.exit(1)

programDone = () ->
  process.exit 0

runCommand = (cmd) ->
  return () ->
    # make these variables available outside of initialize scope
    dataDir = data = dataFile = currentScheme = scheme = commands = colors = undefined

    schemeMsg = (msg) ->
      console.error chalk.cyan("[ #{currentScheme} ]") + " - #{msg}"

    saveDataFile = () ->
      fs.writeFileSync(dataFile, JSON.stringify(data), "utf8")

    initalizeScheme = (scheme) ->
        data.schemes[scheme] =
          slots: {}
        saveDataFile()

    initialize = () ->
      dataDir = process.env.QDHOME ? path.join(process.env.HOME, ".quick-dir")
      fs.mkdirSync(dataDir) unless fs.existsSync(dataDir)
      dataFile = path.join(dataDir, "data.json")
      if fs.existsSync dataFile
        data = JSON.parse(fs.readFileSync(dataFile, "utf8"))
      else
        data =
          currentScheme: "default"
          color: true
          schemes: {}
        initalizeScheme "default"
      currentScheme = data.currentScheme
      chalk.enabled = colors = (if data.color? then data.color else true)
      fatalError("currentScheme property is missing in data.json") unless _.isString(currentScheme)
      scheme = data.schemes[currentScheme]
      fatalError("#{currentScheme} scheme object is missing in data.json") unless _.isObject(scheme)
      fatalError("#{currentScheme} scheme object is missing slots property in data.json") unless _.isObject(scheme.slots)

    #prompt.message = "(crypto-pass)"
    #cacheFile = (commander.config ? commander.config : path.join(getUserHome(), ".crypto-pass"));

    #if (fs.existsSync(cacheFile)) {
    #  cache = jsonfile.readFileSync(cacheFile);
    #}

    # load config
    #config = cache._config;

    commands =
      init: () ->
        console.log """
        function qd() {
          local newPath
          newPath=$(/Users/james/node.js/quick-directory/app.js get $1)
          if [ $? -eq 0 ]; then
            cd "$newPath"
          fi
        }
        """

      printCurrentScheme: () ->
        console.error currentScheme
        programDone()

      changeScheme: (name) ->
        commands.printCurrentScheme() unless name?
        programDone() if name is currentScheme

        data.currentScheme = currentScheme = name
        console.error "changing scheme to #{chalk.cyan name}"
        if _.isObject(data.schemes[name])
          saveDataFile()
        else
          console.error chalk.grey "initializing empty scheme object"
          initalizeScheme name
        programDone()

      listSchemes: () ->
        console.error "schemes"
        console.error "------------------------------"
        for scheme in _.keys(data.schemes)
          console.error chalk.gray scheme

      listSlots: (noExit) ->
        schemeMsg "listing slots"
        console.error "------------------------------"
        slots = _.sortBy(_.pairs(scheme.slots), (pair) -> parseInt(pair[0]))
        for pair in slots
          console.error "#{chalk.yellow pair[0]}\t#{chalk.grey pair[1]}"
        programDone() unless _.isBoolean(noExit) and noExit

      pickSlot: () ->
        commands.listSlots(true)
        readline = require "readline"
        rl = readline.createInterface
          input: process.stdin
          output: process.stderr
          terminal: colors
        rl.on "line", (line) ->
          commands.getSlot(line.trim())
        rl.prompt()

      getSlot: (idx) ->
        idx = parseInt(idx)
        fatalError "argument <idx> should be a whole number" unless _.isNumber(idx) and not _.isNaN(idx) and idx >= 0
        _path = scheme.slots[idx]
        fatalError "path #{_path} is not a string" unless _.isString(_path)
        console.log _path
        programDone()

      saveSlot: (idx, _path) ->
        idx = parseInt(idx)
        fatalError "argument <idx> should be a whole number" unless _.isNumber(idx) and not _.isNaN(idx) and idx >= 0
        _path = process.cwd() unless _.isString(_path)
        fatalError "path #{_path} does not exist" unless fs.existsSync _path
        scheme.slots[idx] = _path
        schemeMsg "saving slot #{chalk.yellow idx} as #{chalk.grey _path}"
        saveDataFile()
        programDone()

      clearSlots: () ->
        schemeMsg chalk.yellow "clearing all slots"
        scheme.slots = {}
        saveDataFile()
        programDone()

      compactSlots: () ->
        schemeMsg "compacting slot idx numbers"
        slotsArray = []
        for idx, slot of scheme.slots
          slotsArray.push
            idx: parseInt(idx)
            slot: slot
        slotsArray = _.sortBy(slotsArray, 'idx')
        scheme.slots = {}
        for obj, idx in slotsArray
          scheme.slots[idx] = obj.slot
        saveDataFile()
        programDone()

    initialize()
    commands[cmd].apply(this, arguments);

commander
  .version(require("../package.json").version)

commander
  .command("init")
  .action(runCommand("init"));

commander
  .command('scheme [name]')
  .description('changes schemes (prints current scheme if no name is given)')
  .action(runCommand("changeScheme"));

commander
  .command("schemes")
  .action(runCommand("listSchemes"));

commander
  .command("list")
  .action(runCommand("listSlots"));

commander
  .command("pick")
  .action(runCommand("pickSlot"));

commander
  .command("get <idx>")
  .action(runCommand("getSlot"));

commander
  .command("set <idx> [path]")
  .action(runCommand("saveSlot"));

commander
  .command("clear")
  .action(runCommand("clearSlots"));

commander
  .command("compact")
  .action(runCommand("compactSlots"));

commander
  .command('*')
  .description('output usage information')
  .action(commander.help)

commander.parse(process.argv);