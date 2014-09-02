"use strict";
var amdify, fs, logger, path, _, _cleanFilesViaTrackingInfo, _removeFile;

fs = require('fs');

path = require('path');

_ = require('lodash');

logger = null;

amdify = null;

_removeFile = function(fileName) {
  var err;
  try {
    fs.unlinkSync(fileName);
    return logger.info("Removed file [[ " + fileName + " ]]");
  } catch (_error) {
    err = _error;
    return logger.warn("Unable to clean file [[ " + fileName + " ]], was it moved from this location or already cleaned?");
  }
};

_cleanFilesViaTrackingInfo = function(mimosaConfig) {
  var installedFiles, track;
  track = require('./track');
  installedFiles = track.getPreviousInstalledFileList(mimosaConfig);
  if (installedFiles.length === 0) {
    logger.info("No files to clean.");
  } else {
    installedFiles.map(function(installedFile) {
      return path.join(mimosaConfig.root, installedFile);
    }).forEach(_removeFile);
  }
  track.removeTrackFiles(mimosaConfig);
  return logger.success("Amdify files cleaned.");
};

exports.amdifyClean = function(mimosaConfig) {
  logger = mimosaConfig.log;
  if (!mimosaConfig.amdify) {
    amdify = require("amdify");
  }
  amdify.config.directory = mimosaConfig.amdify.amdifyDir.path;
  return _cleanFilesViaTrackingInfo(mimosaConfig);
};
