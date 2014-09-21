_ = require("lodash")

commands = {}

extend = (moreCommands) ->
  _.extend(commands, moreCommands)

module.exports = {
  commands: commands
  extend: extend
}