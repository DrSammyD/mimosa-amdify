"use strict"
 
path = require 'path'
exports.defaults = ->
  amdify:
 
exports.placeholder = ->
  """
  \t
 
    amdify:          # Configuration for the mimosa-require-admify module
      globals: {'jquery':['jQuery','$']}
      overrides:[]
  """
 
exports.validate = (config, validators) ->
  errors = []
 
  if validators.ifExistsIsObject(errors, "amdify config", config.amdify)
    javascriptDir = path.join config.watch.sourceDir, config.watch.javascriptDir
    validators.ifExistsFileExcludeWithRegexAndString(errors, "amdify.exclude", config.amdify, javascriptDir)
 
  errors