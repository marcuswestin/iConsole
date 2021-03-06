//
//  iConsole.m
//
//  Version 1.5.2
//
//  Created by Nick Lockwood on 20/12/2010.
//  Copyright 2010 Charcoal Design
//
//  Distributed under the permissive zlib License
//  Get the latest version from here:
//
//  https://github.com/nicklockwood/iConsole
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//  claim that you wrote the original software. If you use this software
//  in a product, an acknowledgment in the product documentation would be
//  appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//  misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//

#import "iConsole.h"
#import <stdarg.h>
#import <string.h> 
#import "iConsoleManager.h"
#import "ICTextView.h"

#import <Availability.h>
#if !__has_feature(objc_arc)
#error This class requires automatic reference counting
#endif


#if ICONSOLE_USE_GOOGLE_STACK_TRACE
#import "GTMStackTrace.h"
#endif


#define EDITFIELD_HEIGHT 28
#define ACTION_BUTTON_WIDTH 28
#define kiConsoleLog @"iConsoleLog"


@interface iConsole() <UITextFieldDelegate, UIActionSheetDelegate>

@property (nonatomic, strong) ICTextView *consoleView;
@property (nonatomic, strong) UITextField *inputField;
@property (nonatomic, strong) UIButton *actionButton;
@property (nonatomic, strong) UIButton *pathButton;
@property (nonatomic, strong) UILabel *matchNumLabel;
@property (nonatomic, strong) NSMutableArray *log;
@property (nonatomic, assign) BOOL animating;

- (void)saveSettings;

void exceptionHandler(NSException *exception);

@end


@implementation iConsole

#pragma mark -
#pragma mark Private methods

void exceptionHandler(NSException *exception)
{
	
#if ICONSOLE_USE_GOOGLE_STACK_TRACE
	
    extern NSString *GTMStackTraceFromException(NSException *e);
    [iConsole crash:@"%@\n\nStack trace:\n%@)", exception, GTMStackTraceFromException(exception)];
	
#else
	
	[iConsole crash:@"%@", exception];
	 
#endif

	[[iConsole sharedConsole] saveSettings];
}

+ (void)load
{
    //initialise the console
    [iConsole performSelectorOnMainThread:@selector(sharedConsole) withObject:nil waitUntilDone:NO];
}

- (UIWindow *)mainWindow
{
    UIApplication *app = [UIApplication sharedApplication];
    if ([app.delegate respondsToSelector:@selector(window)])
    {
        return [app.delegate window];
    }
    else
    {
        return [app keyWindow];
    }
}

- (void)setConsoleText
{
	NSString *text = _infoString;
	NSInteger touches = (TARGET_IPHONE_SIMULATOR ? _simulatorTouchesToShow: _deviceTouchesToShow);
	if (touches > 0 && touches < 11)
	{
		text = [text stringByAppendingFormat:@"\nSwipe down with %li finger%@ to hide console", (long)touches, (touches != 1)? @"s": @""];
	}
	else if (TARGET_IPHONE_SIMULATOR ? _simulatorShakeToShow: _deviceShakeToShow)
	{
		text = [text stringByAppendingString:@"\nShake device to hide console"];
	}
	text = [text stringByAppendingString:@"\n--------------------------------------\n"];
	text = [text stringByAppendingString:[[_log arrayByAddingObject:@">"] componentsJoinedByString:@"\n"]];
	_consoleView.text = text;
    [_consoleView scrollRangeToVisible:NSMakeRange(0, 0)];
	[_consoleView scrollRangeToVisible:NSMakeRange(_consoleView.text.length, 0)];
}

- (void)resetLog
{
    [self.log removeAllObjects];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kiConsoleLog];
    [[NSUserDefaults standardUserDefaults] synchronize];
	[self setConsoleText];
}

