//
//  main.m
//  SIDPLAY
//
//  Created by Andreas Varga on 15.11.07.
//  Copyright __MyCompanyName__ 2007. All rights reserved.
//

#import <Cocoa/Cocoa.h>

int main(int argc, char *argv[])
{
    time_t seed;
    time(&seed);
    srandom(seed);

    return NSApplicationMain(argc,  (const char **) argv);
}
