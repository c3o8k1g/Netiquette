//
//  main.m
//  Netiquette
//
//  Created by Patrick Wardle on 7/1/19.
//  Copyright © 2019 Objective-See. All rights reserved.
//

#import "main.h"
#import "sort.h"
#import "Event.h"
#import "Monitor.h"
#import "utilities.h"
#import "procInfo/procInfo.h"

#import <Cocoa/Cocoa.h>

//TODO: add features such as:
// 0. update check
// 1. add reverse dns lookup (in bg)
// 2. add filters (#apple #established #listen #nonapple

@import Sentry;

//main
// process cmdline args, show UI, etc
int main(int argc, const char * argv[])
{
    //return var
    int status = -1;
    
    //args
    NSArray* arguments = nil;
    
    //grab args
    arguments = [[NSProcessInfo processInfo] arguments];
    
    //disable stderr
    // crash reporter dumps info here
    disableSTDERR();
    
    //init crash reporting
    // kicks off sentry.io
    initCrashReporting();
    
    //dbg msg
    //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"starting main app (args: %@)", [[NSProcessInfo processInfo] arguments]]);
    
    //handle '-h' or '-help'
    if( (YES == [arguments containsObject:@"-h"]) ||
        (YES == [arguments containsObject:@"-help"]) )
    {
        //print usage
        usage();
        
        //done
        goto bail;
    }
    
    //handle '-scan'
    // cmdline scan without UI
    if(YES == [arguments containsObject:@"-list"])
    {
        //scan
        cmdlineInterface();
        
        //happy
        status = 0;
        
        //done
        goto bail;
    }
    
    //handle invalid args
    // allow `-psn_` cuz OS sometimes adds this?
    if( (arguments.count > 1) &&
        (YES != [arguments[1] hasPrefix:@"-psn_"]) &&
        (YES != [arguments[1] isEqualToString:@"-NSDocumentRevisionsDebugMode"]) )
    {
        //print usage
        usage();
        
        //done
        goto bail;
    }
    
    //running non-cmdline mode
    // so, make foreground so app has an dock icon, etc
    transformApp(kProcessTransformToForegroundApplication);
    
    //launch app normally
    status = NSApplicationMain(argc, argv);
    
bail:
    
    return status;
}

//print usage
void usage()
{
    //usage
    printf("\nNETIQUETTE USAGE:\n");
    printf(" -h or -help  display this usage info\n");
    printf(" -list        enumerate all network connections\n");
    printf(" -names       resolve remote host names (via DNS)\n");
    printf(" -pretty      JSON output is 'pretty-printed' for readability\n");
    printf(" -skipApple   ignore connections that belong to Apple processes \n\n");
    
    return;
}

//perform a cmdline scan
void cmdlineInterface()
{
    //monitor
    Monitor* monitor = nil;

    //events
    __block NSMutableDictionary* connections = nil;
    
    //output
    NSMutableString* output = nil;
    
    //wait semaphore
    dispatch_semaphore_t semaphore = 0;
    
    //init monitor
    monitor = [[Monitor alloc] init];
    
    //init wait semaphore
    semaphore = dispatch_semaphore_create(0);

    //start
    // once...
    [monitor start:0 callback:^(NSMutableDictionary* events) {
        
        //save
        connections = events;
        
        //trigger wait semaphore
        dispatch_semaphore_signal(semaphore);
        
    }];
    
    //wait for request to complete
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
    //stop monitor
    [monitor stop];
    
    //cleanup
    [monitor deinit];
    
    //format results
    // convert to JSON
    output = formatResults(sortEvents(connections), [[[NSProcessInfo processInfo] arguments] containsObject:@"-skipApple"]);
    
    //pretty print?
    if(YES == [[[NSProcessInfo processInfo] arguments] containsObject:@"-pretty"])
    {
        //make me pretty!
        printf("%s\n", prettifyJSON(output).UTF8String);
    }
    else
    {
        //output
        printf("%s\n", output.UTF8String);
    }

    return;
}