- (void)saveSettings
{
    if (_saveLogToDisk)
    {
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (BOOL)findAndResignFirstResponder:(UIView *)view
{
    if ([view isFirstResponder])
	{
        [view resignFirstResponder];
        return YES;     
    }
    for (UIView *subview in view.subviews)
	{
        if ([self findAndResignFirstResponder:subview])
        {
			return YES;
		}
    }
    return NO;
}

- (void)infoAction
{
	[self findAndResignFirstResponder:[self mainWindow]];

	UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Menu"
                                                       delegate:self
                                              cancelButtonTitle:@"Cancel"
                                         destructiveButtonTitle:@"Clear Log"
                                              otherButtonTitles:@"Send by Email", nil];
    NSDictionary* additionalMenuOptions = [iConsole sharedConsole].additionalMenuOptions;
    for (id title in additionalMenuOptions) {
        [sheet addButtonWithTitle:title];
    }
    
	sheet.actionSheetStyle = UIActionSheetStyleBlackOpaque;
    sheet.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    [sheet setTranslatesAutoresizingMaskIntoConstraints:NO];
	[sheet showInView:self.view];
    
}

- (void)command:(id)sender
{
    //pop up command type menu
    UIButton *button = (id)sender;
    [[iConsoleManager sharediConsoleManager].commandMenu showInView:self.view targetRect:button.frame animated:YES];
}

- (void)commandAction
{
    switch ([iConsoleManager sharediConsoleManager].cmdType) {
        case CMDTypeFind: {
            if (_delegate) {
                _inputField.placeholder = @"Find";
                [_inputField becomeFirstResponder];
            }
        }
            break;
        case CMDTypeVersion:{
            [iConsole log:@"Your app version:%@", [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString *)kCFBundleVersionKey]];
        }
            break;
        default:
            break;
    }
}

- (CGAffineTransform)viewTransform
{
	CGFloat angle = 0;
    
    
	switch ([UIApplication sharedApplication].statusBarOrientation)
    {
        case UIInterfaceOrientationPortrait:
            angle = 0;
            break;
		case UIInterfaceOrientationPortraitUpsideDown:
			angle = M_PI;
			break;
		case UIInterfaceOrientationLandscapeLeft:
			angle = -M_PI_2;
			break;
		case UIInterfaceOrientationLandscapeRight:
			angle = M_PI_2;
			break;
        case UIInterfaceOrientationUnknown:
            angle = 0;
            break;
	}
	return CGAffineTransformMakeRotation(angle);
}

- (CGRect)onscreenFrame
{
	return [UIScreen mainScreen].applicationFrame;
}

- (CGRect)offscreenFrame
{
	CGRect frame = [self onscreenFrame];
	switch ([UIApplication sharedApplication].statusBarOrientation)
    {
		case UIInterfaceOrientationPortrait:
			frame.origin.y = frame.size.height;
			break;
		case UIInterfaceOrientationPortraitUpsideDown:
			frame.origin.y = -frame.size.height;
			break;
		case UIInterfaceOrientationLandscapeLeft:
			frame.origin.x = frame.size.width;
			break;
		case UIInterfaceOrientationLandscapeRight:
			frame.origin.x = -frame.size.width;
			break;
        case UIInterfaceOrientationUnknown:
            frame.origin.y = frame.size.height;
            break;
	}
	return frame;
}

- (void)showConsole
{	
	if (!_animating && self.view.superview == nil)
	{
        [self setConsoleText];
        
		[self findAndResignFirstResponder:[self mainWindow]];
		
		[iConsole sharedConsole].view.frame = [self offscreenFrame];
		[[self mainWindow] addSubview:[iConsole sharedConsole].view];
		
		_animating = YES;
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationDuration:0.4];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(consoleShown)];
		[iConsole sharedConsole].view.frame = [self onscreenFrame];
        [iConsole sharedConsole].view.transform = [self viewTransform];
		[UIView commitAnimations];
	}
}

- (void)consoleShown
{
	_animating = NO;
	[self findAndResignFirstResponder:[self mainWindow]];
}

- (void)hideConsole
{
	if (!_animating && self.view.superview != nil)
	{
		[self findAndResignFirstResponder:[self mainWindow]];
		
		_animating = YES;
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationDuration:0.4];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(consoleHidden)];
		[iConsole sharedConsole].view.frame = [self offscreenFrame];
		[UIView commitAnimations];
	}
}

- (void)consoleHidden
{
	_animating = NO;
	[[[iConsole sharedConsole] view] removeFromSuperview];
}

- (void)rotateView:(NSNotification *)notification
{
	self.view.transform = [self viewTransform];
	self.view.frame = [self onscreenFrame];
	
	if (_delegate != nil)
	{
		//workaround for autoresizeing glitch
		CGRect frame = self.view.bounds;
		frame.size.height -= EDITFIELD_HEIGHT + 10;
		self.consoleView.frame = frame;
	}
}

