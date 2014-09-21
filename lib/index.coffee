jsonfile = require("jsonfile")
commander = require("commander")
chalk = require("chalk")
fs = require("fs")
path = require("path")
_ = require("lodash")

fatalError = (msg) ->
  console.error chalk.red(msg) if msg?
  process.exit(1)

disableExit = false
programDone = () ->
  process.exit 0 unless disableExit

runCommand = (cmd) ->
  return () ->
    # make these variables available outside of initialize scope
    dataDir = config = configFile = schemes = schemesFile = scheme = currentScheme =
      history = historyFile = commands = colors = autoCompact = history = maxHistory =
      undefined

    schemeMsg = (msg, scheme) ->
      console.error chalk.cyan("[ #{(if scheme? then scheme else currentScheme)} ]") + " - #{msg}"

    saveJsonFile = (fileName, obj) ->
      fs.writeFileSync(fileName, JSON.stringify(obj), "utf8")

    loadJsonFile = (fileName, getInitObj) ->
      return JSON.parse(fs.readFileSync(fileName, "utf8")) if fs.existsSync fileName
      obj = getInitObj()
      saveJsonFile fileName, obj
      return obj

    saveConfgFile   = () -> saveJsonFile(config, configFile)
    saveSchemesFile = () -> saveJsonFile(schemes, schemesFile)
    saveHistoryFile = () -> saveJsonFile(history, historyFile)

    initConfigObj = () ->
      return {
        color: true
        currentScheme: "default"
        autoCompact: true
        maxHistory: 10
      }

    initSchemesObj = () ->
      return {
        default:
          next: 0
          slots: {}
      }

    initHistoryObj = () ->
      return {
        slots: []
      }

    loadConfgFile   = () ->
      config = loadJsonFile(configFile, initConfigObj)

    loadSchemesFile = () ->
      schemes = loadJsonFile(schemesFile, initSchemesObj)
      scheme = schemes[currentScheme]
      return if _.isObject(scheme)
      console.error chalk.yellow "currentScheme is missing from #{schemesFile}, setting to 'default' scheme"
      initalizeScheme "default" unless _.isObject(schemes["default"])
      currentScheme = "default"
      scheme = schemes[currentScheme]

    loadHistoryFile = () ->
      history = loadJsonFile(historyFile, initHistoryObj)

    initalizeScheme = (scheme) ->
      schemes[scheme] =
        next: 0
        slots: {}
      saveSchemesFile()

    initialize = () ->
      dataDir = process.env.QDHOME ? path.join(process.env.HOME, ".quick-dir")
      fs.mkdirSync(dataDir) unless fs.existsSync(dataDir)
      configFile = path.join(dataDir, "config.json")
      schemesFile = path.join(dataDir, "schemes.json")
      historyFile = path.join(dataDir, "history.json")
      loadConfgFile()

      {currentScheme, autoCompact, maxHistory} = config
      chalk.enabled = colors = (if config.color? then config.color else true)
      fatalError("currentScheme property is missing in config.json") unless _.isString(currentScheme)

    callCommand = (cmd) ->
      disableExit = true
      args = Array.prototype.slice.call(arguments);
      args.shift()
      commands[cmd].apply(this, args)
      disableExit = false

    doAutoCompact = () ->
      schemeMsg "auto compacting is enabled"
      callCommand "compactSlots"

    # eval "$(./app.js init)"
    commands =
      init: () ->
        console.log """
        function _qdwrap() {
          local cmd newPath
          cmd="$1"
          shift
          newPath=$(/Users/james/node.js/quick-directory/app.js "$cmd" "$@")
          if [ $? -eq 0 ]; then
            cd "$newPath"
          fi
        }
        function q() {
          _qdwrap get $1
        }
        function qq() {
          _qdwrap pick
        }
        function hh() {
          _qdwrap pick-hist $1
        }
        function cd()
        {
          builtin cd "$@"
          if [[ $? -eq 0 ]]; then
            (/Users/james/node.js/quick-directory/app.js add-hist &)
          fi
        }
        """

      # _wd_scheme_completion()
      # {
      #   local cur schemedir origdir schemelist
      #   origdir=${PWD}
      #   schemedir=${WDHOME}
      #   COMPREPLY=()
      #   cur=${COMP_WORDS[COMP_CWORD]}
      #   # TODO could probably do this without cd to the scheme dir
      #   cd ${schemedir}
      #   schemelist="$(compgen -G "${cur}*.scheme")"
      #   schemelist=${schemelist#history}
      #   COMPREPLY=( ${schemelist//.scheme/} )
      #   cd ${origdir}
      # }
      # complete -o nospace -F _wd_scheme_completion wdscheme

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

      dropScheme: (scheme) ->
        fatalError "Scheme #{scheme} does not exist" unless _.isObject(data.schemes[scheme])
        console.error "Droping scheme #{chalk.cyan scheme}"
        delete data.schemes[scheme]
        writeFileSync()
        programDone()

      listSlots: () ->
        schemeMsg "listing slots"
        console.error "------------------------------"
        slots = _.sortBy(_.pairs(scheme.slots), (pair) -> parseInt(pair[0]))
        for pair in slots
          console.error "#{chalk.yellow pair[0]}\t#{chalk.grey pair[1]}"
        programDone()

      pickSlot: () ->
        callCommand "listSlots"
        programDone() unless _.keys(scheme.slots).length > 0
        readline = require "readline"
        rl = readline.createInterface
          input: process.stdin
          output: process.stderr
          terminal: colors
        rl.on "line", (line) ->
          idx = line.trim()
          if _.isString(scheme.slots[idx])
            commands.getSlot(line.trim())
          else
            rl.prompt()
        rl.prompt()

      getSlot: (idx) ->
        idx = parseInt(idx)
        fatalError "argument <idx> should be a whole number" unless _.isNumber(idx) and not _.isNaN(idx) and idx >= 0
        _path = scheme.slots[idx]
        fatalError "path #{_path} is not a string" unless _.isString(_path)
        console.log _path
        programDone()

      removeSlot: (idx) ->
        idx = parseInt(idx)
        fatalError "argument <idx> should be a whole number" unless _.isNumber(idx) and not _.isNaN(idx) and idx >= 0
        delete scheme.slots[idx]
        doAutoCompact() if autoCompact
        saveDataFile()
        programDone()

      switchSlots: (idx1, idx2) ->
        idx1 = parseInt(idx1)
        fatalError "argument <idx1> should be a whole number" unless _.isNumber(idx1) and not _.isNaN(idx1) and idx1 >= 0
        idx2 = parseInt(idx2)
        fatalError "argument <idx2> should be a whole number" unless _.isNumber(idx2) and not _.isNaN(idx2) and idx2 >= 0
        fatalError "argument <idx1> is not valid" unless _.isString(scheme.slots[idx1])
        fatalError "argument <idx2> is not valid" unless _.isString(scheme.slots[idx2])
        temp = scheme.slots[idx1]
        scheme.slots[idx1] = scheme.slots[idx2]
        scheme.slots[idx2] = temp
        saveDataFile()
        programDone()

      saveSlot: (idx, _path) ->
        if idx? and idx.match /^[0-9]+$/
          idx = parseInt(idx)
          fatalError "argument <idx> should be a whole number" unless _.isNumber(idx) and not _.isNaN(idx) and idx >= 0
        else
          # if idx is a string but not digits, assume it is the path
          _path = idx if _.isString(idx)
          idx = scheme.next

        _path = process.cwd() unless _.isString(_path)
        fatalError "path #{_path} does not exist" unless fs.existsSync _path
        scheme.slots[idx] = _path
        doAutoCompact() if autoCompact and idx > scheme.next
        scheme.next = parseInt(_.max(_.keys(scheme.slots))) + 1
        schemeMsg "saving slot #{chalk.yellow idx} as #{chalk.grey _path}"
        saveDataFile()
        programDone()

      clearSlots: () ->
        schemeMsg chalk.yellow "clearing all slots"
        scheme.slots = {}
        scheme.next = 0
        saveDataFile()
        programDone()

      compactSlots: () ->
        schemeMsg "compacting slot idx numbers"
        slotsArray = []
        for idx, slot of scheme.slots
          slotsArray.push
            idx: parseInt(idx)
            slot: slot
        slotsArray = _.sortBy(slotsArray, "idx")
        scheme.slots = {}
        for obj, idx in slotsArray
          scheme.slots[idx] = obj.slot
        scheme.next = parseInt(_.max(_.keys(scheme.slots))) + 1
        saveDataFile()
        programDone()

      # history commands
      getHistory: (idx) ->
        idx = parseInt(idx)
        fatalError "argument <idx> should be a whole number" unless _.isNumber(idx) and not _.isNaN(idx) and idx >= 0 and idx < history.slots.length
        _path = history.slots[idx]
        fatalError "path #{_path} is not a string" unless _.isString(_path)
        console.log _path
        programDone()

      addHistory: (_path) ->
        _path = process.cwd() unless _.isString(_path)
        fatalError "path #{_path} does not exist" unless fs.existsSync _path
        history.slots = (slot for slot in history.slots when slot isnt _path)
        history.slots.unshift _path
        history.slots.pop() if history.length > maxHistory
        saveDataFile()
        programDone()

      clearHistory: () ->
        console.error chalk.yellow "clearing history"
        data.history.slots = []
        saveDataFile()
        programDone()

      listHistory: () ->
        schemeMsg "listing slots", "history"
        console.error "------------------------------"
        for _path, idx in history.slots
          console.error "#{chalk.yellow idx}\t#{chalk.grey _path}"
        programDone()

      pickHistory: () ->
        callCommand "listHistory"
        programDone() unless history.slots.length > 0
        readline = require "readline"
        rl = readline.createInterface
          input: process.stdin
          output: process.stderr
          terminal: colors
        rl.on "line", (line) ->
          idx = line.trim()
          if idx >= 0 and idx < history.slots.length and _.isString(history.slots[idx])
            commands.getHistory(line.trim())
          else
            rl.prompt()
        rl.prompt()

    initialize()
    commands[cmd].apply(this, arguments)

commander
  .version(require("../package.json").version)

commander
  .command("init")
  .action(runCommand("init"));

commander
  .command("scheme [name]")
  .description("changes schemes (prints current scheme if no name is given)")
  .action(runCommand("changeScheme"));

commander
  .command("schemes")
  .action(runCommand("listSchemes"));

commander
  .command("drop")
  .action(runCommand("dropScheme"));

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
  .command("rm [idx]")
  .action(runCommand("removeSlot"));

commander
  .command("switch <idx1> <idx2>")
  .action(runCommand("switchSlots"));

commander
  .command("set [idx] [path]")
  .action(runCommand("saveSlot"));

commander
  .command("clear")
  .action(runCommand("clearSlots"));

commander
  .command("compact")
  .action(runCommand("compactSlots"));

commander
  .command("add-hist")
  .action(runCommand("addHistory"));

commander
  .command("clear-hist")
  .action(runCommand("clearHistory"));

commander
  .command("pick-hist")
  .action(runCommand("pickHistory"));

commander
  .command("*")
  .description("output usage information")
  .action(commander.help)

commander.parse(process.argv);