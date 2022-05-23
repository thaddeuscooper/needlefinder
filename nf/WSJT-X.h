//
//  WSJT-X.h
//  nf
//
//  Created by Thaddeus Cooper on 5/23/22.
//

#ifndef WSJT_X_h
#define WSJT_X_h

typedef struct HeartbeatStruct {
    int8_t    uniqueKey;
    uint32  maximumSchemaNumber;
    int8_t    version;
    int8_t    revision;
} _HeartBeatStruct, *pHeartbeatStruct;

#endif /* WSJT_X_h */
