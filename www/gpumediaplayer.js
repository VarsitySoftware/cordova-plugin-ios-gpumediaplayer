cordova.define("cordova-plugin-ios-gpumediaplayer.GPUMediaPlayer", function(require, exports, module) {
/*global cordova,window,console*/
/**
 * A GPU Media Player plugin for Cordova
 * 
 * Developed by John Weaver for Varsity Software
 */


    var GPUMediaPlayer = function ()
    {

    };

    GPUMediaPlayer.prototype.startVideo = function (success, fail, options)
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

        return cordova.exec(success, fail, "GPUMediaPlayer", "startVideo", [params]);

    };

    GPUMediaPlayer.prototype.pauseVideo = function (success, fail, options)
    {
        return cordova.exec(success, fail, "GPUMediaPlayer", "pauseVideo", null);
    };

    GPUMediaPlayer.prototype.playVideo = function (success, fail, options)
    {
        return cordova.exec(success, fail, "GPUMediaPlayer", "playVideo", null);
    };

    GPUMediaPlayer.prototype.stopVideo = function (success, fail, options)
    {
        return cordova.exec(success, fail, "GPUMediaPlayer", "stopVideo", null);
    };

    GPUMediaPlayer.prototype.changeFilter = function (success, fail, options)
    {
        if (!options) {
            options = {};
        }

        var params = {
            filterID: options.filterID ? options.filterID : 0
        };

        return cordova.exec(success, fail, "GPUMediaPlayer", "changeFilter", [params]);
    };

    GPUMediaPlayer.prototype.changeFrame = function (success, fail, options)
    {
        if (!options) {
            options = {};
        }

        var params = {
            frameID: options.frameID ? options.frameID : 0
        };

        return cordova.exec(success, fail, "GPUMediaPlayer", "changeFrame", [params]);
    };

    GPUMediaPlayer.prototype.addSticker = function (success, fail, options)
    {
        if (!options) {
            options = {};
        }

        var params = {
            stickerID: options.stickerID ? options.stickerID : 0
        };

        return cordova.exec(success, fail, "GPUMediaPlayer", "addSticker", [params]);
    };

    GPUMediaPlayer.prototype.addLabel = function (success, fail, options)
    {
        if (!options) {
            options = {};
        }

        var params = {
            labelID: options.labelID ? options.labelID : 0
        };

        return cordova.exec(success, fail, "GPUMediaPlayer", "addLabel", [params]);
    };

    GPUMediaPlayer.prototype.updateLabel = function (success, fail, options)
    {
        if (!options) {
            options = {};
        }

        var params = {
            labelID: options.labelID ? options.labelID : 0,
            labelColor: options.labelColor ? options.labelColor : null,
            labelSize: options.labelSize ? options.labelSize : 0,
        };

        return cordova.exec(success, fail, "GPUMediaPlayer", "updateLabel", [params]);
    };

    GPUMediaPlayer.prototype.updateSticker = function (success, fail, options)
    {
        if (!options) {
            options = {};
        }

        var params = {
            stickerID: options.stickerID ? options.stickerID : 0,
            stickerColor: options.stickerColor ? options.stickerColor : null,
            stickerSize: options.stickerSize ? options.stickerSize : 0,
        };

        return cordova.exec(success, fail, "GPUMediaPlayer", "updateSticker", [params]);
    };

    GPUMediaPlayer.prototype.saveVideo = function (success, fail, options)
    {
        return cordova.exec(success, fail, "GPUMediaPlayer", "saveVideo", null);
    };

    window.gpuMediaPlayer = new GPUMediaPlayer();

});