- (void)resizeView:(NSNotification *)notification
{
	CGRect frame = [[notification.userInfo valueForKey:UIApplicationStatusBarFrameUserInfoKey] CGRectValue];
	CGRect bounds = [UIScreen mainScreen].bounds;
	switch ([UIApplication sharedApplication].statusBarOrientation)
    {
		case UIInterfaceOrientationPortrait:
			bounds.origin.y += frame.size.height;
			bounds.size.height -= frame.size.height;
			break;
		case UIInterfaceOrientationPortraitUpsideDown:
			bounds.size.height -= frame.size.height;
			break;
		case UIInterfaceOrientationLandscapeLeft:
			bounds.origin.x += frame.size.width;
			bounds.size.width -= frame.size.width;
			break;
		case UIInterfaceOrientationLandscapeRight:
			bounds.size.width -= frame.size.width;
			break;
        case UIInterfaceOrientationUnknown:
            bounds.origin.y += frame.size.height;
            bounds.size.height -= frame.size.height;
            break;
	}
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
	[UIView setAnimationDuration:0.35];
	self.view.frame = bounds;
	[UIView commitAnimations];
}

- (void)keyboardWillShow:(NSNotification *)notification
{	
	CGRect frame = [[notification.userInfo valueForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
	CGFloat duration = [[notification.userInfo valueForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue];
	UIViewAnimationCurve curve = [[notification.userInfo valueForKey:UIKeyboardAnimationCurveUserInfoKey] intValue];
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationBeginsFromCurrentState:YES];
	[UIView setAnimationDuration:duration];
	[UIView setAnimationCurve:curve];
	
	CGRect bounds = [self onscreenFrame];
	switch ([UIApplication sharedApplication].statusBarOrientation)
    {
		case UIInterfaceOrientationPortrait:
			bounds.size.height -= frame.size.height;
			break;
		case UIInterfaceOrientationPortraitUpsideDown:
			bounds.origin.y += frame.size.height;
			bounds.size.height -= frame.size.height;
			break;
		case UIInterfaceOrientationLandscapeLeft:
			bounds.size.width -= frame.size.width;
			break;
		case UIInterfaceOrientationLandscapeRight:
			bounds.origin.x += frame.size.width;
			bounds.size.width -= frame.size.width;
            break;
        case UIInterfaceOrientationUnknown:
            bounds.size.height -= frame.size.height;
            break;
	}
	self.view.frame = bounds;
	
	[UIView commitAnimations];
}

- (void)keyboardWillHide:(NSNotification *)notification
{
	CGFloat duration = [[notification.userInfo valueForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue];
	UIViewAnimationCurve curve = [[notification.userInfo valueForKey:UIKeyboardAnimationCurveUserInfoKey] intValue];
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationBeginsFromCurrentState:YES];
	[UIView setAnimationDuration:duration];
	[UIView setAnimationCurve:curve];
	
	self.view.frame = [self onscreenFrame];	
	
	[UIView commitAnimations];
}

- (void)logOnMainThread:(NSString *)message
{
	[_log addObject:[@"> " stringByAppendingString:message]];
	if ([_log count] > _maxLogItems)
	{
		[_log removeObjectAtIndex:0];
	}
    [[NSUserDefaults standardUserDefaults] setObject:_log forKey:kiConsoleLog];
    if (self.view.superview)
    {
        [self setConsoleText];
    }
}

#pragma mark -
#pragma mark UITextFieldDelegate methods

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    if ([NSDate date].timeIntervalSinceReferenceDate - didJustClearDate.timeIntervalSinceReferenceDate < .3) {
        return NO;
    }
    [self textFieldDidChange:textField];
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	[textField resignFirstResponder];
	return YES;
}

static NSDate* didJustClearDate;
- (BOOL)textFieldShouldClear:(UITextField *)textField
{
    didJustClearDate = [NSDate date];
	return YES;
}

- (void)textFieldDidChange:(UITextField *)textField
{
    switch ([iConsoleManager sharediConsoleManager].cmdType) {
        case CMDTypeFind:{
            
            if ([textField.text isEqualToString:@""]) {
                [_consoleView resetSearch];
                _matchNumLabel.text = @"";
            } else {
                [_consoleView scrollToString:textField.text searchOptions:NSRegularExpressionCaseInsensitive animated:YES atScrollPosition:ICTextViewScrollPositionTop];
                if (_consoleView.matchingCount == 0) {
                    _matchNumLabel.text = @"Not found";
                } else {
                    _matchNumLabel.text = [NSString stringWithFormat:@"%@ matches",@(_consoleView.matchingCount)];
                }
            }
            
        }
            
            break;
        default:
            break;
    }

   
}

#pragma mark -
#pragma mark UIActionSheetDelegate methods

- (NSString *)URLEncodedString:(NSString *)string
{
    return CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (__bridge CFStringRef)string, NULL, CFSTR("!*'\"();:@&=+$,/?%#[]% "), kCFStringEncodingUTF8));
}

