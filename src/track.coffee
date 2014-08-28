path = require 'path'
fs = require 'fs'

_ = require 'lodash'
wrench = require "wrench"

logger = null

_makeDirectory = (folder) ->
  unless fs.existsSync folder
    wrench.mkdirSyncRecursive folder, 0o0777

_writeJSON = (json, outPath) ->
  jsonString = JSON.stringify json, null, 2
  _makeDirectory path.dirname(outPath)
  fs.writeFileSync outPath, jsonString

_readAnalyzedFileListJSON = (mimosaConfig) ->
  lastAnalyzedFileListPath = _lastAnalyzedFileListPath(mimosaConfig)
  if require.cache[lastAnalyzedFileListPath]
    delete require.cache[lastAnalyzedFileListPath]
  try
    lastAnalyzedJSON = require lastAnalyzedFileListPath
  catch err
    logger.error "Error reading amdify.json [[ #{lastAnalyzedFileListPath} ]]"
    logger.error err

  lastAnalyzedJSON

_lastAnalyzeAmdifyJSONPath = (mimosaConfig) ->
  path.join mimosaConfig.root, '.mimosa', 'amdify', 'last-analyze.json'

_lastMimosaConfigJSONPath = (mimosaConfig) ->
  path.join mimosaConfig.root, '.mimosa', 'amdify', 'last-mimosa-config.json'

_lastAnalyzedFileListPath = (mimosaConfig) ->
  path.join mimosaConfig.root, '.mimosa', 'amdify', 'last-analyzed-files.json'

_isEqual = (obj1, obj2) ->
  JSON.stringify(obj1) is JSON.stringify(obj2)


exports.track = (mimosaConfig, analyzedFiles, appendIntalledFiles) ->
  unless logger
    logger = mimosaConfig.log

  amdifyConfigOutPath = _lastMimosaConfigJSONPath mimosaConfig

  currentAmdifyConfig = _.cloneDeep(mimosaConfig.amdify)
  _writeJSON currentAmdifyConfig, amdifyConfigOutPath
  _writeAnalyzedFiles mimosaConfig, analyzedFiles, appendIntalledFiles

exports.removeTrackFiles = (mimosaConfig) ->
  unless logger
    logger = mimosaConfig.log

  [_lastAnalyzeAmdifyJSONPath(mimosaConfig)
  _lastMimosaConfigJSONPath(mimosaConfig)
  _lastAnalyzedFileListPath(mimosaConfig)].forEach (filepath) ->
    if fs.existsSync filepath
      fs.unlinkSync filepath

exports.getPreviousAnalyzedFileList = (mimosaConfig) ->
  unless logger
    logger = mimosaConfig.log

  analyzedFilePath = _.object(_lastAnalyzedFileListPath mimosaConfig)
  try
    require analyzedFilePath
  catch err
    logger.debug err
    {}
_sort=(item)->item[0]
_writeAnalyzedFiles = (mimosaConfig, analyzedFiles={}, appendIntalledFiles={}) ->
  outPath = _lastAnalyzedFileListPath mimosaConfig

  # remove root and path sep from all analyze paths
  filesMinusRoot=analyzedFiles
  previous = exports.getPreviousAnalyzedFileList(mimosaConfig)
  _.assign filesMinusRoot, previous, appendIntalledFiles

  if !_isEqual(_(previous).pairs().sortBy(_sort).value(),_(filesMinusRoot).pairs().sortBy(_sort).value())
    # remove dupes, then sort to avoid unnecessary diffs in file
    filesMinusRoot = _(filesMinusRoot).pairs().sortBy(_sort).value();
    #= _.sortBy filesMinusRoot, (i) -> i.length
    _writeJSON filesMinusRoot, outPath

exports.isAnalyzeNeeded = (mimosaConfig) ->
  unless logger
    logger = mimosaConfig.log

  try
    oldAmdifyConfig = require _lastMimosaConfigJSONPath(mimosaConfig)
    logger.debug "Found old amdify config"
  catch err
    logger.debug "Could not find old amdify config, analyze needed", err
    return true

  currentAmdifyConfig = _.cloneDeep(mimosaConfig.amdify)
  if _isEqual(currentAmdifyConfig, oldAmdifyConfig)
    logger.debug "Old amdify config matches current, and older amdify.json matches current"
    false
  else
    true