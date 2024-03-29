//
//  main.m
//  nf
//
//  Created by Thaddeus Cooper on 5/23/22.
//

#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <time.h>
#import <Foundation/Foundation.h>
#import "WSJT-X.h"
#import "MaidenheadGridSquares.h"

#define BUFLEN  512
#define NPACK   100
#define PORT    2237 //9932//2237


int strcontains(char *string, char *lookingFor) {
    int rc = 0;
    unsigned long lengthLookingFor;
    unsigned long stringLength;
    
    stringLength = strlen(string);
    lengthLookingFor = strlen(lookingFor);
    
    if ((strcmp(string, "") != 0) && (strcmp(lookingFor, "") != 0)) {
        for (unsigned long index = 0; index < (stringLength - lengthLookingFor) + 1; index++) {
            if (strncmp(&string[index], lookingFor, lengthLookingFor) == 0) {
                rc = 1;
            }
        }
    }
    return rc;
}

void showHelp(void) {
	printf("usage:\n");
	printf("nf -e entities...\n");
	printf("nf -i entities...\n");
	printf("nf grid squares...");
	printf("nf -h\n");

	printf("where -e listens for the entities and will alert when it finds one of them.\n");
	printf("      -i lists the grid squares for the specified entities and exits.\n");
	printf("      -h shows help and exits.\n");
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        struct sockaddr_in  	si_me;
        struct sockaddr_in  	si_other;
        int                		s;
        int                 	i;
        socklen_t           	slen;
        char                	buf[BUFLEN];
        ssize_t             	bufferLength;
        int                 	flags;
        char                	theString[255];
        ssize_t             	rc;
		MaidenheadGridSquares	*theGridSquares = [[MaidenheadGridSquares alloc] init];
		NSMutableSet			*setOfGridSquares = [NSMutableSet set];
		NSMutableArray			*allGridSquares = [NSMutableArray array];

        bufferLength = BUFLEN;
        flags = 0;
        
        if (argc >= 2) {
			if (strcmp(argv[1], "-e") == 0) {
				// User is specifying an entity, so go get all the grid squares for that entity.
				for (int index = 2; index < argc; index++) {
					NSString *theEntity;
					
					theEntity = [[NSString stringWithCString:argv[index] encoding:NSASCIIStringEncoding] uppercaseString];
					if ([[theGridSquares.maidenheadGridSquares allKeys] containsObject:theEntity]) {
						NSArray *nextGridSquares = [theGridSquares.maidenheadGridSquares valueForKey:theEntity];
						[setOfGridSquares addObjectsFromArray:nextGridSquares];
					}
				}
				allGridSquares = [[[setOfGridSquares allObjects] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)] mutableCopy];
				printf("Listening for:\n");
				for (int gridSquaresIndex = 0; gridSquaresIndex < allGridSquares.count; gridSquaresIndex++) {
					NSString *theGridSquare;
					
					theGridSquare = [allGridSquares objectAtIndex:gridSquaresIndex];
					printf("%s ", [theGridSquare UTF8String]);
				}
				printf("\n");
			}
			else if (strcmp(argv[1], "-i") == 0) {
				// User wants a list of all grid squares for an entity, so get all the grid squares and print them out.
				for (int index = 2; index < argc; index++) {
					NSString *theEntity;
					
					theEntity = [[NSString stringWithCString:argv[index] encoding:NSASCIIStringEncoding] uppercaseString];
					if ([[theGridSquares.maidenheadGridSquares allKeys] containsObject:theEntity]) {
						NSArray *nextGridSquares = [theGridSquares.maidenheadGridSquares valueForKey:theEntity];
						printf("%s:\n", [theEntity UTF8String]);
						for (int gsIndex = 0; gsIndex < nextGridSquares.count; gsIndex++) {
							NSString	*theGridSquare;
							
							theGridSquare = [nextGridSquares objectAtIndex:gsIndex];
							printf("%s ", [theGridSquare UTF8String]);
						}
						printf("\n");
					}
				}
				exit(0);
			}
			else if (strcmp(argv[1], "-h") == 0) {
				// User needs help. Show help and exit.
				showHelp();
				exit(0);
			}
			else if (argv[1][0] == '-') {
				// Unknown argument, so show help and exit.
				printf("Unknown argument: %s\n", argv[1]);
				showHelp();
				exit(-3);
			}
			else {
				// Otherwise, the user is specifying a list of grid squares to watch.
				for (int index = 2; index < argc; index++) {
					NSString	*theGridSquare;
					
					theGridSquare = [[NSString stringWithCString:argv[index] encoding:NSASCIIStringEncoding] uppercaseString];
					if (theGridSquare.length >= 4) {
						[allGridSquares addObject:theGridSquare];
					}
				}
			}
        }
        
        slen = sizeof(si_other);
        s = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
        if (s == -1) {
            printf("Unable to create socket, exiting. If you are not running multicast, it may be that another app is connected to WSJT-X.\n");
			exit(-4);
        }
        
        memset((char *)&si_me, 0, sizeof(si_me));
        si_me.sin_family = AF_INET;
        si_me.sin_port = htons(PORT);
        si_me.sin_addr.s_addr = htons(INADDR_ANY);
        
        
        rc = bind(s, (struct sockaddr *)&si_me, sizeof(si_me));
        if (rc == -1) {
			close(s);
			printf("Unable to connect to WSJT-X, exiting.\n");
			exit(-1);
        }
        
        while (1) {
            memset(buf, 0, sizeof(buf));
            for (i = 0; i < NPACK; i++) {
                rc = recvfrom(s, buf, bufferLength, flags, (struct sockaddr *)&si_other, &slen);
                if (rc == -1) {
					printf("An error occurred while listening to WSJT-X\nExiting.");
					exit(-2);
                }
                if (buf[7] == 2) {
                    for (int index = 8; index < 511; index++) {
                        if (((buf[index] == 'C') || (buf[index] == 'c')) && ((buf[index+1] =='Q') || (buf[index+1] == 'q'))) {
                            strcpy(theString, &buf[index]);
                            for (int argvIndex = 1; argvIndex < argc; argvIndex++) {
                                char *ptr;
                                struct tm   *localTime;
                                time_t      now;
                                
                                now = time(NULL);
                                localTime = localtime(&now);
                                ptr = (char *)argv[argvIndex];
								NSString *stringToCheck = [[NSString alloc] initWithCString:theString encoding:NSASCIIStringEncoding];
								NSArray *pieces = [stringToCheck componentsSeparatedByString:@" "];
								if (pieces.count >= 3) {
									if ([allGridSquares containsObject:[pieces objectAtIndex:2]]) {
										fprintf(stdout, "\a%d/%d/%d %d:%02d %s\n", localTime->tm_mon + 1, localTime->tm_mday, localTime->tm_year + 1900, localTime->tm_hour, localTime->tm_min, theString);
										fflush(stdout);
									}
								}
                                if (strcontains(theString, ptr)) {
                                    fprintf(stdout, "\a%d/%d/%d %d:%02d %s\n", localTime->tm_mon + 1, localTime->tm_mday, localTime->tm_year + 1900, localTime->tm_hour, localTime->tm_min, theString);
                                    fflush(stdout);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    return 0;
}

