cordova.define("cordova-plugin-ios-mediaplayer.MediaPlayer", function(require, exports, module) {
/*global cordova,window,console*/
/**
 * A Media Player plugin for Cordova
 * 
 * Developed by John Weaver for Varsity Software
 */


    var MediaPlayer = function ()
    {

    };

    MediaPlayer.prototype.startVideo = function (success, fail, options)
    {
        if (!options) {
            options = {};
        }

        var params = {
            videoURL: options.videoURL ? options.videoURL : null,
            videoPosX: options.videoPosX ? options.videoPosX : 0,
            videoPosY: options.videoPosY ? options.videoPosY : 0,
            videoWidth: options.videoWidth ? options.videoWidth : 0,
            videoHeight: options.videoHeight ? options.videoHeight : 0,
            containerPosX: options.containerPosX ? options.containerPosX : 0,
            containerPosY: options.containerPosY ? options.containerPosY : 0,
            containerWidth: options.containerWidth ? options.containerWidth : 0,
            containerHeight: options.containerHeight ? options.containerHeight : 0,
            orientation: options.orientation ? options.orientation : 0,
            captionText: options.captionText ? options.captionText : null,
            captionFontSize: options.captionFontSize ? options.captionFontSize : 0,
        };

        return cordova.exec(success, fail, "MediaPlayer", "startVideo", [params]);

    };

    MediaPlayer.prototype.pauseVideo = function (success, fail, options)
    {
        return cordova.exec(success, fail, "MediaPlayer", "pauseVideo", null);
    };

    MediaPlayer.prototype.playVideo = function (success, fail, options)
    {
        return cordova.exec(success, fail, "MediaPlayer", "playVideo", null);
    };

    MediaPlayer.prototype.stopVideo = function (success, fail, options)
    {
        return cordova.exec(success, fail, "MediaPlayer", "stopVideo", null);
    };

    MediaPlayer.prototype.changeFilter = function (success, fail, options)
    {
        if (!options) {
            options = {};
        }

        var params = {
            filterID: options.filterID ? options.filterID : 0
        };

        return cordova.exec(success, fail, "MediaPlayer", "changeFilter", [params]);
    };

    MediaPlayer.prototype.changeFrame = function (success, fail, options)
    {
        if (!options) {
            options = {};
        }

        var params = {
            frameID: options.frameID ? options.frameID : 0
        };

        return cordova.exec(success, fail, "MediaPlayer", "changeFrame", [params]);
    };

    MediaPlayer.prototype.addSticker = function (success, fail, options)
    {
        if (!options) {
            options = {};
        }

        var params = {
            stickerID: options.stickerID ? options.stickerID : 0
        };

        return cordova.exec(success, fail, "MediaPlayer", "addSticker", [params]);
    };

    MediaPlayer.prototype.addLabel = function (success, fail, options)
    {
        if (!options) {
            options = {};
        }

        var params = {
            labelID: options.labelID ? options.labelID : 0
        };

        return cordova.exec(success, fail, "MediaPlayer", "addLabel", [params]);
    };

    MediaPlayer.prototype.updateLabel = function (success, fail, options)
    {
        if (!options) {
            options = {};
        }

        var params = {
            labelID: options.labelID ? options.labelID : 0,
            labelColor: options.labelColor ? options.labelColor : null,
            labelSize: options.labelSize ? options.labelSize : 0,
        };

        return cordova.exec(success, fail, "MediaPlayer", "updateLabel", [params]);
    };

    MediaPlayer.prototype.updateSticker = function (success, fail, options)
    {
        if (!options) {
            options = {};
        }

        var params = {
            stickerID: options.stickerID ? options.stickerID : 0,
            stickerColor: options.stickerColor ? options.stickerColor : null,
            stickerSize: options.stickerSize ? options.stickerSize : 0,
        };

        return cordova.exec(success, fail, "MediaPlayer", "updateSticker", [params]);
    };

    MediaPlayer.prototype.saveVideo = function (success, fail, options)
    {
        return cordova.exec(success, fail, "MediaPlayer", "saveVideo", null);
    };

    window.mediaPlayer = new MediaPlayer();

});
