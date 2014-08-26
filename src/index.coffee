"use strict"

config = require './config'
config = require 'jshint'
defineRegex = /(?:(?!\.))define\(/
logger = null  

registration = (mimosaConfig, register) ->
  ending = mimosaConfig.amdify.ending||ending
  starting = mimosaConfig.amdify.starting||starting
  

  createEndingRegex= mimosaConfig.amdify.createEndingRegex||createEndingRegex
  endingRegex=createEndingRegex(mimosaConfig.amdify.endingRegex||endingRegex, mimosaConfig.amdify)
  logger = mimosaConfig.log
  register ['add','update','buildFile'], 'afterCompile', _applyCommonJSWrapper,  [mimosaConfig.extensions.javascript...]

_applyCommonJSWrapper = (mimosaConfig, options, next) ->
  hasFiles = options.files?.length > 0
  return next() unless hasFiles

  for file in options.files
    if file.outputFileText?
      if file.outputFileText.match defineRegex
        if logger.isDebug()
          logger.debug "Not wrapping [[ #{file.inputFileName} ]], it already contains a define block"
      else if file.outputFileText.match endingRegex && !mimosaConfig.amdify?[file.inputFileName]?
          logger.debug "Not wrapping [[ #{file.inputFileName} ]], it already contains a define block"
      else
        if logger.isDebug()
          logger.debug "amdify wrapping [[ #{file.inputFileName} ]]"

        file.outputFileText = _wrap(file.outputFileText,mimosaConfig.amdify)
    else
      logger.debug "skipping amdify wrapping for [[ #{file.inputFileName} ]], file has no text"
  next()

_wrap = (text, amdify) ->
  fileConf=mimosaConfig.amdify?[file.inputFileName]

module.exports =
  registration: registration
  defaults:     config.defaults
  placeholder:  config.placeholder
  validate:     config.validate