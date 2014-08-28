var fs, logger, path, wrench, _, _isEqual, _lastAnalyzeAmdifyJSONPath, _lastAnalyzedFileListPath, _lastMimosaConfigJSONPath, _makeDirectory, _readAnalyzedFileListJSON, _sort, _writeAnalyzedFiles, _writeJSON;

path = require('path');

fs = require('fs');

_ = require('lodash');

wrench = require("wrench");

logger = null;

_makeDirectory = function(folder) {
  if (!fs.existsSync(folder)) {
    return wrench.mkdirSyncRecursive(folder, 0x1ff);
  }
};

_writeJSON = function(json, outPath) {
  var jsonString;
  jsonString = JSON.stringify(json, null, 2);
  _makeDirectory(path.dirname(outPath));
  return fs.writeFileSync(outPath, jsonString);
};

_readAnalyzedFileListJSON = function(mimosaConfig) {
  var err, lastAnalyzedFileListPath, lastAnalyzedJSON;
  lastAnalyzedFileListPath = _lastAnalyzedFileListPath(mimosaConfig);
  if (require.cache[lastAnalyzedFileListPath]) {
    delete require.cache[lastAnalyzedFileListPath];
  }
  try {
    lastAnalyzedJSON = require(lastAnalyzedFileListPath);
  } catch (_error) {
    err = _error;
    logger.error("Error reading amdify.json [[ " + lastAnalyzedFileListPath + " ]]");
    logger.error(err);
  }
  return lastAnalyzedJSON;
};

_lastAnalyzeAmdifyJSONPath = function(mimosaConfig) {
  return path.join(mimosaConfig.root, '.mimosa', 'amdify', 'last-analyze.json');
};

_lastMimosaConfigJSONPath = function(mimosaConfig) {
  return path.join(mimosaConfig.root, '.mimosa', 'amdify', 'last-mimosa-config.json');
};

_lastAnalyzedFileListPath = function(mimosaConfig) {
  return path.join(mimosaConfig.root, '.mimosa', 'amdify', 'last-analyzed-files.json');
};

_isEqual = function(obj1, obj2) {
  return JSON.stringify(obj1) === JSON.stringify(obj2);
};

exports.track = function(mimosaConfig, analyzedFiles, appendIntalledFiles) {
  var amdifyConfigOutPath, currentAmdifyConfig;
  if (!logger) {
    logger = mimosaConfig.log;
  }
  amdifyConfigOutPath = _lastMimosaConfigJSONPath(mimosaConfig);
  currentAmdifyConfig = _.cloneDeep(mimosaConfig.amdify);
  _writeJSON(currentAmdifyConfig, amdifyConfigOutPath);
  return _writeAnalyzedFiles(mimosaConfig, analyzedFiles, appendIntalledFiles);
};

exports.removeTrackFiles = function(mimosaConfig) {
  if (!logger) {
    logger = mimosaConfig.log;
  }
  return [_lastAnalyzeAmdifyJSONPath(mimosaConfig), _lastMimosaConfigJSONPath(mimosaConfig), _lastAnalyzedFileListPath(mimosaConfig)].forEach(function(filepath) {
    if (fs.existsSync(filepath)) {
      return fs.unlinkSync(filepath);
    }
  });
};

exports.getPreviousAnalyzedFileList = function(mimosaConfig) {
  var analyzedFilePath, err;
  if (!logger) {
    logger = mimosaConfig.log;
  }
  analyzedFilePath = _.object(_lastAnalyzedFileListPath(mimosaConfig));
  try {
    return require(analyzedFilePath);
  } catch (_error) {
    err = _error;
    logger.debug(err);
    return {};
  }
};

_sort = function(item) {
  return item[0];
};

_writeAnalyzedFiles = function(mimosaConfig, analyzedFiles, appendIntalledFiles) {
  var filesMinusRoot, outPath, previous;
  if (analyzedFiles == null) {
    analyzedFiles = {};
  }
  if (appendIntalledFiles == null) {
    appendIntalledFiles = {};
  }
  outPath = _lastAnalyzedFileListPath(mimosaConfig);
  filesMinusRoot = analyzedFiles;
  previous = exports.getPreviousAnalyzedFileList(mimosaConfig);
  _.assign(filesMinusRoot, previous, appendIntalledFiles);
  if (!_isEqual(_(previous).pairs().sortBy(_sort).value(), _(filesMinusRoot).pairs().sortBy(_sort).value())) {
    filesMinusRoot = _(filesMinusRoot).pairs().sortBy(_sort).value();
    return _writeJSON(filesMinusRoot, outPath);
  }
};

exports.isAnalyzeNeeded = function(mimosaConfig) {
  var currentAmdifyConfig, err, oldAmdifyConfig;
  if (!logger) {
    logger = mimosaConfig.log;
  }
  try {
    oldAmdifyConfig = require(_lastMimosaConfigJSONPath(mimosaConfig));
    logger.debug("Found old amdify config");
  } catch (_error) {
    err = _error;
    logger.debug("Could not find old amdify config, analyze needed", err);
    return true;
  }
  currentAmdifyConfig = _.cloneDeep(mimosaConfig.amdify);
  if (_isEqual(currentAmdifyConfig, oldAmdifyConfig)) {
    logger.debug("Old amdify config matches current, and older amdify.json matches current");
    return false;
  } else {
    return true;
  }
};