+ (void)sendEmail {
    iConsole* instance = [iConsole sharedConsole];
    NSString *URLSafeName = [instance URLEncodedString:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]];
    NSString *URLSafeLog = [instance URLEncodedString:[instance.log componentsJoinedByString:@"\n"]];
    NSString *URLString = [NSString stringWithFormat:@"mailto:%@?subject=%@%%20Console%%20Log&body=%@",
                           instance.logSubmissionEmail ?: @"", URLSafeName, URLSafeLog];
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:URLString]];
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
    NSMutableArray* actions = [NSMutableArray array];
    [actions addObject:^{
        // 0 = clear console
        [iConsole clear];
    }];
    [actions addObject:^{
        // 1 = send email
        [iConsole sendEmail];
    }];
    [actions addObject:^{
        // 2 = cancel
        [iConsole hide];
    }];
    
    NSDictionary* additionalMenuOptions = [iConsole sharedConsole].additionalMenuOptions;
    for (id title in additionalMenuOptions) {
        [actions addObject:additionalMenuOptions[title]];
    }

    void (^fn)() = actions[buttonIndex];
    fn();
}


#pragma mark -
#pragma mark Life cycle

+ (iConsole *)sharedConsole
{
    @synchronized(self)
    {
        static iConsole *sharedConsole = nil;
        if (sharedConsole == nil)
        {
            sharedConsole = [[self alloc] init];
        }
        return sharedConsole; 
    }
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]))
	{
        
#if ICONSOLE_ADD_EXCEPTION_HANDLER
        
        NSSetUncaughtExceptionHandler(&exceptionHandler);
        
#endif
        
        _enabled = YES;
        _logLevel = iConsoleLogLevelInfo;
        _saveLogToDisk = YES;
        _maxLogItems = 1000;
        _delegate = nil;
        
        _simulatorTouchesToShow = 2;
        _deviceTouchesToShow = 3;
        _simulatorShakeToShow = YES;
        _deviceShakeToShow = NO;
        
        self.infoString = @"iConsole: Copyright © 2010 Charcoal Design";
        self.inputPlaceholderString = @"Find";
        self.logSubmissionEmail = nil;
        
        self.backgroundColor = [UIColor blackColor];
        self.textColor = [UIColor whiteColor];
        self.indicatorStyle = UIScrollViewIndicatorStyleWhite;
        self.additionalMenuOptions = @{};
        
        [[NSUserDefaults standardUserDefaults] synchronize];
        self.log = [NSMutableArray arrayWithArray:[[NSUserDefaults standardUserDefaults] objectForKey:kiConsoleLog]];
        
        if (&UIApplicationDidEnterBackgroundNotification != NULL)
        {
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(saveSettings)
                                                         name:UIApplicationDidEnterBackgroundNotification
                                                       object:nil];
        }

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(saveSettings)
                                                     name:UIApplicationWillTerminateNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(rotateView:)
                                                     name:UIApplicationDidChangeStatusBarOrientationNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(resizeView:)
                                                     name:UIApplicationWillChangeStatusBarFrameNotification
                                                   object:nil];
	}
	return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [iConsoleManager sharediConsoleManager];
    
    self.view.clipsToBounds = YES;
	self.view.backgroundColor = _backgroundColor;
	self.view.autoresizesSubviews = YES;

	_consoleView = [[ICTextView alloc] initWithFrame:self.view.bounds];
	_consoleView.font = [UIFont fontWithName:@"Courier" size:12];
	_consoleView.textColor = _textColor;
	_consoleView.backgroundColor = [UIColor clearColor];
    _consoleView.indicatorStyle = _indicatorStyle;
	_consoleView.editable = NO;
	_consoleView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    _consoleView.primaryHighlightColor = [UIColor colorWithRed:0.93 green:0.89 blue:0 alpha:.8];
    _consoleView.secondaryHighlightColor = [UIColor colorWithRed:1 green:1 blue:1 alpha:.75];
    _consoleView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
	[self setConsoleText];
	[self.view addSubview:_consoleView];
	
	self.actionButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_actionButton setTitle:@"⚙" forState:UIControlStateNormal];
    [_actionButton setTitleColor:_textColor forState:UIControlStateNormal];
    [_actionButton setTitleColor:[_textColor colorWithAlphaComponent:0.5f] forState:UIControlStateHighlighted];
    _actionButton.titleLabel.font = [_actionButton.titleLabel.font fontWithSize:ACTION_BUTTON_WIDTH];
	_actionButton.frame = CGRectMake(self.view.frame.size.width - ACTION_BUTTON_WIDTH - 5,
                                   self.view.frame.size.height - EDITFIELD_HEIGHT - 5,
                                   ACTION_BUTTON_WIDTH, EDITFIELD_HEIGHT);
	[_actionButton addTarget:self action:@selector(infoAction) forControlEvents:UIControlEventTouchUpInside];
	_actionButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin;
	[self.view addSubview:_actionButton];
    
	if (_delegate)
	{
		_inputField = [[UITextField alloc] initWithFrame:CGRectMake(5 + ACTION_BUTTON_WIDTH, self.view.frame.size.height - EDITFIELD_HEIGHT - 5,
                                                                    self.view.frame.size.width - 15 - ACTION_BUTTON_WIDTH *2,
                                                                    EDITFIELD_HEIGHT)];
		_inputField.borderStyle = UITextBorderStyleRoundedRect;
		_inputField.font = [UIFont fontWithName:@"Courier" size:12];
		_inputField.autocapitalizationType = UITextAutocapitalizationTypeNone;
		_inputField.autocorrectionType = UITextAutocorrectionTypeNo;
		_inputField.returnKeyType = UIReturnKeyDone;
		_inputField.enablesReturnKeyAutomatically = NO;
		_inputField.clearButtonMode = UITextFieldViewModeAlways;
        _inputField.keyboardAppearance = UIKeyboardAppearanceDark;
		_inputField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
		_inputField.placeholder = _inputPlaceholderString;
		_inputField.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
		_inputField.delegate = self;
        [_inputField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
		CGRect frame = self.view.bounds;
		frame.size.height -= EDITFIELD_HEIGHT + 10;
		_consoleView.frame = frame;
		[self.view addSubview:_inputField];
        
        
        self.pathButton = ({
            UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
            button.frame = CGRectMake(2, self.view.frame.size.height - EDITFIELD_HEIGHT - 5, ACTION_BUTTON_WIDTH, ACTION_BUTTON_WIDTH);
            [button setTitle:@"⌘" forState:UIControlStateNormal];
            button.titleLabel.font = [UIFont boldSystemFontOfSize:ACTION_BUTTON_WIDTH];
            button.titleLabel.textAlignment = NSTextAlignmentCenter;
            [button setTitleColor:_textColor forState:UIControlStateNormal];
            [button setTitleColor:[_textColor colorWithAlphaComponent:0.5f] forState:UIControlStateHighlighted];
            button.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin;
            [button addTarget:self action:@selector(command:) forControlEvents:UIControlEventTouchUpInside];
            button;
        });
        [self.view addSubview:self.pathButton];
        _matchNumLabel = ({
            UILabel *matchLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 80, 20)];
            matchLabel.font = [UIFont systemFontOfSize:10];
            matchLabel.textAlignment = NSTextAlignmentRight;
            matchLabel.center = CGPointMake(CGRectGetWidth(_inputField.bounds) - CGRectGetMidX(matchLabel.bounds) - EDITFIELD_HEIGHT, CGRectGetMidY(_inputField.bounds));
            [_inputField addSubview:matchLabel];
            matchLabel.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin;
            matchLabel;
        });
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(keyboardWillShow:)
													 name:UIKeyboardWillShowNotification
												   object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(keyboardWillHide:)
													 name:UIKeyboardWillHideNotification
												   object:nil];
	}

	[self.consoleView scrollRangeToVisible:NSMakeRange(self.consoleView.text.length, 0)];
}

