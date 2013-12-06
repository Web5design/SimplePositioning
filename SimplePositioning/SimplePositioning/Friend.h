//
//  Friend.h
//  SimplePositioning
//
//  Created by André Hansson on 25/11/13.
//  Copyright (c) 2013 PingPal AB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface Friend : NSManagedObject

@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSString * uid;
@property (nonatomic, retain) NSString * fbid;

@end
