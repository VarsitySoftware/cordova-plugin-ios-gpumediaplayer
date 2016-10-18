
    var GPUMediaPlayer = function ()
    {

    };

    GPUMediaPlayer.prototype.start = function (success, fail, options)
    {
        if (!options) {
            options = {};
        }

        var params = {
            mediaURL: options.mediaURL ? options.mediaURL : null,
            mediaOrientation: options.mediaOrientation ? options.mediaOrientation : 0,
            mediaType: options.mediaType ? options.mediaType : 0,

            mediaPosX: options.mediaPosX ? options.mediaPosX : 0,
            mediaPosY: options.mediaPosY ? options.mediaPosY : 0,
            mediaWidth: options.mediaWidth ? options.mediaWidth : 0,
            mediaHeight: options.mediaHeight ? options.mediaHeight : 0,

            framesPerSecond: options.framesPerSecond ? options.framesPerSecond : 0,

            playerPosX: options.playerPosX ? options.playerPosX : 0,
            playerPosY: options.playerPosY ? options.playerPosY : 0,
            playerWidth: options.playerWidth ? options.playerWidth : 0,
            playerHeight: options.playerHeight ? options.playerHeight : 0,

            captionEnabled: options.captionEnabled ? options.captionEnabled : 0,
            captionText: options.captionText ? options.captionText : null,
            captionFontSize: options.captionFontSize ? options.captionFontSize : 0,

            frameEnabled: options.frameEnabled ? options.frameEnabled : 0,
            frameShapeURL: options.frameShapeURL ? options.frameShapeURL : null,
            frameThemeURL: options.frameThemeURL ? options.frameThemeURL : null,

            overlayEnabled: options.overlayEnabled ? options.overlayEnabled : 0,
            overlayURL: options.overlayURL ? options.overlayURL : null,

            loop: options.loop ? options.loop : 0
        };

        return cordova.exec(success, fail, "GPUMediaPlayer", "start", [params]);

    };

    GPUMediaPlayer.prototype.pause = function (success, fail, options)
    {
        return cordova.exec(success, fail, "GPUMediaPlayer", "pause", null);
    };

    GPUMediaPlayer.prototype.play = function (success, fail, options)
    {
        return cordova.exec(success, fail, "GPUMediaPlayer", "play", null);
    };

    GPUMediaPlayer.prototype.stop = function (success, fail, options)
    {
        return cordova.exec(success, fail, "GPUMediaPlayer", "stop", null);
    };

    GPUMediaPlayer.prototype.restart = function (success, fail, options)
    {
        return cordova.exec(success, fail, "GPUMediaPlayer", "restart", null);
    };

    GPUMediaPlayer.prototype.hide = function (success, fail, options)
    {
        return cordova.exec(success, fail, "GPUMediaPlayer", "hide", null);
    };

    GPUMediaPlayer.prototype.show = function (success, fail, options)
    {
        return cordova.exec(success, fail, "GPUMediaPlayer", "show", null);
    };

    GPUMediaPlayer.prototype.destroy = function (success, fail, options)
    {
        return cordova.exec(success, fail, "GPUMediaPlayer", "destroy", null);
    };

    GPUMediaPlayer.prototype.seek = function (success, fail, options)
    {
        if (!options) {
            options = {};
        }

        var params = {           

            seekTo: options.seekTo ? options.seekTo : 0
        };

        return cordova.exec(success, fail, "GPUMediaPlayer", "seek", [params]);        
    };

    GPUMediaPlayer.prototype.save = function (success, fail, options)
    {     
        if (!options) {
            options = {};
        }

        var params = {
            mediaURL: options.mediaURL ? options.mediaURL : null,
            mediaType: options.mediaType ? options.mediaType : 0,
            mediaWidth: options.mediaWidth ? options.mediaWidth : 0,
            mediaHeight: options.mediaHeight ? options.mediaHeight : 0,
            avgBitRate: options.avgBitRate ? options.avgBitRate : 0,
            gifFramesPerSecond: options.gifFramesPerSecond ? options.gifFramesPerSecond : 0,
            gifPlaybackSpeed: options.gifPlaybackSpeed ? options.gifPlaybackSpeed : 0,
            gifMaxDuration: options.gifMaxDuration ? options.gifMaxDuration : 0
        };

        return cordova.exec(success, fail, "GPUMediaPlayer", "save", [params]);
    };


    GPUMediaPlayer.prototype.addSticker = function (success, fail, options)
    {
        if (!options) {
            options = {};
        }

        var params = {
            stickerPath: options.stickerPath ? options.stickerPath : null,
            stickerID: options.stickerID ? options.stickerID : 0,
            stickerPosX: options.stickerPosX ? options.stickerPosX : 0,
            stickerPosY: options.stickerPosY ? options.stickerPosY : 0,
            stickerWidth: options.stickerWidth ? options.stickerWidth : 0,
            stickerHeight: options.stickerHeight ? options.stickerHeight : 0
        };

        return cordova.exec(success, fail, "GPUMediaPlayer", "addSticker", [params]);
    };

    GPUMediaPlayer.prototype.addLabel = function (success, fail, options)
    {
        if (!options) {
            options = {};
        }

        var params = {
            labelID: options.labelID ? options.labelID : 0,
            labelPosX: options.labelPosX ? options.labelPosX : 0,
            labelPosY: options.labelPosY ? options.labelPosY : 0,
            labelWidth: options.labelWidth ? options.labelWidth : 0,
            labelHeight: options.labelHeight ? options.labelHeight : 0,
            fontPath: options.fontPath ? options.fontPath : null,
            fontSize: options.fontSize ? options.fontSize : 0,
        };

        return cordova.exec(success, fail, "GPUMediaPlayer", "addLabel", [params]);
    };

    GPUMediaPlayer.prototype.updateLabel = function (success, fail, options)
    {
        if (!options) {
            options = {};
        }

        var params = {
            //labelID: options.labelID ? options.labelID : 0,
            labelColor: options.labelColor ? options.labelColor : null,
            labelSize: options.labelSize ? options.labelSize : 0,
        };

        return cordova.exec(success, fail, "GPUMediaPlayer", "updateLabel", [params]);
    };

    GPUMediaPlayer.prototype.deleteLabel = function (success, fail, options)
    {      
        return cordova.exec(success, fail, "GPUMediaPlayer", "deleteLabel", null);
    };

    GPUMediaPlayer.prototype.updateSticker = function (success, fail, options)
    {
        if (!options) {
            options = {};
        }

        var params = {
            //stickerID: options.stickerID ? options.stickerID : 0,
            stickerColor: options.stickerColor ? options.stickerColor : null,
            stickerSize: options.stickerSize ? options.stickerSize : 0,
        };

        return cordova.exec(success, fail, "GPUMediaPlayer", "updateSticker", [params]);
    };

    GPUMediaPlayer.prototype.deleteSticker = function (success, fail, options)
    {       
        return cordova.exec(success, fail, "GPUMediaPlayer", "deleteSticker", null);
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
            mediaWidth: options.mediaWidth ? options.mediaWidth : 0,
            mediaHeight: options.mediaHeight ? options.mediaHeight : 0,
            frameShapeURL: options.frameShapeURL ? options.frameShapeURL : null,
            frameThemeURL: options.frameThemeURL ? options.frameThemeURL : null,
        };

        return cordova.exec(success, fail, "GPUMediaPlayer", "changeFrame", [params]);
    };

    window.gpuMediaPlayer = new GPUMediaPlayer();