- (void)viewDidUnload
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
	
	self.consoleView = nil;
	self.inputField = nil;
	self.actionButton = nil;
    
    [super viewDidUnload];
}


#pragma mark -
#pragma mark Public methods

+ (void)log:(NSString *)format arguments:(va_list)argList
{	
//	NSLogv(format, argList);
	
    if ([self sharedConsole].enabled)
    {
        NSString *message = [[NSString alloc] initWithFormat:format arguments:argList];
        if ([NSThread currentThread] == [NSThread mainThread])
        {	
            [[self sharedConsole] logOnMainThread:message];
        }
        else
        {
            [[self sharedConsole] performSelectorOnMainThread:@selector(logOnMainThread:)
                                                   withObject:message waitUntilDone:NO];
        }
    }
}

+ (void)log:(NSString *)format, ...
{
    if ([self sharedConsole].logLevel >= iConsoleLogLevelNone)
    {
        va_list argList;
        va_start(argList,format);
        [self log:format arguments:argList];
        va_end(argList);
    }
}

+ (void)info:(NSString *)format, ...
{
    if ([self sharedConsole].logLevel >= iConsoleLogLevelInfo)
    {
        va_list argList;
        va_start(argList, format);
        [self log:[@"INFO: " stringByAppendingString:format] arguments:argList];
        va_end(argList);
    }
}

