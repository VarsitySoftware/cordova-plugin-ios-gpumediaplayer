//
//  GPUMediaPlayer.h
//   
//
//  Created by John Weaver on 10/12/2016. 
//
//

#import <Cordova/CDVPlugin.h> 
#import <GPUImage/GPUImageFramework.h>
#import <GPUImage/GPUImageContext.h>
#import <GPUImage/GPUImageOutput.h> 

//#import <CoreText/CoreText.h>

//@interface UIFontPlus : UIFont
//@property (nonatomic) NSString *fontPath;
//@property (nonatomic)UIFont *font; 
//@end

@interface UITextFieldPlus : UITextField
@property(assign, nonatomic) BOOL pressing; 
@property (nonatomic)NSString *fontName; 
//@property(readwrite, nonatomic) BOOL longPress;
@property (getter = isLongPress) BOOL longPress;
-(void) longPressed_OLD;
@end

/** Protocol for getting Movie played callback.
*/
@protocol GPUImageMoviePlusDelegate <NSObject>

-(void)didCompletePlayingMovie;

@end

/** Source object for filtering movies
*/
@interface GPUImageMoviePlus : GPUImageOutput 

@property (readwrite, retain) AVAsset *asset;
@property (readwrite, retain) AVPlayerItem *playerItem;
@property(readwrite, retain) NSURL *url;

@property(readwrite, nonatomic) BOOL pause;
@property(readwrite, nonatomic) BOOL stop;

@property(readwrite, nonatomic) int timeElapsed;
@property(readwrite, nonatomic) float currentTime;
@property(readwrite, nonatomic) int currentTimeInSecs;
@property(readwrite, nonatomic) float duration;

@property(readwrite, nonatomic) float fpsInput;
@property(readwrite, nonatomic) int fpsOutput; 
@property(readwrite, nonatomic) int frameSkipper;
@property(readwrite, nonatomic) int skipRate;

@property(readwrite, nonatomic) int seekTo;

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
	GPUImageMoviePlus *mediaFile; 
	GPUImageOutput<GPUImageInput> *mediaFilter;   
	GPUImageOutput<GPUImageInput> *saveFilter;
	GPUImageOverlayBlendFilter *overlayFilter;
	GPUImagePicture *overlay;
	GPUImageMovieWriter *movieWriter;
	GPUImageMovie *saveFile;
	NSTimer * playbackTimer;
	NSTimer *saveTimer; 
	NSDictionary *options;	
	UITextFieldPlus *textField;
}

@property (copy)NSString* callbackId;
@property (copy)NSString* callbackIdAddSticker;
@property (copy)NSString* callbackIdAddLabel;
@property (copy)NSString* callbackIdSave;

@property(readwrite, nonatomic) BOOL loop;

@property (nonatomic, strong)AVAudioPlayer *audioPlayer;
@property (strong, nonatomic) UIView* rootView;
@property (strong, nonatomic) UIScrollView* scrollView; 

@property (strong, nonatomic) NSURL* mediaLocalURL;
@property(readwrite, nonatomic) int mediaType; 

@property (strong, nonatomic) UIView* mediaContainer;
@property (strong, nonatomic) UIView* mediaView;
@property (strong, nonatomic) UIView* mediaMask;

@property(readwrite, nonatomic) BOOL mediaMaskEnabled; 
@property(readwrite, nonatomic) BOOL mediaFrameEnabled;

@property (readwrite, nonatomic) CDVPluginResult* pluginResult;

@property (readwrite, nonatomic) NSMutableDictionary* jsonResults;
@property (readwrite, nonatomic) NSMutableDictionary* jsonProgress;

@property (strong, nonatomic) UILabel* captionLabel;
@property (strong, nonatomic) UIImageView* overlayView;
@property (strong, nonatomic) UIImageView* frameView;

//@property(readwrite, nonatomic) int currentTag;
@property(readwrite, nonatomic) int currentStickerID;
@property(readwrite, nonatomic) int currentLabelID;
@property(readwrite, nonatomic) int seekTo;

@property(readwrite, nonatomic) BOOL restart;

//@property(readwrite, nonatomic) CFURLRef customFontURL;
//@property(readwrite, nonatomic) CGDataProviderRef customFontDataProvider;
//@property(readwrite, nonatomic) CGFontRef customFontReference;
//@property(readwrite, nonatomic) CTFontRef customFontGraphic;

-(void)start:(CDVInvokedUrlCommand *)command;
-(void)play:(CDVInvokedUrlCommand *)command;
-(void)pause:(CDVInvokedUrlCommand *)command;
-(void)stop:(CDVInvokedUrlCommand *)command;
-(void)restart:(CDVInvokedUrlCommand *)command;
-(void)save:(CDVInvokedUrlCommand *)command;
-(void)hide:(CDVInvokedUrlCommand *)command;
-(void)show:(CDVInvokedUrlCommand *)command; 
-(void)destroy:(CDVInvokedUrlCommand *)command;
-(void)loop:(CDVInvokedUrlCommand *)command;

-(void)download:(CDVInvokedUrlCommand *)command;
-(void)filter:(CDVInvokedUrlCommand *)command;
-(void)preview:(CDVInvokedUrlCommand *)command;

-(void)begin; 

-(void)changeFilter:(CDVInvokedUrlCommand *)command;
-(void)changeFrame:(CDVInvokedUrlCommand *)command;

-(void)addSticker:(CDVInvokedUrlCommand *)command;
-(void)updateSticker:(CDVInvokedUrlCommand *)command;

-(void)addLabel:(CDVInvokedUrlCommand *)command;
-(void)updateLabel:(CDVInvokedUrlCommand *)command;

-(void)createGIFfromURL:(NSURL*)videoURL framesPerSecond : (int)framesPerSecond loopCount : (int)loopCount completion : (void(^)(NSURL *GifURL))completionBlock;
-(void)optimalGIFfromURL:(NSURL*)videoURL loopCount : (int)loopCount playbackSpeed: (int)playbackSpeed maxDuration:(int)maxDuration completion : (void(^)(NSURL *GifURL))completionBlock;

@end
