commander = require("commander")
# chalk = require("chalk")
fs = require("fs")
path = require("path")
_ = require("lodash")
util = require("./util")
config = require("./config")
cmds = require("./commands")

{runCommand, emitter, programDone} = util

# load plugins
util.requireFiles path.join(__dirname, "plugins"), /(\.coffee|\.js)$/

initStr = (cacheFile) ->
  return """
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
    shift
    _qdwrap get "$@"
  }
  function qs() {
    shift
    _qdwrap set "$@"
  }
  function qq() {
    _qdwrap pick
  }
  function h() {
    shift
    _qdwrap get-hist "$@"
  }
  function hh() {
    _qdwrap pick-hist
  }
  function cd()
  {
    builtin cd "$@"
    if [[ $? -eq 0 ]]; then
      (/Users/james/node.js/quick-directory/app.js _cd &)
    fi
  }
  _qd_completion()
  {
    local cur prev opts job
    COMPREPLY=()
    job="${COMP_WORDS[0]}"
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    if [[ -s "#{cacheFile}" ]]; then
      opts=$(cat "#{cacheFile}")
    else
      opts=$(${job} _bash_complete)
    fi
    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
    return 0
  }
  complete -o nospace -F _qd_completion /Users/james/node.js/quick-directory/app.js
  """

defaultCommands =

  # eval "$(./app.js init)"
  init: (cache) ->
    cacheFile = path.join(config.getDataDir(), "bash_completions")
    if cache
      str = initStr(cacheFile)
      initFile = path.join(config.getDataDir(), "init.sh")
      oldStr = (if fs.existsSync(initFile) then fs.readFileSync initFile, "utf8" else null)
      fs.writeFileSync initFile, str, "utf8" if str != oldStr
    else
      console.log initStr(cacheFile)
    programDone()

  _bash_complete: () ->
    str = (cmd._name for cmd in commander.commands when cmd._name isnt "*").join(" ")
    console.log str
    cacheCompletions str
    programDone()

  _cd: () ->
    _path = process.cwd()
    return unless fs.existsSync _path
    emitter.emit "cd:path", _path
    programDone()

cmds.extend defaultCommands

cacheCompletions = (str) ->
  cacheFile = path.join(config.getDataDir(), "bash_completions")
  str ?= (cmd._name for cmd in commander.commands when cmd._name isnt "*").join(" ")
  oldStr = (if fs.existsSync(cacheFile) then fs.readFileSync cacheFile, "utf8" else null)
  fs.writeFileSync cacheFile, str, "utf8" if str != oldStr

# check for private commands first (start with underscore)
if process.argv.length == 3
  privateCmds = (cmd for cmd in _.keys(cmds.commands) when cmd.match /^_\w+$/)
  cmd = process.argv[2]
  for privateCmd in privateCmds
    do runCommand(cmd) if cmd is privateCmd

commander
  .version(require("../package.json").version)

commander
  .command("init [cache]")
  .action(runCommand("init"));

commander
  .command("*")
  .description("output usage information")
  .action(commander.help)

commander.parse(process.argv);