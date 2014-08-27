"use strict"
 
path = require 'path'
exports.defaults = ->
  amdify:
    path: './assets/javascripts/app/'
    envVars: ['browser','ecmaIdentifiers','reservedVars']
 
exports.placeholder = ->
  """
  \t
 
    amdify:          # Configuration for the mimosa-require-admify module
      path: './assets/javascripts/app/'
      envVars: ['browser','ecmaIdentifiers','reservedVars']
      globals: {'jquery':['jQuery','$']}
  """
 
exports.validate = (config, validators) ->
  errors = []
 
  if validators.ifExistsIsObject(errors, "amdify config", config.amdify)
    javascriptDir = path.join config.watch.sourceDir, config.watch.javascriptDir
    validators.ifExistsFileExcludeWithRegexAndString(errors, "amdify.exclude", config.amdify, javascriptDir)
 
  errors