"use strict"

fs = require 'fs'
path = require 'path'

_ = require 'lodash'

logger = null
amdify = null


_removeFile = (fileName) ->
  try
    fs.unlinkSync fileName
    logger.info "Removed file [[ #{fileName} ]]"
  catch err
    logger.warn "Unable to clean file [[ #{fileName} ]], was it moved from this location or already cleaned?"
_cleanFilesViaTrackingInfo = (mimosaConfig) ->
  track = require './track'
  installedFiles = track.getPreviousInstalledFileList mimosaConfig
  if installedFiles.length is 0
    logger.info "No files to clean."
  else
    installedFiles.map (installedFile) ->
      path.join mimosaConfig.root, installedFile
    .forEach _removeFile
  track.removeTrackFiles mimosaConfig
  logger.success "Amdify files cleaned."

exports.amdifyClean = (mimosaConfig, opts) ->
  logger = mimosaConfig.log

  unless mimosaConfig.amdify
    amdify = require "amdify"


  amdify.config.directory = mimosaConfig.amdify.amdifyDir.path

  _cleanFilesViaTrackingInfo mimosaConfig