+ (void)warn:(NSString *)format, ...
{
	if ([self sharedConsole].logLevel >= iConsoleLogLevelWarning)
    {
        va_list argList;
        va_start(argList, format);
        [self log:[@"WARNING: " stringByAppendingString:format] arguments:argList];
        va_end(argList);
    }
}

+ (void)error:(NSString *)format, ...
{
    if ([self sharedConsole].logLevel >= iConsoleLogLevelError)
    {
        va_list argList;
        va_start(argList, format);
        [self log:[@"ERROR: " stringByAppendingString:format] arguments:argList];
        va_end(argList);
    }
}

+ (void)crash:(NSString *)format, ...
{
    if ([self sharedConsole].logLevel >= iConsoleLogLevelCrash)
    {
        va_list argList;
        va_start(argList, format);
        [self log:[@"CRASH: " stringByAppendingString:format] arguments:argList];
        va_end(argList);
    }
}

+ (void)clear
{
	[[iConsole sharedConsole] resetLog];
}

+ (void)show
{
	[[iConsole sharedConsole] showConsole];
}

+ (void)hide
{
	[[iConsole sharedConsole] hideConsole];
}

@end


@implementation iConsoleWindow

- (void)sendEvent:(UIEvent *)event
{
	if ([iConsole sharedConsole].enabled && event.type == UIEventTypeTouches)
	{
		NSSet *touches = [event allTouches];
		if ([touches count] == (TARGET_IPHONE_SIMULATOR ? [iConsole sharedConsole].simulatorTouchesToShow: [iConsole sharedConsole].deviceTouchesToShow))
		{
			BOOL allUp = YES;
			BOOL allDown = YES;
			BOOL allLeft = YES;
			BOOL allRight = YES;
			
			for (UITouch *touch in touches)
			{
				if ([touch locationInView:self].y <= [touch previousLocationInView:self].y)
				{
					allDown = NO;
				}
				if ([touch locationInView:self].y >= [touch previousLocationInView:self].y)
				{
					allUp = NO;
				}
				if ([touch locationInView:self].x <= [touch previousLocationInView:self].x)
				{
					allLeft = NO;
				}
				if ([touch locationInView:self].x >= [touch previousLocationInView:self].x)
				{
					allRight = NO;
				}
			}
			
			switch ([UIApplication sharedApplication].statusBarOrientation)
            {
                case UIInterfaceOrientationUnknown:
				case UIInterfaceOrientationPortrait:
                {
					if (allUp)
					{
						[iConsole show];
					}
					else if (allDown)
					{
						[iConsole hide];
					}
					break;
                }
				case UIInterfaceOrientationPortraitUpsideDown:
                {
					if (allDown)
					{
						[iConsole show];
					}
					else if (allUp)
					{
						[iConsole hide];
					}
					break;
                }
				case UIInterfaceOrientationLandscapeLeft:
                {
					if (allRight)
					{
						[iConsole show];
					}
					else if (allLeft)
					{
						[iConsole hide];
					}
					break;
                }
				case UIInterfaceOrientationLandscapeRight:
                {
					if (allLeft)
					{
						[iConsole show];
					}
					else if (allRight)
					{
						[iConsole hide];
					}
					break;
                }
			}
		}
	}
	return [super sendEvent:event];
}

- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event {
	
    if ([iConsole sharedConsole].enabled &&
        (TARGET_IPHONE_SIMULATOR ? [iConsole sharedConsole].simulatorShakeToShow: [iConsole sharedConsole].deviceShakeToShow))
    {
        if (event.type == UIEventTypeMotion && event.subtype == UIEventSubtypeMotionShake)
        {
            if ([iConsole sharedConsole].view.superview == nil)
            {
                [iConsole show];
            }
            else
            {
                [iConsole hide];
            }
        }
	}
	[super motionEnded:motion withEvent:event];
}

@end
