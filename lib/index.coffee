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

defaultCommands =

  # eval "$(./app.js init)"
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

      opts=$(${job} _bash_complete)
      COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
      return 0
    }
    complete -o nospace -F _qd_completion /Users/james/node.js/quick-directory/app.js
    """
    programDone()

  _bash_complete: () ->
    console.log (cmd._name for cmd in commander.commands when cmd._name isnt "*").join(" ")
    programDone()

  _cd: () ->
    _path = process.cwd()
    return unless fs.existsSync _path
    emitter.emit "cd:path", _path
    programDone()

cmds.extend defaultCommands


# check for private commands first (start with underscore)
if process.argv.length == 3
  privateCmds = (cmd for cmd in _.keys(cmds.commands) when cmd.match /^_\w+$/)
  cmd = process.argv[2]
  for privateCmd in privateCmds
    do runCommand(cmd) if cmd is privateCmd

commander
  .version(require("../package.json").version)

commander
  .command("init")
  .action(runCommand("init"));

commander
  .command("*")
  .description("output usage information")
  .action(commander.help)

commander.parse(process.argv);