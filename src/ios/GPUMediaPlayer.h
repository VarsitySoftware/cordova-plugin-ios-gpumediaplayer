//
//  MediaPlayer.h
//  
//
//  Created by John Weaver on 10/12/2016.
//
//

#import <Cordova/CDVPlugin.h>
#import <GPUImage/GPUImageFramework.h>
#import <GPUImage/GPUImageContext.h>
#import <GPUImage/GPUImageOutput.h>

/** Protocol for getting Movie played callback.
*/
@protocol GPUVideoMovieDelegate <NSObject>

-(void)didCompletePlayingMovie;

@end

/** Source object for filtering movies
*/
@interface GPUVideoMovie : GPUImageOutput

@property (readwrite, retain) AVAsset *asset;
@property (readwrite, retain) AVPlayerItem *playerItem;
@property(readwrite, retain) NSURL *url;

@property(readwrite, nonatomic) BOOL pause;
@property(readwrite, nonatomic) BOOL stop;
@property(readwrite, nonatomic) float currentTime;
@property(readwrite, nonatomic) int currentTimeInSecs;
@property(readwrite, nonatomic) float duration;

/** This enables the benchmarking mode, which logs out instantaneous and average frame times to the console
*/
@property(readwrite, nonatomic) BOOL runBenchmark;

/** This determines whether to play back a movie as fast as the frames can be processed, or if the original speed of the movie should be respected. Defaults to NO.
*/
@property(readwrite, nonatomic) BOOL playAtActualSpeed;

/** This determines whether the video should repeat (loop) at the end and restart from the beginning. Defaults to NO.
*/
@property(readwrite, nonatomic) BOOL shouldRepeat;

/** This specifies the progress of the process on a scale from 0 to 1.0. A value of 0 means the process has not yet begun, A value of 1.0 means the conversaion is complete.
This property is not key-value observable.
*/
@property(readonly, nonatomic) float progress;

/** This is used to send the delete Movie did complete playing alert
*/
@property (readwrite, nonatomic, assign) id <GPUImageMovieDelegate>delegate;

@property (readonly, nonatomic) AVAssetReader *assetReader;
@property (readonly, nonatomic) BOOL audioEncodingIsFinished;
@property (readonly, nonatomic) BOOL videoEncodingIsFinished;

/// @name Initialization and teardown
-(id)initWithAsset:(AVAsset *)asset;
-(id)initWithPlayerItem:(AVPlayerItem *)playerItem;
-(id)initWithURL:(NSURL *)url;
-(void)yuvConversionSetup;

/// @name Movie processing
-(void)enableSynchronizedEncodingUsingMovieWriter:(GPUImageMovieWriter *)movieWriter;
-(BOOL)readNextVideoFrameFromOutput:(AVAssetReaderOutput *)readerVideoTrackOutput;
-(BOOL)readNextAudioSampleFromOutput:(AVAssetReaderOutput *)readerAudioTrackOutput;
-(void)startProcessing;
-(void)endProcessing;
-(void)cancelProcessing;
-(void)processMovieFrame:(CMSampleBufferRef)movieSampleBuffer;
-(void)pauseVideo:(CDVInvokedUrlCommand *)command;
@end

@interface GPUMediaPlayer : CDVPlugin < UINavigationControllerDelegate, UIScrollViewDelegate>
{
	GPUVideoMovie *movieFile;
	GPUImageOutput<GPUImageInput> *filter;
	GPUImageOutput<GPUImageInput> *saveFilter;
	GPUImageOverlayBlendFilter *overlayFilter;
	GPUImagePicture *overlay;
	GPUImageMovieWriter *movieWriter;
	GPUImageMovie *videoFile;
	NSTimer * timer;
	NSTimer *saveTimer;
}

@property (copy)NSString* callbackId;

@property (nonatomic, strong)AVAudioPlayer *audioPlayer;
@property (strong, nonatomic) UIView* rootView;
@property (strong, nonatomic) UIScrollView* scrollView;

@property (strong, nonatomic) UIView* viewContainer;

@property (strong, nonatomic) UIView* maskView;
@property (strong, nonatomic) UIView* videoView;

@property (readwrite, nonatomic) CDVPluginResult* pluginResult;

@property (readwrite, nonatomic) NSMutableDictionary* jsonResults;
@property (readwrite, nonatomic) NSMutableDictionary* jsonProgress;

@property (strong, nonatomic) UILabel* captionLabel;
@property (strong, nonatomic) UIImageView* overlayView;
@property (strong, nonatomic) UIImageView* frameView;

@property (strong, nonatomic) NSURL* localURL;

@property(readwrite, nonatomic) int currentTextFieldTag;

-(void)startVideo:(CDVInvokedUrlCommand *)command;
-(void)stopVideo:(CDVInvokedUrlCommand *)command;
-(void)playVideo:(CDVInvokedUrlCommand *)command;
-(void)pauseVideo:(CDVInvokedUrlCommand *)command;
-(void)saveVideo:(CDVInvokedUrlCommand *)command;

-(void)changeFilter:(CDVInvokedUrlCommand *)command;
-(void)changeFrame:(CDVInvokedUrlCommand *)command;

-(void)addSticker:(CDVInvokedUrlCommand *)command;
-(void)updateSticker:(CDVInvokedUrlCommand *)command;

-(void)addLabel:(CDVInvokedUrlCommand *)command;
-(void)updateLabel:(CDVInvokedUrlCommand *)command;

@end
